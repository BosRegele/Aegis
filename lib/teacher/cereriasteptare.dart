import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF1D5C2B);
const _kPageBg = Color(0xFFFFFFFF);
const _kCardBg = Color(0xFFF8F8F8);

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
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              title: 'Cereri de învoire',
              onBack: () => Navigator.of(context).maybePop(),
              onProfile: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Expanded(
              child: Stack(
                children: [
                  _classId.isEmpty
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
                              return Center(
                                child: Text('Eroare: ${snap.error}'),
                              );
                            }
                            if (!snap.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            final docs = snap.data!.docs;
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  'Nicio cerere în așteptare',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFF5D655A),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                16,
                                16,
                                18,
                              ),
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 14),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final d = doc.data() as Map<String, dynamic>;
                                final requestId = doc.id;
                                final studentName = (d['studentName'] ?? '')
                                    .toString()
                                    .trim();
                                final dateText = (d['dateText'] ?? '')
                                    .toString();
                                final timeText = (d['timeText'] ?? '')
                                    .toString();
                                final message = (d['message'] ?? '').toString();

                                final initials = studentName
                                    .split(' ')
                                    .where((part) => part.isNotEmpty)
                                    .take(2)
                                    .map((part) => part[0].toUpperCase())
                                    .join();

                                return _RequestCard(
                                  initials: initials.isEmpty ? '??' : initials,
                                  name: studentName.isEmpty
                                      ? 'Elev fără nume'
                                      : studentName,
                                  classLabel: 'ELEV • CLASA A $_classId',
                                  dateText: dateText,
                                  timeText: timeText,
                                  message: message,
                                  onTap: () =>
                                      _showRequestDialog(context, requestId, d),
                                  onAccept: () => _reviewRequest(
                                    requestId: requestId,
                                    status: 'approved',
                                  ),
                                  onReject: () => _reviewRequest(
                                    requestId: requestId,
                                    status: 'rejected',
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ],
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
  final VoidCallback? onProfile;

  const _TopHeader({required this.title, required this.onBack, this.onProfile});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: SizedBox(
        width: double.infinity,
        height: 90 + topPadding,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Container(color: _kHeaderGreen),
            Positioned(right: -60, top: -60, child: _decorCircle(180)),
            Positioned(
              right: 120,
              top: topPadding + 15,
              child: _decorCircle(55),
            ),
            Positioned(left: -40, bottom: -30, child: _decorCircle(130)),
            if (onProfile != null)
              Positioned(
                top: topPadding,
                right: 14,
                child: Hero(
                  tag: 'teacher-profile-btn',
                  child: GestureDetector(
                    onTap: onProfile,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0x337DE38D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x6DC7F4CE),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(4, topPadding - 6, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
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
        color: Colors.white.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String initials;
  final String name;
  final String classLabel;
  final String dateText;
  final String timeText;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.initials,
    required this.name,
    required this.classLabel,
    required this.dateText,
    required this.timeText,
    required this.message,
    required this.onTap,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: const Color(0xFFE3E7DD)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(34),
        child: InkWell(
          borderRadius: BorderRadius.circular(34),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD0DFD0),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF07731F),
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 26,
                              color: Color(0xFF111512),
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDDE9DE),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              classLabel,
                              style: const TextStyle(
                                fontSize: 14,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF126D24),
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _InfoLine(
                  icon: Icons.calendar_today_rounded,
                  text: dateText.isEmpty ? '-' : dateText,
                ),
                const SizedBox(height: 14),
                _InfoLine(
                  icon: Icons.access_time_filled_rounded,
                  text: timeText.isEmpty ? '-' : timeText,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4EA),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.description_rounded,
                          size: 28,
                          color: Color(0xFF0C6A20),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'MOTIV SOLICITARE',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF364037),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              message.isEmpty ? '-' : '"$message"',
                              style: const TextStyle(
                                fontSize: 20,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF1D231D),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 62,
                        child: ElevatedButton.icon(
                          onPressed: onAccept,
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            size: 30,
                          ),
                          label: const Text('Acceptă'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF09731F),
                            foregroundColor: Colors.white,
                            elevation: 6,
                            shadowColor: const Color(0x5509731F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 62,
                        child: ElevatedButton.icon(
                          onPressed: onReject,
                          icon: const Icon(Icons.cancel_rounded, size: 30),
                          label: const Text('Respinge'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF2E8EE),
                            foregroundColor: const Color(0xFF9C2D62),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
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
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 34, color: const Color(0xFF0A7221)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 34,
              color: Color(0xFF303730),
              fontWeight: FontWeight.w500,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }
}
