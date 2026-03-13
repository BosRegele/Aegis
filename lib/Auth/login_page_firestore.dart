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
  bool passwordVisible = false; // control vizibilitate parola

  Future<void> _login() async {
    setState(() => loading = true);
    try {
      final username = userC.text.trim().toLowerCase();
      final password = passC.text.trim();
      if (username.isEmpty || password.isEmpty) throw Exception("Completeaza username si parola");

      final email = "$username@school.local";
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final usersCol = FirebaseFirestore.instance.collection('users');
      QuerySnapshot? qsnap;
      DocumentSnapshot? doc;

      qsnap = await usersCol.where('username', isEqualTo: username).limit(1).get();
      if (qsnap.docs.isNotEmpty) doc = qsnap.docs.first;
      if (doc == null) {
        final d = await usersCol.doc(uid).get();
        if (d.exists) doc = d;
      }
      if (doc == null) {
        qsnap = await usersCol.where('uid', isEqualTo: uid).limit(1).get();
        if (qsnap.docs.isNotEmpty) doc = qsnap.docs.first;
      }
      if (doc == null || !doc.exists) {
        await FirebaseAuth.instance.signOut();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profilul utilizatorului nu exista in Firestore')));
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      if ((data["status"] ?? "active") == "disabled") {
        await FirebaseAuth.instance.signOut();
        throw Exception("Cont dezactivat");
      }

      final role = (data["role"] ?? "").toString();
      final usernameFromDb = (data["username"] ?? username).toString();
      AppSession.setUser(uidValue: uid, usernameValue: usernameFromDb, roleValue: role);

      if (!mounted) return;
      if (role == "student") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AppShell()));
      } else if (role == "gate") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GateScanPage()));
      } else if (role == "admin") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SecretariatRawPage()));
      } else if (role == "teacher") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TeacherDashboardPage()));
      } else if (role == "parent") {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ParentHomePage()));
      } else {
        throw Exception("Rol necunoscut");
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Eroare autentificare";
      if (e.code == "user-not-found") msg = "Utilizator inexistent";
      if (e.code == "wrong-password" || e.code == "invalid-credential") msg = "Parola gresita";
      if (e.code == "invalid-email") msg = "Username invalid";
      if (e.code == "too-many-requests") msg = "Prea multe incercari. Incearca mai tarziu.";
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Eroare: $e")));
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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.fromRGBO(122, 175, 91, 1), Color.fromRGBO(90, 150, 65, 1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.03)),
          Center(
            child: Container(
              width: 360,
              padding: const EdgeInsets.all(35),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                color: Colors.white.withOpacity(0.95),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 30, offset: const Offset(0, 15)),
                  BoxShadow(color: Colors.green.withOpacity(0.1), blurRadius: 25, spreadRadius: -10),
                ],
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color.fromRGBO(122, 175, 91, 1), Color.fromRGBO(90, 150, 65, 1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: const Icon(Icons.shield_rounded, size: 60, color: Colors.white),
                  ),
                  const SizedBox(height: 20),
                  const Text("Autentificare", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 30),

                  TextField(
                    controller: userC,
                    decoration: InputDecoration(
                      hintText: "Nume de utilizator",
                      prefixIcon: const Icon(Icons.person_outline, color: Color.fromRGBO(122, 175, 91, 1)),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.green.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color.fromRGBO(122, 175, 91, 1), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: passC,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      hintText: "Parola",
                      prefixIcon: const Icon(Icons.lock_outline, color: Color.fromRGBO(122, 175, 91, 1)),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(color: Colors.green.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: Color.fromRGBO(122, 175, 91, 1), width: 2),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            passwordVisible = !passwordVisible;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: loading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
                        elevation: 8,
                        shadowColor: Colors.green.withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      child: Text(
                        loading ? "Se conecteaza..." : "Conectează-te",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(width: 80, height: 4, decoration: BoxDecoration(color: Colors.green.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}