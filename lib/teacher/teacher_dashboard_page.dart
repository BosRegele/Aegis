import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';

const _kGreen = Color(0xFF1D5C2B);
const _kBg = Color(0xFFF2F4F0);

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
      backgroundColor: _kBg,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _teacherStream,
          builder: (context, snap) {
            final data = snap.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Diriginte');

            return Column(
              children: [
                _buildHeader(displayName),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      children: [
                        _buildActivityCard(),
                        const SizedBox(height: 20),
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
    );
  }

  // ─── Header verde cu dots + salut + buton profil ────────────────────────────
  Widget _buildHeader(String name) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          color: _kGreen,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Bine ai venit,',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        // Dots decorative pattern
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(painter: _DotPatternPainter()),
          ),
        ),
        // Cercuri decorative stânga-jos
        Positioned(
          left: -55,
          bottom: -15,
          child: IgnorePointer(
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          left: -20,
          bottom: 35,
          child: IgnorePointer(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
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
                      MaterialPageRoute(
                        builder: (_) => const StatusEleviPage(),
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
                      MaterialPageRoute(
                        builder: (_) => const CereriAsteptarePage(),
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
                      MaterialPageRoute(builder: (_) => const OrarDirPage()),
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
                      MaterialPageRoute(builder: (_) => const MesajeDirPage()),
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

// ─── Dot pattern painter ──────────────────────────────────────────────────────

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.fill;
    const spacing = 20.0;
    const radius = 1.8;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
