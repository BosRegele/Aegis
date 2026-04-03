import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/session.dart';

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
      FirebaseFunctions.instance.httpsCallable('authResolveLoginInput').call({
        'input': input,
      }),
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

                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            dialogClosed = true;
                            if (!mounted) return;
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
                            if (!dialogClosed) {
                              setDialogState(() => submitting = false);
                            }
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

                            if (!ctx.mounted) return;
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
                            if (!dialogClosed) {
                              setDialogState(() => sending = false);
                            }
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
        FirebaseFunctions.instance.httpsCallable('authPrecheckLogin').call({
          'username': username,
          'actorKey': _actorKey,
        }),
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
      // or the role dashboard ÔÇö no Navigator.push needed here.
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
            content: Text(
              'Autentificarea a expirat. Verifica internetul si incearca din nou.',
            ),
          ),
        );
      }
    } catch (e) {
      final msg = e.toString().contains('timeout')
          ? 'Autentificarea a expirat. Verifica internetul si incearca din nou.'
          : 'Autentificare esuata. Incearca din nou.';
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
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

  // ÔöÇÔöÇ Colors ÔöÇÔöÇ
  static const _darkBg = Color(0xFF0A2E11);
  static const _greenAccent = Color(0xFF0B741D);
  static const _cardBg = Color(0xFFF5F7F2);
  static const _inputBorder = Color(0xFFD6D9D0);
  static const _hintColor = Color(0xFF8A8F84);

  // ÔöÇÔöÇ Dot pattern painter ÔöÇÔöÇ
  Widget _buildDotPattern({
    int alpha = 10,
    double spacing = 20,
    double radius = 1.5,
  }) {
    return CustomPaint(
      painter: _DotPatternPainter(
        alpha: alpha,
        spacing: spacing,
        radius: radius,
      ),
      size: Size.infinite,
    );
  }

  // ÔöÇÔöÇ Branding panel (left side on landscape) ÔöÇÔöÇ
  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF145A1E), Color(0xFF0D3B15), Color(0xFF0A2E11)],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: _buildDotPattern(alpha: 22, spacing: 20, radius: 1.5),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/images/aegis_logo.png',
                    width: 72,
                    height: 72,
                  ),
                ),
                const SizedBox(height: 36),
                const Text(
                  'Poarta ta către\nsecuritate academică',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Soluția completă, optimizată pentru mobil, '
                  'pentru gestionarea accesului și plecărilor din școală. '
                  'Crește siguranța prin identități QR dinamice, '
                  'integrare automată a orarului și aprobări în timp real '
                  'din partea părinților.',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 14,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ÔöÇÔöÇ Login form card ÔöÇÔöÇ
  Widget _buildLoginForm({required bool compact}) {
    final radius = BorderRadius.circular(12);

    return Container(
      width: compact ? double.infinity : 420,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 28 : 44,
        vertical: compact ? 36 : 48,
      ),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (compact) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  'assets/images/aegis_logo.png',
                  width: 56,
                  height: 56,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
          const Text(
            'Autentificare',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1F1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Introduceți datele pentru a accesa contul',
            style: TextStyle(fontSize: 13, color: _hintColor),
          ),
          const SizedBox(height: 28),

          // Username / Email
          const Text(
            'Nume utilizator sau Email',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2C332C),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: userC,
            decoration: InputDecoration(
              hintText: 'ex: ion.popescu@scoala.ro',
              hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _greenAccent, width: 1.5),
              ),
              suffixIcon: const Icon(
                Icons.alternate_email,
                color: _hintColor,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Password label row
          Row(
            children: [
              const Text(
                'Parolă',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C332C),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: loading ? null : _openForgotPasswordFlow,
                child: const Text(
                  'Ai uitat parola?',
                  style: TextStyle(
                    fontSize: 12,
                    color: _greenAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passC,
            obscureText: !passwordVisible,
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius,
                borderSide: const BorderSide(color: _greenAccent, width: 1.5),
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  passwordVisible
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _hintColor,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => passwordVisible = !passwordVisible),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (loading || _isLocallyBlocked) ? null : _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: _greenAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isLocallyBlocked
                              ? 'Blocat (${_remainingSeconds}s)'
                              : 'Conectează-te',
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(
              children: const [
                Text(
                  'Nu ai un cont încă?',
                  style: TextStyle(fontSize: 13, color: _hintColor),
                ),
                SizedBox(height: 4),
                Text(
                  'Contactează administrația instituției',
                  style: TextStyle(
                    fontSize: 13,
                    color: _greenAccent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          Positioned.fill(child: _buildDotPattern(alpha: 8, radius: 1.0)),
          SafeArea(child: isWide ? _buildLandscape() : _buildPortrait()),
        ],
      ),
    );
  }

  // ÔöÇÔöÇ LANDSCAPE: split view ÔöÇÔöÇ
  Widget _buildLandscape() {
    return Center(
      child: Material(
        color: Colors.transparent,
        elevation: 24,
        shadowColor: Colors.black,
        borderRadius: BorderRadius.circular(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960, maxHeight: 620),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Row(
              children: [
                Expanded(child: _buildBrandingPanel()),
                Expanded(
                  child: Container(
                    color: _cardBg,
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: _buildLoginForm(compact: false),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ÔöÇÔöÇ PORTRAIT: card over dark background ÔöÇÔöÇ
  Widget _buildPortrait() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _buildLoginForm(compact: true),
          ),
        ),
      ),
    );
  }
}

// ÔöÇÔöÇ Dot pattern painter ÔöÇÔöÇ
class _DotPatternPainter extends CustomPainter {
  final int alpha;
  final double spacing;
  final double radius;

  const _DotPatternPainter({
    this.alpha = 10,
    this.spacing = 20,
    this.radius = 1.5,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(alpha)
      ..style = PaintingStyle.fill;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DotPatternPainter oldDelegate) =>
      oldDelegate.alpha != alpha ||
      oldDelegate.spacing != spacing ||
      oldDelegate.radius != radius;
}
