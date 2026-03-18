import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class CereriAsteptarePage extends StatefulWidget {
  const CereriAsteptarePage({super.key});

  @override
  State<CereriAsteptarePage> createState() => _CereriAsteptarePageState();
}

class _CereriAsteptarePageState extends State<CereriAsteptarePage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _teacherStream;
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
      _teacherStream!.listen((doc) {
        if (!mounted) return;
        final classId = ((doc.data() ?? {})['classId'] ?? '').toString().trim();
        if (classId.isNotEmpty && classId != _classId) {
          setState(() => _classId = classId);
        }
      });
    }
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved' ? 'Cerere aprobată' : 'Cerere respinsă',
          ),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _showRequestDialog(
    BuildContext context,
    String requestId,
    Map<String, dynamic> d,
  ) async {
    final studentUid = (d['studentUid'] ?? '').toString();
    final studentName = (d['studentName'] ?? '').toString();
    final status = (d['status'] ?? '').toString();
    final message = (d['message'] ?? '').toString();
    final dateText = (d['dateText'] ?? '').toString();
    final timeText = (d['timeText'] ?? '').toString();

    String? photoUrl;
    String studentId = studentUid;
    if (studentUid.isNotEmpty) {
      try {
        final us = await FirebaseFirestore.instance
            .collection('users')
            .doc(studentUid)
            .get();
        if (us.exists) {
          final ud = us.data()!;
          photoUrl = (ud['photoUrl'] ?? ud['avatarUrl'] ?? '').toString();
          studentId = (ud['studentId'] ?? ud['username'] ?? studentUid)
              .toString();
        }
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(studentName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              (photoUrl != null && photoUrl.isNotEmpty)
                  ? CircleAvatar(
                      radius: 40,
                      backgroundImage: NetworkImage(photoUrl),
                    )
                  : const CircleAvatar(
                      radius: 40,
                      child: Icon(Icons.person, size: 40),
                    ),
              const SizedBox(height: 12),
              Text('ID: $studentId'),
              const SizedBox(height: 4),
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
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Închide'),
          ),
          if (status == 'pending') ...[
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () {
                Navigator.of(ctx).pop();
                _reviewRequest(requestId: requestId, status: 'rejected');
              },
              child: const Text('Respinge'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: () {
                Navigator.of(ctx).pop();
                _reviewRequest(requestId: requestId, status: 'approved');
              },
              child: const Text('Aprobă'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Învoiri', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: _classId.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('leaveRequests')
                  .where('classId', isEqualTo: _classId)
                  .where('status', isEqualTo: 'pending')
                  .orderBy('requestedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(child: Text('Eroare: ${snap.error}'));
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text('Nu există cereri de învoire în așteptare.'),
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

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showRequestDialog(context, requestId, d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF17B5A8,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF17B5A8),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studentName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$dateText $timeText',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5F6771),
                                      ),
                                    ),
                                    if (message.isNotEmpty)
                                      Text(
                                        message,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF5F6771),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 80,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _reviewRequest(
                                        requestId: requestId,
                                        status: 'approved',
                                      ),
                                      child: const Text(
                                        'Aprobă',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 80,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 6,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _reviewRequest(
                                        requestId: requestId,
                                        status: 'rejected',
                                      ),
                                      child: const Text(
                                        'Respinge',
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
                );
              },
            ),
    );
  }
}
