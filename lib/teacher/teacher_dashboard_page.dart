import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../student/logout_dialog.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';

const _kGreen = Color(0xFF1D5C2B);
const _kBg = Color(0xFFFFFFFF);

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
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _kGreen,
      surfaceColor: Colors.white,
      softSurfaceColor: const Color(0xFFEAF2EC),
      titleColor: const Color(0xFF1D5C2B),
      messageColor: const Color(0xFF3A4A3F),
    );

    if (!shouldLogout) return;
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
      backgroundColor: _kBg,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _teacherStream,
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Diriginte');

            final topPadding = MediaQuery.of(context).padding.top;
            final activityTop = topPadding + 150.0;
            final topSectionH = activityTop + 200.0;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: topSectionH,
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildHeader(displayName),
                      ),
                      Positioned(
                        top: activityTop,
                        left: 16,
                        right: 16,
                        child: _buildActivityCard(),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: _buildGrid(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ─── Header verde cu cercuri + salut + buton profil ─────────────────────────
  Widget _buildHeader(String name) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        color: _kGreen,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(right: -80, top: -90, child: _headerCircle(290, 0.08)),
            Positioned(
              right: 38,
              top: 54 + topPadding,
              child: _headerCircle(78, 0.07),
            ),
            Positioned(left: -60, bottom: -44, child: _headerCircle(186, 0.08)),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 8 + topPadding, 18, 110),
              child: Text(
                'Bine ai venit,\n$name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  height: 1.20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Positioned(
              top: topPadding,
              right: 14,
              child: Hero(
                tag: 'teacher-profile-btn',
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0x337DE38D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0x6DC7F4CE),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerCircle(double size, double opacity) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(opacity),
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─── Card "Activitate Recentă" ──────────────────────────────────────────────
  Widget _buildActivityCard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        final pendingDocs = snap.data?.docs ?? [];

        final items = <_ActivityData>[];

        // Cereri în așteptare reale (max 1 pentru a lăsa loc celorlalte)
        for (final doc in pendingDocs.take(1)) {
          final d = doc.data() as Map<String, dynamic>;
          final classId = (d['classId'] ?? '').toString();
          items.add(
            _ActivityData(
              icon: Icons.warning_amber_rounded,
              iconColor: const Color(0xFFF5A623),
              title: 'Cerere în așteptare - $classId',
              time: 'ACUM',
            ),
          );
        }

        items.add(
          const _ActivityData(
            icon: Icons.campaign_rounded,
            iconColor: _kGreen,
            title: 'Anunț școlar nou',
            time: 'ASTĂZI',
          ),
        );

        if (pendingDocs.length > 1) {
          final d = pendingDocs[1].data() as Map<String, dynamic>;
          final studentName = (d['studentName'] ?? '').toString();
          items.add(
            _ActivityData(
              icon: Icons.cancel_rounded,
              iconColor: _kGreen,
              title: 'Cerere respinsă - $studentName',
              time: 'ASTĂZI',
            ),
          );
        }

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 18),
              const Text(
                'Activitate Recentă',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A2E1D),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 6),
              ...items.map((item) => _ActivityItemWidget(data: item)),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ─── Grid 2×2 ───────────────────────────────────────────────────────────────
  Widget _buildGrid(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _pendingStream,
      builder: (context, snap) {
        final count = snap.data?.docs.length ?? 0;
        final cereriSub = count > 0
            ? '$count ${count == 1 ? 'cerere nouă' : 'cereri noi'}'
            : 'Nicio cerere nouă';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  _GridCard(
                    icon: Icons.group_rounded,
                    title: 'Clasa Mea',
                    subtitle: 'Gestionare elevi',
                    isDark: true,
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const StatusEleviPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GridCard(
                    icon: Icons.article_rounded,
                    title: 'Cereri',
                    subtitle: cereriSub,
                    isDark: true,
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) =>
                            const CereriAsteptarePage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: [
                  _GridCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Orar',
                    subtitle: 'Vezi programul',
                    isDark: false,
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const OrarDirPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GridCard(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Mesaje',
                    subtitle: 'Comunicare părinți',
                    isDark: false,
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => const MesajeDirPage(),
                        transitionDuration: Duration.zero,
                        reverseTransitionDuration: Duration.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─── Model date activitate ────────────────────────────────────────────────────

class _ActivityData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String time;

  const _ActivityData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.time,
  });
}

// ─── Widget rând activitate ───────────────────────────────────────────────────

class _ActivityItemWidget extends StatelessWidget {
  final _ActivityData data;

  const _ActivityItemWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.iconColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Color(0xFF1A2E1D),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.time,
                  style: const TextStyle(
                    color: Color(0xFF8A9E8C),
                    fontSize: 12,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w500,
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

// ─── Card grid 2×2 ───────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;
  final VoidCallback? onTap;

  const _GridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? _kGreen : const Color(0xFFE8E9E4);
    final iconBg = isDark
        ? Colors.white.withOpacity(0.18)
        : _kGreen.withOpacity(0.12);
    final iconColor = isDark ? Colors.white : _kGreen;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A2E1D);
    final subtitleColor = isDark
        ? Colors.white.withOpacity(0.72)
        : const Color(0xFF6B7A6D);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: subtitleColor, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
