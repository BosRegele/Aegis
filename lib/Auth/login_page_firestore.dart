import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../StudentInterface/mainnavigation.dart';
import '../session.dart';
import '../gate_scan_page.dart';
import '../admin/secretariat_raw_page.dart';
import '../teacher/teacher_dashboard_page.dart';

class LoginPageFirestore extends StatefulWidget {
  const LoginPageFirestore({super.key});

  @override
  State<LoginPageFirestore> createState() => _LoginPageFirestoreState();
}

class _LoginPageFirestoreState extends State<LoginPageFirestore> {
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;

  Future<void> _login() async {
    setState(() => loading = true);

    try {
      final username = userC.text.trim().toLowerCase();
      final password = passC.text.trim();

      if (username.isEmpty || password.isEmpty) {
        throw Exception("Completeaza username si parola");
      }

      final email = "$username@school.local";

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception("Profilul utilizatorului nu exista in Firestore");
      }

      final data = doc.data()!;
      if ((data["status"] ?? "active") == "disabled") {
        await FirebaseAuth.instance.signOut();
        throw Exception("Cont dezactivat");
      }

      final role = (data["role"] ?? "").toString();
      final usernameFromDb = (data["username"] ?? username).toString();

      AppSession.setUser(
        uidValue: uid,
        usernameValue: usernameFromDb,
        roleValue: role,
      );

      if (!mounted) return;

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      } else if (role == "gate") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GateScanPage()),
        );
      } else if (role == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SecretariatRawPage()),
        );
      } else if (role == "teacher") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const TeacherDashboardPage()),
        );
      } else {
        throw Exception("Rol necunoscut");
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Eroare autentificare";
      if (e.code == "user-not-found") msg = "Utilizator inexistent";
      if (e.code == "wrong-password" || e.code == "invalid-credential") {
        msg = "Parola gresita";
      }
      if (e.code == "invalid-email") msg = "Username invalid";
      if (e.code == "too-many-requests") {
        msg = "Prea multe incercari. Incearca mai tarziu.";
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Eroare: $e")));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    userC.dispose();
    passC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login (Firestore prototype)")),
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: userC,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: passC,
                decoration: const InputDecoration(labelText: "Parola"),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : _login,
                child: Text(loading ? "..." : "Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
