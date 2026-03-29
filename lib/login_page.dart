import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'elev_qr_page.dart';
import 'parent/parent_home_page.dart';
import 'session.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> login() async {
    try {
      String username = usernameController.text.trim();
      String password = passwordController.text.trim();
      if (username.isEmpty || password.isEmpty) {
        throw Exception('Date invalide');
      }

      String email = "$username@school.local";

      // login Firebase Auth
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!userDoc.exists) {
        throw Exception('Date invalide');
      }

      final unameKey = username.toLowerCase();
      final data = userDoc.data();
      final role = data == null ? '' : (data['role'] ?? '').toString();

      if (role.isEmpty) {
        throw Exception('Date invalide');
      }

      // set session
      AppSession.setUser(
        uidValue: uid,
        usernameValue: unameKey,
        roleValue: role,
        fullNameValue: (data?['fullName'] ?? '').toString(),
        classIdValue: (data?['classId'] ?? '').toString(),
      );

      if (!mounted) return;
      if (role == "student") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ElevQrPage(userId: uid)),
        );
      } else if (role == "parent") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ParentHomePage()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Autentificare esuata. Incearca din nou."),
          ),
        );
      }
    } on FirebaseAuthException {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Date de autentificare invalide.")),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Autentificare esuata. Incearca din nou."),
        ),
      );
    }
  }

  bool _obscurePassword = true;

  // ── Colors ──
  static const _darkBg = Color(0xFF0A2E11);
  static const _greenAccent = Color(0xFF0B741D);
  static const _cardBg = Color(0xFFF5F7F2);
  static const _inputBorder = Color(0xFFD6D9D0);
  static const _hintColor = Color(0xFF8A8F84);

  // ── Branding panel (left side on landscape) ──
  Widget _buildBrandingPanel() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D3B15), Color(0xFF0A2E11)],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Shield logo
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Colors.white,
              size: 38,
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
    );
  }

  // ── Login form card ──
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
            controller: usernameController,
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
                onTap: () {
                  // TODO: forgot password flow
                },
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
            controller: passwordController,
            obscureText: _obscurePassword,
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
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _hintColor,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Login button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: login,
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
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Conectează-te'),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer
          Center(
            child: Column(
              children: [
                const Text(
                  'Nu ai un cont încă?',
                  style: TextStyle(fontSize: 13, color: _hintColor),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    // TODO: contact admin
                  },
                  child: const Text(
                    'Contactează administrația instituției',
                    style: TextStyle(
                      fontSize: 13,
                      color: _greenAccent,
                      fontWeight: FontWeight.w700,
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

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final isLandscape = mq.size.width > 750;

    return Scaffold(
      backgroundColor: _darkBg,
      body: SafeArea(child: isLandscape ? _buildLandscape() : _buildPortrait()),
    );
  }

  // ── LANDSCAPE: split view ──
  Widget _buildLandscape() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 620),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Row(
            children: [
              // Left branding panel
              Expanded(child: _buildBrandingPanel()),
              // Right form panel
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
    );
  }

  // ── PORTRAIT: card over dark background ──
  Widget _buildPortrait() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: _buildLoginForm(compact: true),
      ),
    );
  }
}
