const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

exports.adminCreateUser = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const data = request.data;
    const username = String(data.username || "").trim().toLowerCase();
    const password = String(data.password || "").trim();
    const fullName = String(data.fullName || "").trim();
    const role = String(data.role || "").trim();
    const classId = data.classId ? String(data.classId).trim().toUpperCase() : null;

    if (!username || !password || !fullName || !role) {
        throw new HttpsError("invalid-argument", "Lipsesc campuri obligatorii");
    }

    const callerUid = request.auth.uid;

    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists) {
        throw new HttpsError("permission-denied", "Profil admin inexistent");
    }

    const callerData = callerDoc.data();
    if (callerData.role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate crea conturi");
    }

    const email = `${username}@school.local`;

    const user = await admin.auth().createUser({
        email,
        password,
        displayName: fullName,
    });

    await admin.firestore().collection("users").doc(user.uid).set({
        username,
        fullName,
        role,
        classId,
        status: "active",
        inSchool: false,
        lastInAt: null,
        lastOutAt: null,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // daca este profesor si are clasa -> seteaza dirigintele clasei
    if (role === "teacher" && classId) {
        await admin.firestore().collection("classes").doc(classId).set({
            name: classId,
            teacherUsername: username,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
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
exports.adminResetPassword = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate reseta parole");
    }

    const username = String(request.data.username || "").trim().toLowerCase();
    const uid = await getUidByUsername(username);

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
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate dezactiva conturi");
    }

    const username = String(request.data.username || "").trim().toLowerCase();
    const disabled = request.data.disabled === true;
    const uid = await getUidByUsername(username);

    await admin.auth().updateUser(uid, { disabled });

    await admin.firestore().collection("users").doc(uid).set({
        status: disabled ? "disabled" : "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true, uid };
});


exports.adminMoveStudentClass = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate muta elevi");
    }

    const username = String(request.data.username || "").trim().toLowerCase();
    const newClassId = String(request.data.newClassId || "").trim().toUpperCase();

    if (!newClassId) {
        throw new HttpsError("invalid-argument", "newClassId lipsa");
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
            tx.set(classRef, {
                name: newClassId,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        const oldClassId = String(userData.classId || "").trim().toUpperCase();
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
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate sterge utilizatori");
    }

    const username = String(request.data.username || "").trim().toLowerCase();
    if (!username) {
        throw new HttpsError("invalid-argument", "username lipsa");
    }

    const uid = await getUidByUsername(username);

    // delete auth account
    try {
        await admin.auth().deleteUser(uid);
    } catch (e) {
        // ignore if user already gone
    }

    // delete firestore doc (and also clear teacher assignment in store.deleteUser if needed)
    await admin.firestore().collection("users").doc(uid).delete();

    return { ok: true, uid };
});


exports.adminCreateClass = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const { name } = request.data;

    const classId = name.toUpperCase();

    await admin.firestore().collection("classes").doc(classId).set({
        name: classId,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    return { ok: true };
});
exports.adminSetClassNoExitSchedule = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists) {
        throw new HttpsError("permission-denied", "Profil admin inexistent");
    }

    const callerData = callerDoc.data();
    if (callerData.role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate seta orarul");
    }

    const classId = String(request.data.classId || "").trim().toUpperCase();
    const startHHmm = String(request.data.startHHmm || "").trim();
    const endHHmm = String(request.data.endHHmm || "").trim();

    // Procesa zilele - asigura-te ca sunt numere intregi
    let days = [1, 2, 3, 4, 5];
    if (Array.isArray(request.data.days) && request.data.days.length > 0) {
        days = request.data.days.map(d => parseInt(d, 10)).filter(d => !isNaN(d) && d >= 1 && d <= 5);
        if (days.length === 0) {
            days = [1, 2, 3, 4, 5];
        }
    }

    if (!classId || !startHHmm || !endHHmm) {
        throw new HttpsError("invalid-argument", "Campuri lipsa");
    }

    const hhmm = /^\d{2}:\d{2}$/;
    if (!hhmm.test(startHHmm) || !hhmm.test(endHHmm)) {
        throw new HttpsError("invalid-argument", "Format invalid. Foloseste HH:mm");
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
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Login required");
        }

        const callerUid = request.auth.uid;
        const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
        if (!callerDoc.exists) {
            throw new HttpsError("permission-denied", "Profil admin inexistent");
        }

        const callerData = callerDoc.data();
        if (callerData.role !== "admin") {
            throw new HttpsError("permission-denied", "Doar adminul poate seta orarul");
        }

        const classId = String(request.data.classId || "").trim().toUpperCase();
        let scheduleData = request.data.schedule;

        console.log("1. classId:", classId);
        console.log("2. scheduleData type:", typeof scheduleData);
        console.log("3. scheduleData content:", JSON.stringify(scheduleData));

        if (!classId || !scheduleData || typeof scheduleData !== 'object' || Object.keys(scheduleData).length === 0) {
            throw new HttpsError("invalid-argument", `Missing classId, schedule, or empty schedule. classId=${classId}, schedule keys=${Object.keys(scheduleData || {}).length}`);
        }

        const hhmm = /^\d{2}:\d{2}$/;
        const schedule = {};

        for (const [dayStr, timesObj] of Object.entries(scheduleData)) {
            console.log(`Processing day: ${dayStr}, timesObj:`, JSON.stringify(timesObj));

            const dayNum = parseInt(dayStr, 10);
            if (isNaN(dayNum) || dayNum < 1 || dayNum > 5) {
                throw new HttpsError("invalid-argument", `Invalid day number: ${dayStr}`);
            }

            // Access times safely
            const startTime = timesObj?.start || timesObj?.["start"];
            const endTime = timesObj?.end || timesObj?.["end"];

            console.log(`Day ${dayNum}: start=${startTime}, end=${endTime}`);

            if (!startTime || !endTime) {
                throw new HttpsError("invalid-argument", `Missing start/end time for day ${dayNum}. Received: ${JSON.stringify(timesObj)}`);
            }

            if (!hhmm.test(String(startTime)) || !hhmm.test(String(endTime))) {
                throw new HttpsError("invalid-argument", `Invalid time format for day ${dayNum}. Expected HH:mm, got start=${startTime}, end=${endTime}`);
            }

            schedule[dayNum.toString()] = {
                start: String(startTime),
                end: String(endTime)
            };
        }

        console.log("Final schedule to save:", JSON.stringify(schedule));

        const classRef = admin.firestore().collection("classes").doc(classId);
        const classSnap = await classRef.get();

        if (!classSnap.exists) {
            throw new HttpsError("not-found", `Class ${classId} does not exist`);
        }

        await classRef.set({
            schedule: schedule,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        console.log("✓ Schedule saved successfully for class:", classId);
        return { ok: true, schedule: schedule };
    } catch (error) {
        console.error("✗ Error in adminSetClassSchedulePerDay:", error.message, error.stack);
        if (error instanceof HttpsError) {
            throw error;
        }
        throw new HttpsError("internal", `Unexpected error: ${error.message}`);
    }
});

