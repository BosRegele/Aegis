import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

const _kHeaderGreen = Color(0xFF0E6A22);
const _kPageBg = Color(0xFFF0F3EC);
const _kCardBg = Color(0xFFF7F7F7);

/// Placeholder status page for teachers. Currently mirrors the dashboard UI.
class StatusEleviPage extends StatefulWidget {
  const StatusEleviPage({super.key});

  @override
  State<StatusEleviPage> createState() => _StatusEleviPageState();
}

class _StatusEleviPageState extends State<StatusEleviPage> {
  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              title: 'Clasa Mea',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: teacherDoc.get(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Eroare: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.data!.exists) {
                    return const Center(child: Text('Teacher not found'));
                  }

                  final data = snap.data!.data() as Map<String, dynamic>;
                  final classId = (data['classId'] ?? '').toString().trim();

                  if (classId.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final studentsStream = FirebaseFirestore.instance
                      .collection('users')
                      .where('classId', isEqualTo: classId)
                      .where('role', isEqualTo: 'student')
                      .orderBy('fullName')
                      .snapshots();

                  final eventsStream = FirebaseFirestore.instance
                      .collection('accessEvents')
                      .where('classId', isEqualTo: classId)
                      .orderBy('timestamp', descending: true)
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: studentsStream,
                    builder: (context, stuSnap) {
                      if (stuSnap.hasError) {
                        return Center(
                          child: Text('Eroare elevi: ${stuSnap.error}'),
                        );
                      }
                      if (!stuSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final students = stuSnap.data!.docs;
                      if (students.isEmpty) {
                        return const Center(
                          child: Text('Nu exista elevi in clasa.'),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: eventsStream,
                        builder: (context, evSnap) {
                          if (evSnap.hasError) {
                            return Center(
                              child: Text(
                                'Eroare evenimente: ${evSnap.error}',
                              ),
                            );
                          }
                          if (!evSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final lastEvent = <String, Map<String, dynamic>>{};
                          for (final doc in evSnap.data!.docs) {
                            final d = doc.data() as Map<String, dynamic>;
                            final uid = (d['userId'] ?? '').toString();
                            if (uid.isEmpty || lastEvent.containsKey(uid)) {
                              continue;
                            }
                            lastEvent[uid] = d;
                          }

                          final sortedStudents = [...students]
                            ..sort((a, b) {
                              final aIn =
                                  (a.data() as Map<String, dynamic>)['inSchool'] ==
                                      true
                                  ? 0
                                  : 1;
                              final bIn =
                                  (b.data() as Map<String, dynamic>)['inSchool'] ==
                                      true
                                  ? 0
                                  : 1;
                              return aIn.compareTo(bIn);
                            });

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                            itemCount: sortedStudents.length,
                            itemBuilder: (context, index) {
                              final stu = sortedStudents[index];
                              final ud = stu.data() as Map<String, dynamic>;
                              final uid = stu.id;
                              final name =
                                  (ud['fullName'] ?? ud['username'] ?? uid)
                                      .toString();
                              final inSchool = ud['inSchool'] == true;
                              final statusText = inSchool
                                  ? 'in incinta'
                                  : 'in afara incintei';

                              String lastScanDate = '';
                              String lastScanTime = '';
                              String lastScanLocation = '';
                              final ev = lastEvent[uid];
                              if (ev != null) {
                                final ts = ev['timestamp'] as Timestamp?;
                                if (ts != null) {
                                  final dt = ts.toDate().toLocal();
                                  lastScanDate =
                                      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                                  lastScanTime =
                                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                }
                                lastScanLocation =
                                    (ev['location'] ?? ev['gate'] ?? '')
                                        .toString();
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('leaveRequests')
                                    .where('studentUid', isEqualTo: uid)
                                    .where('classId', isEqualTo: classId)
                                    .where('status', isEqualTo: 'approved')
                                    .limit(1)
                                    .snapshots(),
                                builder: (context, permSnap) {
                                  final hasPermission =
                                      permSnap.data?.docs.isNotEmpty ?? false;
                                  final initials = name
                                      .trim()
                                      .split(' ')
                                      .where((w) => w.isNotEmpty)
                                      .take(2)
                                      .map((w) => w[0].toUpperCase())
                                      .join();

                                  return _StudentListCard(
                                    initials: initials,
                                    name: name,
                                    classLabel: 'Clasa a $classId',
                                    inSchool: inSchool,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => _StudentDetailPage(
                                            name: name,
                                            status: statusText,
                                            lastScanDate: lastScanDate,
                                            lastScanTime: lastScanTime,
                                            lastScanLocation: lastScanLocation,
                                            hasPermission: hasPermission,
                                          ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(38)),
      child: SizedBox(
        height: 152,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _kHeaderGreen),
            CustomPaint(painter: _HeaderDotsPainter()),
            Positioned(
              right: 58,
              top: -40,
              child: _decorCircle(110),
            ),
            Positioned(
              left: 175,
              bottom: -28,
              child: _decorCircle(72),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 18, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 43,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
      ),
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.15);
    const spacing = 18.0;
    const radius = 1.3;
    for (double y = 12; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StudentListCard extends StatelessWidget {
  final String initials;
  final String name;
  final String classLabel;
  final bool inSchool;
  final VoidCallback onTap;

  const _StudentListCard({
    required this.initials,
    required this.name,
    required this.classLabel,
    required this.inSchool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = inSchool
        ? const Color(0xFF268A34)
        : const Color(0xFFB84A7A);
    final avatarText = inSchool
        ? const Color(0xFFB4EDB8)
        : const Color(0xFFFCE9F3);
    final statusText = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool
        ? const Color(0xFFE2EFE6)
        : const Color(0xFFF1E4EC);
    final pillBorder = inSchool
        ? const Color(0xFFA6C8B0)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF0D6D1E)
        : const Color(0xFF922255);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6DE)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarText,
                      fontWeight: FontWeight.w700,
                      fontSize: 36,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101310),
                            fontWeight: FontWeight.w700,
                            fontSize: 24,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          classLabel,
                          style: const TextStyle(
                            color: Color(0xFF273027),
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(
                                  color: pillText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                statusText,
                                style: TextStyle(
                                  color: pillText,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 22,
                                  height: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 56,
                  height: 56,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E4DB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 36,
                    color: Color(0xFF1B231A),
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

// ─── Student detail page ──────────────────────────────────────────────────────

class _StudentDetailPage extends StatelessWidget {
  final String name;
  final String status;
  final String lastScanDate;
  final String lastScanTime;
  final String lastScanLocation;
  final bool hasPermission;

  const _StudentDetailPage({
    required this.name,
    required this.status,
    required this.lastScanDate,
    required this.lastScanTime,
    required this.lastScanLocation,
    required this.hasPermission,
  });

  @override
  Widget build(BuildContext context) {
    final inSchool = status == 'in incinta';
    final hasScan = lastScanDate.isNotEmpty || lastScanTime.isNotEmpty;
    final initials = name
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFFE6EBEE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: inSchool
                      ? [const Color(0xFF7AAF5B), const Color(0xFF4E8A3A)]
                      : [const Color(0xFFE57373), const Color(0xFFC62828)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (inSchool
                                ? const Color(0xFF7AAF5B)
                                : const Color(0xFFE57373))
                            .withOpacity(0.30),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white.withOpacity(0.22),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              inSchool
                                  ? Icons.school_rounded
                                  : Icons.logout_rounded,
                              color: Colors.white.withOpacity(0.85),
                              size: 16,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              inSchool
                                  ? 'În incinta școlii'
                                  : 'În afara școlii',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.90),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Last scan card
            _InfoCard(
              icon: Icons.qr_code_scanner,
              iconColor: const Color.fromRGBO(122, 175, 91, 1),
              label: 'Ultima scanare',
              value: hasScan
                  ? '$lastScanDate${lastScanTime.isNotEmpty ? ', $lastScanTime' : ''}${lastScanLocation.isNotEmpty ? '\n$lastScanLocation' : ''}'
                  : 'Nicio scanare înregistrată',
            ),
            const SizedBox(height: 12),
            // Permission card
            _InfoCard(
              icon: hasPermission ? Icons.verified : Icons.block,
              iconColor: hasPermission ? Colors.green : Colors.red,
              label: 'Permisiune activă',
              value: hasPermission ? 'Da' : 'Nu',
              valueColor: hasPermission ? Colors.green : Colors.red,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: valueColor ?? const Color(0xFF1C1C1C),
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
