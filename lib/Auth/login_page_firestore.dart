import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../StudentInterface/mainnavigation.dart';
import '../session.dart';
import '../gate_scan_page.dart';
import '../admin/secretariat_raw_page.dart';
import '../teacher/teacher_dashboard_page.dart';
import '../parent/parent_home_page.dart';

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

      // Lookup user document robustly: try by username field first, then by doc id = uid,
      // then by uid field. This handles different methods of creating user documents.
      final usersCol = FirebaseFirestore.instance.collection('users');
      QuerySnapshot? qsnap;
      DocumentSnapshot? doc;

      // 1) try query where username field equals input
      qsnap = await usersCol
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (qsnap.docs.isNotEmpty) {
        doc = qsnap.docs.first;
      }

      // 2) try doc with id == uid
      if (doc == null) {
        final d = await usersCol.doc(uid).get();
        if (d.exists) doc = d;
      }

      // 3) try query where uid field equals auth uid
      if (doc == null) {
        qsnap = await usersCol.where('uid', isEqualTo: uid).limit(1).get();
        if (qsnap.docs.isNotEmpty) doc = qsnap.docs.first;
      }

      if (doc == null || !doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profilul utilizatorului nu exista in Firestore'),
            ),
          );
        }
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if ((data["status"] ?? "active") == "disabled") {
        await FirebaseAuth.instance.signOut();
        throw Exception("Cont dezactivat");
      }

      final role = (data["role"] ?? "").toString();
      final usernameFromDb = (data["username"] ?? username).toString();

      // Debug: inform what doc id we matched
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logged in — role: $role | docId: ${doc.id}')),
        );
      }

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
      } else if (role == "parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentHomePage()),
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
