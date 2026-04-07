import 'dart:async';

import 'package:firster/Auth/login_page_firestore.dart';
import 'package:firster/Auth/two_factor_verify_page.dart';
import 'package:firster/student/mainnavigation.dart';
import 'package:firster/admin/secretariat_raw_page.dart'
    show SecretariatRawPage;
import 'package:firster/gate/gate_scan_page.dart';
import 'package:firster/teacher/teacher_dashboard_page.dart';
import 'package:firster/parent/parent_home_page.dart';
import 'package:firster/services/security_flags_service.dart';
import 'package:firster/core/session.dart';
import 'package:firster/auth/onboarding_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/firebase_options.dart';

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();
StreamSubscription<String>? _tokenRefreshSub;
String? _tokenBoundUid;
String? _tokenInitUid;

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signOut(); // TEMP: force logout
  if (kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      webExperimentalForceLongPolling: true,
    );
  }

  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (kIsWeb) return; // handled by the Firebase service worker on web
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
  if (_tokenBoundUid == uid && _tokenRefreshSub != null) return;
  if (_tokenInitUid == uid) return;
  _tokenInitUid = uid;
  try {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmToken': token,
    }, SetOptions(merge: true));
    await _tokenRefreshSub?.cancel();
    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      newToken,
    ) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcmToken': newToken,
      }, SetOptions(merge: true));
    });
    _tokenBoundUid = uid;
  } catch (_) {
  } finally {
    if (_tokenInitUid == uid) {
      _tokenInitUid = null;
    }
  }
}

