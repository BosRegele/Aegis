import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/security_flags_service.dart';
import '../core/session.dart';

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
  static const _darkBg = Color(0xFF0A2E11);
  static const _leftPanelGreen = Color(0xFF0C5A22);
  static const _primaryGreen = Color(0xFF1F6B38);
  static const _cardBg = Color(0xFFF5F7F2);
  static const _infoBoxBg = Color(0xFFE9F4EE);
  static const _infoBoxBorder = Color(0xFFBFDECC);

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
      await _persistVerified();
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

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_sending && _maskedEmail.isEmpty && _error.isEmpty) {
      return const Scaffold(
        backgroundColor: _darkBg,
        body: Center(child: CircularProgressIndicator(color: _primaryGreen)),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _TfaDotsPainter(), size: Size.infinite),
          ),
          SafeArea(child: isWide ? _buildWideLayout() : _buildNarrowLayout()),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 40, child: _buildLeftPanel()),
                Expanded(flex: 60, child: _buildRightPanel()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _buildRightPanel(),
          ),
        ),
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Container(
      color: _leftPanelGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _TfaLeftDotsPainter()),
              Positioned(top: -34, right: -24, child: _panelCircle(130)),
              Positioned(bottom: -42, left: -28, child: _panelCircle(150)),
              SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 54,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: _primaryGreen,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryGreen.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/aegis_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 56),
                        const Text(
                          'Poarta ta catre\nsecuritate academica',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 46,
                            fontWeight: FontWeight.w700,
                            height: 1.08,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Solutia completa, optimizata pentru mobil, '
                          'pentru gestionarea accesului si plecarilor din '
                          'scoala. Creste siguranta prin identitati QR '
                          'dinamice, integrare automata a orarului si '
                          'aprobari in timp real din partea parintilor.',
                          style: TextStyle(
                            color: Color(0xCCFFFFFF),
                            fontSize: 15,
                            height: 1.62,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _panelCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: _cardBg,
      padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: _infoBoxBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _infoBoxBorder),
              ),
              child: const Icon(
                Icons.shield_outlined,
                color: _primaryGreen,
                size: 28,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text(
              'Verificare în doi pași',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              _sending
                  ? 'Pregătim trimiterea codului...'
                  : 'Am trimis un cod de 6 cifre la\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tău"}.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF777777),
                height: 1.4,
              ),
            ),
          ),
          if (_sending) ...[
            const SizedBox(height: 20),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _primaryGreen,
                ),
              ),
            ),
          ],
          const SizedBox(height: 28),
          const Text(
            'Cod de verificare (6 cifre)',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_sending,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              letterSpacing: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '- - - - - -',
              hintStyle: const TextStyle(
                letterSpacing: 4,
                color: Color(0xFFAAAAAA),
                fontSize: 16,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primaryGreen, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            onChanged: (_) {
              if (_error.isNotEmpty) setState(() => _error = '');
            },
            onSubmitted: (_) => _verify(),
          ),
          if (_error.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 19),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (_loading || _sending)
                      ? null
                      : () => FirebaseAuth.instance.signOut(),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 14,
                    color: Color(0xFF333333),
                  ),
                  label: const Text(
                    'Înapoi',
                    style: TextStyle(
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFCCCCCC)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: (_loading || _sending) ? null : _verify,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    disabledBackgroundColor: const Color(0xFF1F6B38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Verifică',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: TextButton(
              onPressed: (_resendCooldown > 0 || _sending) ? null : _resend,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _resendCooldown > 0
                    ? 'Retrimite în ${_resendCooldown}s'
                    : 'Nu ai primit codul? Retrimite →',
                style: TextStyle(
                  color: _resendCooldown > 0
                      ? const Color(0xFF999999)
                      : _primaryGreen,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                const Text(
                  'Ai nevoie de ajutor?',
                  style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Contactează suportul IT',
                    style: TextStyle(
                      fontSize: 13,
                      color: _primaryGreen,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: _primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TfaDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..style = PaintingStyle.fill;
    const spacing = 20.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TfaLeftDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.09);
    const spacing = 18.0;
    for (double y = 12; y < size.height; y += spacing) {
      for (double x = 12; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
