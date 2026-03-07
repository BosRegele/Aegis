import 'package:firster/Auth/login_page_firestore.dart';
import 'package:firster/StudentInterface/mainnavigation.dart';
import 'package:firster/admin/secretariat_raw_page.dart';
import 'package:firster/gate_scan_page.dart';
import 'package:firster/teacher/teacher_dashboard_page.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _buildHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists) {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }

    final data = doc.data()!;
    final role = (data['role'] ?? '').toString();
    final username = (data['username'] ?? '').toString();

    AppSession.setUser(
      uidValue: user.uid,
      usernameValue: username,
      roleValue: role,
    );

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(useMaterial3: true),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return const LoginPageFirestore();
          }

          return FutureBuilder<Widget>(
            future: _buildHome(user),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return snap.data ?? const LoginPageFirestore();
            },
          );
        },
      ),
    );
  }
}

//VEZI BA ASTEA SAU ESTI BULANGIU
// O vad ba bulangiule
