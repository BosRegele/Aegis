import 'package:flutter/material.dart';
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
  static const _stepEmail    = 'email';
  static const _stepPassword = 'password';
  static const _stepPhoto    = 'photo';
  static const _stepComplete = 'complete';

  static const _darkBg        = Color(0xFF0B2B17);
  static const _leftPanelGreen = Color(0xFF0C5A22);
  static const _primaryGreen  = Color(0xFF1F6B38);
  static const _cardCream     = Color(0xFFF5F1E8);
  static const _infoBoxBg     = Color(0xFFE9F4EE);
  static const _infoBoxBorder = Color(0xFFBFDECC);

  final _emailC            = TextEditingController();
  final _newPasswordC      = TextEditingController();
  final _confirmPasswordC  = TextEditingController();
  final _verificationCodeC = TextEditingController();

  bool    _loading             = false;
  bool    _showPassword        = false;
  bool    _showConfirmPassword = false;
  bool    _codeSent            = false;
  String  _step                = _stepEmail;
  String? _errorMsg;
  final   _api                 = AdminApi();

  bool get _isSecretariatRole {
    final role = (widget.userData['role'] ?? '').toString().trim().toLowerCase();
    return role == 'secretariat' || role == 'admin';
  }

  @override
  void initState() {
    super.initState();
    final existingEmail = (widget.userData['personalEmail'] ?? '').toString();
    final emailVerified = widget.userData['emailVerified'] == true;
    if (existingEmail.trim().isNotEmpty) {
      _emailC.text   = existingEmail;
    }
    _step = (existingEmail.trim().isNotEmpty && emailVerified)
        ? _stepPassword
        : _stepEmail;
  }

  Future<void> _sendCode() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Email invalid');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await _api.sendVerificationEmail(uid: widget.user.uid, email: email);
      if (mounted) {
        setState(() { _codeSent = true; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cod trimis pe email. Verifica inbox-ul.')),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() { _errorMsg = e.message ?? 'Nu am putut trimite codul.'; _loading = false; });
    } catch (e) {
      setState(() { _errorMsg = 'Eroare: $e'; _loading = false; });
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
    setState(() { _loading = true; _errorMsg = null; });
    try {
      final result = await _api.verifyEmailCode(uid: widget.user.uid, code: code);
      if (result['verified'] != true) throw Exception('Cod de verificare invalid');
      _newPasswordC.clear();
      _confirmPasswordC.clear();
      if (mounted) setState(() { _step = _stepPassword; _loading = false; _errorMsg = null; });
    } catch (e) {
      setState(() { _errorMsg = 'Cod invalid: $e'; _loading = false; });
    }
  }

  Future<void> _submitPassword() async {
    final newPass     = _newPasswordC.text.trim();
    final confirmPass = _confirmPasswordC.text.trim();
    if (newPass.isEmpty || newPass.length < 8) {
      setState(() => _errorMsg = 'Parola trebuie sa aiba cel putin 8 caractere');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'Parolele nu se potrivesc');
      return;
    }
    setState(() { _loading = true; _errorMsg = null; });
    try {
      await widget.user.updatePassword(newPass);
      if (mounted) setState(() { _step = _stepPhoto; _loading = false; });
    } on FirebaseAuthException catch (e) {
      setState(() { _errorMsg = 'Eroare: ${e.message}'; _loading = false; });
    } catch (e) {
      setState(() { _errorMsg = 'Eroare: $e'; _loading = false; });
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
    setState(() { _step = _stepEmail; _errorMsg = null; });
  }

  void _goBackToPasswordStep() {
    setState(() { _step = _stepPassword; _errorMsg = null; });
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

    return Scaffold(
      backgroundColor: _darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return Center(
            child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
          );
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.24),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              height: 560,
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
      ),
    );
  }

  Widget _buildNarrowLayout() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMobileBrandingCard(),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _buildRightPanel(compact: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileBrandingCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _leftPanelGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _OnboardingLeftDotsPainter())),
          Positioned(top: -26, right: -18, child: _panelCircle(112)),
          Positioned(bottom: -34, left: -20, child: _panelCircle(120)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGreen.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/aegis_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Poarta ta către\nsecuritate academică',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Soluția completă, optimizată pentru mobil, pentru gestionarea accesului și plecărilor din școală.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13,
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

  Widget _buildLeftPanel() {
    return Container(
      color: _leftPanelGreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _OnboardingLeftDotsPainter()),
          Positioned(top: -34, right: -24, child: _panelCircle(130)),
          Positioned(bottom: -42, left: -28, child: _panelCircle(150)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
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
                const SizedBox(height: 48),
                const Text(
                  'Poarta ta către\nsecuritate academică',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Soluția completă, optimizată pentru mobil, '
                  'pentru gestionarea accesului și plecărilor din '
                  'școală. Crește siguranța prin identități QR '
                  'dinamice, integrare automată a orarului și '
                  'aprobări în timp real din partea părinților.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
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

  Widget _buildRightPanel({bool compact = false}) {
    return Container(
      color: _cardCream,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 44,
        vertical: compact ? 22 : 36,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStepIndicator(compact: compact),
          SizedBox(height: compact ? 18 : 22),
          ..._buildStepContent(compact: compact),
          SizedBox(height: compact ? 16 : 18),
          _buildHelpText(compact: compact),
        ],
      ),
    );
  }

  Widget _buildStepIndicator({bool compact = false}) {
    final n = _step == _stepEmail ? 1 : _step == _stepPassword ? 2 : 3;
    return Row(
      children: [
        Text(
          'PASUL $n DIN 3',
          style: TextStyle(
            fontSize: compact ? 10 : 11,
            letterSpacing: compact ? 1.2 : 1.6,
            fontWeight: FontWeight.w600,
            color: _primaryGreen,
          ),
        ),
        SizedBox(width: compact ? 10 : 14),
        Expanded(
          child: Row(
            children: List.generate(3, (i) => Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < n ? _primaryGreen : const Color(0xFFCDE0D4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStepContent({bool compact = false}) {
    switch (_step) {
      case _stepEmail:    return _emailStepWidgets(compact: compact);
      case _stepPassword: return _passwordStepWidgets(compact: compact);
      default:            return [];
    }
  }

  List<Widget> _emailStepWidgets({bool compact = false}) => [
    Text(
      'Configurare Email',
      style: TextStyle(
        fontSize: compact ? 26 : 30, fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A), height: 1.1,
      ),
    ),
    SizedBox(height: compact ? 6 : 8),
    Text(
      'Introdu adresa de email personal si codul de verificare.',
      style: TextStyle(
        fontSize: compact ? 12.5 : 13,
        color: const Color(0xFF777777),
        height: 1.4,
      ),
    ),
    SizedBox(height: compact ? 22 : 28),

    _label('Email Personal', compact: compact),
    const SizedBox(height: 6),
    _field(
      controller: _emailC,
      hint: 'nume@scoala.edu.ro',
      keyboard: TextInputType.emailAddress,
      suffix: const Icon(Icons.alternate_email, color: Color(0xFF999999), size: 20),
      compact: compact,
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
          style: TextStyle(
            color: _primaryGreen,
            fontSize: compact ? 12 : 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ),
    const SizedBox(height: 16),

    _label('Cod Verificare (6 cifre)', compact: compact),
    const SizedBox(height: 6),
    _field(
      controller: _verificationCodeC,
      hint: '• • • • • •',
      keyboard: TextInputType.number,
      suffix: const Icon(Icons.vpn_key_outlined, color: Color(0xFF999999), size: 20),
      compact: compact,
    ),
    const SizedBox(height: 12),

    _infoBox('Verifica folderul Spam daca nu ai primit codul.', compact: compact),

    if (_errorMsg != null) ...[const SizedBox(height: 12), _errorBox(_errorMsg!)],
    SizedBox(height: compact ? 22 : 24),

    _navRow(
      onBack: _loading ? null : _signOut,
      onContinue: _loading ? null : _verifyEmail,
      continueLabel: 'Continua',
      compact: compact,
    ),
  ];

  List<Widget> _passwordStepWidgets({bool compact = false}) => [
    Text(
      'Setare Parola',
      style: TextStyle(
        fontSize: compact ? 26 : 30, fontWeight: FontWeight.bold,
        color: Color(0xFF1A1A1A), height: 1.1,
      ),
    ),
    SizedBox(height: compact ? 6 : 8),
    Text(
      'Alege o parola securizata pentru contul tau.',
      style: TextStyle(
        fontSize: compact ? 12.5 : 13,
        color: const Color(0xFF777777),
        height: 1.4,
      ),
    ),
    SizedBox(height: compact ? 22 : 28),

    _label('Parola noua (min. 8 caractere)', compact: compact),
    const SizedBox(height: 6),
    _field(
      controller: _newPasswordC,
      hint: '••••••••',
      obscure: !_showPassword,
      suffix: IconButton(
        icon: Icon(
          _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF999999), size: 20,
        ),
        onPressed: () => setState(() => _showPassword = !_showPassword),
      ),
      compact: compact,
    ),
    const SizedBox(height: 16),

    _label('Confirma parola', compact: compact),
    const SizedBox(height: 6),
    _field(
      controller: _confirmPasswordC,
      hint: '••••••••',
      obscure: !_showConfirmPassword,
      suffix: IconButton(
        icon: Icon(
          _showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFF999999), size: 20,
        ),
        onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
      ),
      compact: compact,
    ),

    if (_errorMsg != null) ...[const SizedBox(height: 12), _errorBox(_errorMsg!)],
    SizedBox(height: compact ? 22 : 28),

    _navRow(
      onBack: _loading ? null : _goBackToEmailStep,
      onContinue: _loading ? null : _submitPassword,
      continueLabel: 'Continua',
      compact: compact,
    ),
  ];

  Widget _label(String text, {bool compact = false}) => Text(
    text,
    style: TextStyle(
      fontSize: compact ? 13 : 13.5,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF333333),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    bool compact = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      obscureText: obscure,
      style: TextStyle(fontSize: compact ? 13.5 : 14, color: const Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: const Color(0xFFAAAAAA), fontSize: compact ? 13.5 : 14),
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
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 12 : 13),
      ),
    );
  }

  Widget _infoBox(String msg, {bool compact = false}) => Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 11 : 12),
    decoration: BoxDecoration(
      color: _infoBoxBg,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _infoBoxBorder),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFF2D7A4F), size: 19),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            msg,
            style: TextStyle(
              fontSize: compact ? 12.5 : 13,
              color: const Color(0xFF3D3D3D),
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
            style: const TextStyle(fontSize: 13, color: Colors.white, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _navRow({
    required VoidCallback? onBack,
    required VoidCallback? onContinue,
    required String continueLabel,
    bool compact = false,
  }) {
    final backButton = OutlinedButton.icon(
      onPressed: onBack,
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 14, color: Color(0xFF333333),
      ),
      label: const Text(
        'Inapoi',
        style: TextStyle(color: Color(0xFF333333), fontWeight: FontWeight.w500),
      ),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: compact ? 13 : 14),
        side: const BorderSide(color: Color(0xFFCCCCCC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final continueButton = ElevatedButton(
      onPressed: onContinue,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryGreen,
        disabledBackgroundColor: const Color(0xFF1F6B38),
        padding: EdgeInsets.symmetric(vertical: compact ? 13 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
      ),
      child: _loading
          ? const SizedBox(
              height: 20, width: 20,
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
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          backButton,
          const SizedBox(height: 10),
          continueButton,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: backButton),
        const SizedBox(width: 12),
        Expanded(child: continueButton),
      ],
    );
  }

  Widget _buildHelpText({bool compact = false}) => Center(
    child: Column(
      children: [
        Text(
          'Ai nevoie de ajutor?',
          style: TextStyle(fontSize: compact ? 12 : 13, color: const Color(0xFF888888)),
        ),
        GestureDetector(
          onTap: () {},
          child: Text(
            'Contacteaza suportul IT',
            style: TextStyle(
              fontSize: compact ? 12.5 : 13,
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
    return Scaffold(
      backgroundColor: _darkBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 48),
            decoration: BoxDecoration(
              color: _cardCream,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_rounded, color: _primaryGreen, size: 72),
                SizedBox(height: 24),
                Text(
                  'Profil Configurat!',
                  style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A),
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Poti accesa aplicatia.\nBun venit!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF777777), height: 1.5),
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