exports.adminDeleteClassCascade = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const callerUid = request.auth.uid;
    const callerDoc = await admin.firestore().collection("users").doc(callerUid).get();
    if (!callerDoc.exists) {
        throw new HttpsError("permission-denied", "Profil admin inexistent");
    }

    const callerData = callerDoc.data();
    if (callerData.role !== "admin") {
        throw new HttpsError("permission-denied", "Doar adminul poate sterge clase");
    }

    const classId = String(request.data.classId || "").trim().toUpperCase();
    if (!classId) {
        throw new HttpsError("invalid-argument", "classId lipsa");
    }

    const db = admin.firestore();
    const classRef = db.collection("classes").doc(classId);
    const classSnap = await classRef.get();

    if (!classSnap.exists) {
        throw new HttpsError("not-found", `Clasa ${classId} nu exista`);
    }

    const teacherUsername = String(classSnap.data()?.teacherUsername || "")
        .trim()
        .toLowerCase();

    const studentsSnap = await db
        .collection("users")
        .where("role", "==", "student")
        .where("classId", "==", classId)
        .get();

    const batch = db.batch();

    for (const d of studentsSnap.docs) {
        batch.delete(d.ref);
    }

    if (teacherUsername) {
        const teacherSnap = await db
            .collection("users")
            .where("username", "==", teacherUsername)
            .limit(1)
            .get();

        if (!teacherSnap.empty) {
            batch.delete(teacherSnap.docs[0].ref);
        }
    }

    batch.delete(classRef);

    await batch.commit();

    return { ok: true };
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
        } else if (inSchool && isAfterSchedule) {
            // student exiting after class hours
            eventType = "exit";
            tx.update(userRef, {
                inSchool: false,
                // keep lastInAt as is, do not clear it
                lastOutAt: nowTs,
            });
            result.type = "exit";
        } else {
            // student already in school during or before end schedule
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

        const eventRef = db.collection("accessEvents").doc();
        tx.set(eventRef, {
            tokenId,
            userId,
            fullName,
            classId,
            gateUid: callerUid,
            timestamp: nowTs,
            type: eventType,
            reason: result.ok ? null : result.reason,
        });

        return result;
    });

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