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

      String email = "$username@school.local";

      // login Firebase Auth
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      // citim rolul din Firestore — încercăm mai multe fallback-uri deoarece
      // doc-urile pot fi cheiate fie prin username, fie prin uid
      final unameKey = username.toLowerCase();

      final usersCol = FirebaseFirestore.instance.collection("users");

      late DocumentSnapshot userDoc;

      // 1) încercăm id = username
      userDoc = await usersCol.doc(unameKey).get();

      // 2) fallback: id = uid
      if (!userDoc.exists) {
        userDoc = await usersCol.doc(uid).get();
      }

      // 3) fallback: query by username field
      if (!userDoc.exists) {
        final qSnap = await usersCol
            .where('username', isEqualTo: unameKey)
            .limit(1)
            .get();
        if (qSnap.docs.isNotEmpty) userDoc = qSnap.docs.first;
      }

      final docExists = userDoc.exists;
      final docId = userDoc.id;
      final data = docExists ? (userDoc.data() as Map<String, dynamic>?) : null;
      final role = data == null ? '' : (data['role'] ?? '').toString();

      // show debug dialog with lookup details so user can see what was found
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Debug login'),
          content: SingleChildScrollView(
            child: Text(
              'uid: $uid\nusername input: $username\nunameKey: $unameKey\n'
              'docExists: $docExists\ndocId: $docId\nrole: ${role.isEmpty ? '(none)' : role}\n\ndata: ${data ?? {}}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );

      if (role.isEmpty) {
        return;
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
