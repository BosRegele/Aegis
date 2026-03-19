import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

class MeniuScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const MeniuScreen({super.key, this.onNavigateTab, this.onOpenOrar});

  @override
  State<MeniuScreen> createState() => _MeniuScreenState();
}

class _MeniuScreenState extends State<MeniuScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _lastScanStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveActiveStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots();
      _lastScanStream = FirebaseFirestore.instance
          .collection('accessEvents')
          .where('userId', isEqualTo: currentUser.uid)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots();
      _leaveActiveStream = FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentUid', isEqualTo: currentUser.uid)
          .where('status', whereIn: ['approved', 'active'])
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, snapshot) {
            final userData = snapshot.data?.data() ?? const <String, dynamic>{};
            final fullName = (userData['fullName'] ?? '').toString().trim();
            // ...existing code...
            final unreadCount = (userData['unreadCount'] as int?) ?? 0;

            final displayName = fullName.isNotEmpty ? fullName : fallbackName;

            return Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 110,
                  color: const Color(0xFF7AAF5B),
                  child: Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 8,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.shield_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE6EBEE),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              'Bun venit, $displayName!',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2E3B4E),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: _MenuTile(
                                  label: 'Acces\nQR',
                                  icon: Icons.qr_code_2_rounded,
                                  colors: const [
                                    Color(0xFF4B78D2),
                                    Color(0xFF304EAF),
                                  ],
                                  onTap: () {
                                    if (widget.onNavigateTab != null) {
                                      widget.onNavigateTab!(1);
                                      return;
                                    }

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const TeodorScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _MenuTile(
                                  label: 'Orar',
                                  icon: Icons.calendar_month_rounded,
                                  colors: const [
                                    Color(0xFFF0B15A),
                                    Color(0xFFE47E2D),
                                  ],
                                  onTap: () {
                                    if (widget.onOpenOrar != null) {
                                      widget.onOpenOrar!();
                                      return;
                                    }

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const OrarScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _MenuTile(
                                  label: 'Cereri\nInvoire',
                                  icon: Icons.article_rounded,
                                  colors: const [
                                    Color(0xFF17B5A8),
                                    Color(0xFF0C8D80),
                                  ],
                                  onTap: () {
                                    if (widget.onNavigateTab != null) {
                                      widget.onNavigateTab!(3);
                                      return;
                                    }

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const CereriScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _UnreadMessagesTile(
                                  unreadCount: unreadCount,
                                  onTap: () async {
                                    if (widget.onNavigateTab != null) {
                                      widget.onNavigateTab!(4);
                                      return;
                                    }

                                    final uid = AppSession.uid;
                                    if (uid != null && uid.isNotEmpty) {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .set({
                                            'inboxLastOpenedAt':
                                                FieldValue.serverTimestamp(),
                                            'unreadCount': 0,
                                          }, SetOptions(merge: true));
                                    }

                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const InboxScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Color(0xFF2E3B4E).withOpacity(0.22),
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0xFF2E3B4E).withOpacity(0.09),
                                  blurRadius: 18,
                                  offset: Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Status elevului
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Statusul elevului:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E3B4E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (userData['inSchool'] == true)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF4B78D2,
                                          ).withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF4B78D2),
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.school_rounded,
                                              color: Color(0xFF4B78D2),
                                              size: 15,
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              'În incintă',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF4B78D2),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.10),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.red,
                                            width: 1.2,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.logout_rounded,
                                              color: Colors.red,
                                              size: 15,
                                            ),
                                            const SizedBox(width: 5),
                                            const Text(
                                              'În afara incintei',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.red,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Divider(
                                  color: Color(0xFF2E3B4E).withOpacity(0.18),
                                  thickness: 2,
                                  height: 16,
                                ),
                                // Ultima scanare
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Ultima scanare:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E3B4E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child:
                                          StreamBuilder<
                                            QuerySnapshot<Map<String, dynamic>>
                                          >(
                                            stream: _lastScanStream,
                                            builder: (context, snapshot) {
                                              final docs =
                                                  snapshot.data?.docs ?? [];
                                              if (docs.isNotEmpty) {
                                                final doc = docs.first;
                                                final type =
                                                    ((doc.data()['type']) ?? '')
                                                        .toString();
                                                final ts =
                                                    (doc['timestamp']
                                                        as Timestamp?);
                                                final dateStr = ts != null
                                                    ? '${ts.toDate().day.toString().padLeft(2, '0')}.${ts.toDate().month.toString().padLeft(2, '0')}.${ts.toDate().year} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                                                    : '';
                                                final scanColor =
                                                    type == 'entry'
                                                    ? const Color(0xFF17B5A8)
                                                    : type == 'exit'
                                                    ? const Color(0xFFE47E2D)
                                                    : const Color(0xFF4B78D2);
                                                final scanIcon = type == 'entry'
                                                    ? Icons.login_rounded
                                                    : type == 'exit'
                                                    ? Icons.logout_rounded
                                                    : Icons
                                                          .qr_code_scanner_rounded;
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: scanColor
                                                        .withOpacity(0.10),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: scanColor,
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        scanIcon,
                                                        color: scanColor,
                                                        size: 15,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      Flexible(
                                                        child: Text(
                                                          dateStr,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: scanColor,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else {
                                                return Text(
                                                  'Niciuna',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(
                                                      0xFF2E3B4E,
                                                    ).withOpacity(0.45),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              }
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                                Divider(
                                  color: Color(0xFF2E3B4E).withOpacity(0.18),
                                  thickness: 2,
                                  height: 16,
                                ),
                                // Cereri de învoire
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Cereri de învoire:',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2E3B4E),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child:
                                          StreamBuilder<
                                            QuerySnapshot<Map<String, dynamic>>
                                          >(
                                            stream: _leaveActiveStream,
                                            builder: (context, snapshot) {
                                              final docs =
                                                  snapshot.data?.docs ?? [];
                                              if (docs.any(
                                                (doc) =>
                                                    doc.data()['status'] ==
                                                    'approved',
                                              )) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF4CAF50,
                                                    ).withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF4CAF50,
                                                      ),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .check_circle_rounded,
                                                        color: Color(
                                                          0xFF4CAF50,
                                                        ),
                                                        size: 15,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      const Flexible(
                                                        child: Text(
                                                          'Invoire activă',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Color(
                                                              0xFF388E3C,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else if (docs.isNotEmpty) {
                                                return Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 10,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF17B5A8,
                                                    ).withOpacity(0.12),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                    border: Border.all(
                                                      color: const Color(
                                                        0xFF17B5A8,
                                                      ),
                                                      width: 1.2,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      const Icon(
                                                        Icons
                                                            .hourglass_top_rounded,
                                                        color: Color(
                                                          0xFF17B5A8,
                                                        ),
                                                        size: 15,
                                                      ),
                                                      const SizedBox(width: 5),
                                                      const Flexible(
                                                        child: Text(
                                                          'Cerere în așteptare',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Color(
                                                              0xFF17B5A8,
                                                            ),
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              } else {
                                                return Text(
                                                  'Niciuna',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(
                                                      0xFF2E3B4E,
                                                    ).withOpacity(0.45),
                                                    fontWeight: FontWeight.w400,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              }
                                            },
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
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

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final int? badgeCount;

  const _MenuTile({
    required this.label,
    required this.icon,
    required this.colors,
    this.onTap,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: Colors.white, size: 44),
                  if (badgeCount != null && badgeCount! > 0)
                    Positioned(
                      right: -8,
                      top: -8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          badgeCount!.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadMessagesTile extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _UnreadMessagesTile({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _MenuTile(
      label: 'Mesaje',
      icon: Icons.chat_bubble_rounded,
      colors: const [Color(0xFF9C84E0), Color(0xFF6E46C2)],
      onTap: onTap,
      badgeCount: unreadCount,
    );
  }
}

// ...existing code...
