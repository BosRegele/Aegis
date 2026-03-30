import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../Auth/login_page_firestore.dart';
import '../core/session.dart';
import 'parent_inbox_page.dart';
import 'parent_requests_page.dart';
import 'parent_students_page.dart';

const _kHeaderGreen = Color(0xFF0A741F);
const _kPageBg = Color(0xFFEDF2E8);
const _kSurface = Color(0xFFF6F7F3);

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  String? _fullName;
  List<String> _childrenUids = [];

  bool _isVisibleToParent(Map<String, dynamic> data) {
    final targetRole = (data['targetRole'] ?? '').toString().trim();
    final source = (data['source'] ?? '').toString().trim();
    return (targetRole.isEmpty || targetRole == 'parent') &&
        source != 'secretariat';
  }

  bool _isPendingParentRequest(Map<String, dynamic> data) {
    final targetRole = (data['targetRole'] ?? '').toString().trim();
    final status = (data['status'] ?? '').toString().trim();
    final source = (data['source'] ?? '').toString().trim();
    final viewedByParent = data['viewedByParent'] == true;
    return targetRole == 'parent' &&
        status == 'pending' &&
        source != 'secretariat' &&
        !viewedByParent;
  }

  @override
  void initState() {
    super.initState();
    _loadParentName();
  }

  Future<void> _loadParentName() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _fullName = data['fullName'] as String?);
        final children = data['children'];
        if (children is List) {
          setState(() => _childrenUids = List<String>.from(children));
        }
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _kHeaderGreen,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text(
            'Deconectare',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          content: const Text(
            'Esti sigur ca vrei sa te deconectezi?',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: [
                  Expanded(
                    child: _BouncingButton(
                      onTap: () => Navigator.pop(context, false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Anuleaza',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BouncingButton(
                      onTap: () => Navigator.pop(context, true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD83838),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Deconectare',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPageFirestore()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_fullName ?? AppSession.username ?? 'Parinte').trim();

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: StreamBuilder<DocumentSnapshot>(
          stream: AppSession.uid != null
              ? FirebaseFirestore.instance.collection('users').doc(AppSession.uid).snapshots()
              : null,
          builder: (context, userSnap) {
            final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
            final inboxLastOpened = (userData['inboxLastOpenedAt'] as Timestamp?)?.toDate();

            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ParentHeader(
                    name: displayName,
                    onAvatarTap: _signOut,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -42),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _ActivityCard(childrenUids: _childrenUids),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    child: Column(
                      children: [
                        _BouncingButton(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ParentStudentsPage()),
                          ),
                          borderRadius: BorderRadius.circular(24),
                          child: _ChildrenCard(),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _BouncingButton(
                                onTap: () {
                                  if (AppSession.uid != null) {
                                    FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(AppSession.uid)
                                        .update({
                                          'requestsLastOpenedAt': FieldValue.serverTimestamp(),
                                        });
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ParentRequestsPage()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(26),
                                child: _RequestsCard(
                                  badgeStream: _childrenUids.isNotEmpty
                                      ? FirebaseFirestore.instance
                                            .collection('leaveRequests')
                                            .where('studentUid', whereIn: _childrenUids)
                                            .snapshots()
                                      : null,
                                  countPredicate: _isPendingParentRequest,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _BouncingButton(
                                onTap: () {
                                  if (AppSession.uid != null) {
                                    FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(AppSession.uid)
                                        .update({
                                          'inboxLastOpenedAt': FieldValue.serverTimestamp(),
                                        });
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ParentInboxPage()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(26),
                                child: _MessagesCard(
                                  badgeStream: _childrenUids.isNotEmpty
                                      ? FirebaseFirestore.instance
                                            .collection('leaveRequests')
                                            .where('studentUid', whereIn: _childrenUids)
                                            .snapshots()
                                      : null,
                                  lastViewed: inboxLastOpened,
                                  timestampField: 'reviewedAt',
                                  statusWhitelist: const ['approved', 'rejected'],
                                  countPredicate: _isVisibleToParent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ParentHeader extends StatelessWidget {
  final String name;
  final VoidCallback onAvatarTap;

  const _ParentHeader({required this.name, required this.onAvatarTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: SizedBox(
        width: double.infinity,
        height: 360,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _kHeaderGreen),
            CustomPaint(painter: _HeaderDotsPainter()),
            Positioned(
              right: -58,
              top: -22,
              child: Container(
                width: 265,
                height: 265,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -46,
              bottom: -72,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.11),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              top: 72,
              left: 26,
              right: 24,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Bine ai venit,\n$name',
                      style: const TextStyle(
                        fontSize: 62,
                        height: 1.04,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -1.0,
                      ),
                    ),
                  ),
                  _BouncingButton(
                    onTap: onAvatarTap,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.16)),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
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
}

class _ActivityCard extends StatelessWidget {
  final List<String> childrenUids;

  const _ActivityCard({required this.childrenUids});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(42),
      ),
      child: Column(
        children: [
          const Text(
            'Activitate Recenta',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: Color(0xFF121712),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: 86,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFD2D7D1),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          _ActivityStream(childrenUids: childrenUids),
        ],
      ),
    );
  }
}

class _ActivityStream extends StatelessWidget {
  final List<String> childrenUids;

  const _ActivityStream({required this.childrenUids});

  @override
  Widget build(BuildContext context) {
    if (childrenUids.isEmpty) {
      return const Column(
        children: [
          _ActivityRow(
            icon: Icons.login_rounded,
            title: 'Andrei Popescu a intrat',
            subtitle: '25 OCT, 15:45',
            iconBg: Color(0xFFD6DED6),
            iconColor: Color(0xFF0A741F),
          ),
          SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.check_circle,
            title: 'Cerere aprobata',
            subtitle: '25 OCT, 15:45',
            iconBg: Color(0xFFD6DED6),
            iconColor: Color(0xFF0A741F),
          ),
          SizedBox(height: 12),
          _ActivityRow(
            icon: Icons.notifications_active,
            title: 'Anunt Scolar Nou',
            subtitle: '25 OCT, 15:45',
            iconBg: Color(0xFFD6DED6),
            iconColor: Color(0xFF4F8456),
          ),
        ],
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentUid', whereIn: childrenUids)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const Column(
            children: [
              _ActivityRow(
                icon: Icons.notifications_active,
                title: 'Nu exista activitate recenta',
                subtitle: 'Verifica mai tarziu',
                iconBg: Color(0xFFD6DED6),
                iconColor: Color(0xFF4F8456),
              ),
            ],
          );
        }

        final docs = snap.data!.docs;
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = (aData['reviewedAt'] ?? aData['createdAt'] ?? aData['requestedAt']) as Timestamp?;
          final bTs = (bData['reviewedAt'] ?? bData['createdAt'] ?? bData['requestedAt']) as Timestamp?;
          final ad = aTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bd = bTs?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });

        final items = docs.take(3).map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString();
          final studentName = (data['studentName'] ?? 'Elev').toString();
          final ts = (data['reviewedAt'] ?? data['createdAt'] ?? data['requestedAt']) as Timestamp?;
          final subtitle = _fmt(ts?.toDate());

          if (status == 'approved') {
            return _ActivityRow(
              icon: Icons.check_circle,
              title: 'Cerere aprobata pentru $studentName',
              subtitle: subtitle,
              iconBg: const Color(0xFFD6DED6),
              iconColor: const Color(0xFF0A741F),
            );
          }
          if (status == 'rejected') {
            return _ActivityRow(
              icon: Icons.cancel,
              title: 'Cerere respinsa pentru $studentName',
              subtitle: subtitle,
              iconBg: const Color(0xFFE6D6D6),
              iconColor: const Color(0xFF9B2E2E),
            );
          }
          return _ActivityRow(
            icon: Icons.mail_rounded,
            title: 'Cerere noua de la $studentName',
            subtitle: subtitle,
            iconBg: const Color(0xFFD6DED6),
            iconColor: const Color(0xFF0A741F),
          );
        }).toList();

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              items[i],
              if (i != items.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }

  static String _fmt(DateTime? dt) {
    if (dt == null) return '--';
    const months = [
      'IAN',
      'FEB',
      'MAR',
      'APR',
      'MAI',
      'IUN',
      'IUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$day $month, $hh:$mm';
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBg;
  final Color iconColor;

  const _ActivityRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF1EC),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: iconColor, size: 31),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF151A15),
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF707970),
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

class _ChildrenCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFAFC7B1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: const Color(0xFFD3DDD4),
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Color(0xFF0A741F),
              size: 41,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Copiii Mei',
                  style: TextStyle(
                    fontSize: 22,
                    color: Color(0xFF0A741F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Vezi detaliile elevilor tai',
                  style: TextStyle(
                    fontSize: 17,
                    color: Color(0xFF32465B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF95BB98),
            size: 38,
          ),
        ],
      ),
    );
  }
}

class _RequestsCard extends StatelessWidget {
  final Stream<QuerySnapshot>? badgeStream;
  final bool Function(Map<String, dynamic>) countPredicate;

  const _RequestsCard({required this.badgeStream, required this.countPredicate});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 292,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: _kHeaderGreen,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A741F).withOpacity(0.22),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.article_rounded, size: 42, color: Colors.white),
          ),
          const Spacer(),
          const Text(
            'Cererile de\ninvoire',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.06,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<QuerySnapshot>(
            stream: badgeStream,
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                count = snapshot.data!.docs
                    .where((doc) => countPredicate(doc.data() as Map<String, dynamic>))
                    .length;
              }
              return Text(
                count > 0 ? '$count cereri noi' : 'Vezi cererile primite',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: count > 0 ? FontWeight.w700 : FontWeight.w500,
                  color: Colors.white.withOpacity(0.86),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MessagesCard extends StatelessWidget {
  final Stream<QuerySnapshot>? badgeStream;
  final DateTime? lastViewed;
  final String? timestampField;
  final List<String>? statusWhitelist;
  final bool Function(Map<String, dynamic>)? countPredicate;

  const _MessagesCard({
    required this.badgeStream,
    required this.lastViewed,
    required this.timestampField,
    required this.statusWhitelist,
    required this.countPredicate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 292,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD7DDD3),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFD0D6CB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFC6D1C8),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.chat_bubble_rounded, size: 38, color: _kHeaderGreen),
          ),
          const Spacer(),
          const Text(
            'Mesaje',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w600,
              color: Color(0xFF121712),
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: badgeStream,
            builder: (context, snapshot) {
              int count = 0;

              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                var docs = snapshot.data!.docs;
                if (statusWhitelist != null) {
                  docs = docs.where((d) => statusWhitelist!.contains(d['status'])).toList();
                }

                count = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  if (countPredicate != null && !countPredicate!(data)) return false;
                  if (lastViewed == null) return true;
                  final ts = (data[timestampField] as Timestamp?)?.toDate();
                  return ts != null && ts.isAfter(lastViewed!);
                }).length;
              }

              return Row(
                children: [
                  const Icon(Icons.circle, size: 13, color: _kHeaderGreen),
                  const SizedBox(width: 10),
                  Text(
                    count > 0 ? '$count mesaje noi' : 'Nu ai mesaje noi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF657165),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.14);
    const spacing = 36.0;
    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2.0, paint);
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
