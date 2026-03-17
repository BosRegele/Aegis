import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

/// A simple page that shows the list of pending leave requests for the
/// currently logged-in teacher's class.  The teacher can approve or reject
/// each request.
class CereriAsteptarePage extends StatefulWidget {
  const CereriAsteptarePage({super.key});

  @override
  State<CereriAsteptarePage> createState() => _CereriAsteptarePageState();
}

class _CereriAsteptarePageState extends State<CereriAsteptarePage> {
  // Keep true for interface demos without backend dependencies.
  static const bool _demoMode = true;

  final List<Map<String, dynamic>> _demoRequests = [
    {
      'requestId': 'demo-1',
      'studentName': 'Andrei Popescu',
      'studentUid': 'elev-001',
      'status': 'pending',
      'dateText': '14.03.2026',
      'timeText': '11:30 - 13:00',
      'message': 'Solicit invoire pentru control medical programat.',
    },
    {
      'requestId': 'demo-2',
      'studentName': 'Maria Ionescu',
      'studentUid': 'elev-002',
      'status': 'pending',
      'dateText': '14.03.2026',
      'timeText': '09:50 - 10:40',
      'message': 'Trebuie sa merg la olimpiada judeteana.',
    },
    {
      'requestId': 'demo-3',
      'studentName': 'Radu Stancu',
      'studentUid': 'elev-003',
      'status': 'pending',
      'dateText': '15.03.2026',
      'timeText': '12:00 - 14:00',
      'message': 'Am programare la stomatolog.',
    },
    {
      'requestId': 'demo-4',
      'studentName': 'Elena Tudor',
      'studentUid': 'elev-004',
      'status': 'pending',
      'dateText': '15.03.2026',
      'timeText': '08:00 - 09:00',
      'message': 'Particip la un concurs de dezbateri.',
    },
  ];

  void _reviewDemoRequest({required String requestId, required String status}) {
    setState(() {
      _demoRequests.removeWhere((r) => r['requestId'] == requestId);
    });
    final text = status == 'approved' ? 'Cerere aprobata' : 'Cerere respinsa';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$text (demo)')));
  }

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

  /// Shows a pop-up dialog with detailed information about a leave
  /// request.  Includes optional photo, name, student ID, status and the
  /// message body in a large read‑only text field.
  Future<void> _showRequestDialog(
    BuildContext context,
    Map<String, dynamic> requestData,
  ) async {
    final studentUid = (requestData['studentUid'] ?? '').toString();
    String? photoUrl;
    String studentId = studentUid;
    String status = (requestData['status'] ?? '').toString();
    String studentName = (requestData['studentName'] ?? '').toString();
    if (studentUid.isNotEmpty) {
      try {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentUid)
            .get();
        if (userSnap.exists) {
          final ud = userSnap.data() as Map<String, dynamic>;
          photoUrl = (ud['photoUrl'] ?? ud['avatarUrl'] ?? '').toString();
          // many apps store an id field; fall back to username if present
          studentId = (ud['studentId'] ?? ud['username'] ?? studentUid)
              .toString();
        }
      } catch (_) {
        // ignore fetch error, we'll still show basic info
      }
    }

    final message = (requestData['message'] ?? '').toString();
    final dateText = (requestData['dateText'] ?? '').toString();
    final timeText = (requestData['timeText'] ?? '').toString();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(studentName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (photoUrl != null && photoUrl.isNotEmpty)
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: NetworkImage(photoUrl),
                  )
                else
                  const CircleAvatar(
                    radius: 40,
                    child: Icon(Icons.person, size: 40),
                  ),
                const SizedBox(height: 12),
                Text('ID: $studentId'),
                const SizedBox(height: 4),
                Text('Status: $status'),
                const SizedBox(height: 12),
                Text('Cerere pentru: $dateText $timeText'),
                const SizedBox(height: 12),
                TextField(
                  controller: TextEditingController(text: message),
                  readOnly: true,
                  maxLines: null,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Motivul cererii',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Închide'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_demoMode) {
      final pending = _demoRequests
          .where((item) => (item['status'] ?? '').toString() == 'pending')
          .toList();

      return Scaffold(
        appBar: AppBar(
          title: const Text('Cereri in asteptare'),
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
        body: pending.isEmpty
            ? const Center(child: Text('Nu exista cereri in asteptare.'))
            : ListView.separated(
                padding: const EdgeInsets.all(12),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: pending.length,
                itemBuilder: (context, index) {
                  final d = pending[index];
                  final requestId = (d['requestId'] ?? '').toString();
                  final studentName = (d['studentName'] ?? '').toString();
                  final dateText = (d['dateText'] ?? '').toString();
                  final timeText = (d['timeText'] ?? '').toString();
                  final message = (d['message'] ?? '').toString();

                  return Card(
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _showRequestDialog(context, d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$studentName - $dateText $timeText',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () => _reviewDemoRequest(
                                      requestId: requestId,
                                      status: 'approved',
                                    ),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () => _reviewDemoRequest(
                                      requestId: requestId,
                                      status: 'rejected',
                                    ),
                                    child: const Text(
                                      'NG',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
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
      appBar: AppBar(title: const Text('Cereri în așteptare')),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: FutureBuilder<DocumentSnapshot>(
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
            return const Center(child: Text('Nu ai clasa asignata.'));
          }

          final requestsStream = FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('classId', isEqualTo: classId)
              .where('status', isEqualTo: 'pending')
              .snapshots();

          return StreamBuilder<QuerySnapshot>(
            stream: requestsStream,
            builder: (context, reqSnap) {
              if (reqSnap.hasError) {
                return Center(child: Text('Eroare: ${reqSnap.error}'));
              }
              if (!reqSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = reqSnap.data!.docs;
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Nu exista cereri în așteptare.'),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(12),
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final d = doc.data() as Map<String, dynamic>;
                  final requestId = doc.id;
                  final studentName = (d['studentName'] ?? '').toString();
                  final dateText = (d['dateText'] ?? '').toString();
                  final timeText = (d['timeText'] ?? '').toString();
                  final message = (d['message'] ?? '').toString();

                  // notification-style card with tap handler
                  return Card(
                    elevation: 2,
                    child: InkWell(
                      onTap: () => _showRequestDialog(context, d),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$studentName • $dateText $timeText',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () => _reviewRequest(
                                      requestId: requestId,
                                      status: 'approved',
                                    ),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(
                                  width: 60,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.zero,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                    ),
                                    onPressed: () => _reviewRequest(
                                      requestId: requestId,
                                      status: 'rejected',
                                    ),
                                    child: const Text(
                                      'NG',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}
