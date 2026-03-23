import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin/admin_api.dart';
import 'session.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> userData;

  const OnboardingPage({required this.user, required this.userData, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _emailC = TextEditingController();
  final _newPasswordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();

  bool _loading = false;
  String _step =
      'email-password'; // 'email-password' | 'verify-email' | 'complete'
  String? _errorMsg;
  String? _personalEmail;
  final _api = AdminApi();

  @override
  void initState() {
    super.initState();
    final existingEmail = (widget.userData['personalEmail'] ?? '').toString();
    final passwordChanged = widget.userData['passwordChanged'] == true;
    final emailVerified = widget.userData['emailVerified'] == true;

    if (existingEmail.trim().isNotEmpty) {
      _emailC.text = existingEmail;
      _personalEmail = existingEmail;
    }

    // If the user already changed the password but didn't verify email yet,
    // continue from verification step to avoid forcing another password change.
    if (existingEmail.trim().isNotEmpty && passwordChanged && !emailVerified) {
      _step = 'verify-email';
      return;
    }

    _step = 'email-password';
  }

  Future<void> _submitEmailAndPassword() async {
    final email = _emailC.text.trim();
    final newPass = _newPasswordC.text.trim();
    final confirmPass = _confirmPasswordC.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMsg = 'Email invalid');
      return;
    }
    if (newPass.isEmpty || newPass.length < 8) {
      setState(
        () => _errorMsg = 'Parola trebuie să aibă cel puțin 8 caractere',
      );
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'Parolele nu se potrivesc');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // 1. Schimb parola în Firebase Auth
      await widget.user.updatePassword(newPass);

      // 2. Marchez schimbarea parolei prin Cloud Function
      await _api.markPasswordChanged(uid: widget.user.uid);

      // 3. Trimit email de verificare prin Cloud Function
      await _api.sendVerificationEmail(uid: widget.user.uid, email: email);

      _personalEmail = email;

      setState(() {
        _step = 'verify-email';
        _loading = false;
        _errorMsg = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email de verificare trimis. Verifică inbox-ul.'),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMsg = 'Eroare: ${e.message}';
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
    final code = _verificationCodeC.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMsg = 'Introduc codul de verificare');
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // Cloud Function verifică codul
      final result = await _api.verifyEmailCode(
        uid: widget.user.uid,
        code: code,
      );

      if (result['verified'] != true) {
        throw Exception('Cod de verificare invalid');
      }

      setState(() {
        _step = 'complete';
        _loading = false;
      });

      // Refresh și navighează după 1.5s
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          // Skip 2FA for this session — user just completed onboarding
          AppSession.twoFactorVerified = true;
          Navigator.of(context).pushReplacementNamed('/');
        }
      }
    } catch (e) {
      setState(() {
        _errorMsg = 'Cod invalid: $e';
        _loading = false;
      });
    }
  }

  void _goBackToEmailStep() {
    if (_loading) return;

    setState(() {
      _step = 'email-password';
      _verificationCodeC.clear();
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
    const primaryGreen = Color(0xFF5A9641);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Completează Profilul'),
        automaticallyImplyLeading: false,
        backgroundColor: primaryGreen,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_step == 'email-password') ...[
                    const Text(
                      'Configurează Contul Tău',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Introduc un email personal și o parolă nouă pentru a proteja contul.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailC,
                      decoration: InputDecoration(
                        labelText: 'Email Personal',
                        hintText: 'exampl@gmail.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _newPasswordC,
                      decoration: InputDecoration(
                        labelText: 'Parolă Nouă (min 8 caractere)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPasswordC,
                      decoration: InputDecoration(
                        labelText: 'Confirmă Parola',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      obscureText: true,
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _submitEmailAndPassword,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: primaryGreen,
                          disabledBackgroundColor: primaryGreen.withOpacity(
                            0.5,
                          ),
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
                            : const Text(
                                'Continuă',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ] else if (_step == 'verify-email') ...[
                    const Text(
                      'Verifică Email-ul',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Am trimis un cod de verificare la\n$_personalEmail\n\nIntroduci codul din email.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _verificationCodeC,
                      decoration: InputDecoration(
                        labelText: 'Cod de Verificare (6 cifre)',
                        hintText: '123456',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    if (_errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          border: Border.all(color: Colors.red),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _errorMsg!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _goBackToEmailStep,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: primaryGreen),
                            ),
                            child: const Text('Inapoi'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _loading ? null : _verifyEmail,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              backgroundColor: primaryGreen,
                              disabledBackgroundColor: primaryGreen.withOpacity(
                                0.5,
                              ),
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
                                : const Text(
                                    'Verifică',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (_step == 'complete') ...[
                    const Icon(
                      Icons.check_circle,
                      color: primaryGreen,
                      size: 72,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Profil Configurat!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Poți accesa aplicația.\nBun venit!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
