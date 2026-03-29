import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/security_flags_service.dart';
import '../session.dart';

class TwoFactorVerifyPage extends StatefulWidget {
  final String uid;
  final String role;
  final String username;
  final String fullName;
  final String classId;

  const TwoFactorVerifyPage({
    super.key,
    required this.uid,
    required this.role,
    required this.username,
    required this.fullName,
    required this.classId,
  });

  @override
  State<TwoFactorVerifyPage> createState() => _TwoFactorVerifyPageState();
}

class _TwoFactorVerifyPageState extends State<TwoFactorVerifyPage> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _sending = true;
  String _maskedEmail = '';
  String _error = '';
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final flags = await SecurityFlagsService.getOnce();
      if (!mounted) return;

      if (!flags.twoFactorEnabled) {
        AppSession.twoFactorVerified = true;
        return;
      }

      // On web, localStorage is shared across all tabs. If the user already
      // verified 2FA in another tab within the same session, skip the challenge
      // to avoid invalidating the other tab's active code.
      if (await _isAlreadyVerifiedInBrowser()) {
        AppSession.twoFactorVerified = true;
        return;
      }

      await _startChallenge();
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Eroare la initializarea verificarii. Incearca din nou.';
        });
      }
    }
  }

  static String _prefKey(String uid) => 'tf_verified_$uid';

  static Future<bool> _isAlreadyVerifiedInBrowser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // We read the key from the current uid set by the outer StreamBuilder.
      // Because we may not have AppSession.uid at this point yet, we rely on
      // the stored key independently of uid for lookup.
      final keys = prefs.getKeys();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final key in keys) {
        if (!key.startsWith('tf_verified_')) continue;
        final expiry = prefs.getInt(key);
        if (expiry != null && now < expiry) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistVerified() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiry = DateTime.now()
          .add(const Duration(hours: 8))
          .millisecondsSinceEpoch;
      await prefs.setInt(_prefKey(widget.uid), expiry);
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).set({
        'twoFactorVerifiedUntil': Timestamp.fromMillisecondsSinceEpoch(expiry),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _resendCooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCooldown = (_resendCooldown - 1).clamp(0, 9999);
        if (_resendCooldown == 0) t.cancel();
      });
    });
  }

  Future<void> _startChallenge() async {
    setState(() {
      _sending = true;
      _error = '';
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('authStartSecondFactor')
          .call({});
      final data = Map<String, dynamic>.from(result.data as Map);
      final maskedEmail = data['maskedEmail']?.toString() ?? '';
      final cooldown = (data['cooldownRemaining'] as num?)?.toInt() ?? 60;
      setState(() {
        _maskedEmail = maskedEmail;
        _sending = false;
      });
      _startResendCountdown(cooldown > 0 ? cooldown : 60);
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _sending = false;
        _error = e.message ?? 'Eroare la trimiterea codului.';
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = 'Eroare la trimiterea codului. Incearca din nou.';
      });
    }
  }

  Future<void> _verify() async {
    final flags = await SecurityFlagsService.getOnce();
    if (!flags.twoFactorEnabled) {
      AppSession.twoFactorVerified = true;
      return;
    }

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Introdu codul de 6 cifre primit pe email.');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      await FirebaseFunctions.instance
          .httpsCallable('authVerifySecondFactor')
          .call({'code': code});
      // Persist so other open browser tabs skip 2FA automatically.
      await _persistVerified();
      // Setting twoFactorVerified triggers the ValueListenableBuilder in
      // main.dart to rebuild and route to the correct dashboard — no
      // Navigator.push needed (which would remove main.dart's StreamBuilder
      // from the tree and break logout).
      AppSession.twoFactorVerified = true;
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message ?? 'Cod incorect.';
      });
    } catch (_) {
      setState(() {
        _loading = false;
        _error = 'Eroare la verificare. Incearca din nou.';
      });
    }
  }

  Future<void> _resend() async {
    final flags = await SecurityFlagsService.getOnce();
    if (!flags.twoFactorEnabled) {
      AppSession.twoFactorVerified = true;
      return;
    }

    if (_resendCooldown > 0 || _sending) return;
    setState(() {
      _sending = true;
      _error = '';
      _codeController.clear();
    });
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('authResendSecondFactor')
          .call({});
      final data = Map<String, dynamic>.from(result.data as Map);
      setState(() {
        if (data['maskedEmail'] != null) {
          _maskedEmail = data['maskedEmail'].toString();
        }
        _sending = false;
      });
      _startResendCountdown(60);
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _sending = false;
        _error = e.message ?? 'Eroare la retrimitera codului.';
      });
    } catch (_) {
      setState(() {
        _sending = false;
        _error = 'Eroare. Incearca din nou.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sending && _maskedEmail.isEmpty && _error.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: Color(0xFF7AAF5B),
            ),
          ),
        ),
      );
    }

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
                  const Icon(
                    Icons.shield_outlined,
                    size: 52,
                    color: Color(0xFF7AAF5B),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Verificare in doi pasi',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _sending
                        ? 'Pregatim trimiterea codului catre\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tau"}.'
                        : 'Am trimis un cod de 6 cifre la\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tau"}.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54, height: 1.4),
                  ),
                  if (_sending) ...[
                    const SizedBox(height: 18),
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Color(0xFF7AAF5B),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_sending,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      letterSpacing: 8,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: '------',
                      hintStyle: const TextStyle(
                        letterSpacing: 4,
                        color: Colors.black26,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF7AAF5B),
                          width: 2,
                        ),
                      ),
                    ),
                    onChanged: (_) {
                      if (_error.isNotEmpty) {
                        setState(() => _error = '');
                      }
                    },
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: (_loading || _sending) ? null : _verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7AAF5B),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(
                          0xFF7AAF5B,
                        ).withOpacity(0.6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verifica',
                              style: TextStyle(fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: (_resendCooldown > 0 || _sending)
                        ? null
                        : _resend,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Retrimite in ${_resendCooldown}s'
                          : 'Nu ai primit codul? Retrimite',
                      style: TextStyle(
                        color: _resendCooldown > 0
                            ? Colors.grey
                            : const Color(0xFF7AAF5B),
                        fontSize: 13,
                      ),
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
