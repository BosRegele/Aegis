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

  // --- Funcție nouă pentru aprobare/respingere în masă ---
  Future<void> _reviewAllRequests(
    List<QueryDocumentSnapshot> docs,
    String status,
  ) async {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final now = Timestamp.now();
    final reviewerName = (AppSession.username ?? '').toString();

    for (var doc in docs) {
      batch.update(doc.reference, {
        'status': status,
        'reviewedAt': now,
        'reviewedByUid': teacherUid,
        'reviewedByName': reviewerName,
      });
    }

    await batch.commit();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Toate cererile au fost aprobate'
                : 'Toate cererile au fost respinse',
          ),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
    }
  }
  // ---------------------------------------------------------

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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFE6EBEE),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header verde
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF7AAF5B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white.withOpacity(0.22),
                      backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                          ? NetworkImage(photoUrl) as ImageProvider
                          : null,
                      child: (photoUrl == null || photoUrl.isEmpty)
                          ? Text(
                              studentName
                                  .trim()
                                  .split(' ')
                                  .where((w) => w.isNotEmpty)
                                  .take(2)
                                  .map((w) => w[0].toUpperCase())
                                  .join(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: $studentId',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF4B78D2),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$dateText${timeText.isNotEmpty ? '  ·  $timeText' : ''}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E3B4E),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Motivul cererii',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8A9BB0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFF2E3B4E),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (status == 'pending') ...[
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _reviewRequest(
                                  requestId: requestId,
                                  status: 'rejected',
                                );
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                              label: const Text('Respinge'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE53935),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _reviewRequest(
                                  requestId: requestId,
                                  status: 'approved',
                                );
                              },
                              icon: const Icon(Icons.check_rounded, size: 18),
                              label: const Text('Aprobă'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4CAF50),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
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
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Învoiri', style: TextStyle(color: Colors.white)),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE6EBEE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _classId.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leaveRequests')
                    .where('classId', isEqualTo: _classId)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Eroare: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs =
                      snap.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final targetRole = (data['targetRole'] ?? '')
                            .toString();
                        final status = (data['status'] ?? '').toString();
                        return targetRole == 'teacher' && status == 'pending';
                      }).toList()..sort((a, b) {
                        final aTs =
                            (a.data() as Map<String, dynamic>)['requestedAt']
                                as Timestamp?;
                        final bTs =
                            (b.data() as Map<String, dynamic>)['requestedAt']
                                as Timestamp?;
                        final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                        final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                        return bMs.compareTo(aMs);
                      });
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

                  // Aici am adăugat Stack-ul cu lista și butonul bulk persistent
                  return Stack(
                    children: [
                      ListView.separated(
                        // Am adăugat padding la final (90) pentru ca ultimul element să nu fie ascuns sub butonul plutitor
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final d = doc.data() as Map<String, dynamic>;
                          final requestId = doc.id;
                          final studentName = (d['studentName'] ?? '')
                              .toString();
                          final dateText = (d['dateText'] ?? '').toString();
                          final timeText = (d['timeText'] ?? '').toString();
                          final message = (d['message'] ?? '').toString();

                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2E3B4E,
                                  ).withOpacity(0.07),
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
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    14,
                                    10,
                                    14,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF4B78D2,
                                                    ).withOpacity(0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .calendar_today_rounded,
                                                        size: 11,
                                                        color: Color(
                                                          0xFF4B78D2,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        '$dateText${timeText.isNotEmpty ? ' · $timeText' : ''}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                            0xFF4B78D2,
                                                          ),
                                                          fontWeight:
                                                              FontWeight.w600,
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
                                      const SizedBox(width: 10),
                                      // Action buttons
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          SizedBox(
                                            width: 90,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _reviewRequest(
                                                requestId: requestId,
                                                status: 'approved',
                                              ),
                                              icon: const Icon(
                                                Icons.check_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Aprobă'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF4CAF50,
                                                ),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          SizedBox(
                                            width: 90,
                                            child: ElevatedButton.icon(
                                              onPressed: () => _reviewRequest(
                                                requestId: requestId,
                                                status: 'rejected',
                                              ),
                                              icon: const Icon(
                                                Icons.close_rounded,
                                                size: 16,
                                              ),
                                              label: const Text('Respinge'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFFE53935,
                                                ),
                                                foregroundColor: Colors.white,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                textStyle: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
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
                      ),

                      // Butonul oval persistente pentru aprobare/respingere în masă
                      Positioned(
                        bottom: 20,
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              Expanded(
                                child: Material(
                                  color: const Color(0xFFE53935), // Roșu
                                  child: InkWell(
                                    onTap: () =>
                                        _reviewAllRequests(docs, 'rejected'),
                                    child: const Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.close_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Respinge Toate',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Material(
                                  color: const Color(0xFF4CAF50), // Verde
                                  child: InkWell(
                                    onTap: () =>
                                        _reviewAllRequests(docs, 'approved'),
                                    child: const Center(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Aprobă Toate',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
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
