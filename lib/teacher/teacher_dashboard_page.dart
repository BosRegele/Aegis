import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../student/logout_dialog.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});
  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

const _kGreen = Color(0xFF0D631B);
const _kBg = Color(0xFFF7F9F0);

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _studentsStream;
  String _classId = '';
  bool _profilePressed = false;

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
            _studentsStream = FirebaseFirestore.instance
                .collection('users')
                .where('classId', isEqualTo: classId)
                .where('role', isEqualTo: 'student')
                .snapshots();
          });
        }
      });
    }
  }

  // ignore: unused_element
  Future<void> _logout() async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _kGreen,
      surfaceColor: Colors.white,
      softSurfaceColor: const Color(0xFFEAF2EC),
      titleColor: const Color(0xFF0D631B),
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

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: _teacherStream,
              builder: (context, snap) {
                final data = snap.data?.data() ?? const <String, dynamic>{};
                final fullName = (data['fullName'] ?? '').toString().trim();
                final displayName = fullName.isNotEmpty
                    ? fullName
                    : (AppSession.username ?? 'Diriginte');

                final scrollStart = 190.0;

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: _kBg),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _buildHeader(displayName),
                    ),
                    Positioned(
                      top: scrollStart,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            _buildActivityCard(),
                            const SizedBox(height: 16),
                            _buildGrid(context),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            top: topPadding + 5,
            right: 14,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _profilePressed = true),
              onTapUp: (_) {
                setState(() => _profilePressed = false);
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const OrarDirPage(),
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                  ),
                );
              },
              onTapCancel: () => setState(() => _profilePressed = false),
              child: AnimatedScale(
                scale: _profilePressed ? 0.78 : 1.0,
                duration: const Duration(milliseconds: 100),
                curve: Curves.easeOut,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
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
        height: 220 + topPadding,
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
              padding: EdgeInsets.fromLTRB(28, 8 + topPadding, 18, 0),
              child: Text(
                'Bine ai venit,\n$name',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
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
              iconColor: const Color(0xFF9D1F5F),
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
          height: 390,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(34),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                const SizedBox(height: 4),
                const Text(
                  'Activitate Recentă',
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.7,
                    color: Color(0xFF1A2E1D),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDDDDD),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: items
                          .map((item) => _ActivityItemWidget(data: item))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: _studentsStream,
                  builder: (context, stuSnap) {
                    final students = stuSnap.data?.docs ?? [];
                    final inSchool = students
                        .where(
                          (d) =>
                              (d.data() as Map<String, dynamic>)['inSchool'] ==
                              true,
                        )
                        .length;
                    final absent = students.length - inSchool;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatBox(
                              label: 'PREZENȚI',
                              value: students.isEmpty ? '--' : '$inSchool',
                              valueColor: _kGreen,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatBox(
                              label: 'ABSENȚI',
                              value: students.isEmpty ? '--' : '$absent',
                              valueColor: absent > 0
                                  ? const Color(0xFF8E3557)
                                  : const Color(0xFF717B6E),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
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

        return Column(
          children: [
            _GridCard(
              icon: Icons.group_rounded,
              title: 'Clasa Mea',
              subtitle: 'Gestionare elevi',
              isDark: false,
              wide: true,
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _GridCard(
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
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _GridCard(
                    icon: Icons.chat_bubble_rounded,
                    title: 'Mesaje',
                    subtitle: 'Istoric cereri',
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
                ),
              ],
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

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF717B6E),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityItemWidget extends StatelessWidget {
  final _ActivityData data;

  const _ActivityItemWidget({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4FBF6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.iconColor.withOpacity(1.0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(data.icon, color: Colors.white, size: 26),
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
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.time,
                      style: const TextStyle(
                        color: Color(0xFF8A9E8C),
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
  final bool wide;
  final VoidCallback? onTap;

  const _GridCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
    this.wide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : _kGreen.withValues(alpha: 0.10);
    final iconColor = isDark ? Colors.white : _kGreen;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A2E1D);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.74)
        : const Color(0xFF6B7A6D);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: wide ? null : 184,
        padding: wide
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            : const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isDark && !wide
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D631B), Color(0xFF19802E)],
                )
              : null,
          color: wide
              ? const Color(0xFFFFFFFF)
              : isDark
              ? null
              : const Color(0xFFE7EDE1),
          borderRadius: BorderRadius.circular(22),
          border: (!isDark && !wide)
              ? Border.all(
                  color: const Color(0xFFC8D1C2).withValues(alpha: 0.36),
                  width: 1.1,
                )
              : null,
          boxShadow: isDark && !wide
              ? const [
                  BoxShadow(
                    color: Color(0x350D631B),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ]
              : wide
              ? const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: wide
            ? Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4E9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: _kGreen, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: _kGreen,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: Color(0xFF717B6E),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF717B6E),
                    size: 24,
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 24),
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: 22,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subtitleColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
