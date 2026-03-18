import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

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
  DateTime? _blockedUntil;
  String _blockedUsername = '';
  Timer? _countdownTimer;

  static const _kBlockedUntilMs = 'login_blocked_until_ms';
  static const _kBlockedUsername = 'login_blocked_username';

  bool get _isLocallyBlocked {
    if (_blockedUntil == null) return false;
    final entered = userC.text.trim().toLowerCase();
    if (_blockedUsername.isNotEmpty && entered != _blockedUsername) {
      return false;
    }
    return DateTime.now().isBefore(_blockedUntil!);
  }

  int get _remainingSeconds {
    if (_blockedUntil == null) return 0;
    final diff = _blockedUntil!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final expired =
          _blockedUntil != null && DateTime.now().isAfter(_blockedUntil!);
      if (expired) {
        _countdownTimer?.cancel();
        _clearLocalBlockState();
      }
      setState(() {});
    });
  }

  Future<void> _setBlockedForSeconds(int sec, String username) async {
    if (sec <= 0) return;
    _blockedUntil = DateTime.now().add(Duration(seconds: sec));
    _blockedUsername = username.trim().toLowerCase();
    _startCountdown();
    await _saveLocalBlockState();
    setState(() {});
  }

  Future<void> _saveLocalBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_blockedUntil != null) {
      await prefs.setInt(
        _kBlockedUntilMs,
        _blockedUntil!.millisecondsSinceEpoch,
      );
      await prefs.setString(_kBlockedUsername, _blockedUsername);
    }
  }

  Future<void> _clearLocalBlockState() async {
    _blockedUntil = null;
    _blockedUsername = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBlockedUntilMs);
    await prefs.remove(_kBlockedUsername);
  }

  Future<void> _loadLocalBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kBlockedUntilMs);
    final uname = prefs.getString(_kBlockedUsername) ?? '';
    if (ms == null) return;

    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (DateTime.now().isBefore(dt)) {
      _blockedUntil = dt;
      _blockedUsername = uname;
      _startCountdown();
      if (mounted) setState(() {});
      return;
    }

    await _clearLocalBlockState();
  }

  @override
  void initState() {
    super.initState();
    userC.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_loadLocalBlockState());
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  Future<void> _login() async {
    if (_isLocallyBlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Cont blocat temporar. Incearca din nou in ${_remainingSeconds}s.",
            ),
          ),
        );
      }
      return;
    }

    setState(() => loading = true);
    String attemptToken = '';
    try {
      final username = userC.text.trim().toLowerCase();
      final password = passC.text.trim();
      if (username.isEmpty || password.isEmpty) {
        throw Exception("Date invalide");
      }

      final precheck = await FirebaseFunctions.instance
          .httpsCallable('authPrecheckLogin')
          .call({'username': username});
      final preData = Map<String, dynamic>.from(precheck.data as Map);
      attemptToken = (preData['attemptToken'] ?? '').toString();
      if (preData['blocked'] == true) {
        final sec = _asInt(preData['remainingSeconds'], fallback: 120);
        await _setBlockedForSeconds(sec, username);
        throw Exception("Cont blocat temporar. Incearca din nou in ${sec}s.");
      }

      final email = "$username@school.local";
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        throw Exception('Date invalide');
      }

      final data = doc.data() as Map<String, dynamic>;
      if ((data["status"] ?? "active") == "disabled") {
        await FirebaseAuth.instance.signOut();
        throw Exception("Autentificare indisponibila");
      }

      final role = (data["role"] ?? "").toString();
      final usernameFromDb = (data["username"] ?? username).toString();

      await FirebaseFunctions.instance
          .httpsCallable('authRegisterLoginSuccess')
          .call();

      AppSession.setUser(
        uidValue: uid,
        usernameValue: usernameFromDb,
        roleValue: role,
        fullNameValue: (data["fullName"] ?? "").toString(),
        classIdValue: (data["classId"] ?? "").toString(),
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
        throw Exception("Autentificare indisponibila");
      }
    } on FirebaseAuthException catch (e) {
      String msg = "Date de autentificare invalide.";
      if (e.code == "wrong-password" ||
          e.code == "invalid-credential" ||
          e.code == "user-not-found" ||
          e.code == "invalid-email" ||
          e.code == "user-disabled") {
        final username = userC.text.trim().toLowerCase();
        try {
          if (attemptToken.isNotEmpty) {
            final failRes = await FirebaseFunctions.instance
                .httpsCallable('authReportLoginFailure')
                .call({'username': username, 'attemptToken': attemptToken});
            final failData = Map<String, dynamic>.from(failRes.data as Map);
            if (failData['blocked'] == true) {
              final sec = _asInt(failData['remainingSeconds'], fallback: 120);
              await _setBlockedForSeconds(sec, username);
              msg =
                  "Autentificare temporar indisponibila. Incearca din nou mai tarziu.";
            }
          }
        } on FirebaseFunctionsException catch (fx) {
          if (fx.code == 'resource-exhausted') {
            msg =
                "Autentificare temporar indisponibila. Incearca din nou mai tarziu.";
          } else if (fx.code == 'failed-precondition') {
            msg = "Date de autentificare invalide.";
          }
        }
      }
      if (e.code == "too-many-requests") {
        msg = "Autentificare temporar indisponibila. Incearca din nou mai tarziu.";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          const SnackBar(content: Text("Autentificare esuata. Incearca din nou.")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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
                colors: [
                  Color.fromRGBO(122, 175, 91, 1),
                  Color.fromRGBO(90, 150, 65, 1),
                ],
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
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 25,
                    spreadRadius: -10,
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [
                          Color.fromRGBO(122, 175, 91, 1),
                          Color.fromRGBO(90, 150, 65, 1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Autentificare",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 30),

                  TextField(
                    controller: userC,
                    decoration: InputDecoration(
                      hintText: "Nume de utilizator",
                      prefixIcon: const Icon(
                        Icons.person_outline,
                        color: Color.fromRGBO(122, 175, 91, 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color.fromRGBO(122, 175, 91, 1),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: passC,
                    obscureText: !passwordVisible,
                    decoration: InputDecoration(
                      hintText: "Parola",
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: Color.fromRGBO(122, 175, 91, 1),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(
                          color: Color.fromRGBO(122, 175, 91, 1),
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          passwordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
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
                      onPressed: (loading || _isLocallyBlocked) ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
                        elevation: 8,
                        shadowColor: Colors.green.withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        loading
                            ? "Se conecteaza..."
                            : _isLocallyBlocked
                            ? "Blocat (${_remainingSeconds}s)"
                            : "Conectează-te",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 80,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
