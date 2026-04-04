import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/services/admin_api.dart';
import '../core/session.dart';
import 'login_add_photo.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> userData;

  const OnboardingPage({required this.user, required this.userData, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepEmail = 'email';
  static const _stepPassword = 'password';
  static const _stepPhoto = 'photo';
  static const _stepComplete = 'complete';

  static const _darkBg = Color(0xFF0A2E11);
  static const _leftPanelGreen = Color(0xFF0C5A22);
  static const _primaryGreen = Color(0xFF1F6B38);
  static const _cardBg = Color(0xFFF5F7F2);
  static const _infoBoxBg = Color(0xFFE9F4EE);
  static const _infoBoxBorder = Color(0xFFBFDECC);

  final _emailC = TextEditingController();
  final _newPasswordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _codeSent = false;
  String _step = _stepEmail;
  String? _errorMsg;
  final _api = AdminApi();

  bool get _isSecretariatRole {
    final role = (widget.userData['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return role == 'secretariat' || role == 'admin';
  }

  bool get _isStudentRole {
    final role = (widget.userData['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    return role == 'student';
  }

  @override
  void initState() {
    super.initState();
    final existingEmail = (widget.userData['personalEmail'] ?? '').toString();
    final emailVerified = widget.userData['emailVerified'] == true;
    final passwordChanged = widget.userData['passwordChanged'] == true;
    if (existingEmail.trim().isNotEmpty) {
      _emailC.text = existingEmail;
    }
    if (passwordChanged && _isStudentRole) {
      _step = _stepPhoto;
    } else if (passwordChanged) {
      // Non-student with passwordChanged but onboardingComplete still false
      // (e.g. re-sign-in failed after setNewPassword, or old data).
      // Fire-and-forget: call markPasswordChanged to set onboardingComplete
      // in Firestore. The StreamBuilder in main.dart will pick it up and
      // navigate away. Do NOT touch AppSession to avoid rebuild loops.
      _step = _stepComplete;
      _loading = true;
      Future.microtask(() async {
        try {
          await _api.markPasswordChanged(uid: widget.user.uid);
        } catch (_) {}
      });
    } else if (existingEmail.trim().isNotEmpty && emailVerified) {
      _step = _stepPassword;
    } else {
      _step = _stepEmail;
    }
  }

  Future<void> _sendCode() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Email invalid');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      await _api.sendVerificationEmail(uid: widget.user.uid, email: email);
      if (mounted) {
        setState(() {
          _codeSent = true;
          _loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cod trimis pe email. Verifica inbox-ul.'),
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMsg = e.message ?? 'Nu am putut trimite codul.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Eroare: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyEmail() async {
    if (!_codeSent) {
      setState(() => _errorMsg = 'Trimite mai intai codul pe email.');
      return;
    }
    final code = _verificationCodeC.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'Introdu codul de verificare');
      return;
    }
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final result = await _api.verifyEmailCode(
        uid: widget.user.uid,
        code: code,
      );
      if (result['verified'] != true)
        throw Exception('Cod de verificare invalid');
      _newPasswordC.clear();
      _confirmPasswordC.clear();
      if (mounted)
        setState(() {
          _step = _stepPassword;
          _loading = false;
          _errorMsg = null;
        });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Cod incorect. Verifică și încearcă din nou.';
        _loading = false;
      });
    }
  }

  Future<void> _submitPassword() async {
    final newPass = _newPasswordC.text.trim();
    final confirmPass = _confirmPasswordC.text.trim();
    if (newPass.isEmpty || newPass.length < 8) {
      setState(
        () => _errorMsg = 'Parola trebuie sa aiba cel putin 8 caractere',
      );
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'Parolele nu se potrivesc');
      return;
    }

    // Dismiss keyboard before async work
    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      // 1) Change password server-side.
      //    The CF does NOT write to Firestore to avoid race conditions.
      final result = await _api.setNewPassword(password: newPass);

      // 2) Re-authenticate with the NEW password immediately.
      //    updateUser() revoked the old refresh token; this restores the
      //    auth session before any Firestore listener can react.
      final authEmail = (result['authEmail'] ?? widget.user.email ?? '')
          .toString();
      if (authEmail.isNotEmpty) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: authEmail,
          password: newPass,
        );
      }

      if (!mounted) return;

      // 3) NOW that auth is restored, write to Firestore.
      if (_isStudentRole) {
        // Student → mark passwordChanged, then go to photo step.
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .set({
              'passwordChanged': true,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        if (!mounted) return;
        setState(() {
          _step = _stepPhoto;
          _loading = false;
        });
      } else {
        // Non-student → call markPasswordChanged which sets
        // passwordChanged + onboardingComplete + twoFactorVerifiedUntil.
        // StreamBuilder in main.dart will pick up onboardingComplete
        // and route away from OnboardingPage.
        await _api.markPasswordChanged(uid: widget.user.uid);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Eroare la schimbarea parolei: $e';
        _loading = false;
      });
    }
  }

  Future<void> _markCompleteAfterPhoto() async {
    AppSession.twoFactorVerified = true;
    await _api.markPasswordChanged(uid: widget.user.uid);
    if (mounted) setState(() => _step = _stepComplete);
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void _goBackToEmailStep() {
    if (_loading) return;
    setState(() {
      _step = _stepEmail;
      _errorMsg = null;
    });
  }

  void _goBackToPasswordStep() {
    setState(() {
      _step = _stepPassword;
      _errorMsg = null;
    });
  }

  @override
  void dispose() {
    _emailC.dispose();
    _newPasswordC.dispose();
    _confirmPasswordC.dispose();
    _verificationCodeC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_step == _stepPhoto) {
      return ProfilePicturePage(
        user: widget.user,
        onBack: _goBackToPasswordStep,
        onFinalize: _markCompleteAfterPhoto,
        canUploadPhoto: !_isSecretariatRole,
        showSkipButton: _isSecretariatRole,
      );
    }
    if (_step == _stepComplete) return _buildCompleteScreen();

    final isWide = MediaQuery.of(context).size.width > 750;

    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          Positioned.fill(child: _buildDotPattern(alpha: 8, radius: 1.0)),
          SafeArea(child: isWide ? _buildWideLayout() : _buildNarrowLayout()),
        ],
      ),
    );
  }

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
              CustomPaint(painter: _OnboardingLeftDotsPainter()),
              Positioned(top: -34, right: -24, child: _panelCircle(130)),
              Positioned(bottom: -42, left: -28, child: _panelCircle(150)),
              SingleChildScrollView(
                padding: EdgeInsets.zero,
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
                                color: _primaryGreen.withOpacity(0.35),
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
        color: Colors.white.withOpacity(0.07),
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
          _buildStepIndicator(),
          const SizedBox(height: 22),
          ..._buildStepContent(),
          const SizedBox(height: 18),
          _buildHelpText(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final n = _step == _stepEmail
        ? 1
        : _step == _stepPassword
        ? 2
        : 3;
    return Row(
      children: [
        Text(
          'PASUL $n DIN 3',
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < n ? _primaryGreen : const Color(0xFFCDE0D4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStepContent() {
    switch (_step) {
      case _stepEmail:
        return _emailStepWidgets();
      case _stepPassword:
        return _passwordStepWidgets();
      default:
        return [];
    }
  }

  List<Widget> _emailStepWidgets() => [
    const Text(
      'Configurare Email',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
        height: 1.1,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Introdu adresa de email personal si codul de verificare.',
      style: TextStyle(fontSize: 13, color: Color(0xFF777777), height: 1.4),
    ),
    const SizedBox(height: 28),

    _label('Email Personal'),
    const SizedBox(height: 6),
    _field(
      controller: _emailC,
      hint: 'nume@scoala.edu.ro',
      keyboard: TextInputType.emailAddress,
      suffix: const Icon(
        Icons.alternate_email,
        color: Color(0xFF999999),
        size: 20,
      ),
    ),
    const SizedBox(height: 4),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _loading ? null : _sendCode,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          _codeSent ? 'Retrimite codul →' : 'Trimite cod pe email →',
          style: const TextStyle(
            color: _primaryGreen,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
    const SizedBox(height: 16),

    _label('Cod Verificare (6 cifre)'),
    const SizedBox(height: 6),
    _field(
      controller: _verificationCodeC,
      hint: '• • • • • •',
      keyboard: TextInputType.number,
      suffix: const Icon(
        Icons.vpn_key_outlined,
        color: Color(0xFF999999),
        size: 20,
      ),
    ),
    const SizedBox(height: 12),

    _infoBox('Verifica folderul Spam daca nu ai primit codul.'),

    if (_errorMsg != null) ...[
      const SizedBox(height: 12),
      _errorBox(_errorMsg!),
    ],
    const SizedBox(height: 24),

    _navRow(
      onBack: _loading ? null : _signOut,
      onContinue: _loading ? null : _verifyEmail,
      continueLabel: 'Continua',
    ),
  ];

  List<Widget> _passwordStepWidgets() => [
    const Text(
      'Setare Parola',
      style: TextStyle(
        fontSize: 30,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A),
        height: 1.1,
      ),
    ),
    const SizedBox(height: 8),
    const Text(
      'Alege o parola securizata pentru contul tau.',
      style: TextStyle(fontSize: 13, color: Color(0xFF777777), height: 1.4),
    ),
    const SizedBox(height: 28),

    _label('Parola noua (min. 8 caractere)'),
    const SizedBox(height: 6),
    _field(
      controller: _newPasswordC,
      hint: '••••••••',
      obscure: !_showPassword,
      suffix: IconButton(
        icon: Icon(
          _showPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF999999),
          size: 20,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
    ),
    const SizedBox(height: 16),

    _label('Confirma parola'),
    const SizedBox(height: 6),
    _field(
      controller: _confirmPasswordC,
      hint: '••••••••',
      obscure: !_showConfirmPassword,
      suffix: IconButton(
        icon: Icon(
          _showConfirmPassword
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF999999),
          size: 20,
        ),
        onPressed: () =>
            setState(() => _showConfirmPassword = !_showConfirmPassword),
      ),
    ),

    if (_errorMsg != null) ...[
      const SizedBox(height: 12),
      _errorBox(_errorMsg!),
    ],
    const SizedBox(height: 28),

    _navRow(
      onBack: _loading ? null : _goBackToEmailStep,
      onContinue: _loading ? null : _submitPassword,
      continueLabel: 'Continua',
    ),
  ];

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: Color(0xFF333333),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
        suffixIcon: suffix,
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
          vertical: 13,
        ),
      ),
    );
  }

  Widget _infoBox(String msg) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _infoBoxBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _infoBoxBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: Color(0xFF2D7A4F),
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF3D3D3D),
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _errorBox(String msg) => Container(
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
            msg,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _navRow({
    required VoidCallback? onBack,
    required VoidCallback? onContinue,
    required String continueLabel,
  }) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: Color(0xFF333333),
            ),
            label: const Text(
              'Inapoi',
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
            onPressed: onContinue,
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        continueLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildHelpText() => Center(
    child: Column(
      children: [
        const Text(
          'Ai nevoie de ajutor?',
          style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
        ),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Contacteaza suportul IT',
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
  );

  Widget _buildCompleteScreen() {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _darkBg,
        body: Center(child: CircularProgressIndicator(color: _primaryGreen)),
      );
    }
    return Scaffold(
      backgroundColor: _darkBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: _primaryGreen,
                  size: 72,
                ),
                SizedBox(height: 24),
                Text(
                  'Profil Configurat!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Poti accesa aplicatia.\nBun venit!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF777777),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingLeftDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.09);
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
