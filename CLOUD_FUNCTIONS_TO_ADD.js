// ===== EMAIL VERIFICATION FUNCTIONS =====
// Adauga acestea la SFARSITUL fisierului functions/index.js

exports.sendVerificationEmail = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = String(request.data?.uid || "").trim();
    const email = String(request.data?.email || "").trim();

    if (!uid || !email || !email.includes("@")) {
        throw new HttpsError("invalid-argument", "uid si email obligatorii si email valid");
    }

    if (uid !== request.auth.uid) {
        throw new HttpsError("permission-denied", "Nu poti trimite verificare pentru alt utilizator");
    }

    // Generez cod 6 cifre
    const code = Math.floor(100000 + Math.random() * 900000).toString();
    const expiryMs = Date.now() + 60 * 60 * 1000; // 1 ora

    // Salvez codul în Firestore
    await admin.firestore().collection("users").doc(uid).update({
        verificationCode: code,
        verificationCodeExpiry: admin.firestore.Timestamp.fromMillis(expiryMs),
    });

    // TODO: Trimite email cu codul
    // Momentan loghez pentru testing
    console.log(`Verification code for ${email}: ${code}`);

    // Pentru testing, puteți implementa nodemailer sau SendGrid
    // Exemplu cu nodemailer (necesită configurație):
    /*
    const nodemailer = require("nodemailer");
    const transporter = nodemailer.createTransport({
        host: process.env.SMTP_HOST,
        port: process.env.SMTP_PORT,
        auth: {
            user: process.env.SMTP_USER,
            pass: process.env.SMTP_PASS
        }
    });

    await transporter.sendMail({
        from: process.env.SMTP_FROM,
        to: email,
        subject: "Cod de verificare - Firster",
        html: `<p>Codul tau de verificare este: <strong>${code}</strong></p>
                <p>Codul expira în 1 oră.</p>`
    });
    */

    return { success: true };
});

exports.verifyEmailCode = onCall(async (request) => {
    if (!request.auth) {
        throw new HttpsError("unauthenticated", "Login required");
    }

    const uid = request.auth.uid;
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

    if (!storedCode) {
        throw new HttpsError("failed-precondition", "Niciun cod de verificare in asteptare");
    }

    if (storedCode !== code) {
        throw new HttpsError("invalid-argument", "Cod de verificare incorect");
    }

    if (!expiryTs || expiryTs.toMillis() < Date.now()) {
        throw new HttpsError("deadline-exceeded", "Cod de verificare expirat");
    }

    // Codul e corect! Marchez ca verificat
    await admin.firestore().collection("users").doc(uid).update({
        verificationCode: admin.firestore.FieldValue.delete(),
        verificationCodeExpiry: admin.firestore.FieldValue.delete(),
    });

    return { verified: true };
});
