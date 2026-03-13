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
  // Set to false when you want to switch back to live Firestore data.
  static const bool _demoMode = true;

  static const List<Map<String, dynamic>> _demoStudents = [
    {
      'name': 'Andrei Popescu',
      'status': 'in incinta',
      'lastScan': '08:02 - Turnichet principal',
      'hasPermission': true,
    },
    {
      'name': 'Maria Ionescu',
      'status': 'in afara incintei',
      'lastScan': '07:55 - Turnichet principal',
      'hasPermission': false,
    },
    {
      'name': 'Radu Stancu',
      'status': 'in incinta',
      'lastScan': '08:11 - Poarta secundara',
      'hasPermission': true,
    },
    {
      'name': 'Elena Tudor',
      'status': 'in afara incintei',
      'lastScan': '08:30 - Turnichet principal',
      'hasPermission': false,
    },
    {
      'name': 'Mihai Georgescu',
      'status': 'in incinta',
      'lastScan': '08:17 - Turnichet principal',
      'hasPermission': true,
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (_demoMode) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
          title: const Text(
            'Status elevi',
            style: TextStyle(color: Colors.white),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: Text(
                  'DEMO',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          height: 56,
          color: const Color.fromRGBO(122, 175, 91, 1),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _demoStudents.length,
          itemBuilder: (context, index) {
            final item = _demoStudents[index];
            final statusText = item['status'].toString();
            final inSchool = statusText == 'in incinta';
            final hasPermission = item['hasPermission'] == true;

            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['name'].toString(),
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
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.red.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: inSchool ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ultima scanare: ${item['lastScan']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 14),
                        children: [
                          TextSpan(
                            text: 'Permisiune activa: ',
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                          TextSpan(
                            text: hasPermission ? 'Da' : 'Nu',
                            style: TextStyle(
                              color: hasPermission ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

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
        title: const Text(
          "Status elevi",
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
                    padding: const EdgeInsets.all(16),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final stu = students[index];
                      final ud = stu.data() as Map<String, dynamic>;
                      final uid = stu.id;
                      final name = (ud['fullName'] ?? ud['username'] ?? uid)
                          .toString();
                      String statusText = 'in afara incintei';
                      Color statusColor = Colors.red;

                      final ev = lastEvent[uid];
                      if (ev != null) {
                        final scanType = (ev['scanType'] ?? 'entry').toString();
                        final result = (ev['result'] ?? '').toString();
                        if (skipNull(result) == 'allow' &&
                            scanType == 'entry') {
                          statusText = 'in incinta';
                          statusColor = Colors.green;
                        } else {
                          statusText = 'in afara incintei';
                          statusColor = Colors.red;
                        }
                      }

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Expanded(child: Text(name)),
                            Text(
                              statusText,
                              style: TextStyle(color: statusColor),
                            ),
                          ],
                        ),
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
