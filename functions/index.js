const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { randomBytes, createHash } = require("crypto");
const nodemailer = require("nodemailer");
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
const PASSWORD_RESET_CODE_TTL_MS = 30 * 60 * 1000;
const PASSWORD_RESET_RESEND_COOLDOWN_MS = 60 * 1000;

function normalizeEmail(value) {
    return String(value || "").trim().toLowerCase();
}

async function assertPersonalEmailUnique({ uid, email }) {
    const emailLower = normalizeEmail(email);
    if (!emailLower || !emailLower.includes("@")) {
        throw new HttpsError("invalid-argument", "Email personal invalid");
    }

    const db = admin.firestore();
    const [takenByVerified, takenByPending] = await Promise.all([
        db.collection("users")
            .where("personalEmailLower", "==", emailLower)
            .limit(3)
            .get(),
        db.collection("users")
            .where("pendingPersonalEmailLower", "==", emailLower)
            .limit(3)
            .get(),
    ]);

    const hasOtherVerifiedOwner = takenByVerified.docs.some((d) => d.id !== uid);
    const hasOtherPendingOwner = takenByPending.docs.some((d) => d.id !== uid);

    if (hasOtherVerifiedOwner || hasOtherPendingOwner) {
        throw new HttpsError(
            "already-exists",
            "Acest email este deja asignat altui utilizator."
        );
    }

    // Backward-compatibility: older user docs may miss *Lower fields.
    // Fallback to normalized comparison on raw email fields to prevent duplicates.
    const allUsers = await db.collection("users").get();
    const hasLegacyOwner = allUsers.docs.some((d) => {
        if (d.id === uid) return false;
        const data = d.data() || {};
        const verified = normalizeEmail(data.personalEmail || "");
        const pending = normalizeEmail(data.pendingPersonalEmail || "");
        return verified === emailLower || pending === emailLower;
    });

    if (hasLegacyOwner) {
        throw new HttpsError(
            "already-exists",
            "Acest email este deja asignat altui utilizator."
        );
    }

    return emailLower;
}

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

