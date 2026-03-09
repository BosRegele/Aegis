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
      backgroundColor: const Color(0xFFD8DDD8),
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
                  final classId = (userData['classId'] ?? '')
                      .toString()
                      .trim()
                      .toUpperCase();
                  final lastOpenedAt =
                      (userData['inboxLastOpenedAt'] as Timestamp?)?.toDate();

                  final displayName = fullName.isNotEmpty
                      ? fullName
                      : fallbackName;

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD8DDD8),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
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
                        const SizedBox(height: 16),
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
                                onTap: () {
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
                        if (classId.isNotEmpty)
                          _AccessInfoCard(classId: classId),
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

class _AccessInfoCard extends StatelessWidget {
  final String classId;

  const _AccessInfoCard({required this.classId});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D6D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Clasa: $classId',
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF48515A),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
