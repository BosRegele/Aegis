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
      backgroundColor: const Color(0xFFE6EBEE),
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
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 64,
                          color: const Color(0xFF7AAF5B).withOpacity(0.5),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nicio cerere în așteptare',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5F6771),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final d = doc.data() as Map<String, dynamic>;
                    final requestId = doc.id;
                    final studentName = (d['studentName'] ?? '').toString();
                    final dateText = (d['dateText'] ?? '').toString();
                    final timeText = (d['timeText'] ?? '').toString();
                    final message = (d['message'] ?? '').toString();

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2E3B4E).withOpacity(0.07),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () =>
                              _showRequestDialog(context, requestId, d),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4B78D2,
                                    ).withOpacity(0.10),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF4B78D2),
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF2E3B4E),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4B78D2,
                                              ).withOpacity(0.10),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 11,
                                                  color: Color(0xFF4B78D2),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$dateText${timeText.isNotEmpty ? ' · $timeText' : ''}',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF4B78D2),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (message.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF5F6771),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Action buttons
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ActionBtn(
                                      icon: Icons.check_rounded,
                                      color: const Color(0xFF4CAF50),
                                      onTap: () => _reviewRequest(
                                        requestId: requestId,
                                        status: 'approved',
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    _ActionBtn(
                                      icon: Icons.close_rounded,
                                      color: const Color(0xFFE53935),
                                      onTap: () => _reviewRequest(
                                        requestId: requestId,
                                        status: 'rejected',
                                      ),
                                    ),
                                  ],
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
            ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.4), width: 1.2),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