Future<void> _cleanupAuthState({bool clearPersistedTwoFactor = true}) async {
  final uidToClear = AppSession.uid;
  await _tokenRefreshSub?.cancel();
  _tokenRefreshSub = null;
  _tokenBoundUid = null;
  _tokenInitUid = null;
  if (clearPersistedTwoFactor) {
    // Clear the persisted 2FA verified flag so the next login (or a different
    // user on the same machine) must verify again.
    try {
      final prefs = await SharedPreferences.getInstance();
      final keysToRemove = prefs
          .getKeys()
          .where((k) => k.startsWith('tf_verified_'))
          .toList();
      for (final k in keysToRemove) {
        await prefs.remove(k);
      }
    } catch (_) {}

    if (uidToClear != null && uidToClear.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uidToClear)
            .set({
              'twoFactorVerifiedUntil': FieldValue.delete(),
            }, SetOptions(merge: true));
      } catch (_) {}
    }
  }
  AppSession.clear();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Cached streams — created once, never recreated on rebuilds.
  // Recreating streams inside builder functions creates new Firestore
  // listeners on every rebuild, leading to rapid widget-type swaps and
  // the "Cannot hit test a render box that has never been laid out" loop.
  late final Stream<SecurityFlags> _flagsStream;
  String? _cachedUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  bool _hadAuthenticatedUser = false;
  final Set<String> _authEmailMirroredUids = {};

  // Cached so that StreamBuilder rebuilds do not recreate the Future,
  // which would reset the FutureBuilder to ConnectionState.waiting.
  String? _twoFactorPersistedUid;
  Future<bool>? _twoFactorPersistedFuture;

  Future<bool> _getOrCreateTwoFactorFuture(String uid) {
    if (_twoFactorPersistedUid != uid || _twoFactorPersistedFuture == null) {
      _twoFactorPersistedUid = uid;
      _twoFactorPersistedFuture = _loadPersistedTwoFactorState(uid);
    }
    return _twoFactorPersistedFuture!;
  }

  Future<bool> _loadPersistedTwoFactorState(String uid) async {
    if (AppSession.twoFactorVerified) {
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'tf_verified_$uid';
      final expiry = prefs.getInt(key);
      final now = DateTime.now().millisecondsSinceEpoch;
      if (expiry != null && now < expiry) {
        AppSession.twoFactorVerified = true;
        return true;
      }
      if (expiry != null) {
        await prefs.remove(key);
      }
    } catch (_) {}

    return false;
  }

  @override
  void initState() {
    super.initState();
    _flagsStream = SecurityFlagsService.watch();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserDocStream(String uid) {
    if (uid != _cachedUid) {
      _cachedUid = uid;
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    return _userDocStream!;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Aegis',
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
            unawaited(
              _cleanupAuthState(clearPersistedTwoFactor: _hadAuthenticatedUser),
            );
            return const LoginPageFirestore();
          }

          _hadAuthenticatedUser = true;

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _getUserDocStream(user.uid),
            builder: (context, userDocSnap) {
              final bootstrapData = AppSession.uid == user.uid
                  ? AppSession.bootstrapUserData
                  : null;
              final userDoc = userDocSnap.data;
              final resolvedData = userDoc?.data() ?? bootstrapData;

              if (userDocSnap.connectionState == ConnectionState.waiting &&
                  resolvedData == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnap.hasError && resolvedData == null) {
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              if (userDoc != null && !userDoc.exists) {
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              if (resolvedData == null) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              final data = resolvedData;
              final status = (data['status'] ?? 'active').toString();
              if (status == 'disabled') {
                // A cached snapshot may still contain the previous disabled
                // state right after an admin re-enables the account.
                if (userDoc != null && userDoc.metadata.isFromCache) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                unawaited(_cleanupAuthState());
                unawaited(FirebaseAuth.instance.signOut());
                return const LoginPageFirestore();
              }

              // personalEmail, passwordChanged, emailVerified read but
              // not currently consumed — kept as data[] access only.
              final onboardingComplete = data['onboardingComplete'] == true;
              final role = (data['role'] ?? '').toString();
              final twoFactorVerifiedUntil =
                  (data['twoFactorVerifiedUntil'] as Timestamp?)?.toDate();
              final hasRemoteTwoFactorSession =
                  twoFactorVerifiedUntil != null &&
                  twoFactorVerifiedUntil.isAfter(DateTime.now());
              if (hasRemoteTwoFactorSession && !AppSession.twoFactorVerified) {
                AppSession.twoFactorVerified = true;
              }

              // Backward compatibility: for old documents that already satisfy
              // onboarding conditions, persist onboardingComplete once.
              // Do NOT auto-complete onboarding — only _markCompleteAfterPhoto
              // in onboarding_page.dart should set onboardingComplete.
              final effectivelyOnboarded = onboardingComplete;
              if (effectivelyOnboarded && !onboardingComplete) {
                // Already onboarded, no-op now.
              }

              // Keep auth email mirrored in Firestore user profile.
              // Only attempt once per uid to avoid write-loops on rebuilds.
              if (!_authEmailMirroredUids.contains(user.uid) &&
                  (data['authEmail'] ?? '').toString().trim().isEmpty &&
                  (user.email ?? '').trim().isNotEmpty) {
                _authEmailMirroredUids.add(user.uid);
                unawaited(
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'authEmail': user.email,
                        'updatedAt': FieldValue.serverTimestamp(),
                      }, SetOptions(merge: true)),
                );
              }

              return StreamBuilder<SecurityFlags>(
                stream: _flagsStream,
                initialData: SecurityFlags.defaults,
                builder: (context, settingsSnap) {
                  final flags = settingsSnap.data ?? SecurityFlags.defaults;

                  if (role != 'gate' &&
                      flags.onboardingEnabled &&
                      !effectivelyOnboarded) {
                    return OnboardingPage(user: user, userData: data);
                  }

                  final requiresTwoFactor =
                      role != 'gate' &&
                      flags.twoFactorEnabled &&
                      effectivelyOnboarded &&
                      !hasRemoteTwoFactorSession;

                  return FutureBuilder<bool>(
                    future: requiresTwoFactor
                        ? _getOrCreateTwoFactorFuture(user.uid)
                        : Future<bool>.value(false),
                    builder: (context, persistedTwoFaSnap) {
                      if (requiresTwoFactor &&
                          !AppSession.twoFactorVerified &&
                          persistedTwoFaSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      return ValueListenableBuilder<bool>(
                        valueListenable: AppSession.twoFactorNotifier,
                        builder: (context, twoFaVerified, _) {
                          if (requiresTwoFactor && !twoFaVerified) {
                            final username = (data['username'] ?? '')
                                .toString();
                            return TwoFactorVerifyPage(
                              uid: user.uid,
                              role: role,
                              username: username,
                              fullName: (data['fullName'] ?? '').toString(),
                              classId: (data['classId'] ?? '').toString(),
                            );
                          }

                          final username = (data['username'] ?? '').toString();

                          AppSession.setUser(
                            uidValue: user.uid,
                            usernameValue: username,
                            roleValue: role,
                            fullNameValue: (data['fullName'] ?? '').toString(),
                            classIdValue: (data['classId'] ?? '').toString(),
                          );

                          unawaited(_saveFcmToken(user.uid));

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
                          }

                          unawaited(_cleanupAuthState());
                          unawaited(FirebaseAuth.instance.signOut());
                          return const LoginPageFirestore();
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
