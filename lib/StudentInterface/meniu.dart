import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

class MeniuScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const MeniuScreen({super.key, this.onNavigateTab, this.onOpenOrar});

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';
    final currentUser = FirebaseAuth.instance.currentUser;
    final userDocStream = currentUser == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(currentUser.uid)
              .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        child: Column(
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
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: userDocStream,
                builder: (context, snapshot) {
                  final userData =
                      snapshot.data?.data() ?? const <String, dynamic>{};
                  final fullName = (userData['fullName'] ?? '')
                      .toString()
                      .trim();
                  // ...existing code...
                  final lastOpenedAt =
                      (userData['inboxLastOpenedAt'] as Timestamp?)?.toDate();

                  final displayName = fullName.isNotEmpty
                      ? fullName
                      : fallbackName;

                  return Container(
                    width: double.infinity,
                    clipBehavior: Clip.antiAlias,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD8DDD8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
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
                                  if (onNavigateTab != null) {
                                    onNavigateTab!(1);
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
                                  if (onOpenOrar != null) {
                                    onOpenOrar!();
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
                                  if (onNavigateTab != null) {
                                    onNavigateTab!(3);
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
                                userId: currentUser?.uid,
                                lastOpenedAt: lastOpenedAt,
                                onTap: () async {
                                  print('[Menu] Mesaje onTap');
                                  if (onNavigateTab != null) {
                                    onNavigateTab!(4);
                                    return;
                                  }

                                  // Apelăm markAsRead direct aici
                                  final uid = AppSession.uid;
                                  print(
                                    '[Inbox] _markAsRead() called, uid: $uid',
                                  );
                                  if (uid != null && uid.isNotEmpty) {
                                    try {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(uid)
                                          .set({
                                            'inboxLastOpenedAt':
                                                FieldValue.serverTimestamp(),
                                          }, SetOptions(merge: true));
                                      print(
                                        '[Inbox] _markAsRead() Firestore update OK',
                                      );
                                    } catch (e) {
                                      print(
                                        '[Inbox] _markAsRead() Firestore error: $e',
                                      );
                                    }
                                  } else {
                                    print(
                                      '[Inbox] _markAsRead() aborted: uid null/gol',
                                    );
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
                                    Text(
                                      'în incinta școlii',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Color(0xFF4B78D2),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  else ...[
                                    Container(
                                      width: 12,
                                      height: 12,
                                      margin: const EdgeInsets.only(right: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.red.withOpacity(0.2),
                                            blurRadius: 2,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'În afara incintei',
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                        fontFamily: 'Roboto',
                                        letterSpacing: 0.2,
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
                                          stream: FirebaseFirestore.instance
                                              .collection('accessEvents')
                                              .where(
                                                'userId',
                                                isEqualTo:
                                                    currentUser?.uid ?? '',
                                              )
                                              .orderBy(
                                                'timestamp',
                                                descending: true,
                                              )
                                              .limit(1)
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            final docs =
                                                snapshot.data?.docs ?? [];
                                            if (docs.isNotEmpty) {
                                              final doc = docs.first;
                                              final type = (doc['type'] ?? '')
                                                  .toString();
                                              final ts =
                                                  (doc['timestamp']
                                                      as Timestamp?);
                                              final dateStr = ts != null
                                                  ? '${ts.toDate().day.toString().padLeft(2, '0')}.${ts.toDate().month.toString().padLeft(2, '0')}.${ts.toDate().year} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                                                  : '';
                                              if (type == 'entry') {
                                                return Text(
                                                  'Intrare - $dateStr',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF17B5A8),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              } else if (type == 'exit') {
                                                return Text(
                                                  'Ieșire - $dateStr',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFFE47E2D),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              } else {
                                                return Text(
                                                  'Scanare - $dateStr',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF2E3B4E),
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                );
                                              }
                                            } else {
                                              return Text(
                                                'Nu există scanări.',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF2E3B4E),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
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
                                          stream: FirebaseFirestore.instance
                                              .collection('leaveRequests')
                                              .where(
                                                'studentUid',
                                                isEqualTo:
                                                    currentUser?.uid ?? '',
                                              )
                                              .where(
                                                'status',
                                                whereIn: ['accepted', 'active'],
                                              )
                                              .snapshots(),
                                          builder: (context, snapshot) {
                                            final docs =
                                                snapshot.data?.docs ?? [];
                                            if (docs.any(
                                              (doc) =>
                                                  doc['status'] == 'accepted',
                                            )) {
                                              return Text(
                                                'Există o cerere acceptată.',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF4B78D2),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            } else if (docs.isNotEmpty) {
                                              return Text(
                                                'Există cereri active.',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF17B5A8),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              );
                                            } else {
                                              return Text(
                                                'Nu există nicio cerere activă.',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF2E3B4E),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
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
                        const Spacer(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
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
                  if ((badgeCount ?? 0) > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD53A3A),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.6),
                        ),
                        child: Text(
                          (badgeCount! > 99) ? '99+' : '${badgeCount!}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
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
  final String? userId;
  final DateTime? lastOpenedAt;
  final VoidCallback onTap;

  const _UnreadMessagesTile({
    required this.userId,
    required this.lastOpenedAt,
    required this.onTap,
  });

  int _countUnread(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String timestampField,
  ) {
    if (lastOpenedAt == null) {
      return snapshot.docs.length;
    }

    return snapshot.docs.where((doc) {
      final ts = (doc.data()[timestampField] as Timestamp?)?.toDate();
      if (ts == null) {
        return false;
      }
      return ts.isAfter(lastOpenedAt!);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    if (userId == null || userId!.isEmpty) {
      return _MenuTile(
        label: 'Mesaje',
        icon: Icons.chat_bubble_rounded,
        colors: const [Color(0xFF9C84E0), Color(0xFF6E46C2)],
        onTap: onTap,
      );
    }

    final leaveRequestsStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: userId)
        .snapshots();

    final accessEventsStream = FirebaseFirestore.instance
        .collection('accessEvents')
        .where('userId', isEqualTo: userId)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: leaveRequestsStream,
      builder: (context, leaveSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: accessEventsStream,
          builder: (context, accessSnap) {
            var unreadCount = 0;
            if (leaveSnap.hasData) {
              unreadCount += _countUnread(leaveSnap.data!, 'requestedAt');
            }
            if (accessSnap.hasData) {
              unreadCount += _countUnread(accessSnap.data!, 'timestamp');
            }

            return _MenuTile(
              label: 'Mesaje',
              icon: Icons.chat_bubble_rounded,
              colors: const [Color(0xFF9C84E0), Color(0xFF6E46C2)],
              onTap: onTap,
              badgeCount: unreadCount,
            );
          },
        );
      },
    );
  }
}

// ...existing code...
