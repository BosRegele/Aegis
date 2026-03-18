import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;
  String _classId = '';

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _teacherStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();

      // Listen once to get classId and initialize pending stream
      _teacherStream!.listen((doc) {
        if (!mounted) return;
        final data = doc.data() ?? {};
        final classId = (data['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() {
            _classId = classId;
            _pendingStream = FirebaseFirestore.instance
                .collection('leaveRequests')
                .where('classId', isEqualTo: classId)
                .where('status', isEqualTo: 'pending')
                .snapshots();
          });
        }
      });
    }
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        backgroundColor: const Color(0xFFE6EBEE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Confirmare logout',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF223127),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            SizedBox(height: 4),
            Text(
              'Ești sigur că vrei să ieși din cont?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF3A4A3F),
                fontSize: 18,
                fontWeight: FontWeight.w400,
                height: 1.2,
              ),
            ),
            SizedBox(height: 12),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: 120,
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7AAF5B),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              child: const Text('Anulează'),
            ),
          ),
          SizedBox(
            width: 120,
            height: 44,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AAF5B),
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Logout'),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    try {
      await FirebaseAuth.instance.signOut();
      AppSession.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut face logout. Încearcă din nou.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _teacherStream,
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final classId = (data['classId'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Diriginte');

            return Column(
              children: [
                // ── Header verde cu logo + nume + clasă ─────────────────
                Container(
                  width: double.infinity,
                  color: const Color(0xFF7AAF5B),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          tooltip: 'Logout',
                          onPressed: _logout,
                          icon: const Icon(
                            Icons.logout_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.shield_rounded,
                            size: 64,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      if (classId.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Diriginte · Clasa $classId',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        const Text(
                          'Diriginte',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // ── Corp principal ──────────────────────────────────────
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD8DDD8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Card proeminent: Învoiri ──────────────────
                          _PrimaryActionCard(
                            icon: Icons.article_rounded,
                            iconBgColor: const Color(0xFF17B5A8),
                            title: 'Cereri de învoire',
                            subtitle: 'Aprobă sau respinge cererile elevilor',
                            pendingStream: _pendingStream,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CereriAsteptarePage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ── Label secțiune ────────────────────────────
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text(
                              'Clasa mea',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF5F6771),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                          // ── Lista acțiuni ─────────────────────────────
                          _NavCard(
                            icon: Icons.group_rounded,
                            iconColor: const Color(0xFF4B78D2),
                            title: 'Elevii clasei',
                            subtitle: 'Status, scanări și permisiuni active',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const StatusEleviPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _NavCard(
                            icon: Icons.calendar_month_rounded,
                            iconColor: const Color(0xFFE47E2D),
                            title: 'Orar',
                            subtitle: 'Orarul clasei pe zile',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const OrarDirPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _NavCard(
                            icon: Icons.chat_bubble_rounded,
                            iconColor: const Color(0xFF6E46C2),
                            title: 'Mesaje',
                            subtitle: 'Comunicare cu părinții și elevii',
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MesajeDirPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Card proeminent cu badge live ───────────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final Stream<QuerySnapshot>? pendingStream;
  final VoidCallback? onTap;

  const _PrimaryActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    this.pendingStream,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: pendingStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF17B5A8), Color(0xFF0C8D80)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF17B5A8).withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: Colors.white, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Color(0xFF0C8D80),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    )
                  else
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white70,
                      size: 28,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Card navigare (full-width, list style) ──────────────────────────────────

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E3B4E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6771),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SimplePage extends StatelessWidget {
  final String title;

  const SimplePage({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 24))),
    );
  }
}