async function resolveUserByLoginInput(inputRaw) {
    const input = String(inputRaw || "").trim().toLowerCase();
    if (!input) {
        throw new HttpsError("invalid-argument", "input lipsa");
    }

    const db = admin.firestore();
    let userSnap = null;

    if (input.includes("@")) {
        const byEmail = await db
            .collection("users")
            .where("personalEmailLower", "==", input)
            .limit(1)
            .get();
        if (!byEmail.empty) {
            userSnap = byEmail.docs[0];
        }
    } else if (USERNAME_RE.test(input)) {
        const byUsername = await db
            .collection("users")
            .where("username", "==", input)
            .limit(1)
            .get();
        if (!byUsername.empty) {
            userSnap = byUsername.docs[0];
        }
    } else {
        throw new HttpsError("invalid-argument", "Input trebuie sa fie username sau email");
    }

    if (!userSnap) {
        throw new HttpsError("not-found", "Utilizator inexistent");
    }

    const userData = userSnap.data() || {};
    const username = String(userData.username || "").trim().toLowerCase();
    if (!username) {
        throw new HttpsError("failed-precondition", "Username lipsa");
    }

    const personalEmail = String(userData.personalEmail || "").trim();
    const personalEmailLower = normalizeEmail(userData.personalEmailLower || personalEmail);

    return {
        uid: userSnap.id,
        username,
        userData,
        personalEmail,
        personalEmailLower,
    };
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

exports.authResolveLoginInput = onCall(async (request) => {
    // Resolve login input (username or email) to username
    // This function is unauthenticated to allow email lookup during login
    const input = String(request.data?.input || "").trim().toLowerCase();
    if (!input) {
        throw new HttpsError("invalid-argument", "input lipsa");
    }

    // If input is already a valid username, return it as-is
    if (USERNAME_RE.test(input)) {
        return { username: input };
    }

    // If input contains @, treat as email and look up by personalEmailLower
    if (input.includes("@")) {
        const emailLower = input.toLowerCase();
        const snap = await admin.firestore()
            .collection("users")
            .where("personalEmailLower", "==", emailLower)
            .limit(1)
            .get();

        if (snap.empty) {
            throw new HttpsError("not-found", "Email-ul nu a fost gasit");
        }

        const username = String(snap.docs[0].data()?.username || "").trim().toLowerCase();
        if (!username) {
            throw new HttpsError("failed-precondition", "Username lipsa pentru email");
        }

        return { username };
    }

    // Input doesn't match username pattern and is not an email
    throw new HttpsError("invalid-argument", "Input trebuie sa fie username sau email");
});

exports.authRequestPasswordReset = onCall(async (request) => {
    const input = String(request.data?.input || "").trim().toLowerCase();
    if (!input) {
        throw new HttpsError("invalid-argument", "Input obligatoriu");
    }

    let resolved = null;
    try {
        resolved = await resolveUserByLoginInput(input);
    } catch (_) {
        // Prevent account enumeration: return success even when user is missing.
        return { ok: true, sent: false };
    }

    const role = String(resolved.userData.role || "").trim().toLowerCase();
    const status = String(resolved.userData.status || "active").trim().toLowerCase();
    if (role === "gate" || status === "disabled") {
        return { ok: true, sent: false };
    }

    const toEmail = resolved.personalEmail;
    const toEmailLower = resolved.personalEmailLower;
    if (!toEmailLower || !toEmailLower.includes("@")) {
        return { ok: true, sent: false };
    }

    const nowMs = Date.now();
    const sentAtMs = resolved.userData.passwordResetSentAt?.toMillis?.() || 0;
    if (sentAtMs > 0 && nowMs - sentAtMs < PASSWORD_RESET_RESEND_COOLDOWN_MS) {
        const remaining = Math.ceil((PASSWORD_RESET_RESEND_COOLDOWN_MS - (nowMs - sentAtMs)) / 1000);
        return { ok: true, sent: false, cooldownSeconds: Math.max(1, remaining) };
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiryMs = nowMs + PASSWORD_RESET_CODE_TTL_MS;

    await admin.firestore().collection("users").doc(resolved.uid).set({
        passwordResetCode: code,
        passwordResetCodeExpiry: admin.firestore.Timestamp.fromMillis(expiryMs),
        passwordResetSentAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    const smtpHost = String(process.env.SMTP_HOST || "").trim();
    const smtpPort = Number(process.env.SMTP_PORT || 587);
    const smtpUser = String(process.env.SMTP_USER || "").trim();
    const smtpPass = String(process.env.SMTP_PASS || "").trim();
    const smtpFrom = String(process.env.SMTP_FROM || smtpUser).trim();

    if (!smtpHost || !smtpUser || !smtpPass || !smtpFrom) {
        throw new HttpsError(
            "failed-precondition",
            "SMTP neconfigurat. Seteaza SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM."
        );
    }

    const secure = smtpPort === 465;
    const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure,
        auth: {
            user: smtpUser,
            pass: smtpPass,
        },
    });

    await transporter.sendMail({
        from: smtpFrom,
        to: toEmail,
        subject: "Resetare parola Firster",
        text: `Codul tau pentru resetarea parolei este ${code}. Codul expira in 30 de minute.`,
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #1f2937;">
            <h2 style="margin: 0 0 12px;">Resetare parola Firster</h2>
            <p>Codul tau de resetare este:</p>
            <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px; margin: 8px 0 16px; color: #16a34a;">${code}</p>
            <p>Codul expira in <strong>30 de minute</strong>.</p>
            <p style="color: #6b7280; font-size: 12px; margin-top: 16px;">Daca nu ai solicitat resetarea, ignora acest email.</p>
          </div>
        `,
    });

    return { ok: true, sent: true };
});

exports.authConfirmPasswordReset = onCall(async (request) => {
    const input = String(request.data?.input || "").trim().toLowerCase();
    const code = String(request.data?.code || "").trim();
    const newPassword = String(request.data?.newPassword || "").trim();

    if (!input || !code || !newPassword) {
        throw new HttpsError("invalid-argument", "Input, cod si parola noua sunt obligatorii");
    }
    if (newPassword.length < 6) {
        throw new HttpsError("invalid-argument", "Parola trebuie sa aiba minim 6 caractere");
    }

    const resolved = await resolveUserByLoginInput(input);
    const userData = resolved.userData || {};
    const storedCode = String(userData.passwordResetCode || "");
    const expiryMs = userData.passwordResetCodeExpiry?.toMillis?.() || 0;

    if (!storedCode || storedCode !== code) {
        throw new HttpsError("invalid-argument", "Cod invalid");
    }
    if (!expiryMs || expiryMs < Date.now()) {
        throw new HttpsError("deadline-exceeded", "Cod expirat");
    }

    await admin.auth().updateUser(resolved.uid, { password: newPassword });

    const emailVerified = userData.emailVerified === true;
    await admin.firestore().collection("users").doc(resolved.uid).set({
        passwordChanged: true,
        onboardingComplete: emailVerified,
        passwordResetCode: admin.firestore.FieldValue.delete(),
        passwordResetCodeExpiry: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

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
            authEmail: email,
            fullName,
            role,
            classId: role === "student" || role === "teacher" ? classId : null,
            status: "active",
            inSchool: false,
            lastInAt: null,
            lastOutAt: null,
            personalEmail: null,
            personalEmailLower: null,
            pendingPersonalEmail: null,
            pendingPersonalEmailLower: null,
            emailVerified: false,
            passwordChanged: false,
            onboardingComplete: false,
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
    const newPass = String(request.data.newPassword || "");
    if (!newPass || newPass.length < 6) {
        throw new HttpsError("invalid-argument", "Parola noua trebuie sa aiba minim 6 caractere");
    }

    const uid = await getUidByUsername(username);

    const targetDoc = await admin.firestore().collection("users").doc(uid).get();
    if (targetDoc.exists && String(targetDoc.data()?.status || "active") === "disabled") {
        throw new HttpsError("failed-precondition", "Contul este dezactivat. Activeaza contul inainte de resetare.");
    }

    await admin.auth().updateUser(uid, { password: newPass });

    // Also reset onboarding flags so the user goes through onboarding again
    await admin.firestore().collection("users").doc(uid).set({
        passwordChanged: false,
        onboardingComplete: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid };
});

exports.adminRemovePersonalEmail = onCall(async (request) => {
    await assertAdmin(request);

    const username = String(request.data.username || "").trim().toLowerCase();
    if (!username) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }

    const uid = await getUidByUsername(username);
    const userRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Utilizator inexistent");
    }

    const role = String(userSnap.data()?.role || "").toLowerCase();
    if (role === "gate") {
        throw new HttpsError("failed-precondition", "Turnichetul nu are email personal");
    }

    await userRef.set({
        personalEmail: admin.firestore.FieldValue.delete(),
        personalEmailLower: admin.firestore.FieldValue.delete(),
        pendingPersonalEmail: admin.firestore.FieldValue.delete(),
        pendingPersonalEmailLower: admin.firestore.FieldValue.delete(),
        verificationCode: admin.firestore.FieldValue.delete(),
        verificationCodeExpiry: admin.firestore.FieldValue.delete(),
        emailVerified: false,
        onboardingComplete: false,
        passwordChanged: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    // Invalidate any active 2FA challenge for this user
    await admin.firestore()
        .collection("loginSecondFactorChallenges")
        .doc(uid)
        .delete()
        .catch(() => { });

    return { ok: true, uid };
});

exports.adminUpdateUserFullName = onCall(async (request) => {
    await assertAdmin(request);

    const username = String(request.data?.username || "").trim().toLowerCase();
    const fullName = String(request.data?.fullName || "").trim();

    if (!username) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }
    if (!fullName || fullName.length < 3) {
        throw new HttpsError("invalid-argument", "Numele complet trebuie sa aiba minim 3 caractere");
    }

    const uid = await getUidByUsername(username);
    const userRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Utilizator inexistent");
    }

    const currentFullName = String(userSnap.data()?.fullName || "").trim();
    if (currentFullName === fullName) {
        return { ok: true, uid, changed: false, fullName };
    }

    await admin.auth().updateUser(uid, { displayName: fullName });

    await userRef.set({
        fullName,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid, changed: true, fullName };
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
    if (!linkedUsers.empty || teacherUsername !== "") {
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
    const scanTimestamp = admin.firestore.Timestamp.now();

    // Pre-read the token outside the transaction to get userId for the leave-request query.
    // (tx.get(query) is unreliable with multi-field filters in firebase-admin v13)
    const preScanSnap = await tokenRef.get();
    const preUserId = preScanSnap.exists ? String(preScanSnap.data().userId || "") : "";

    let approvedLeaveExit = false;
    if (preUserId) {
        const roNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
        const roDay = String(roNow.getDate()).padStart(2, "0");
        const roMonth = String(roNow.getMonth() + 1).padStart(2, "0");
        const roYear = roNow.getFullYear();
        const todayText = `${roDay}/${roMonth}/${roYear}`;
        const nowMinutes = roNow.getHours() * 60 + roNow.getMinutes();

        // Query approved leave requests for today, then check timeText in code
        const leaveSnap = await db.collection("leaveRequests")
            .where("studentUid", "==", preUserId)
            .where("status", "==", "approved")
            .where("dateText", "==", todayText)
            .get();

        // approvedLeaveExit is true if at least one request's timeText (HH:mm) is <= now
        approvedLeaveExit = leaveSnap.docs.some((doc) => {
            const timeText = String(doc.data().timeText || "");
            const parts = timeText.split(":").map((x) => parseInt(x, 10));
            if (parts.length !== 2 || isNaN(parts[0]) || isNaN(parts[1])) return false;
            const requestMinutes = parts[0] * 60 + parts[1];
            return nowMinutes >= requestMinutes;
        });
    }

    let activeHolidayExit = false;
    if (preUserId) {
        const roNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
        const nowKey =
            roNow.getFullYear() * 10000 +
            (roNow.getMonth() + 1) * 100 +
            roNow.getDate();

        const vacancySnap = await db.collection("vacancies").get();
        activeHolidayExit = vacancySnap.docs.some((doc) => {
            const data = doc.data() || {};
            const startTs = data.startDate;
            const endTs = data.endDate;
            if (!startTs || typeof startTs.toDate !== "function") return false;
            if (!endTs || typeof endTs.toDate !== "function") return false;

            const roStart = new Date(startTs.toDate().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
            const roEnd = new Date(endTs.toDate().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
            const startKey =
                roStart.getFullYear() * 10000 +
                (roStart.getMonth() + 1) * 100 +
                roStart.getDate();
            const endKey =
                roEnd.getFullYear() * 10000 +
                (roEnd.getMonth() + 1) * 100 +
                roEnd.getDate();

            return nowKey >= startKey && nowKey <= endKey;
        });
    }

    const result = await db.runTransaction(async (tx) => {
        let result = null;

        scan : {
        const snap = await tx.get(tokenRef);

        if (!snap.exists) {
            result = { ok: false, reason: "NOT_FOUND", type: "deny"};
            accessEventToLog = {
                gateUid: callerUid,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        const data = snap.data() || {};
        const used = data.used === true;
        const userId = String(data.userId || "");
        const expiresAt = data.expiresAt;

        if (used) {
            result = { ok: false, reason: "ALREADY_USED", userId, type: "deny" };
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        if (!expiresAt || typeof expiresAt.toDate !== "function") {
            result = { ok: false, reason: "BAD_EXPIRES", userId, type: "deny" };
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        const nowMs = Date.now();
        const expMs = expiresAt.toDate().getTime();

        if (expMs <= nowMs) {
            result = { ok: false, reason: "EXPIRED", userId, type: "deny" };
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        const userRef = db.collection("users").doc(userId);
        const userSnap = await tx.get(userRef);

        if (!userSnap.exists) {
            result = { ok: false, reason: "USER_NOT_FOUND", userId, type: "deny" };
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        const userData = userSnap.data() || {};
        const inSchool = userData.inSchool === true;
        const status = String(userData.status || "active");
        const fullName = String(userData.fullName || userData.username || userId);
        const classId = String(userData.classId || "");
        const canExitForHoliday = inSchool && activeHolidayExit;

        if (status === "disabled") {
            result = {ok: false, reason: "USER_DISABLED", userId, fullName, classId, type: "deny"};
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                fullName,
                classId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        // --- Class timetable check added here ---
        if (!classId) {
            result = {ok: false, reason: "NO_CLASS_ASSIGNED", userId, fullName, classId, type: "deny"};
            accessEventToLog = {
                gateUid: callerUid,
                userId,
                fullName,
                classId,
                type: "deny",
                timestamp: scanTimestamp,
                tokenId,
                scanResult: "denied",
                reason: result.reason || null,
            };
            break scan;
        }

        const classRef = db.collection("classes").doc(classId);
        const classSnap = await tx.get(classRef);
        const classData = classSnap.exists ? classSnap.data() || {} : {};
        const schedule = classData.schedule || {};

        // Use local school timezone (e.g. Europe/Bucharest) for timetable checks,
        // because Cloud Functions uses UTC by default and can be 2-3h behind local time.
        const localNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Europe/Bucharest" }));
        const dayIdx = localNow.getDay(); // 0=Sunday, 1=Monday, ..., 6=Saturday
        const isWeekend = dayIdx === 0 || dayIdx === 6;

        const now = localNow;

        let isAfterSchedule = false;
        let isBeforeSchedule = false;

        

            const dayKey = String(dayIdx);
            const daySchedule = schedule[dayKey];
            if (!daySchedule || !daySchedule.start || !daySchedule.end) {
                result = {ok: false, reason: "NO_SCHEDULE", userId, fullName, classId, type: "deny"};
                accessEventToLog = {
                    gateUid: callerUid,
                    userId,
                    fullName,
                    classId,
                    type: "deny",
                    timestamp: scanTimestamp,
                    tokenId,
                    scanResult: "denied",
                    reason: result.reason || null,
                };
                break scan;
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
                result = {ok: false, reason: "BAD_SCHEDULE", userId, fullName, classId, type: "deny"};
                accessEventToLog = {
                    gateUid: callerUid,
                    userId,
                    fullName,
                    classId,
                    type: "deny",
                    timestamp: scanTimestamp,
                    tokenId,
                    scanResult: "denied",
                    reason: result.reason || null,
                };
                break scan;
            }

            const nowMinutes = now.getHours() * 60 + now.getMinutes();
            isAfterSchedule = nowMinutes > endMinutes;
            isBeforeSchedule = nowMinutes < startMinutes;
        

        // approvedLeaveExit was determined before the transaction via a plain query.
        // (tx.get(query) is unreliable with multi-field filters in firebase-admin v13)

        const nowTs = scanTimestamp;

        tx.update(tokenRef, {
            used: true,
            usedAt: nowTs,
            redeemedBy: callerUid,
        });

        let eventType = "entry";
        result = {
            ok: true,
            userId,
            fullName,
            classId,
            type: "entry"
        };

        if (!inSchool) {
            // student entering school
            tx.update(userRef, {
                inSchool: true,
                lastInAt: nowTs,
                // keep lastOutAt as is, do not clear it
            });
        } else if (canExitForHoliday || isWeekend || isAfterSchedule || isBeforeSchedule) {
            // on weekends or outside class hours: allow free exit
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
            type: eventType,
            timestamp: nowTs,
            tokenId,
            scanResult: result.ok === true ? "allowed" : "denied",
            reason: result.reason || null,
        };
    }
    

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
// ===== EMAIL VERIFICATION FUNCTIONS =====
// If SMTP .env values change, redeploy these functions to refresh runtime env (rev2).
// Adauga acestea la SFARSITUL fisierului functions/index.js

exports.sendVerificationEmail = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = String(request.data?.uid || "").trim();
    const email = String(request.data?.email || "").trim();
    const emailLower = normalizeEmail(email);

    if (!uid || !emailLower || !emailLower.includes("@")) {
        throw new HttpsError("invalid-argument", "uid si email obligatorii si email valid");
    }

    if (uid !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Nu poti trimite verificare pentru alt utilizator");
    }

    const userRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Profil inexistent");
    }
    const role = String(userSnap.data()?.role || "").trim().toLowerCase();
    if (role === "gate") {
        throw new HttpsError("failed-precondition", "Turnichetul nu necesita onboarding");
    }

    await assertPersonalEmailUnique({ uid, email: emailLower });

    // Generez cod 6 cifre
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiryMs = Date.now() + 60 * 60 * 1000; // 1 ora

    // Salvez codul în Firestore
    await userRef.update({
        pendingPersonalEmail: email,
        pendingPersonalEmailLower: emailLower,
        emailVerified: false,
        onboardingComplete: false,
        verificationCode: code,
        verificationCodeExpiry: admin.firestore.Timestamp.fromMillis(expiryMs),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const smtpHost = String(process.env.SMTP_HOST || "").trim();
    const smtpPort = Number(process.env.SMTP_PORT || 587);
    const smtpUser = String(process.env.SMTP_USER || "").trim();
    const smtpPass = String(process.env.SMTP_PASS || "").trim();
    const smtpFrom = String(process.env.SMTP_FROM || smtpUser).trim();

    if (!smtpHost || !smtpUser || !smtpPass || !smtpFrom) {
        throw new HttpsError(
            "failed-precondition",
            "SMTP neconfigurat. Seteaza SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM."
        );
    }

    const secure = smtpPort === 465;
    const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure,
        auth: {
            user: smtpUser,
            pass: smtpPass,
        },
    });

    await transporter.sendMail({
        from: smtpFrom,
        to: email,
        subject: "Cod verificare cont Firster",
        text: `Codul tau de verificare este ${code}. Codul expira in 60 de minute.`,
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #1f2937;">
            <h2 style="margin: 0 0 12px;">Verificare email Firster</h2>
            <p>Codul tau de verificare este:</p>
            <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px; margin: 8px 0 16px;">${code}</p>
            <p>Codul expira in 60 de minute.</p>
          </div>
        `,
    });

    return { success: true };
});

// Student self-service password change during onboarding (uses Admin SDK, no re-auth needed)
exports.setNewPassword = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const newPassword = String(request.data?.password || "").trim();

    if (!newPassword || newPassword.length < 8) {
        throw new HttpsError("invalid-argument", "Parola trebuie sa aiba minim 8 caractere");
    }

    const userRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Profil inexistent");
    }

    // Change password via Admin SDK (no re-auth needed on client).
    // NOTE: updateUser with password REVOKES the refresh token on the client.
    await admin.auth().updateUser(uid, { password: newPassword });

    // We intentionally do NOT write to Firestore here — the client writes
    // passwordChanged (and optionally calls markPasswordChanged) only AFTER
    // it has re-authenticated.  This eliminates the race condition where
    // the Firestore listener fires while the old (revoked) auth session
    // is still active.

    // Return the user's authEmail so the client can re-sign-in with the
    // new password (custom tokens require IAM signBlob permission which
    // the default compute SA may not have).
    const authEmail = (userSnap.data() || {}).authEmail || '';
    return { ok: true, authEmail };
});

