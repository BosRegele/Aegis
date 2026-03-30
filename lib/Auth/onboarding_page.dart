import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../admin/services/admin_api.dart';
import '../core/session.dart';

class OnboardingPage extends StatefulWidget {
  final User user;
  final Map<String, dynamic> userData;

  const OnboardingPage({required this.user, required this.userData, super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepEmail = 'email';
  static const _stepVerifyEmail = 'verify-email';
  static const _stepPassword = 'password';
  static const _stepComplete = 'complete';

  final _emailC = TextEditingController();
  final _newPasswordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();

  bool _loading = false;
  String _step = _stepEmail;
  String? _errorMsg;
  String? _personalEmail;
  final _api = AdminApi();

  @override
  void initState() {
    super.initState();
    final existingEmail = (widget.userData['personalEmail'] ?? '').toString();
    final emailVerified = widget.userData['emailVerified'] == true;

    if (existingEmail.trim().isNotEmpty) {
      _emailC.text = existingEmail;
      _personalEmail = existingEmail;
    }

    if (existingEmail.trim().isNotEmpty && emailVerified) {
      _step = _stepPassword;
      return;
    }

    _step = _stepEmail;
  }

  Future<void> _submitEmail() async {
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
      // Send verification code first. Password is configured on next step.
      await _api.sendVerificationEmail(uid: widget.user.uid, email: email);

      _personalEmail = email;

      setState(() {
        _step = _stepVerifyEmail;
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
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMsg = e.message ?? 'Nu am putut trimite codul de verificare.';
        _loading = false;
      });
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

  Future<void> _resendVerificationCode() async {
    final email = (_personalEmail ?? _emailC.text).trim();
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Cod retrimis pe email.')));
      }
      setState(() {
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _errorMsg = e.message ?? 'Nu am putut retrimite codul.';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Nu am putut retrimite codul: $e';
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

      _newPasswordC.clear();
      _confirmPasswordC.clear();
      setState(() {
        _step = _stepPassword;
        _loading = false;
        _errorMsg = null;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Cod invalid: $e';
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

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await widget.user.updatePassword(newPass);
      // Set twoFactorVerified BEFORE the Firestore write so that when
      // main.dart's StreamBuilder reacts to the passwordChanged update it
      // already sees twoFactorVerified = true and skips the 2FA screen.
      AppSession.twoFactorVerified = true;
      await _api.markPasswordChanged(uid: widget.user.uid);

      if (mounted) {
        setState(() {
          _step = _stepComplete;
          _loading = false;
        });
      }
      // No manual navigation needed – the Firestore stream in main.dart
      // automatically re-routes the user once passwordChanged is reflected.
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

  void _goBackToEmailStep() {
    if (_loading) return;

    setState(() {
      _step = _stepEmail;
      _verificationCodeC.clear();
      _errorMsg = null;
    });
  }

  void _goBackToVerifyStep() {
    if (_loading) return;

    setState(() {
      _step = _stepVerifyEmail;
      _errorMsg = null;
    });
  }

  void _goBack() {
    if (_step == _stepVerifyEmail) {
      _goBackToEmailStep();
      return;
    }
    if (_step == _stepPassword) {
      _goBackToVerifyStep();
    }
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
        leading: (_step == _stepVerifyEmail || _step == _stepPassword)
            ? IconButton(
                onPressed: _loading ? null : _goBack,
                icon: const Icon(Icons.arrow_back),
              )
            : null,
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
                  if (_step == _stepEmail) ...[
                    const Text(
                      'Pasul 1: Email personal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Introdu un email personal unde primesti codul de verificare.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _emailC,
                      decoration: InputDecoration(
                        labelText: 'Email Personal',
                        hintText: 'exemplu@gmail.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      keyboardType: TextInputType.emailAddress,
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
                        onPressed: _loading ? null : _submitEmail,
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
                                'Trimite cod',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ] else if (_step == _stepVerifyEmail) ...[
                    const Text(
                      'Pasul 2: Verifica email-ul',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Am trimis un cod de verificare la\n$_personalEmail\n\nIntrodu codul din email.',
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
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _loading ? null : _resendVerificationCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retrimite codul'),
                    ),
                  ] else if (_step == _stepPassword) ...[
                    const Text(
                      'Pasul 3: Seteaza parola',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Email verificat. Acum seteaza o parola noua pentru cont.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _newPasswordC,
                      decoration: InputDecoration(
                        labelText: 'Parola noua (min 8 caractere)',
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
                        labelText: 'Confirma parola',
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
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _loading ? null : _goBackToVerifyStep,
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
                            onPressed: _loading ? null : _submitPassword,
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
                                    'Finalizeaza',
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
                  ] else if (_step == _stepComplete) ...[
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
