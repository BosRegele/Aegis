import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../session.dart';

class LoginPageFirestore extends StatefulWidget {
  const LoginPageFirestore({super.key});

  @override
  State<LoginPageFirestore> createState() => _LoginPageFirestoreState();
}

class _LoginPageFirestoreState extends State<LoginPageFirestore> {
  static const Duration _authTimeout = Duration(seconds: 15);
  final userC = TextEditingController();
  final passC = TextEditingController();
  bool loading = false;
  bool passwordVisible = false; // control vizibilitate parola
  DateTime? _blockedUntil;
  Timer? _countdownTimer;
  String _actorKey = '';

  static const _kBlockedUntilMs = 'login_blocked_until_ms';
  static const _kLoginActorKey = 'login_actor_key';

  bool get _isLocallyBlocked {
    if (_blockedUntil == null) return false;
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

  Future<void> _setBlockedForSeconds(int sec) async {
    if (sec <= 0) return;
    _blockedUntil = DateTime.now().add(Duration(seconds: sec));
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
    }
  }

  Future<void> _clearLocalBlockState() async {
    _blockedUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBlockedUntilMs);
  }

  Future<void> _loadLocalBlockState() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(_kBlockedUntilMs);
    if (ms == null) return;

    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    if (DateTime.now().isBefore(dt)) {
      _blockedUntil = dt;
      _startCountdown();
      if (mounted) setState(() {});
      return;
    }

    await _clearLocalBlockState();
  }

  String _randomHex(int length) {
    final rnd = Random.secure();
    final bytes = List<int>.generate(length ~/ 2, (_) => rnd.nextInt(256));
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  Future<void> _ensureActorKey() async {
    if (_actorKey.isNotEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = (prefs.getString(_kLoginActorKey) ?? '').trim();
    if (RegExp(r'^[a-f0-9]{32,128}$').hasMatch(existing)) {
      _actorKey = existing;
      return;
    }

    final generated = _randomHex(32);
    _actorKey = generated;
    await prefs.setString(_kLoginActorKey, generated);
  }

  @override
  void initState() {
    super.initState();
    userC.addListener(() {
      if (mounted) setState(() {});
    });
    unawaited(_loadLocalBlockState());
    unawaited(_ensureActorKey());
  }

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? fallback;
  }

  Future<T> _withAuthTimeout<T>(Future<T> future, String operationLabel) async {
    try {
      return await future.timeout(_authTimeout);
    } on TimeoutException {
      throw Exception('$operationLabel timeout');
    }
  }

  Future<String> _resolveUsernameFromInput(String input) async {
    final resolveRes = await _withAuthTimeout(
      FirebaseFunctions.instance
          .httpsCallable('authResolveLoginInput')
          .call({'input': input}),
      'authResolveLoginInput',
    );
    final resolveData = Map<String, dynamic>.from(resolveRes.data as Map);
    final username = (resolveData['username'] ?? '').toString().toLowerCase();
    if (username.isEmpty) {
      throw Exception('Date invalide - username lipsa');
    }
    return username;
  }

  Future<void> _showResetPasswordCodeDialog(String initialInput) async {
    final inputC = TextEditingController(text: initialInput);
    final codeC = TextEditingController();
    final newPassC = TextEditingController();
    final confirmPassC = TextEditingController();

    bool submitting = false;
    bool showPass = false;
    bool showConfirmPass = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Resetare parola'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: inputC,
                      decoration: const InputDecoration(
                        labelText: 'Username sau email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: codeC,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cod resetare (6 cifre)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPassC,
                      obscureText: !showPass,
                      decoration: InputDecoration(
                        labelText: 'Parola noua',
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPass ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(() => showPass = !showPass);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmPassC,
                      obscureText: !showConfirmPass,
                      decoration: InputDecoration(
                        labelText: 'Confirma parola noua',
                        suffixIcon: IconButton(
                          icon: Icon(
                            showConfirmPass
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setDialogState(
                              () => showConfirmPass = !showConfirmPass,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Anuleaza'),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final input = inputC.text.trim().toLowerCase();
                          final code = codeC.text.trim();
                          final newPass = newPassC.text.trim();
                          final confirmPass = confirmPassC.text.trim();

                          if (input.isEmpty ||
                              code.isEmpty ||
                              newPass.isEmpty ||
                              confirmPass.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Completeaza toate campurile.'),
                              ),
                            );
                            return;
                          }
                          if (newPass != confirmPass) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Parolele nu coincid.'),
                              ),
                            );
                            return;
                          }
                          if (newPass.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parola trebuie sa aiba minim 6 caractere.',
                                ),
                              ),
                            );
                            return;
                          }

                          var dialogClosed = false;
                          setDialogState(() => submitting = true);
                          try {
                            await FirebaseFunctions.instance
                                .httpsCallable('authConfirmPasswordReset')
                                .call({
                                  'input': input,
                                  'code': code,
                                  'newPassword': newPass,
                                });

                            if (!mounted) return;
                            Navigator.of(ctx).pop();
                            dialogClosed = true;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parola a fost resetata. Te poti loga acum.',
                                ),
                              ),
                            );
                          } on FirebaseFunctionsException catch (e) {
                            var msg = 'Resetare esuata. Incearca din nou.';
                            if (e.code == 'invalid-argument') {
                              msg = 'Date invalide sau cod gresit.';
                            } else if (e.code == 'deadline-exceeded') {
                              msg = 'Cod expirat. Cere un cod nou.';
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Resetare esuata. Incearca din nou.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (dialogClosed) return;
                            setDialogState(() => submitting = false);
                          }
                        },
                  child: Text(submitting ? 'Se salveaza...' : 'Reseteaza'),
                ),
              ],
            );
          },
        );
      },
    );

    inputC.dispose();
    codeC.dispose();
    newPassC.dispose();
    confirmPassC.dispose();
  }

  Future<void> _openForgotPasswordFlow() async {
    final inputC = TextEditingController(text: userC.text.trim());
    bool sending = false;
    String? nextInput;
    String? postMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: !sending,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Ai uitat parola?'),
              content: TextField(
                controller: inputC,
                decoration: const InputDecoration(
                  labelText: 'Username sau email',
                  hintText: 'ex: elev1 sau elev1@gmail.com',
                ),
              ),
              actions: [
                TextButton(
                  onPressed: sending ? null : () => Navigator.of(ctx).pop(),
                  child: const Text('Anuleaza'),
                ),
                ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          final input = inputC.text.trim().toLowerCase();
                          if (input.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Completeaza username sau email.',
                                ),
                              ),
                            );
                            return;
                          }

                          var dialogClosed = false;
                          setDialogState(() => sending = true);
                          try {
                            final res = await FirebaseFunctions.instance
                                .httpsCallable('authRequestPasswordReset')
                                .call({'input': input});
                            final data = Map<String, dynamic>.from(
                              res.data as Map,
                            );
                            final cooldown = _asInt(
                              data['cooldownSeconds'],
                              fallback: 0,
                            );

                            if (!mounted) return;
                            nextInput = input;
                            postMessage = cooldown > 0
                                ? 'Un cod a fost deja trimis recent. Reincearca in ${cooldown}s.'
                                : 'Daca datele exista in sistem, am trimis codul de resetare pe email.';
                            Navigator.of(ctx).pop();
                            dialogClosed = true;
                          } on FirebaseFunctionsException catch (e) {
                            var msg =
                                'Nu am putut trimite codul. Incearca din nou.';
                            if (e.code == 'failed-precondition') {
                              msg = e.message ?? msg;
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text(msg)));
                            }
                          } catch (_) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Nu am putut trimite codul. Incearca din nou.',
                                  ),
                                ),
                              );
                            }
                          } finally {
                            if (dialogClosed) return;
                            setDialogState(() => sending = false);
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.email_outlined, size: 18),
                  label: const Text('Trimite cod'),
                ),
              ],
            );
          },
        );
      },
    );

    inputC.dispose();

    if (!mounted) return;
    if (postMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(postMessage!)));
    }
    if (nextInput != null && nextInput!.isNotEmpty) {
      await _showResetPasswordCodeDialog(nextInput!);
    }
  }

  Future<void> _login() async {
    if (loading) return;

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
      final input = userC.text.trim().toLowerCase();
      final password = passC.text.trim();
      if (input.isEmpty || password.isEmpty) {
        throw Exception("Date invalide");
      }

      final username = await _resolveUsernameFromInput(input);

      await _ensureActorKey();
      if (_actorKey.isEmpty) {
        throw Exception("Autentificare temporar indisponibila");
      }

      final precheck = await _withAuthTimeout(
        FirebaseFunctions.instance
            .httpsCallable('authPrecheckLogin')
            .call({'username': username, 'actorKey': _actorKey}),
        'authPrecheckLogin',
      );
      final preData = Map<String, dynamic>.from(precheck.data as Map);
      attemptToken = (preData['attemptToken'] ?? '').toString();
      if (preData['blocked'] == true) {
        final sec = _asInt(preData['remainingSeconds'], fallback: 120);
        await _setBlockedForSeconds(sec);
        throw Exception("Cont blocat temporar. Incearca din nou in ${sec}s.");
      }

      final email = "$username@school.local";
      final cred = await _withAuthTimeout(
        FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        ),
        'signInWithEmailAndPassword',
      );
      final uid = cred.user!.uid;
      final doc = await _withAuthTimeout(
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get(const GetOptions(source: Source.server)),
        'users/$uid get',
      );

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
      // routing is handled by main.dart's StreamBuilder
      assert(role.isNotEmpty || usernameFromDb.isEmpty);

      AppSession.setUser(
        uidValue: uid,
        usernameValue: usernameFromDb,
        roleValue: role,
        fullNameValue: (data['fullName'] ?? '').toString(),
        classIdValue: (data['classId'] ?? '').toString(),
      );
      AppSession.setBootstrapUserData(uidValue: uid, data: data);

      try {
        await _withAuthTimeout(
          FirebaseFunctions.instance
              .httpsCallable('authRegisterLoginSuccess')
              .call({'actorKey': _actorKey}),
          'authRegisterLoginSuccess',
        );
      } on FirebaseFunctionsException {
        // Keep login successful even if this post-login hook fails.
      } on Exception {
        // Keep login successful even if this post-login hook fails.
      } catch (_) {
        // Keep login successful even if this post-login hook fails.
      }

      // Authentication succeeded. The StreamBuilder in main.dart detects the
      // auth-state change and routes to OnboardingPage, TwoFactorVerifyPage,
      // or the role dashboard — no Navigator.push needed here.
    } on FirebaseAuthException catch (e) {
      String msg = "Date de autentificare invalide.";
      if (e.code == "wrong-password" ||
          e.code == "invalid-credential" ||
          e.code == "invalid-login-credentials" ||
          e.code == "user-not-found" ||
          e.code == "invalid-email" ||
          e.code == "user-disabled") {
        // Extract username from input - might be email or username
        final input = userC.text.trim().toLowerCase();
        String usernameForFailure = input;
        if (input.contains('@')) {
          // If email was entered, try to resolve it via Cloud Function
          try {
            usernameForFailure = await _resolveUsernameFromInput(input);
          } catch (_) {
            // If lookup fails, use original input
          }
        }

        try {
          if (attemptToken.isNotEmpty) {
            final failRes = await FirebaseFunctions.instance
                .httpsCallable('authReportLoginFailure')
                .call({
                  'username': usernameForFailure,
                  'attemptToken': attemptToken,
                  'actorKey': _actorKey,
                });
            final failData = Map<String, dynamic>.from(failRes.data as Map);
            if (failData['blocked'] == true) {
              final sec = _asInt(failData['remainingSeconds'], fallback: 120);
              await _setBlockedForSeconds(sec);
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
        msg =
            "Autentificare temporar indisponibila. Incearca din nou mai tarziu.";
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Autentificarea a expirat. Verifica internetul si incearca din nou.'),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().contains('timeout')
          ? 'Autentificarea a expirat. Verifica internetul si incearca din nou.'
          : 'Autentificare esuata. Incearca din nou.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
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
          Positioned.fill(
            child: Container(
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
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.03)),
          ),
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
                      hintText: "Nume de utilizator sau email",
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: loading ? null : _openForgotPasswordFlow,
                      child: const Text('Ai uitat parola?'),
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
