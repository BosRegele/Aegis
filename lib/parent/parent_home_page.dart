import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Auth/login_page_firestore.dart';
import '../core/session.dart';
import 'parent_inbox_page.dart';
import 'parent_requests_page.dart';
import 'parent_students_page.dart';

// ── Colour tokens (same palette as student) ──────────────────────────────────
const _primary = Color(0xFF0D631B);
const _surface = Color(0xFFF7F9F0);
const _surfaceContainerLow = Color(0xFFF0F4E9);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFC8D1C2);
const _onSurface = Color(0xFF151A14);
const _danger = Color(0xFF8E3557);

// ─────────────────────────────────────────────────────────────────────────────
// MAIN WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  DateTime? _localInboxLastOpened;

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Parinte');
            final rawChildren = data['children'];
            final childrenUids = rawChildren is List
                ? List<String>.from(
                    rawChildren,
                  ).where((s) => s.trim().isNotEmpty).toList()
                : <String>[];
            final serverInboxLastOpened =
                (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();
            final inboxLastOpened = _effectiveLastOpened(
              serverInboxLastOpened,
              _localInboxLastOpened,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 760;
                final topSectionH = compact ? 444.0 : 484.0;
                final activityTop = compact ? 170.0 : 186.0;
                final activityCardHeight = compact ? 248.0 : 286.0;
                final childrenCardHeight = compact ? 84.0 : 92.0;
                final contentLift = 0.0;
                final topGap = compact ? 12.0 : 16.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: topSectionH,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _TopHeroHeader(
                            displayName: displayName,
                            onSettings: () => _showSettingsSheet(context),
                          ),
                          Positioned(
                            top: activityTop,
                            left: 20,
                            right: 20,
                            child: _ActivityCard(
                              childrenUids: childrenUids,
                              height: activityCardHeight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Transform.translate(
                          offset: Offset(0, contentLift),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                            child: Column(
                              children: [
                                SizedBox(height: topGap),
                                SizedBox(
                                  height: childrenCardHeight,
                                  child: _CopiiMeiCard(
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ParentStudentsPage(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                LayoutBuilder(
                                  builder: (context, innerConstraints) {
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: _CereriCard(
                                              childrenUids: childrenUids,
                                              onTap: () {
                                                _markOpened(
                                                  uid,
                                                  'requestsLastOpenedAt',
                                                );
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) =>
                                                        const ParentRequestsPage(),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: AspectRatio(
                                            aspectRatio: 1,
                                            child: _MesajeCard(
                                              childrenUids: childrenUids,
                                              inboxLastOpened: inboxLastOpened,
                                              onTap: () async {
                                                await _openInbox(context, uid);
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  DateTime? _effectiveLastOpened(DateTime? serverValue, DateTime? localValue) {
    if (serverValue == null) return localValue;
    if (localValue == null) return serverValue;
    return localValue.isAfter(serverValue) ? localValue : serverValue;
  }

  Future<void> _openInbox(BuildContext context, String uid) async {
    final openedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _localInboxLastOpened = openedAt;
      });
    }

    _markOpened(uid, 'inboxLastOpenedAt', openedAt);

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ParentInboxPage()),
    );

    final returnedAt = DateTime.now();
    if (mounted) {
      setState(() {
        _localInboxLastOpened = returnedAt;
      });
    }
    _markOpened(uid, 'inboxLastOpenedAt', returnedAt);
  }

  static Future<void> _markOpened(String uid, String field, [DateTime? when]) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({
          field: Timestamp.fromDate(when ?? DateTime.now()),
        }, SetOptions(merge: true))
        .catchError((_) {});
  }

  static void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _SettingsSheet(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatelessWidget {
  final String displayName;
  final VoidCallback onSettings;

  const _TopHeroHeader({required this.displayName, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: 220 + topPadding,
        color: _primary,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -80,
              top: -90,
              child: _Circle(size: 290, opacity: 0.08),
            ),
            Positioned(
              right: 38,
              top: 54 + topPadding,
              child: _Circle(size: 78, opacity: 0.07),
            ),
            Positioned(
              left: -60,
              bottom: -44,
              child: _Circle(size: 186, opacity: 0.08),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(28, 4 + topPadding, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      'Bine ai venit,\n$displayName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: onSettings,
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.person_outline_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
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

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;

  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
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

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityCard extends StatelessWidget {
  final List<String> childrenUids;
  final double height;

  const _ActivityCard({required this.childrenUids, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x140D631B),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: const [
                  Text(
                    'Activitate Recenta',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              thickness: 1,
              color: _outlineVariant.withValues(alpha: 0.35),
              indent: 20,
              endIndent: 20,
            ),
            Expanded(
              child: childrenUids.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 20,
                      ),
                      child: Center(
                        child: Text(
                          'Nu sunt copii adaugati.',
                          style: TextStyle(color: _outline),
                        ),
                      ),
                    )
                  : _ActivityFeed(childrenUids: childrenUids),
            ),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTIVITY FEED
// ─────────────────────────────────────────────────────────────────────────────
class _ActivityItem {
  final String title;
  final DateTime? time;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;

  const _ActivityItem({
    required this.title,
    required this.time,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
  });
}

class _ActivityFeed extends StatefulWidget {
  final List<String> childrenUids;

  const _ActivityFeed({required this.childrenUids});

  @override
  State<_ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<_ActivityFeed> {
  final Map<String, String> _names = {};

  @override
  void initState() {
    super.initState();
    _loadNames();
  }

  @override
  void didUpdateWidget(_ActivityFeed old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) _loadNames();
  }

  Future<void> _loadNames() async {
    for (final uid in widget.childrenUids) {
      if (_names.containsKey(uid)) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final d = doc.data() ?? {};
        final name = (d['fullName'] ?? d['username'] ?? '').toString().trim();
        if (name.isNotEmpty && mounted) {
          setState(() => _names[uid] = name);
        }
      } catch (_) {}
    }
  }

  String _resolveName(String uid, Map<String, dynamic> eventData) {
    if (_names.containsKey(uid)) return _names[uid]!;
    for (final key in ['studentName', 'fullName', 'userName', 'username']) {
      final v = (eventData[key] ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return 'Elev';
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '--';
    final day = dt.day.toString().padLeft(2, '0');
    final month = _monthShort(dt.month);
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day $month, $hour:$min';
  }

  static String _monthShort(int m) {
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
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    final uids = widget.childrenUids;

    final accessStream = FirebaseFirestore.instance
        .collection('accessEvents')
        .where('userId', whereIn: uids)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();

    final requestStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', whereIn: uids)
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('reviewedAt', descending: true)
        .limit(5)
        .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: accessStream,
      builder: (context, accessSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: requestStream,
          builder: (context, reqSnap) {
            final List<_ActivityItem> items = [];

            for (final doc in accessSnap.data?.docs ?? []) {
              final d = doc.data();
              final typStr = (d['type'] ?? '').toString().trim();
              final isExit = typStr == 'exit';
              final uid = (d['userId'] ?? '').toString();
              final name = _resolveName(uid, d);
              final ts = (d['timestamp'] as Timestamp?)?.toDate();
              items.add(
                _ActivityItem(
                  title: isExit ? '$name a iesit' : '$name a intrat',
                  time: ts,
                  icon: isExit
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                  iconBg: isExit
                      ? const Color(0xFFFFF0F5)
                      : const Color(0xFFF0F4EA),
                  iconColor: isExit ? _danger : _primary,
                ),
              );
            }

            for (final doc in reqSnap.data?.docs ?? []) {
              final d = doc.data();
              final status = (d['status'] ?? '').toString();
              final ts =
                  ((d['reviewedAt'] ?? d['updatedAt'] ?? d['createdAt'])
                          as Timestamp?)
                      ?.toDate();
              final approved = status == 'approved';
              items.add(
                _ActivityItem(
                  title: approved ? 'Cerere aprobata' : 'Cerere respinsa',
                  time: ts,
                  icon: approved
                      ? Icons.check_circle_outline_rounded
                      : Icons.cancel_outlined,
                  iconBg: approved
                      ? const Color(0xFFF0F4EA)
                      : const Color(0xFFFFF0F5),
                  iconColor: approved ? _primary : _danger,
                ),
              );
            }

            items.sort((a, b) {
              if (a.time == null && b.time == null) return 0;
              if (a.time == null) return 1;
              if (b.time == null) return -1;
              return b.time!.compareTo(a.time!);
            });

            final shown = items.take(3).toList();

            if (shown.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                child: Center(
                  child: Text(
                    'Nicio activitate recenta.',
                    style: TextStyle(color: _outline, fontSize: 14),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: shown
                  .map(
                    (item) => _ActivityTile(
                      item: item,
                      formattedTime: _formatTime(item.time),
                    ),
                  )
                  .toList(),
            );
          },
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final _ActivityItem item;
  final String formattedTime;

  const _ActivityTile({required this.item, required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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

// ─────────────────────────────────────────────────────────────────────────────
// COPIII MEI CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CopiiMeiCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CopiiMeiCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surfaceLowest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.group_rounded,
                  color: _primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Copiii mei',
                      style: TextStyle(
                        color: _primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Vezi detaliile elevilor tăi',
                      style: TextStyle(
                        color: _outline,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: _outline,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CERERI CARD (dark green)
// ─────────────────────────────────────────────────────────────────────────────
class _CereriCard extends StatelessWidget {
  final List<String> childrenUids;
  final VoidCallback onTap;

  const _CereriCard({required this.childrenUids, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeStream = childrenUids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: childrenUids)
              .where('status', isEqualTo: 'pending')
              .snapshots()
        : null;

    return Material(
      color: _primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        splashColor: Colors.white.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  if (badgeStream != null)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: badgeStream,
                        builder: (context, snap) {
                          final count = snap.data?.docs.length ?? 0;
                          if (count == 0) return const SizedBox();
                          return Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: _primary, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              const Spacer(),
              const Text(
                'Cereri de\ninvoire',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vezi rapid',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESAJE CARD (light)
// ─────────────────────────────────────────────────────────────────────────────
class _MesajeCard extends StatelessWidget {
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;
  final VoidCallback onTap;

  const _MesajeCard({
    required this.childrenUids,
    required this.inboxLastOpened,
    required this.onTap,
  });

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _decisionMessageTime(Map<String, dynamic> data) {
    return _readDateTime(data['reviewedAt']) ??
        _readDateTime(data['updatedAt']) ??
        _readDateTime(data['requestedAt']);
  }

  int _countUnreadDecisions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = inboxLastOpened;
    return docs.where((doc) {
      final data = doc.data();
      final source = (data['source'] ?? '').toString();
      if (source == 'secretariat') {
        return false;
      }

      final when = _decisionMessageTime(data);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  int _countUnreadSecretariat(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = inboxLastOpened;
    final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in docs) doc.id: doc,
    };
    return uniqueDocs.values.where((doc) {
      final when = _readDateTime(doc.data()['createdAt']) ??
          _readDateTime(doc.data()['reviewedAt']) ??
          _readDateTime(doc.data()['requestedAt']);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  int _countUnreadPendingRequests(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final lastViewed = inboxLastOpened;
    return docs.where((doc) {
      final when = _readDateTime(doc.data()['requestedAt']) ??
          _readDateTime(doc.data()['createdAt']) ??
          _readDateTime(doc.data()['updatedAt']);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams() {
    if (childrenUids.isEmpty) {
      return const <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    }

    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    return [
      base
          .where('recipientRole', isEqualTo: 'parent')
          .where('studentUid', isEqualTo: '')
          .snapshots(),
      ...childrenUids.map(
        (childUid) => base
            .where('recipientRole', isEqualTo: 'parent')
            .where('studentUid', isEqualTo: childUid)
            .snapshots(),
      ),
    ];
  }

  Widget _buildMergedStream(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
    Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)
    onReady,
  ) {
    if (streams.isEmpty) {
      return onReady(const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    Widget step(
      int index,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> acc,
    ) {
      if (index >= streams.length) {
        return onReady(acc);
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (!snap.hasData) {
            return onReady(acc);
          }
          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  @override
  Widget build(BuildContext context) {
      final parentUid = (AppSession.uid ?? '').trim();
    final decisionStream = childrenUids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: childrenUids)
              .where('status', whereIn: ['approved', 'rejected'])
              .snapshots()
        : null;
      final pendingRequestsStream = parentUid.isNotEmpty
      ? FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('targetUid', isEqualTo: parentUid)
        .where('targetRole', isEqualTo: 'parent')
        .where('status', isEqualTo: 'pending')
        .snapshots()
      : null;
    final secretariatStreams = _buildSecretariatStreams();

    return Material(
      color: _surfaceContainerLow,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: _primary,
                  size: 22,
                ),
              ),
              const Spacer(),
              const Text(
                'Mesaje',
                style: TextStyle(
                  color: _onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: pendingRequestsStream,
                builder: (context, pendingSnap) {
                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: decisionStream,
                    builder: (context, decisionSnap) {
                      return _buildMergedStream(secretariatStreams, (
                        secretariatDocs,
                      ) {
                        final unread =
                            _countUnreadPendingRequests(
                              pendingSnap.data?.docs ?? const [],
                            ) +
                            _countUnreadDecisions(
                              decisionSnap.data?.docs ?? const [],
                            ) +
                            _countUnreadSecretariat(secretariatDocs);
                        return Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: unread > 0 ? _primary : _outline,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              unread > 0
                                  ? '$unread mesaje noi'
                                  : 'Niciun mesaj nou',
                              style: TextStyle(
                                color: unread > 0 ? _primary : _outline,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        );
                      });
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Setari cont',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Schimba parola',
            onTap: () {
              Navigator.pop(context);
              _sendPasswordReset(context);
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Deconecteaza-te',
            danger: true,
            onTap: () {
              Navigator.pop(context);
              _logout(context);
            },
          ),
        ],
      ),
    );
  }

  void _sendPasswordReset(BuildContext context) async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu exista o adresa de email asociata contului.'),
        ),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Email de resetare trimis la $email.')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Eroare la trimiterea emailului de resetare.'),
          ),
        );
      }
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPageFirestore()),
        (_) => false,
      );
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? _danger : _primary;
    return Material(
      color: danger ? _danger.withValues(alpha: 0.07) : _surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
