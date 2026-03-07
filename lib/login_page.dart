import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'elev_qr_page.dart';

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

      String email = "$username@school.local";

      // login Firebase Auth
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      String uid = cred.user!.uid;

      // citim rolul din Firestore
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(uid)
          .get();

      String role = userDoc["role"];

      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ElevQrPage(userId: uid)),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Rol necunoscut")));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Eroare login: $e")));
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
