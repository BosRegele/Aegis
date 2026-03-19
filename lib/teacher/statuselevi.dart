import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

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
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Elevii clasei',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE6EBEE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: FutureBuilder<DocumentSnapshot>(
          future: teacherDoc.get(),
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(child: Text("Eroare: ${snap.error}"));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snap.data!.exists) {
              return const Center(child: Text("Teacher not found"));
            }

            final data = snap.data!.data() as Map<String, dynamic>;
            final classId = (data["classId"] ?? "").toString().trim();

            if (classId.isEmpty) {
              return Center(
                child: Text(
                  "Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.",
                ),
              );
            }

            // stream of students in this class
            final studentsStream = FirebaseFirestore.instance
                .collection('users')
                .where('classId', isEqualTo: classId)
                .where('role', isEqualTo: 'student')
                .orderBy('fullName')
                .snapshots();

            // stream of recent access events for class
            final eventsStream = FirebaseFirestore.instance
                .collection('accessEvents')
                .where('classId', isEqualTo: classId)
                .orderBy('timestamp', descending: true)
                .snapshots();

            return StreamBuilder<QuerySnapshot>(
              stream: studentsStream,
              builder: (context, stuSnap) {
                if (stuSnap.hasError) {
                  return Center(child: Text('Eroare elevi: ${stuSnap.error}'));
                }
                if (!stuSnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final students = stuSnap.data!.docs;
                if (students.isEmpty) {
                  return const Center(child: Text('Nu exista elevi in clasa.'));
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: eventsStream,
                  builder: (context, evSnap) {
                    if (evSnap.hasError) {
                      return Center(
                        child: Text('Eroare evenimente: ${evSnap.error}'),
                      );
                    }
                    if (!evSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // map latest event per studentUid
                    final lastEvent = <String, Map<String, dynamic>>{};
                    for (var doc in evSnap.data!.docs) {
                      final d = doc.data() as Map<String, dynamic>;
                      final uid = (d['userId'] ?? '').toString();
                      if (uid.isEmpty) continue;
                      if (lastEvent.containsKey(uid))
                        continue; // keep first (latest)
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      itemCount: sortedStudents.length,
                      itemBuilder: (context, index) {
                        final stu = sortedStudents[index];
                        final ud = stu.data() as Map<String, dynamic>;
                        final uid = stu.id;
                        final name = (ud['fullName'] ?? ud['username'] ?? uid)
                            .toString();
                        String statusText = 'in afara incintei';
                        bool inSchool = ud['inSchool'] == true;
                        if (inSchool) statusText = 'in incinta';
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
                              (ev['location'] ?? ev['gate'] ?? '').toString();
                        }

                        // check active permission from leaveRequests
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
                                (permSnap.data?.docs.isNotEmpty ?? false);

                            final initials = name
                                .trim()
                                .split(' ')
                                .where((w) => w.isNotEmpty)
                                .take(2)
                                .map((w) => w[0].toUpperCase())
                                .join();
                            final avatarBg = inSchool
                                ? const Color(0xFFDCEED5)
                                : const Color(0xFFFFE0E0);
                            final avatarFg = inSchool
                                ? const Color(0xFF4E8A3A)
                                : const Color(0xFFD32F2F);
                            final badgeColor = inSchool
                                ? const Color(0xFF4CAF50)
                                : Colors.red;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.07),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: avatarBg,
                                          child: Text(
                                            initials,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                              color: avatarFg,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF2E3B4E),
                                                ),
                                              ),
                                              if (lastScanDate.isNotEmpty) ...[
                                                const SizedBox(height: 3),
                                                Text(
                                                  '$lastScanDate${lastScanTime.isNotEmpty ? '  $lastScanTime' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF8A9BB0),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.11),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: badgeColor,
                                              width: 1.2,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                inSchool
                                                    ? Icons.school_rounded
                                                    : Icons.logout_rounded,
                                                size: 13,
                                                color: badgeColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                inSchool
                                                    ? 'în incintă'
                                                    : 'în afară',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: badgeColor,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: const Color(
                                            0xFF2E3B4E,
                                          ).withOpacity(0.30),
                                        ),
                                      ],
                                    ),
                                  ),
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
        ),
      ),
    );
  }

  /// helper to avoid null compare
  String skipNull(String? s) => s ?? '';
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
