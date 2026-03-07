import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  Future<void> _reviewRequest({
    required String requestId,
    required String status,
  }) async {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) return;

    await FirebaseFirestore.instance
        .collection('leaveRequests')
        .doc(requestId)
        .update({
          'status': status,
          'reviewedAt': Timestamp.now(),
          'reviewedByUid': teacherUid,
          'reviewedByName': (AppSession.username ?? '').toString(),
        });
  }

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
      appBar: AppBar(title: const Text("Diriginte")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: teacherDoc.snapshots(),
        builder: (context, snap) {
          if (snap.hasError)
            return Center(child: Text("Eroare: ${snap.error}"));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists)
            return const Center(child: Text("Teacher not found"));

          final data = snap.data!.data() as Map<String, dynamic>;
          final fullName =
              (data["fullName"] ?? AppSession.username ?? teacherUid)
                  .toString();
          final classId = (data["classId"] ?? "").toString().trim();

          if (classId.isEmpty) {
            return Center(
              child: Text(
                "Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.",
              ),
            );
          }

          final studentsQuery = FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('classId', isEqualTo: classId);

          final requestsQuery = FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('classId', isEqualTo: classId)
              .where('status', isEqualTo: 'pending');

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "$fullName\nClasa: $classId",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Text(
                  'Cereri in asteptare',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              SizedBox(
                height: 220,
                child: StreamBuilder<QuerySnapshot>(
                  stream: requestsQuery.snapshots(),
                  builder: (context, rSnap) {
                    if (rSnap.hasError) {
                      return Center(
                        child: Text('Eroare cereri: ${rSnap.error}'),
                      );
                    }
                    if (!rSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = rSnap.data!.docs.toList()
                      ..sort((a, b) {
                        final at =
                            (a['requestedAt'] as Timestamp?)?.toDate() ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bt =
                            (b['requestedAt'] as Timestamp?)?.toDate() ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bt.compareTo(at);
                      });

                    if (docs.isEmpty) {
                      return const Center(child: Text('Nu exista cereri noi.'));
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final m = d.data() as Map<String, dynamic>;
                        final student =
                            (m['studentName'] ?? m['studentUsername'])
                                .toString();
                        final dateText = (m['dateText'] ?? '-').toString();
                        final timeText = (m['timeText'] ?? '-').toString();
                        final message = (m['message'] ?? '').toString();

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$student - $dateText $timeText',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(message),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    ElevatedButton(
                                      onPressed: () => _reviewRequest(
                                        requestId: d.id,
                                        status: 'approved',
                                      ),
                                      child: const Text('Accepta'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: () => _reviewRequest(
                                        requestId: d.id,
                                        status: 'rejected',
                                      ),
                                      child: const Text('Respinge'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Text(
                  'Elevii clasei',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: studentsQuery.snapshots(),
                  builder: (context, s2) {
                    if (s2.hasError)
                      return Center(child: Text("Eroare elevi: ${s2.error}"));
                    if (!s2.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final docs = s2.data!.docs;
                    if (docs.isEmpty)
                      return const Center(
                        child: Text("Nu exista elevi in clasa asta"),
                      );

                    // sort local
                    final list = docs.toList()
                      ..sort((a, b) {
                        final an = ((a.data() as Map)['fullName'] ?? '')
                            .toString();
                        final bn = ((b.data() as Map)['fullName'] ?? '')
                            .toString();
                        return an.compareTo(bn);
                      });

                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final d = list[i];
                        final sd = d.data() as Map<String, dynamic>;
                        final u = d.id;
                        final n = (sd["fullName"] ?? u).toString();
                        final status = (sd["status"] ?? "active").toString();

                        return ListTile(
                          title: Text(n),
                          subtitle: Text("user: $u | $status"),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
