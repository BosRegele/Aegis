import 'package:firster/Auth/login_page_firestore.dart';
import 'package:firster/StudentInterface/mainnavigation.dart';
import 'package:firster/admin/secretariat_raw_page.dart';
import 'package:firster/gate_scan_page.dart';
import 'package:firster/teacher/teacher_dashboard_page.dart';
import 'package:firster/parent/parent_home_page.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await _localNotifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _localNotifications.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'student_channel',
          'Notificari elev',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  });

  runApp(const MyApp());
}

Future<void> _saveFcmToken(String uid) async {
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
  } catch (_) {}
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
      fullNameValue: (data['fullName'] ?? '').toString(),
      classIdValue: (data['classId'] ?? '').toString(),
    );

    _saveFcmToken(user.uid);

    if (role == 'student') {
      return const AppShell();
    } else if (role == 'gate') {
      return const GateScanPage();
    } else if (role == 'admin') {
      return const SecretariatRawPage();
    } else if (role == 'teacher') {
      return const TeacherDashboardPage();
    } else if (role == 'parent') {
      return const ParentHomePage();
    } else {
      await FirebaseAuth.instance.signOut();
      return const LoginPageFirestore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QR Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Color(0xFF7AAF5B)),
      ),
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
