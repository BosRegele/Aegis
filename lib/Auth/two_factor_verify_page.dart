import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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

  Widget _buildLogoBadge({
    double size = 72,
    double radius = 18,
    Color background = const Color(0xFF3E8B3D),
    double shadowOpacity = 0.34,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: background.withValues(alpha: shadowOpacity),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: EdgeInsets.all(size * 0.14),
          child: Image.asset(
            'assets/images/aegis_logo.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 770, maxHeight: 572),
          child: AspectRatio(
            aspectRatio: 770 / 572,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 26,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF1D6D2C),
                              Color(0xFF0E4B1B),
                              Color(0xFF0A3914),
                            ],
                            stops: [0.0, 0.56, 1.0],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: CustomPaint(
                                painter: _TwoFactorDotsPainter(
                                  color: Color(0x14FFFFFF),
                                  spacing: 18,
                                  radius: 0.9,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 112,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: _buildLogoBadge(
                                  size: 66,
                                  radius: 16,
                                  background: const Color(0xFF4B973D),
                                  shadowOpacity: 0.42,
                                ),
                              ),
                            ),
                            Positioned(
                              left: 38,
                              right: 38,
                              bottom: 36,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Poarta ta către\nsecuritate academică',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  Text(
                                    'Soluția completă, optimizată pentru mobil,\n'
                                    'pentru gestionarea accesului și plecărilor din\n'
                                    'școală. Crește siguranța prin identități QR\n'
                                    'dinamice, integrare automată a orarului și\n'
                                    'aprobări în timp real din partea părinților.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.78),
                                      fontSize: 13.4,
                                      height: 1.6,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        color: const Color(0xFFF8FAEF),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(48, 46, 48, 32),
                          child: Column(
                            children: [
                              const SizedBox(height: 2),
                              Center(
                                child: Image.asset(
                                  'assets/images/aegis_logo.png',
                                  width: 22,
                                  height: 22,
                                  fit: BoxFit.contain,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'Verificare în doi pași',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF192016),
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 230,
                                child: Text(
                                  _sending
                                      ? 'Pregătim trimiterea codului către\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tău"}.'
                                      : 'Am trimis un cod de 6 cifre la\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tău"}.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF697062),
                                    fontSize: 13,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              if (_sending) ...[
                                const SizedBox(height: 12),
                                const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Color(0xFF0B741D),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 34),
                              SizedBox(
                                width: double.infinity,
                                height: 58,
                                child: TextField(
                                  controller: _codeController,
                                  keyboardType: TextInputType.number,
                                  maxLength: 6,
                                  enabled: !_sending,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    letterSpacing: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF222820),
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    hintText: '-  -  -  -  -  -',
                                    hintStyle: const TextStyle(
                                      letterSpacing: 8,
                                      color: Color(0xFFC9CEC3),
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 18,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE1E6DB),
                                        width: 1.3,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFE1E6DB),
                                        width: 1.3,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: const BorderSide(
                                        color: Color(0xFF0B741D),
                                        width: 1.8,
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
                              ),
                              if (_error.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0B741D)
                                            .withValues(alpha: 0.20),
                                        blurRadius: 14,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: (_loading || _sending)
                                        ? null
                                        : _verify,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B741D),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor: const Color(
                                        0xFF0B741D,
                                      ).withValues(alpha: 0.55),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 0,
                                      textStyle: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Verifică'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                onPressed: (_resendCooldown > 0 || _sending)
                                    ? null
                                    : _resend,
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF0B741D),
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(0, 0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _resendCooldown > 0
                                      ? 'Retrimite în ${_resendCooldown}s'
                                      : 'Nu ai primit codul? Retrimite',
                                  style: TextStyle(
                                    color: _resendCooldown > 0
                                        ? const Color(0xFF99A090)
                                        : const Color(0xFF0B741D),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: Color(0xFFE9EEDF),
                              ),
                              const SizedBox(height: 22),
                              SizedBox(
                                height: 64,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 38,
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            () => Navigator.of(context).pop(),
                                        icon: const Icon(
                                          Icons.arrow_back,
                                          size: 17,
                                        ),
                                        label: const Text('Înapoi'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor:
                                              const Color(0xFF0B741D),
                                          side: const BorderSide(
                                            color: Color(0xFFD9E2CF),
                                          ),
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    const Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Ai nevoie de ajutor?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF8D9388),
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Contactează suportul IT',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF0B741D),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Spacer(flex: 2),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNarrowLayout() {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF1D6D2C),
                        Color(0xFF0E4B1B),
                        Color(0xFF0A3914),
                      ],
                      stops: [0.0, 0.56, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TwoFactorDotsPainter(
                            color: const Color(0x14FFFFFF),
                            spacing: 18,
                            radius: 0.9,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLogoBadge(
                              size: 58,
                              radius: 14,
                              background: const Color(0xFF4B973D),
                              shadowOpacity: 0.40,
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              'Poarta ta către\nsecuritate academică',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Soluția completă pentru acces, identități QR dinamice și aprobări în timp real din partea părinților.',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAEF),
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Center(
                          child: Image.asset(
                            'assets/images/aegis_logo.png',
                            width: 20,
                            height: 20,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Verificare în doi pași',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF192016),
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _sending
                              ? 'Pregătim trimiterea codului către\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tău"}.'
                              : 'Am trimis un cod de 6 cifre la\n${_maskedEmail.isNotEmpty ? _maskedEmail : "emailul tău"}.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF697062),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        if (_sending) ...[
                          const SizedBox(height: 12),
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Color(0xFF0B741D),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 58,
                          child: TextField(
                            controller: _codeController,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            enabled: !_sending,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              letterSpacing: 10,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF222820),
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              hintText: '-  -  -  -  -  -',
                              hintStyle: const TextStyle(
                                letterSpacing: 6,
                                color: Color(0xFFC9CEC3),
                                fontSize: 18,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE1E6DB),
                                  width: 1.2,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFFE1E6DB),
                                  width: 1.2,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(
                                  color: Color(0xFF0B741D),
                                  width: 1.8,
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
                        ),
                        if (_error.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            _error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: (_loading || _sending) ? null : _verify,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0B741D),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(
                                0xFF0B741D,
                              ).withValues(alpha: 0.55),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Verifică'),
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextButton(
                          onPressed: (_resendCooldown > 0 || _sending)
                              ? null
                              : _resend,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF0B741D),
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            _resendCooldown > 0
                                ? 'Retrimite în ${_resendCooldown}s'
                                : 'Nu ai primit codul? Retrimite',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _resendCooldown > 0
                                  ? const Color(0xFF99A090)
                                  : const Color(0xFF0B741D),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFE9EEDF),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back, size: 17),
                                label: const Text('Înapoi'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0B741D),
                                  side: const BorderSide(
                                    color: Color(0xFFD9E2CF),
                                  ),
                                  backgroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Column(
                          children: [
                            Text(
                              'Ai nevoie de ajutor?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8D9388),
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Contactează suportul IT',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF0B741D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_sending && _maskedEmail.isEmpty && _error.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A2E11),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _TwoFactorDotsPainter(
                  color: const Color(0x14FFFFFF),
                  spacing: 22,
                  radius: 1.0,
                ),
              ),
            ),
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: Color(0xFF7AAF5B),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A2E11),
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _TwoFactorDotsPainter(
                color: const Color(0x10FFFFFF),
                spacing: 22,
                radius: 1.0,
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 860) {
                  return _buildNarrowLayout();
                }
                return _buildWideLayout();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoFactorDotsPainter extends CustomPainter {
  final Color color;
  final double spacing;
  final double radius;

  const _TwoFactorDotsPainter({
    required this.color,
    required this.spacing,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (double y = spacing * 0.6; y < size.height; y += spacing) {
      for (double x = spacing * 0.6; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TwoFactorDotsPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.radius != radius;
  }
}
