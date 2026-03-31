import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
  // UIDs strictly from parent.children array — used for leaveRequests query
  // (security rule only allows reads for students in this array).
  List<String> _childrenFromArray = const [];
  bool _loadedOnce = false;
  Stream<QuerySnapshot>? _leaveRequestsStream;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _parentDocSub;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    final parentUid = (AppSession.uid ?? '').trim();
    if (parentUid.isEmpty) {
      setState(() => _loadedOnce = true);
      return;
    }

    _parentDocSub = FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        final children = ((snap.data() ?? {})['children'] as List? ?? [])
            .map((v) => v.toString().trim())
            .where((v) => v.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
        final queryIds = children.take(30).toList(growable: false);
        if (_loadedOnce && listEquals(_childrenFromArray, children)) {
          return;
        }
        setState(() {
          _childrenFromArray = children;
          _leaveRequestsStream = queryIds.isEmpty
              ? null
              : FirebaseFirestore.instance
                    .collection('leaveRequests')
                    .where('studentUid', whereIn: queryIds)
                    .snapshots();
          _loadedOnce = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loadedOnce = true);
      },
    );
  }

  @override
  void dispose() {
    _parentDocSub?.cancel();
    super.dispose();
  }

  Future<void> _handleRequest(String docId, bool approved) async {
    final parentName = (AppSession.fullName != null && AppSession.fullName!.isNotEmpty)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Parinte');
    try {
      await FirebaseFirestore.instance.collection('leaveRequests').doc(docId).update({
        'status': approved ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedByUid': AppSession.uid,
        'reviewedByName': parentName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Cerere aprobata!' : 'Cerere respinsa.'),
          backgroundColor: approved ? Colors.green : const Color(0xFFAD3765),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _loadedOnce
                    ? _buildRequests()
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests() {
    final parentUid = (AppSession.uid ?? '').trim();
    final childIds = _childrenFromArray
        .where((uid) => uid.isNotEmpty && uid != parentUid)
        .toList();

    if (childIds.isEmpty) {
      return const Center(
        child: Text(
          'Nu exista elevi atribuiti.',
          style: TextStyle(color: Color(0xFF7A8077), fontSize: 16),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _leaveRequestsStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Eroare: ${snapshot.error}'));
        }

        final docs = (snapshot.data?.docs ?? [])
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final status = (data['status'] ?? '').toString().trim();
              final source = (data['source'] ?? '').toString().trim();
              return status == 'pending' && source != 'secretariat';
            })
            .toList()
          ..sort((a, b) {
            final aTs = (a.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
            final bTs = (b.data() as Map<String, dynamic>)['requestedAt'] as Timestamp?;
            return (bTs?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTs?.millisecondsSinceEpoch ?? 0);
          });

        if (docs.isEmpty) {
          return const Center(
            child: Text(
              'Nu exista cereri noi.',
              style: TextStyle(color: Color(0xFF7A8077), fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(top: 2, bottom: 24),
          itemCount: docs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            return _RequestCard(
              data: data,
              onAccept: () => _handleRequest(doc.id, true),
              onReject: () => _handleRequest(doc.id, false),
            );
          },
        );
      },
    );
  }
}

class _TopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(46),
        bottomRight: Radius.circular(46),
      ),
      child: SizedBox(
        width: double.infinity,
        height: topPadding + 148,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: _kHeaderGreen)),
            Positioned(right: -46, top: -34, child: _circle(122, 0.12)),
            Positioned(left: 182, top: 104, child: _circle(78, 0.11)),
            Positioned(right: 24, top: 40 + topPadding, child: _circle(66, 0.14)),
            Padding(
              padding: EdgeInsets.fromLTRB(22, topPadding + 38, 22, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Cereri de invoire',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
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

  Widget _circle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({required this.data, required this.onAccept, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final studentName = (data['studentName'] ?? 'Elev necunoscut').toString().trim();
    final classId = (data['classId'] ?? '').toString().trim();
    final dateText = (data['dateText'] ?? '-').toString();
    final timeText = (data['timeText'] ?? '-').toString();
    final reason = (data['message'] ?? 'Fara motiv').toString().trim();

    final initials = _initials(studentName);
    final classLabel = classId.isEmpty ? 'ELEV' : 'ELEV • CLASA ${classId.toUpperCase()}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5E9E0)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: const Color(0xFFC9DCCB),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBCD2BE)),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: _kHeaderGreen,
                      height: 1,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(
                          fontSize: 21,
                          height: 1,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111811),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE9DD),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          classLabel,
                          style: const TextStyle(
                            color: _kHeaderGreen,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(icon: Icons.calendar_today_rounded, text: dateText),
          const SizedBox(height: 11),
          _InfoLine(icon: Icons.access_time_filled_rounded, text: timeText),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            decoration: BoxDecoration(
              color: const Color(0xFFEAEFE4),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.description_rounded,
                    color: _kHeaderGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOTIV SOLICITARE',
                        style: TextStyle(
                          color: Color(0xFF2A342A),
                          fontSize: 13,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '"$reason"',
                        style: const TextStyle(
                          color: Color(0xFF1A211A),
                          fontSize: 17,
                          fontStyle: FontStyle.italic,
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
                child: _BouncingButton(
                  onTap: onAccept,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 82,
                    decoration: BoxDecoration(
                      color: _kHeaderGreen,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0D6F1C).withOpacity(0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Accepta',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BouncingButton(
                  onTap: onReject,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    height: 82,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0E8EE),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cancel_rounded, color: Color(0xFF9C2A60), size: 28),
                        SizedBox(width: 10),
                        Text(
                          'Respinge',
                          style: TextStyle(
                            color: Color(0xFF9C2A60),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
        Icon(icon, color: _kHeaderGreen, size: 27),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF1B221B),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.12);
    const spacing = 28.0;
    for (double y = 16; y < size.height; y += spacing) {
      for (double x = 14; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BgDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFD2DED0);
    const spacing = 32.0;
    for (double y = 16; y < 128; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  double _scale = 1.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {
        _scale = 0.96;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        Future.delayed(const Duration(milliseconds: 90), widget.onTap);
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _isPressed ? 0.10 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
