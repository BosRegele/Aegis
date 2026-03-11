import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminCreateUserPage extends StatefulWidget {
  const AdminCreateUserPage({super.key});

  @override
  State<AdminCreateUserPage> createState() => _AdminCreateUserPageState();
}

class _AdminCreateUserPageState extends State<AdminCreateUserPage> {
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final classController = TextEditingController();

  String role = "student";

  Future<void> createUser() async {
    try {
      String username = usernameController.text.trim();
      String password = passwordController.text.trim();
      String name = nameController.text.trim();
      String classId = classController.text.trim();

      String email = "$username@school.local";

      // 1️⃣ create Firebase Auth user
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      String uid = cred.user!.uid;

      // 2️⃣ save to Firestore
      await FirebaseFirestore.instance.collection("users").doc(uid).set({
        "name": name,
        "username": username,
        "role": role,
        "classId": classId,
        "status": "active",
        "inSchool": false,
        "lastInAt": null,
        "lastOutAt": null,
        "createdAt": FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User creat cu succes")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Eroare: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Secretariat - Creeaza cont")),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nume complet"),
              ),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: "Username"),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: "Parola"),
              ),
              TextField(
                controller: classController,
                decoration: const InputDecoration(labelText: "Clasa"),
              ),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: role,
                items: const [
                  DropdownMenuItem(value: "student", child: Text("Elev")),
                  DropdownMenuItem(value: "teacher", child: Text("Diriginte")),
                ],
                onChanged: (v) {
                  setState(() {
                    role = v!;
                  });
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: createUser,
                child: const Text("Creeaza cont"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