exports.markPasswordChanged = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = String(request.data?.uid || "").trim();
    if (!uid || uid !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Operatiune nepermisa");
    }

    const userRef = admin.firestore().collection("users").doc(uid);
    const userSnap = await userRef.get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Profil inexistent");
    }

    const data = userSnap.data() || {};
    const role = String(data.role || "").trim().toLowerCase();
    if (role === "gate") {
        return { ok: true, skipped: true };
    }

    const emailVerified = data.emailVerified === true;
    const twoFactorVerifiedUntil = admin.firestore.Timestamp
        .fromMillis(Date.now() + 5 * 60 * 1000);
    await userRef.set({
        passwordChanged: true,
        onboardingComplete: emailVerified,
        twoFactorVerifiedUntil: twoFactorVerifiedUntil,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true };
});

exports.verifyEmailCode = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const uidFromData = String(request.data?.uid || "").trim();
    if (uidFromData && uidFromData !== uid) {
        throw new HttpsError("permission-denied", "Operatiune nepermisa");
    }
    const code = String(request.data?.code || "").trim();

    if (!code) {
        throw new HttpsError("invalid-argument", "Cod obligatoriu");
    }

    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    if (!userDoc.exists) {
        throw new HttpsError("not-found", "User inexistent");
    }

    const userData = userDoc.data();
    const storedCode = String(userData.verificationCode || "");
    const expiryTs = userData.verificationCodeExpiry;
    const pendingPersonalEmail = String(userData.pendingPersonalEmail || "").trim();
    const pendingPersonalEmailLower = normalizeEmail(
        userData.pendingPersonalEmailLower || pendingPersonalEmail
    );

    if (!storedCode) {
        throw new HttpsError("failed-precondition", "Niciun cod de verificare in asteptare");
    }

    if (storedCode !== code) {
        throw new HttpsError("invalid-argument", "Cod de verificare incorect");
    }

    if (!expiryTs || expiryTs.toMillis() < Date.now()) {
        throw new HttpsError("deadline-exceeded", "Cod de verificare expirat");
    }

    if (!pendingPersonalEmailLower) {
        throw new HttpsError("failed-precondition", "Email personal lipsa pentru verificare");
    }

    await assertPersonalEmailUnique({ uid, email: pendingPersonalEmailLower });

    const passwordChanged = userData.passwordChanged === true;

    // Codul e corect! Marchez ca verificat
    await admin.firestore().collection("users").doc(uid).update({
        personalEmail: pendingPersonalEmail,
        personalEmailLower: pendingPersonalEmailLower,
        emailVerified: true,
        onboardingComplete: passwordChanged,
        pendingPersonalEmail: admin.firestore.FieldValue.delete(),
        pendingPersonalEmailLower: admin.firestore.FieldValue.delete(),
        verificationCode: admin.firestore.FieldValue.delete(),
        verificationCodeExpiry: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { verified: true };
});

