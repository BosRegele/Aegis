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