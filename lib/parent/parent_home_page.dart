import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Auth/login_page_firestore.dart';
import 'parent_students_page.dart';
import 'parent_requests_page.dart';
import 'parent_inbox_page.dart';
import '../session.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  String? _fullName;

  @override
  void initState() {
    super.initState();
    _loadParentName();
  }

  Future<void> _loadParentName() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _fullName = data['fullName'] as String?);
      }
    } catch (_) {}
  }

  // Method for signing out
  Future<void> _signOut() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Deconectare"),
          content: const Text("Ești sigur că vrei să te deconectezi?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Anulează"),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Deconectare", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPageFirestore()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 110,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    bottom: 8,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.shield_rounded,
                    size: 72,
                    color: Colors.white,
                  ),
                  Positioned(
                    top: 10,
                    right: 4,
                    child: TextButton.icon(
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Deconectare",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _signOut,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7EDF0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 26.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 26.0),
                          child: Text(
                            'Bine ai venit,\n${_fullName ?? AppSession.username ?? "Părinte"}!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              color: Color(0xFF1F252B),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      _buildMenuButton(
                        context,
                        title: "Elevi",
                        icon: Icons.people_outline,
                        colors: const [Color(0xFFF0B15A), Color(0xFFE47E2D)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentStudentsPage()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildMenuButton(
                        context,
                        title: "Cereri de învoire",
                        icon: Icons.mail_outline,
                        colors: const [Color(0xFF17B5A8), Color(0xFF0C8D80)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentRequestsPage()),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildMenuButton(
                        context,
                        title: "Inbox",
                        icon: Icons.inbox_outlined,
                        colors: const [Color(0xFF4B78D2), Color(0xFF304EAF)],
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ParentInboxPage()),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Color> colors,
      required VoidCallback onTap}) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            borderRadius: BorderRadius.circular(24),
            // Less intense shadow to match clean student look
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: Colors.white),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
    );
  }
}