// ===== 2-FACTOR AUTHENTICATION (2FA) FUNCTIONS =====

const TWO_FA_EXPIRY_MS = 10 * 60 * 1000; // 10 minutes
const TWO_FA_COOLDOWN_MS = 60 * 1000;     // 60 seconds between resends
const TWO_FA_MAX_ATTEMPTS = 5;

function maskEmail(email) {
    const atIdx = String(email || "").indexOf("@");
    if (atIdx <= 0) return "***@***";
    const local = email.substring(0, atIdx);
    const domain = email.substring(atIdx);
    if (local.length <= 2) return "*" + domain;
    return local.charAt(0) + "*".repeat(Math.min(4, local.length - 2)) + local.charAt(local.length - 1) + domain;
}

async function sendTwoFactorEmail(to, code) {
    const smtpHost = String(process.env.SMTP_HOST || "").trim();
    const smtpPort = Number(process.env.SMTP_PORT || 587);
    const smtpUser = String(process.env.SMTP_USER || "").trim();
    const smtpPass = String(process.env.SMTP_PASS || "").trim();
    const smtpFrom = String(process.env.SMTP_FROM || smtpUser).trim();

    if (!smtpHost || !smtpUser || !smtpPass || !smtpFrom) {
        throw new HttpsError(
            "failed-precondition",
            "SMTP neconfigurat. Seteaza SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM."
        );
    }

    const secure = smtpPort === 465;
    const transporter = nodemailer.createTransport({
        host: smtpHost,
        port: smtpPort,
        secure,
        auth: { user: smtpUser, pass: smtpPass },
    });

    await transporter.sendMail({
        from: smtpFrom,
        to,
        subject: "Cod autentificare in doi pasi Firster",
        text: `Codul tau de autentificare este ${code}. Codul expira in 10 minute.`,
        html: `
          <div style="font-family: Arial, sans-serif; line-height: 1.5; color: #1f2937;">
            <h2 style="margin: 0 0 12px;">Autentificare in doi pasi Firster</h2>
            <p>Codul tau de autentificare este:</p>
            <p style="font-size: 32px; font-weight: 700; letter-spacing: 6px; margin: 8px 0 16px; color: #16a34a;">${code}</p>
            <p>Codul expira in <strong>10 minute</strong>.</p>
            <p style="color: #6b7280; font-size: 12px; margin-top: 16px;">Daca nu ai solicitat acest cod, ignora acest email.</p>
          </div>
        `,
    });
}

