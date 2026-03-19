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
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Elevii clasei',
          style: TextStyle(color: Colors.white),
        ),
      ),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: FutureBuilder<DocumentSnapshot>(
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

                  return ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final stu = students[index];
                      final ud = stu.data() as Map<String, dynamic>;
                      final uid = stu.id;
                      final name = (ud['fullName'] ?? ud['username'] ?? uid)
                          .toString();
                      String statusText = 'in afara incintei';
                      bool inSchool = false;
                      String lastScanDate = '';
                      String lastScanTime = '';
                      String lastScanLocation = '';

                      final ev = lastEvent[uid];
                      if (ev != null) {
                        final scanType = (ev['scanType'] ?? 'entry').toString();
                        final result = (ev['result'] ?? '').toString();
                        if (skipNull(result) == 'allow' &&
                            scanType == 'entry') {
                          statusText = 'in incinta';
                          inSchool = true;
                        }
                        final ts = ev['timestamp'] as Timestamp?;
                        if (ts != null) {
                          final dt = ts.toDate().toLocal();
                          lastScanDate =
                              '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                          lastScanTime =
                              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                        }
                        lastScanLocation = (ev['location'] ?? ev['gate'] ?? '')
                            .toString();
                      }

                      // check active permission from leaveRequests
                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('leaveRequests')
                            .where('studentUid', isEqualTo: uid)
                            .where('status', isEqualTo: 'approved')
                            .limit(1)
                            .get(),
                        builder: (context, permSnap) {
                          final hasPermission =
                              (permSnap.data?.docs.isNotEmpty ?? false);

                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
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
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: inSchool
                                            ? Colors.green.withValues(
                                                alpha: 0.12,
                                              )
                                            : Colors.red.withValues(
                                                alpha: 0.12,
                                              ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: inSchool
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                  ],
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

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        title: Text(name, style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + name
            Center(
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 48,
                    backgroundColor: Color(0xFFDCEED5),
                    child: Icon(
                      Icons.person,
                      size: 52,
                      color: Color(0xFF6C7D62),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Status card
            _InfoCard(
              icon: inSchool ? Icons.check_circle : Icons.cancel,
              iconColor: inSchool ? Colors.green : Colors.red,
              label: 'Status',
              value: inSchool ? 'În incinta școlii' : 'În afara școlii',
              valueColor: inSchool ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
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
