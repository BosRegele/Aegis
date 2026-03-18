import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'elev_qr_page.dart';
import 'parent/parent_home_page.dart';
import 'session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    try {
      String username = usernameController.text.trim();
      String password = passwordController.text.trim();
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Date invalide');
      }

      String email = "$username@school.local";

      // login Firebase Auth
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Date invalide');
      }

      final unameKey = username.toLowerCase();
      final data = userDoc.data();
      final role = data == null ? '' : (data['role'] ?? '').toString();

      if (role.isEmpty) {
        throw Exception('Date invalide');
      }

      // set session
      AppSession.setUser(
        uidValue: uid,
        usernameValue: unameKey,
        roleValue: role,
        fullNameValue: (data?['fullName'] ?? '').toString(),
        classIdValue: (data?['classId'] ?? '').toString(),
      );

      if (!mounted) return;
      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ElevQrPage(userId: uid)),
        );
      } else if (role == "parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentHomePage()),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text("Autentificare esuata. Incearca din nou.")),
        );
      }
    } on FirebaseAuthException {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text("Date de autentificare invalide.")),
      );
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        const SnackBar(content: Text("Autentificare esuata. Incearca din nou.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login elev / profesor")),
      body: Center(
        child: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Parola"),
                obscureText: true,
              ),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: login, child: const Text("Login")),
            ],
          ),
        ),
      ),
    );
  }
}