// Trimite codul 2FA dupa autentificarea cu parola.
// Returneaza maskedEmail si cooldownRemaining.
// Daca exista deja un challenge trimis recent (cooldown), nu retrimite — returneaza sent: false.
exports.authStartSecondFactor = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Profil inexistent");
    }

    const userData = userSnap.data() || {};
    const role = String(userData.role || "").trim().toLowerCase();
    const onboardingComplete = userData.onboardingComplete === true;

    if (role === "gate") {
        throw new HttpsError("failed-precondition", "2FA nu se aplica turnichetului");
    }
    if (!onboardingComplete) {
        throw new HttpsError("failed-precondition", "Onboarding incomplet");
    }

    const personalEmail = String(userData.personalEmail || "").trim();
    if (!personalEmail) {
        throw new HttpsError("failed-precondition", "Email personal neasignat");
    }

    const nowMs = Date.now();
    const challengeRef = db.collection("loginSecondFactorChallenges").doc(uid);
    const existingSnap = await challengeRef.get();

    // authStartSecondFactor is called ONCE per login — always generate a fresh code.
    // Cooldown applies only to authResendSecondFactor (user-triggered resends).

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = createHash("sha256").update(code).digest("hex");
    const nowTs = admin.firestore.Timestamp.fromMillis(nowMs);

    await challengeRef.set({
        uid,
        codeHash,
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMs + TWO_FA_EXPIRY_MS),
        attempts: 0,
        verifiedAt: null,
        createdAt: existingSnap.exists ? (existingSnap.data()?.createdAt ?? nowTs) : nowTs,
        lastSentAt: nowTs,
    });

    await sendTwoFactorEmail(personalEmail, code);

    return { sent: true, maskedEmail: maskEmail(personalEmail), cooldownRemaining: 0 };
});

