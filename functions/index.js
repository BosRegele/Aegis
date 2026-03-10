const { onCall, HttpsError } = require("firebase-functions/v2/https");
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
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

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

        tx.update(userRef, {
            classId: newClassId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
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
        noExitDays: [1, 2, 3, 4, 5],
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    return { ok: true };
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
            return { ok: false, reason: "NOT_FOUND" };
        }

        const data = snap.data() || {};
        const used = data.used === true;
        const userId = String(data.userId || "");
        const expiresAt = data.expiresAt;

        if (used) {
            return { ok: false, reason: "ALREADY_USED", userId };
        }

        if (!expiresAt || typeof expiresAt.toDate !== "function") {
            return { ok: false, reason: "BAD_EXPIRES", userId };
        }

        const nowMs = Date.now();
        const expMs = expiresAt.toDate().getTime();

        if (expMs <= nowMs) {
            return { ok: false, reason: "EXPIRED", userId };
        }

        const userRef = db.collection("users").doc(userId);
        const userSnap = await tx.get(userRef);

        if (!userSnap.exists) {
            return { ok: false, reason: "USER_NOT_FOUND", userId };
        }

        const userData = userSnap.data() || {};
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
            };
        }

        const nowTs = admin.firestore.FieldValue.serverTimestamp();

        tx.update(tokenRef, {
            used: true,
            usedAt: nowTs,
            redeemedBy: callerUid,
        });

        const eventRef = db.collection("accessEvents").doc();
        tx.set(eventRef, {
            tokenId,
            userId,
            fullName,
            classId,
            gateUid: callerUid,
            timestamp: nowTs,
            type: "entry",
        });

        return {
            ok: true,
            userId,
            fullName,
            classId,
        };
    });

    return result;
});