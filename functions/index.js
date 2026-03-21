const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { randomBytes, createHash } = require("crypto");
const admin = require("firebase-admin");

admin.initializeApp();

const USERNAME_RE = /^[a-z0-9._-]{3,30}$/;
const CLASS_ID_RE = /^(?:[1-9]|1[0-2])[A-Z]$/;
const LOGIN_MAX_FAILURES = 5;
const LOGIN_BLOCK_SECONDS = 120;
const ACTOR_MAX_FAILURES = 5;
const ACTOR_BLOCK_SECONDS = 600;
const ATTEMPT_TOKEN_TTL_SECONDS = 300;
const ACTOR_KEY_RE = /^[a-f0-9]{32,128}$/;

function resolveActorKey(request) {
    const provided = String(request.data?.actorKey || "").trim().toLowerCase();
    if (ACTOR_KEY_RE.test(provided)) {
        return provided;
    }

    const forwardedFor = String(request.rawRequest?.headers?.["x-forwarded-for"] || "");
    const ip = forwardedFor.split(",")[0].trim();
    const ua = String(request.rawRequest?.headers?.["user-agent"] || "").trim();
    const appId = String(request.app?.appId || "").trim();
    const fingerprint = `${ip}|${ua}|${appId}`;
    const hasSignal = ip || ua || appId;
    if (!hasSignal) {
        return "";
    }

    return createHash("sha256").update(fingerprint).digest("hex");
}

function toMinutes(hhmm) {
    const [h, m] = String(hhmm || "").split(":").map((x) => parseInt(x, 10));
    if (Number.isNaN(h) || Number.isNaN(m)) return null;
    return h * 60 + m;
}

async function assertAdmin(request) {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data()?.role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate executa aceasta actiune");
    }

    return { callerUid, callerData: callerDoc.data() || {} };
}

async function getActiveAdminCount() {
    const snap = await admin.firestore().collection("users").where("role", "==", "admin").get();
    return snap.docs.filter((d) => String(d.data()?.status || "active") !== "disabled").length;
}