// Verifica codul 2FA introdus de utilizator.
exports.authVerifySecondFactor = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const code = String(request.data?.code || "").trim();

    if (!code || !/^\d{6}$/.test(code)) {
        throw new HttpsError("invalid-argument", "Codul trebuie sa aiba exact 6 cifre");
    }

    const db = admin.firestore();
    const challengeRef = db.collection("loginSecondFactorChallenges").doc(uid);

    let alreadyVerified = false;
    await db.runTransaction(async (tx) => {
        const snap = await tx.get(challengeRef);
        if (!snap.exists) {
            throw new HttpsError("not-found", "Nicio verificare 2FA activa. Solicita un nou cod.");
        }

        const data = snap.data() || {};

        if (data.verifiedAt != null) {
            alreadyVerified = true;
            return;
        }

        const expiresAtMs = data.expiresAt?.toMillis?.() || 0;
        if (Date.now() > expiresAtMs) {
            throw new HttpsError("deadline-exceeded", "Codul a expirat. Solicita un nou cod.");
        }

        const attempts = Number(data.attempts || 0);
        if (attempts >= TWO_FA_MAX_ATTEMPTS) {
            throw new HttpsError(
                "resource-exhausted",
                "Prea multe incercari gresite. Solicita un nou cod."
            );
        }

        const inputHash = createHash("sha256").update(code).digest("hex");

        if (inputHash !== data.codeHash) {
            tx.update(challengeRef, {
                attempts: attempts + 1,
                lastAttemptAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            const remaining = TWO_FA_MAX_ATTEMPTS - attempts - 1;
            throw new HttpsError(
                "invalid-argument",
                remaining > 0
                    ? `Cod incorect. Mai ai ${remaining} ${remaining === 1 ? "incercare" : "incercari"}.`
                    : "Cod incorect. Nu mai ai incercari. Solicita un nou cod."
            );
        }

        tx.update(challengeRef, {
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
            attempts: attempts + 1,
        });
    });

    return { verified: true };
});

// Retrimite codul 2FA (cu cooldown de 60s).
exports.authResendSecondFactor = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const [userSnap, challengeSnap] = await Promise.all([
        db.collection("users").doc(uid).get(),
        db.collection("loginSecondFactorChallenges").doc(uid).get(),
    ]);

    if (!userSnap.exists) {
        throw new HttpsError("not-found", "Profil inexistent");
    }

    const personalEmail = String(userSnap.data()?.personalEmail || "").trim();
    if (!personalEmail) {
        throw new HttpsError("failed-precondition", "Email personal neasignat");
    }

    const nowMs = Date.now();

    if (challengeSnap.exists) {
        const existing = challengeSnap.data() || {};
        const lastSentMs = existing.lastSentAt?.toMillis?.() || 0;
        if (nowMs - lastSentMs < TWO_FA_COOLDOWN_MS) {
            const remaining = Math.ceil((TWO_FA_COOLDOWN_MS - (nowMs - lastSentMs)) / 1000);
            throw new HttpsError(
                "resource-exhausted",
                `Asteapta ${remaining} secunde inainte de a retrimite codul.`
            );
        }
    }

    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const codeHash = createHash("sha256").update(code).digest("hex");
    const nowTs = admin.firestore.Timestamp.fromMillis(nowMs);

    await db.collection("loginSecondFactorChallenges").doc(uid).set({
        uid,
        codeHash,
        expiresAt: admin.firestore.Timestamp.fromMillis(nowMs + TWO_FA_EXPIRY_MS),
        attempts: 0,
        verifiedAt: null,
        createdAt: challengeSnap.exists
            ? (challengeSnap.data()?.createdAt ?? nowTs)
            : nowTs,
        lastSentAt: nowTs,
    });

    await sendTwoFactorEmail(personalEmail, code);

    return { sent: true, maskedEmail: maskEmail(personalEmail) };
});