async function removeStudentFromParentChildren(studentUid) {
    const db = admin.firestore();
    const parentsSnap = await db.collection("users").where("children", "array-contains", studentUid).get();
    if (parentsSnap.empty) return;

    const batch = db.batch();
    for (const doc of parentsSnap.docs) {
        batch.update(doc.ref, {
            children: admin.firestore.FieldValue.arrayRemove(studentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
}

async function removeParentFromStudentParents(parentUid) {
    const db = admin.firestore();
    const studentsSnap = await db.collection("users").where("parents", "array-contains", parentUid).get();
    if (studentsSnap.empty) return;

    const batch = db.batch();
    for (const doc of studentsSnap.docs) {
        batch.update(doc.ref, {
            parents: admin.firestore.FieldValue.arrayRemove(parentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    await batch.commit();
}

async function deleteByQueryInChunks(query, chunkSize = 400) {
    let snap = await query.limit(chunkSize).get();
    while (!snap.empty) {
        const batch = admin.firestore().batch();
        for (const d of snap.docs) {
            batch.delete(d.ref);
        }
        await batch.commit();
        if (snap.size < chunkSize) break;
        snap = await query.limit(chunkSize).get();
    }
}

exports.authPrecheckLogin = onCall(async (request) => {
    const username = String(request.data?.username || "").trim().toLowerCase();
    const actorKey = resolveActorKey(request);
    if (!USERNAME_RE.test(username)) {
        throw new HttpsError("invalid-argument", "Username invalid");
    }

    const db = admin.firestore();
    const guardRef = db.collection("authLoginGuards").doc(username);
    const actorGuardRef = actorKey
        ? db.collection("authLoginActorGuards").doc(actorKey)
        : null;
    const guardSnap = await guardRef.get();
    const actorGuardSnap = actorGuardRef ? await actorGuardRef.get() : null;

    const nowMs = Date.now();
    const blockedUntilTs = guardSnap.data()?.blockedUntil;
    const blockedUntilMs = blockedUntilTs?.toMillis?.() || 0;
    const actorBlockedUntilTs = actorGuardSnap?.data()?.blockedUntil;
    const actorBlockedUntilMs = actorBlockedUntilTs?.toMillis?.() || 0;

    if (blockedUntilMs > nowMs || actorBlockedUntilMs > nowMs) {
        const remainingSeconds = Math.max(
            blockedUntilMs > nowMs ? Math.ceil((blockedUntilMs - nowMs) / 1000) : 0,
            actorBlockedUntilMs > nowMs ? Math.ceil((actorBlockedUntilMs - nowMs) / 1000) : 0,
        );
        return {
            blocked: true,
            remainingSeconds: Math.max(1, remainingSeconds),
            attemptToken: "",
        };
    }

    const attemptToken = randomBytes(24).toString("hex");
    await db.collection("authLoginAttemptTokens").doc(attemptToken).set({
        username,
        actorKey,
        used: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMs + ATTEMPT_TOKEN_TTL_SECONDS * 1000),
    });

    return { blocked: false, remainingSeconds: 0, attemptToken };
});

exports.authReportLoginFailure = onCall(async (request) => {
    const username = String(request.data?.username || "").trim().toLowerCase();
    const attemptToken = String(request.data?.attemptToken || "").trim();
    const actorKey = resolveActorKey(request);

    if (!USERNAME_RE.test(username) || !attemptToken) {
        throw new HttpsError("failed-precondition", "Date invalide");
    }

    const db = admin.firestore();
    const guardRef = db.collection("authLoginGuards").doc(username);
    const actorGuardRef = actorKey
        ? db.collection("authLoginActorGuards").doc(actorKey)
        : null;
    const tokenRef = db.collection("authLoginAttemptTokens").doc(attemptToken);

    const result = await db.runTransaction(async (tx) => {
        const tokenSnap = await tx.get(tokenRef);
        if (!tokenSnap.exists) {
            throw new HttpsError("failed-precondition", "Attempt token invalid");
        }

        const tokenData = tokenSnap.data() || {};
        if (String(tokenData.username || "") !== username) {
            throw new HttpsError("failed-precondition", "Attempt token invalid");
        }
        const tokenActorKey = String(tokenData.actorKey || "");
        if (tokenActorKey && tokenActorKey !== actorKey) {
            throw new HttpsError("failed-precondition", "Attempt token invalid");
        }
        if (tokenData.used === true) {
            throw new HttpsError("failed-precondition", "Attempt token folosit");
        }

        const expMs = tokenData.expiresAt?.toMillis?.() || 0;
        const nowMs = Date.now();
        if (expMs <= nowMs) {
            throw new HttpsError("failed-precondition", "Attempt token expirat");
        }

        const guardSnap = await tx.get(guardRef);
        const actorGuardSnap = actorGuardRef ? await tx.get(actorGuardRef) : null;
        const guardData = guardSnap.data() || {};
        const actorGuardData = actorGuardSnap?.data() || {};
        const blockedUntilMs = guardData.blockedUntil?.toMillis?.() || 0;
        const actorBlockedUntilMs = actorGuardData.blockedUntil?.toMillis?.() || 0;

        // Firestore transactions require all reads before writes.
        tx.set(tokenRef, {
            used: true,
            usedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        if (blockedUntilMs > nowMs || actorBlockedUntilMs > nowMs) {
            const remainingSeconds = Math.max(
                blockedUntilMs > nowMs ? Math.ceil((blockedUntilMs - nowMs) / 1000) : 0,
                actorBlockedUntilMs > nowMs ? Math.ceil((actorBlockedUntilMs - nowMs) / 1000) : 0,
            );
            return {
                blocked: true,
                remainingSeconds: Math.max(1, remainingSeconds),
            };
        }

        const failures = Number(guardData.failures || 0) + 1;
        const actorFailures = Number(actorGuardData.failures || 0) + 1;
        let blocked = false;
        let remainingSeconds = 0;

        if (failures >= LOGIN_MAX_FAILURES) {
            blocked = true;
            remainingSeconds = LOGIN_BLOCK_SECONDS;
            tx.set(guardRef, {
                failures: 0,
                blockedUntil: admin.firestore.Timestamp.fromMillis(nowMs + LOGIN_BLOCK_SECONDS * 1000),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        } else {
            tx.set(guardRef, {
                failures,
                blockedUntil: null,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }

        if (actorGuardRef && actorFailures >= ACTOR_MAX_FAILURES) {
            blocked = true;
            remainingSeconds = Math.max(remainingSeconds, ACTOR_BLOCK_SECONDS);
            tx.set(actorGuardRef, {
                failures: 0,
                blockedUntil: admin.firestore.Timestamp.fromMillis(nowMs + ACTOR_BLOCK_SECONDS * 1000),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        } else if (actorGuardRef) {
            tx.set(actorGuardRef, {
                failures: actorFailures,
                blockedUntil: null,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }

        return { blocked, remainingSeconds };
    });

    return result;
});

exports.authRegisterLoginSuccess = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const userSnap = await admin.firestore().collection("users").doc(uid).get();
    if (!userSnap.exists) {
        return { ok: true };
    }

    const username = String(userSnap.data()?.username || "").trim().toLowerCase();
    if (!username) {
        return { ok: true };
    }

    await admin.firestore().collection("authLoginGuards").doc(username).set({
        failures: 0,
        blockedUntil: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const actorKey = String(request.data?.actorKey || "").trim().toLowerCase();
    if (ACTOR_KEY_RE.test(actorKey)) {
        await admin.firestore().collection("authLoginActorGuards").doc(actorKey).set({
            failures: 0,
            blockedUntil: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    return { ok: true };
});

exports.adminCreateUser = onCall(async (request) => {
    const { callerUid } = await assertAdmin(request);

    const data = request.data;
    const username = String(data.username || "").trim().toLowerCase();
    const password = String(data.password || "").trim();
    const fullName = String(data.fullName || "").trim();
    const role = String(data.role || "").trim();
    const classId = data.classId ? String(data.classId).trim().toUpperCase() : null;

    if (!username || !password || !fullName || !role) {
        throw new HttpsError("invalid-argument", "Lipsesc campuri obligatorii");
    }

    if (!USERNAME_RE.test(username)) {
        throw new HttpsError("invalid-argument", "Username invalid. Foloseste 3-30 caractere: litere mici, cifre, . _ -");
    }
    if (password.length < 6) {
        throw new HttpsError("invalid-argument", "Parola trebuie sa aiba minim 6 caractere");
    }
    if (fullName.length < 3) {
        throw new HttpsError("invalid-argument", "Numele complet este prea scurt");
    }

    const allowedRoles = new Set(["student", "teacher", "admin", "parent", "gate"]);
    if (!allowedRoles.has(role)) {
        throw new HttpsError("invalid-argument", "Rol invalid");
    }

    if (role === "student" || role === "teacher") {
        if (!classId) {
            throw new HttpsError("invalid-argument", `Pentru ${role} trebuie selectata o clasa`);
        }
        if (!CLASS_ID_RE.test(classId)) {
            throw new HttpsError("invalid-argument", "Format clasa invalid (ex: 9A, 10B)");
        }

        const classSnap = await admin.firestore().collection("classes").doc(classId).get();
        if (!classSnap.exists) {
            throw new HttpsError("not-found", `Clasa ${classId} nu exista`);
        }

        if (role === "teacher") {
            const existingTeacher = String(classSnap.data()?.teacherUsername || "")
                .trim()
                .toLowerCase();
            if (existingTeacher) {
                throw new HttpsError(
                    "failed-precondition",
                    `Clasa ${classId} are deja diriginte: ${existingTeacher}`
                );
            }
        }
    }

    if (role === "admin" && classId) {
        throw new HttpsError("invalid-argument", "Administratorul nu poate avea classId");
    }

    // Don't allow creating duplicate username in Firestore legacy docs.
    const duplicates = await admin.firestore().collection("users").where("username", "==", username).limit(1).get();
    if (!duplicates.empty) {
        throw new HttpsError("already-exists", `Username '${username}' exista deja`);
    }


    const email = `${username}@school.local`;

    const user = await admin.auth().createUser({
        email,
        password,
        displayName: fullName,
    });

    try {
        await admin.firestore().collection("users").doc(user.uid).set({
            username,
            fullName,
            role,
            classId: role === "student" || role === "teacher" ? classId : null,
            status: "active",
            inSchool: false,
            lastInAt: null,
            lastOutAt: null,
            createdBy: callerUid,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // daca este profesor si are clasa -> seteaza dirigintele clasei doar daca e libera
        if (role === "teacher" && classId) {
            await admin.firestore().runTransaction(async (tx) => {
                const classRef = admin.firestore().collection("classes").doc(classId);
                const classSnap = await tx.get(classRef);

                if (!classSnap.exists) {
                    throw new HttpsError("not-found", `Clasa ${classId} nu exista`);
                }

                const existingTeacher = String(classSnap.data()?.teacherUsername || "")
                    .trim()
                    .toLowerCase();
                if (existingTeacher && existingTeacher !== username) {
                    throw new HttpsError(
                        "failed-precondition",
                        `Clasa ${classId} are deja diriginte: ${existingTeacher}`
                    );
                }

                tx.set(classRef, {
                    name: classId,
                    teacherUsername: username,
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            });
        }
    } catch (e) {
        // rollback auth user in case firestore/class assignment fails
        try {
            await admin.auth().deleteUser(user.uid);
        } catch (_) {
            // ignore rollback failures
        }
        throw e;
    }

    return { uid: user.uid };

});
async function getUidByUsername(username) {
    const uname = String(username || "").trim().toLowerCase();
    if (!uname) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }

    const snap = await admin.firestore()
        .collection("users")
        .where("username", "==", uname)
        .limit(1)
        .get();

    if (snap.empty) {
        throw new HttpsError("not-found", `User '${uname}' nu exista`);
    }

    return snap.docs[0].id; // uid
}

async function getUidByUsernameOrEmail(username) {
    const uname = String(username || "").trim().toLowerCase();
    if (!uname) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }

    try {
        return await getUidByUsername(uname);
    } catch (e) {
        // fallback on auth email when Firestore doc is already missing
    }

    try {
        const authUser = await admin.auth().getUserByEmail(`${uname}@school.local`);
        return authUser.uid;
    } catch (e) {
        throw new HttpsError("not-found", `User '${uname}' nu exista`);
    }
}
exports.adminResetPassword = onCall(async (request) => {
    await assertAdmin(request);

    const username = String(request.data.username || "").trim().toLowerCase();
    const uid = await getUidByUsername(username);

    const targetDoc = await admin.firestore().collection("users").doc(uid).get();
    if (targetDoc.exists && String(targetDoc.data()?.status || "active") === "disabled") {
        throw new HttpsError("failed-precondition", "Contul este dezactivat. Activeaza contul inainte de resetare.");
    }

    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
    const newPass = Array.from({ length: 10 }, () =>
        chars[Math.floor(Math.random() * chars.length)]
    ).join("");

    await admin.auth().updateUser(uid, { password: newPass });

    await admin.firestore().collection("users").doc(uid).set({
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { password: newPass, uid };
});


exports.adminSetDisabled = onCall(async (request) => {
    const { callerUid } = await assertAdmin(request);

    const username = String(request.data.username || "").trim().toLowerCase();
    const disabled = request.data.disabled === true;
    const uid = await getUidByUsername(username);

    if (uid === callerUid) {
        throw new HttpsError("failed-precondition", "Nu iti poti modifica propriul status");
    }

    const targetDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!targetDoc.exists) {
        throw new HttpsError("not-found", "Utilizator inexistent");
    }

    const targetData = targetDoc.data() || {};
    const targetRole = String(targetData.role || "");
    const currentStatus = String(targetData.status || "active");

    if (targetRole === "admin" && disabled) {
        const activeAdmins = await getActiveAdminCount();
        if (currentStatus !== "disabled" && activeAdmins <= 1) {
            throw new HttpsError("failed-precondition", "Nu poti dezactiva ultimul administrator activ");
        }
    }

    if ((disabled && currentStatus === "disabled") || (!disabled && currentStatus === "active")) {
        return { ok: true, uid, changed: false, status: currentStatus };
    }

    await admin.auth().updateUser(uid, { disabled });

    await admin.firestore().collection("users").doc(uid).set({
        status: disabled ? "disabled" : "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid, changed: true, status: disabled ? "disabled" : "active" };
});


exports.adminMoveStudentClass = onCall(async (request) => {
    await assertAdmin(request);

    const username = String(request.data.username || "").trim().toLowerCase();
    const newClassId = String(request.data.newClassId || "").trim().toUpperCase();

    if (!newClassId) {
        throw new HttpsError("invalid-argument", "newClassId lipsa");
    }
    if (!CLASS_ID_RE.test(newClassId)) {
        throw new HttpsError("invalid-argument", "Format clasa invalid");
    }

    const uid = await getUidByUsername(username);

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const classRef = db.collection("classes").doc(newClassId);

    await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) {
            throw new HttpsError("not-found", "User inexistent");
        }

        const userData = userSnap.data() || {};
        const role = String(userData.role || "");
        if (role !== "student" && role !== "teacher") {
            throw new HttpsError("failed-precondition", "Doar student/teacher poate fi mutat");
        }

        const classSnap = await tx.get(classRef);
        if (!classSnap.exists) {
            throw new HttpsError("not-found", `Clasa ${newClassId} nu exista`);
        }
        const oldClassId = String(userData.classId || "").trim().toUpperCase();

        if (role === "teacher") {
            const classData = classSnap.exists ? (classSnap.data() || {}) : {};
            const existingTeacher = String(classData.teacherUsername || "")
                .trim()
                .toLowerCase();

            if (existingTeacher && existingTeacher !== username) {
                throw new HttpsError(
                    "failed-precondition",
                    `Clasa ${newClassId} are deja diriginte: ${existingTeacher}`
                );
            }
        }

        tx.update(userRef, {
            classId: newClassId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        if (role === "teacher") {
            if (oldClassId && oldClassId !== newClassId) {
                const oldClassRef = db.collection("classes").doc(oldClassId);
                tx.set(oldClassRef, {
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
                tx.update(oldClassRef, {
                    teacherUsername: admin.firestore.FieldValue.delete(),
                });
            }

            tx.set(classRef, {
                name: newClassId,
                teacherUsername: username,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
    });

    return { ok: true, uid };
});


// ---------- new function for deleting users ----------
exports.adminDeleteUser = onCall(async (request) => {
    const { callerUid } = await assertAdmin(request);

    const username = String(request.data.username || "").trim().toLowerCase();
    if (!username) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }

    const db = admin.firestore();
    const uid = await getUidByUsernameOrEmail(username);

    // Determine user data from uid doc or username query fallback.
    let userDocRef = db.collection("users").doc(uid);
    let userDocSnap = await userDocRef.get();
    let userData = userDocSnap.exists ? (userDocSnap.data() || {}) : null;

    if (!userData) {
        const byUsernameSnap = await db
            .collection("users")
            .where("username", "==", username)
            .limit(1)
            .get();
        if (!byUsernameSnap.empty) {
            userDocRef = byUsernameSnap.docs[0].ref;
            userDocSnap = byUsernameSnap.docs[0];
            userData = byUsernameSnap.docs[0].data() || {};
        }
    }

    const role = String(userData?.role || "").trim().toLowerCase();
    const classId = String(userData?.classId || "").trim().toUpperCase();

    if (uid === callerUid) {
        throw new HttpsError("failed-precondition", "Nu iti poti sterge propriul cont");
    }

    if (role === "admin") {
        const status = String(userData?.status || "active");
        const activeAdmins = await getActiveAdminCount();
        if (status !== "disabled" && activeAdmins <= 1) {
            throw new HttpsError("failed-precondition", "Nu poti sterge ultimul administrator activ");
        }
    }

    // If deleted user is a homeroom teacher, clear all class references.
    if (role === "teacher") {
        const linkedClassesSnap = await db
            .collection("classes")
            .where("teacherUsername", "==", username)
            .get();

        if (!linkedClassesSnap.empty) {
            const batch = db.batch();
            for (const classDoc of linkedClassesSnap.docs) {
                batch.set(classDoc.ref, {
                    teacherUsername: admin.firestore.FieldValue.delete(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
            await batch.commit();
        }

        // Legacy safeguard when classId exists but teacherUsername was not indexed/queryable.
        if (classId) {
            const classRef = db.collection("classes").doc(classId);
            const classSnap = await classRef.get();
            if (classSnap.exists) {
                const currentTeacher = String(classSnap.data()?.teacherUsername || "")
                    .trim()
                    .toLowerCase();
                if (currentTeacher === username) {
                    await classRef.set({
                        teacherUsername: admin.firestore.FieldValue.delete(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    }, { merge: true });
                }
            }
        }
    }

    if (role === "student") {
        await removeStudentFromParentChildren(uid);
        await deleteByQueryInChunks(db.collection("leaveRequests").where("studentUid", "==", uid));
        await deleteByQueryInChunks(db.collection("accessEvents").where("userId", "==", uid));
    }

    if (role === "parent") {
        await removeParentFromStudentParents(uid);
    }

    // Delete Firestore user docs by uid and by username (for legacy inconsistencies).
    if (userDocSnap.exists) {
        await userDocRef.delete();
    }
    const duplicates = await db
        .collection("users")
        .where("username", "==", username)
        .get();
    for (const d of duplicates.docs) {
        if (d.id !== userDocRef.id) {
            await d.ref.delete();
        }
    }

    // Delete auth account.
    try {
        await admin.auth().deleteUser(uid);
    } catch (e) {
        // ignore if user already gone
    }

    return { ok: true, uid };
});


exports.adminCreateClass = onCall(async (request) => {
    await assertAdmin(request);

    const classId = String(request.data?.name || "").trim().toUpperCase();
    if (!classId) {
        throw new HttpsError("invalid-argument", "Numele clasei este obligatoriu");
    }
    if (!CLASS_ID_RE.test(classId)) {
        throw new HttpsError("invalid-argument", "Format clasa invalid (ex: 9A, 10B)");
    }

    const classRef = admin.firestore().collection("classes").doc(classId);
    try {
        await classRef.create({
            name: classId,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    } catch (e) {
        if (e && e.code === 6) {
            throw new HttpsError("already-exists", `Clasa ${classId} exista deja`);
        }
        throw e;
    }

    return { ok: true, classId };
});

exports.adminSetClassNoExitSchedule = onCall(async (request) => {
    await assertAdmin(request);

    const classId = String(request.data.classId || "").trim().toUpperCase();
    const startHHmm = String(request.data.startHHmm || "").trim();
    const endHHmm = String(request.data.endHHmm || "").trim();

    let days = [1, 2, 3, 4, 5];
    if (Array.isArray(request.data.days) && request.data.days.length > 0) {
        days = request.data.days.map((d) => parseInt(d, 10)).filter((d) => !isNaN(d) && d >= 1 && d <= 5);
        if (days.length === 0) {
            days = [1, 2, 3, 4, 5];
        }
    }

    if (!classId || !startHHmm || !endHHmm) {
        throw new HttpsError("invalid-argument", "Campuri lipsa");
    }
    if (!CLASS_ID_RE.test(classId)) {
        throw new HttpsError("invalid-argument", "Format clasa invalid");
    }

    const hhmm = /^\d{2}:\d{2}$/;
    if (!hhmm.test(startHHmm) || !hhmm.test(endHHmm)) {
        throw new HttpsError("invalid-argument", "Format invalid. Foloseste HH:mm");
    }

    const startMinutes = toMinutes(startHHmm);
    const endMinutes = toMinutes(endHHmm);
    if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
        throw new HttpsError("invalid-argument", "Interval orar invalid (ora finala trebuie sa fie dupa ora de inceput)");
    }

    const classRef = admin.firestore().collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        throw new HttpsError("not-found", `Clasa ${classId} nu exista`);
    }

    await classRef.set({
        noExitStart: startHHmm,
        noExitEnd: endHHmm,
        noExitDays: days,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, days: days };
});

exports.adminSetClassSchedulePerDay = onCall(async (request) => {
    try {
        await assertAdmin(request);

        const classId = String(request.data.classId || "").trim().toUpperCase();
        const scheduleData = request.data.schedule;

        if (!classId || !scheduleData || typeof scheduleData !== "object" || Object.keys(scheduleData).length === 0) {
            throw new HttpsError("invalid-argument", "Missing classId, schedule, or empty schedule");
        }
        if (!CLASS_ID_RE.test(classId)) {
            throw new HttpsError("invalid-argument", "Format clasa invalid");
        }

        const hhmm = /^\d{2}:\d{2}$/;
        const schedule = {};

        for (const [dayStr, timesObj] of Object.entries(scheduleData)) {
            const dayNum = parseInt(dayStr, 10);
            if (isNaN(dayNum) || dayNum < 1 || dayNum > 5) {
                throw new HttpsError("invalid-argument", `Invalid day number: ${dayStr}`);
            }

            const startTime = timesObj?.start || timesObj?.["start"];
            const endTime = timesObj?.end || timesObj?.["end"];

            if (!startTime || !endTime) {
                throw new HttpsError("invalid-argument", `Missing start/end time for day ${dayNum}`);
            }

            if (!hhmm.test(String(startTime)) || !hhmm.test(String(endTime))) {
                throw new HttpsError("invalid-argument", `Invalid time format for day ${dayNum}`);
            }

            const startMinutes = toMinutes(startTime);
            const endMinutes = toMinutes(endTime);
            if (startMinutes == null || endMinutes == null || endMinutes <= startMinutes) {
                throw new HttpsError("invalid-argument", `Interval invalid pentru ziua ${dayNum}`);
            }

            schedule[dayNum.toString()] = {
                start: String(startTime),
                end: String(endTime)
            };
        }

        const classRef = admin.firestore().collection("classes").doc(classId);
        const classSnap = await classRef.get();

        if (!classSnap.exists) {
            throw new HttpsError("not-found", `Class ${classId} does not exist`);
        }

        await classRef.set({
            schedule: schedule,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        return { ok: true, schedule: schedule };
    } catch (error) {
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError("internal", `Unexpected error: ${error.message}`);
    }
});

exports.adminDeleteClassCascade = onCall(async (request) => {
    await assertAdmin(request);

    const classId = String(request.data.classId || "").trim().toUpperCase();
    if (!classId) {
        throw new HttpsError("invalid-argument", "classId lipsa");
    }
    if (!CLASS_ID_RE.test(classId)) {
        throw new HttpsError("invalid-argument", "Format clasa invalid");
    }

    const db = admin.firestore();
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        throw new HttpsError("not-found", `Clasa ${classId} nu exista`);
    }

    const linkedUsers = await db.collection("users").where("classId", "==", classId).limit(1).get();
    const teacherUsername = String(classSnap.data()?.teacherUsername || "").trim();
    if (!linkedUsers.empty || teacherUsername.isNotEmpty) {
        throw new HttpsError(
            "failed-precondition",
            `Clasa ${classId} are utilizatori/diriginte asignati. Muta sau sterge utilizatorii inainte.`
        );
    }

    await classRef.delete();

    return { ok: true };
});

exports.adminAssignParentToStudent = onCall(async (request) => {
    await assertAdmin(request);

    const studentUid = String(request.data.studentUid || "").trim();
    const parentUid = String(request.data.parentUid || "").trim();
    if (!studentUid || !parentUid) {
        throw new HttpsError("invalid-argument", "studentUid si parentUid sunt obligatorii");
    }
    if (studentUid === parentUid) {
        throw new HttpsError("invalid-argument", "Un utilizator nu poate fi propriul parinte");
    }

    const db = admin.firestore();
    const studentRef = db.collection("users").doc(studentUid);
    const parentRef = db.collection("users").doc(parentUid);

    return db.runTransaction(async (tx) => {
        const [studentSnap, parentSnap] = await Promise.all([tx.get(studentRef), tx.get(parentRef)]);
        if (!studentSnap.exists) {
            throw new HttpsError("not-found", "Elev inexistent");
        }
        if (!parentSnap.exists) {
            throw new HttpsError("not-found", "Parinte inexistent");
        }

        const studentData = studentSnap.data() || {};
        const parentData = parentSnap.data() || {};
        if (String(studentData.role || "") !== "student") {
            throw new HttpsError("failed-precondition", "Target-ul elev nu are rol student");
        }
        if (String(parentData.role || "") !== "parent") {
            throw new HttpsError("failed-precondition", "Target-ul parinte nu are rol parent");
        }

        const parents = Array.isArray(studentData.parents) ? studentData.parents.map(String) : [];
        if (parents.includes(parentUid)) {
            return { ok: true, changed: false };
        }
        if (parents.length >= 2) {
            throw new HttpsError("failed-precondition", "Elevul are deja 2 parinti atribuiti");
        }

        tx.update(studentRef, {
            parents: admin.firestore.FieldValue.arrayUnion(parentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(parentRef, {
            children: admin.firestore.FieldValue.arrayUnion(studentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return { ok: true, changed: true };
    });
});

exports.adminRemoveParentFromStudent = onCall(async (request) => {
    await assertAdmin(request);

    const studentUid = String(request.data.studentUid || "").trim();
    const parentUid = String(request.data.parentUid || "").trim();
    if (!studentUid || !parentUid) {
        throw new HttpsError("invalid-argument", "studentUid si parentUid sunt obligatorii");
    }

    const db = admin.firestore();
    const studentRef = db.collection("users").doc(studentUid);
    const parentRef = db.collection("users").doc(parentUid);

    return db.runTransaction(async (tx) => {
        const [studentSnap, parentSnap] = await Promise.all([tx.get(studentRef), tx.get(parentRef)]);
        if (!studentSnap.exists) {
            throw new HttpsError("not-found", "Elev inexistent");
        }
        if (!parentSnap.exists) {
            throw new HttpsError("not-found", "Parinte inexistent");
        }

        tx.update(studentRef, {
            parents: admin.firestore.FieldValue.arrayRemove(parentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(parentRef, {
            children: admin.firestore.FieldValue.arrayRemove(studentUid),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { ok: true, changed: true };
    });
});
exports.generateQrToken = onCall(async (request) => {

    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;

    const rand = Math.random().toString().slice(2, 18);

    const expiresAt = new Date(Date.now() + 20000); // 20 sec

    await admin.firestore().collection("qrTokens").doc(rand).set({
        userId: uid,
        expiresAt: expiresAt,
        used: false
    });

    return {
        token: rand
    };

});

exports.redeemQrToken = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;

    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists) {
        throw new HttpsError("permission-denied", "Profil inexistent");
    }

    const callerData = callerDoc.data();
    if (callerData.role !== "gate" && callerData.role !== "admin") {
        throw new HttpsError("permission-denied", "Doar poarta/admin poate valida QR");
    }

    const tokenId = String(request.data.token || "").trim();
    if (!tokenId) {
        throw new HttpsError("invalid-argument", "Token lipsa");
    }

    const db = admin.firestore();
    const tokenRef = db.collection("qrTokens").doc(tokenId);

    let accessEventToLog = null;

    const result = await db.runTransaction(async (tx) => {
        const snap = await tx.get(tokenRef);

        if (!snap.exists) {
            return { ok: false, reason: "NOT_FOUND", type: "deny" };
        }

        const data = snap.data() || {};
        const used = data.used === true;
        const userId = String(data.userId || "");
        const expiresAt = data.expiresAt;

        if (used) {
            return { ok: false, reason: "ALREADY_USED", userId, type: "deny" };
        }

        if (!expiresAt || typeof expiresAt.toDate !== "function") {
            return { ok: false, reason: "BAD_EXPIRES", userId };
        }

        const nowMs = Date.now();
        const expMs = expiresAt.toDate().getTime();

        if (expMs <= nowMs) {
            return { ok: false, reason: "EXPIRED", userId, type: "deny" };
        }

        const userRef = db.collection("users").doc(userId);
        const userSnap = await tx.get(userRef);

        if (!userSnap.exists) {
            return { ok: false, reason: "USER_NOT_FOUND", userId, type: "deny" };
        }

        const userData = userSnap.data() || {};
        const inSchool = userData.inSchool === true;
        const status = String(userData.status || "active");
        const fullName = String(userData.fullName || userData.username || userId);
        const classId = String(userData.classId || "");

        if (status === "disabled") {
            return {
                ok: false,
                reason: "USER_DISABLED",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }

        // --- Class timetable check added here ---
        if (!classId) {
            return {
                ok: false,
                reason: "NO_CLASS_ASSIGNED",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }

        const classRef = db.collection("classes").doc(classId);
        const classSnap = await tx.get(classRef);
        const classData = classSnap.exists ? classSnap.data() || {} : {};
        const schedule = classData.schedule || {};

        // Use local school timezone (e.g. Europe/Bucharest) for timetable checks,
        // because Cloud Functions uses UTC by default and can be 2-3h behind local time.
        const localNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
        const dayIdx = localNow.getDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday
        if (dayIdx < 1 || dayIdx > 5) {
            return {
                ok: false,
                reason: "OUTSIDE_CLASS_DAY",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }

        const now = localNow;

        const dayKey = String(dayIdx);
        const daySchedule = schedule[dayKey];
        if (!daySchedule || !daySchedule.start || !daySchedule.end) {
            return {
                ok: false,
                reason: "NO_SCHEDULE",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }

        const parseTime = (s) => {
            const parts = String(s).split(":").map((x) => parseInt(x, 10));
            if (parts.length !== 2 || Number.isNaN(parts[0]) || Number.isNaN(parts[1])) {
                return null;
            }
            return parts[0] * 60 + parts[1];
        };

        const startMinutes = parseTime(daySchedule.start);
        const endMinutes = parseTime(daySchedule.end);

        if (startMinutes == null || endMinutes == null || endMinutes < startMinutes) {
            return {
                ok: false,
                reason: "BAD_SCHEDULE",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }

        const nowMinutes = now.getHours() * 60 + now.getMinutes();
        const isWithinSchedule = nowMinutes >= startMinutes && nowMinutes <= endMinutes;
        const isAfterSchedule = nowMinutes > endMinutes;
        const isBeforeSchedule = nowMinutes < startMinutes;

        // approvedLeaveExit was determined before the transaction via a plain query.
        // (tx.get(query) is unreliable with multi-field filters in firebase-admin v13)

        const nowTs = admin.firestore.FieldValue.serverTimestamp();

        tx.update(tokenRef, {
            used: true,
            usedAt: nowTs,
            redeemedBy: callerUid,
        });

        let eventType = "entry";
        let result = {
            ok: true,
            userId,
            fullName,
            classId,
            type: "entry"
        };

        if (!inSchool) {
            // student entering school (now allowed regardless of timetable)
            tx.update(userRef, {
                inSchool: true,
                lastInAt: nowTs,
                // keep lastOutAt as is, do not clear it
            });
        } else if (inSchool && (isAfterSchedule || isBeforeSchedule)) {
            // student exiting outside class hours (before or after schedule)
            eventType = "exit";
            tx.update(userRef, {
                inSchool: false,
                // keep lastInAt as is, do not clear it
                lastOutAt: nowTs,
            });
            result.type = "exit";
        } else if (approvedLeaveExit) {
            // student has an approved leave request for right now — allow early exit
            eventType = "exit";
            tx.update(userRef, {
                inSchool: false,
                lastOutAt: nowTs,
            });
            result = {
                ok: true,
                userId,
                fullName,
                classId,
                type: "exit"
            };
        } else {
            // student already in school during class hours, no approved leave
            eventType = "deny";
            result = {
                ok: false,
                reason: "ALREADY_IN_SCHOOL",
                userId,
                fullName,
                classId,
                type: "deny"
            };
        }
        // Capture access event data — will be logged after the transaction commits
        accessEventToLog = {
            gateUid: callerUid,
            userId,
            fullName,
            classId,
            gateUid: callerUid,
            timestamp: nowTs,
            fullName,
            tokenId,
        };
        return result;
    });

    // Log access event AFTER the transaction commits, properly awaited
    // (doing it inside the callback is wrong: it's not part of the transaction,
    //  it's not awaited, and it runs again on every retry)
    if (accessEventToLog) {
        await db.collection('accessEvents').add(accessEventToLog);
    }

    return result;
});

exports.cleanupExpiredQrTokens = onSchedule("every 60 minutes", async (event) => {
    const db = admin.firestore();
    const cutoff = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
    const expiredSnap = await db.collection("qrTokens")
        .where("expiresAt", "<=", cutoff)
        .get();

    if (expiredSnap.empty) {
        console.log("cleanupExpiredQrTokens: no expired QR tokens found");
        return;
    }

    const docs = expiredSnap.docs;
    const chunkSize = 500;
    let deletedCount = 0;

    for (let i = 0; i < docs.length; i += chunkSize) {
        const chunk = docs.slice(i, i + chunkSize);
        const batch = db.batch();
        chunk.forEach((doc) => batch.delete(doc.ref));
        await batch.commit();
        deletedCount += chunk.length;
    }

    console.log(`cleanupExpiredQrTokens: deleted ${deletedCount} expired QR tokens`);
});

// Increment unreadCount when a new accessEvent is created for a student
exports.onAccessEventCreated = onDocumentCreated("accessEvents/{docId}", async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const userId = String(data.userId || "").trim();
    if (!userId) return;

    const userRef = admin.firestore().collection("users").doc(userId);

    await userRef.set(
        { unreadCount: admin.firestore.FieldValue.increment(1) },
        { merge: true }
    );

    // Send push notification
    const userDoc = await userRef.get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const eventType = String(data.type || "");
    const title = eventType === "exit" ? "Ai iesit din scoala" : "Ai intrat in scoala";
    const body = eventType === "exit"
        ? "Iesirea ta a fost inregistrata."
        : "Intrarea ta a fost inregistrata.";

    try {
        await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            android: { notification: { channelId: "student_channel" } },
        });
    } catch (e) {
        console.error("onAccessEventCreated: FCM send failed:", e.message);
    }
});

// Cancel (expire) leave requests whose date has passed — runs every hour
exports.cleanupExpiredLeaveRequests = onSchedule("every 60 minutes", async (event) => {
    const db = admin.firestore();

    // Get today's date in Romania (Bucharest) timezone
    const now = new Date();
    const roNow = new Date(now.toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
    const roYear = roNow.getFullYear();
    const roMonth = roNow.getMonth() + 1; // 1-based
    const roDay = roNow.getDate();

    // Fetch all pending & approved leave requests
    const snap = await db.collection("leaveRequests")
        .where("status", "in", ["pending", "approved"])
        .get();

    if (snap.empty) {
        console.log("cleanupExpiredLeaveRequests: no pending/approved requests found");
        return;
    }

    const toExpire = [];

    for (const doc of snap.docs) {
        const data = doc.data();
        const dateText = String(data.dateText || "");

        // Parse DD.MM.YYYY
        const parts = dateText.split(".");
        if (parts.length !== 3) continue;

        const reqDay = parseInt(parts[0], 10);
        const reqMonth = parseInt(parts[1], 10);
        const reqYear = parseInt(parts[2], 10);

        if (isNaN(reqDay) || isNaN(reqMonth) || isNaN(reqYear)) continue;

        // Expire if requested date is strictly before today (Romania timezone)
        const isPast =
            reqYear < roYear ||
            (reqYear === roYear && reqMonth < roMonth) ||
            (reqYear === roYear && reqMonth === roMonth && reqDay < roDay);

        if (isPast) {
            toExpire.push(doc.ref);
        }
    }

    if (toExpire.length === 0) {
        console.log("cleanupExpiredLeaveRequests: nothing to expire");
        return;
    }

    // Firestore batch limit is 500
    const chunkSize = 500;
    for (let i = 0; i < toExpire.length; i += chunkSize) {
        const chunk = toExpire.slice(i, i + chunkSize);
        const batch = db.batch();
        for (const ref of chunk) {
            batch.update(ref, {
                status: "expired",
                expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            });
        }
        await batch.commit();
    }

    console.log(`cleanupExpiredLeaveRequests: expired ${toExpire.length} leave request(s)`);
});

// Increment unreadCount for student when leave request is approved or rejected
exports.onLeaveRequestStatusChanged = onDocumentUpdated("leaveRequests/{docId}", async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();
    if (!before || !after) return;

    const prevStatus = String(before.status || "");
    const newStatus = String(after.status || "");

    // Only fire when status changes to approved or rejected
    if (prevStatus === newStatus) return;
    if (newStatus !== "approved" && newStatus !== "rejected") return;

    const studentUid = String(after.studentUid || "").trim();
    if (!studentUid) return;

    const userRef = admin.firestore().collection("users").doc(studentUid);

    await userRef.set(
        { unreadCount: admin.firestore.FieldValue.increment(1) },
        { merge: true }
    );

    // Send push notification
    const userDoc = await userRef.get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const title = newStatus === "approved" ? "Cerere aprobata" : "Cerere respinsa";
    const dateText = String(after.dateText || "");
    const body = newStatus === "approved"
        ? `Cererea ta pentru ${dateText} a fost aprobata.`
        : `Cererea ta pentru ${dateText} a fost respinsa.`;

    try {
        await admin.messaging().send({
            token: fcmToken,
            notification: { title, body },
            android: { notification: { channelId: "student_channel" } },
        });
    } catch (e) {
        console.error("onLeaveRequestStatusChanged: FCM send failed:", e.message);
    }
});