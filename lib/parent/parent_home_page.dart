import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../Auth/login_page_firestore.dart';
import '../admin/services/admin_api.dart';
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

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});

  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

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

  // Cached user-doc stream — must not be recreated inside build().
  String? _cachedUserDocUid;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  Stream<DocumentSnapshot<Map<String, dynamic>>> _getUserDocStream(String uid) {
    if (uid != _cachedUserDocUid || _userDocStream == null) {
      _cachedUserDocUid = uid;
      _userDocStream = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots();
    }
    return _userDocStream!;
  }

  // Cache the future so it is not recreated on every StreamBuilder rebuild.
  String? _cachedChildrenKey;
  Future<List<String>>? _cachedChildrenFuture;

  Future<List<String>> _getOrCreateChildrenFuture(
    String parentUid,
    List<String> directChildren,
  ) {
    final key = '$parentUid|${directChildren.join(",")}';
    if (key != _cachedChildrenKey || _cachedChildrenFuture == null) {
      _cachedChildrenKey = key;
      _cachedChildrenFuture = _loadLinkedChildren(parentUid, directChildren);
    }
    return _cachedChildrenFuture!;
  }

  Future<List<String>> _loadLinkedChildren(
    String parentUid,
    List<String> directChildren,
  ) async {
    final ids = <String>{
      ...directChildren
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty),
    };

    final users = FirebaseFirestore.instance.collection('users');

    try {
      final byParents = await users
          .where('parents', arrayContains: parentUid)
          .get();
      ids.addAll(byParents.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentUid = await users
          .where('parentUid', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentUid.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentId = await users
          .where('parentId', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentId.docs.map((doc) => doc.id));
    } catch (_) {}

    ids.remove(parentUid);
    final sorted = ids.toList()..sort();
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return const SizedBox();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _getUserDocStream(uid),
          builder: (context, snap) {
            final data = snap.data?.data() ?? <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty
                ? fullName
                : (AppSession.username ?? 'Parinte');
            final rawChildren = data['children'];
            final directChildrenUids = rawChildren is List
                ? rawChildren
                      .map((e) {
                        if (e is String) return e.trim();
                        if (e is Map) {
                          return ((e['uid'] ?? e['studentUid'] ?? e['id']) ??
                                  '')
                              .toString()
                              .trim();
                        }
                        return '';
                      })
                      .where((s) => s.isNotEmpty)
                      .toList()
                : <String>[];
            final serverInboxLastOpened =
                (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();
            final inboxLastOpened = _effectiveLastOpened(
              serverInboxLastOpened,
              _localInboxLastOpened,
            );

            return FutureBuilder<List<String>>(
              future: _getOrCreateChildrenFuture(uid, directChildrenUids),
              builder: (context, childrenSnapshot) {
                final childrenUids =
                    childrenSnapshot.data ?? directChildrenUids;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: _surface),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: _TopHeroHeader(
                        displayName: displayName,
                        onSettings: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentProfilePage(),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 190,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Column(
                          children: [
                            _ActivityCard(
                              childrenUids: childrenUids,
                              height: 390,
                            ),
                            const SizedBox(height: 16),
                            _CopiiMeiCard(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ParentStudentsPage(),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 184,
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
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SizedBox(
                                    height: 184,
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
                            ),
                          ],
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
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatefulWidget {
  final String displayName;
  final VoidCallback onSettings;

  const _TopHeroHeader({required this.displayName, required this.onSettings});

  @override
  State<_TopHeroHeader> createState() => _TopHeroHeaderState();
}

class _TopHeroHeaderState extends State<_TopHeroHeader> {
  bool _pressed = false;

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
                      'Bine ai venit,\n${widget.displayName}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        height: 1.20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTapDown: (_) => setState(() => _pressed = true),
                    onTapUp: (_) {
                      setState(() => _pressed = false);
                      widget.onSettings();
                    },
                    onTapCancel: () => setState(() => _pressed = false),
                    child: AnimatedScale(
                      scale: _pressed ? 0.78 : 1.0,
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.easeOut,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 100),
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
          borderRadius: BorderRadius.circular(34),
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
            const SizedBox(height: 12),
            const Text(
              'Activitate Recentă',
              style: TextStyle(
                fontSize: 31,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.7,
                color: Color(0xFF1A2E1D),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 10),
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
            if (childrenUids.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _ParentStatsRow(childrenUids: childrenUids),
              ),
            ],
            const SizedBox(height: 14),
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

  late Stream<QuerySnapshot<Map<String, dynamic>>> _accessStream;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _requestStream;

  @override
  void initState() {
    super.initState();
    _buildStreams(widget.childrenUids);
    _loadNames();
  }

  @override
  void didUpdateWidget(_ActivityFeed old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStreams(widget.childrenUids);
      _loadNames();
    }
  }

  void _buildStreams(List<String> uids) {
    if (uids.isEmpty) {
      _accessStream = const Stream.empty();
      _requestStream = const Stream.empty();
      return;
    }
    _accessStream = FirebaseFirestore.instance
        .collection('accessEvents')
        .where('userId', whereIn: uids)
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots();
    _requestStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', whereIn: uids)
        .where('status', whereIn: ['approved', 'rejected'])
        .orderBy('reviewedAt', descending: true)
        .limit(5)
        .snapshots();
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
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _accessStream,
      builder: (context, accessSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requestStream,
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

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: shown
                    .map(
                      (item) => _ActivityTile(
                        item: item,
                        formattedTime: _formatTime(item.time),
                      ),
                    )
                    .toList(),
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF4FBF6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: item.iconColor,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(item.icon, color: Colors.white, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        color: Color(0xFF1A2E1D),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        color: Color(0xFF8A9E8C),
                        fontSize: 12,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
class _CereriCard extends StatefulWidget {
  final List<String> childrenUids;
  final VoidCallback onTap;

  const _CereriCard({required this.childrenUids, required this.onTap});

  @override
  State<_CereriCard> createState() => _CereriCardState();
}

class _CereriCardState extends State<_CereriCard> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _badgeStream;

  @override
  void initState() {
    super.initState();
    _buildStream(widget.childrenUids);
  }

  @override
  void didUpdateWidget(_CereriCard old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStream(widget.childrenUids);
    }
  }

  void _buildStream(List<String> uids) {
    _badgeStream = uids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: uids)
              .where('status', isEqualTo: 'pending')
              .snapshots()
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final badgeStream = _badgeStream;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D631B), Color(0xFF19802E)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x350D631B),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                if (badgeStream != null) const SizedBox.shrink(),
              ],
            ),
            const Spacer(),
            const Text(
              'Cereri de\ninvoire',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Vezi rapid',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MESAJE CARD (light)
// ─────────────────────────────────────────────────────────────────────────────
class _MesajeCard extends StatefulWidget {
  final List<String> childrenUids;
  final DateTime? inboxLastOpened;
  final VoidCallback onTap;

  const _MesajeCard({
    required this.childrenUids,
    required this.inboxLastOpened,
    required this.onTap,
  });

  @override
  State<_MesajeCard> createState() => _MesajeCardState();
}

class _MesajeCardState extends State<_MesajeCard> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _decisionStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pendingRequestsStream;
  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _secretariatStreams = [];

  @override
  void initState() {
    super.initState();
    _buildStreams(widget.childrenUids);
  }

  @override
  void didUpdateWidget(_MesajeCard old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStreams(widget.childrenUids);
    }
  }

  void _buildStreams(List<String> uids) {
    final parentUid = (AppSession.uid ?? '').trim();
    _decisionStream = uids.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', whereIn: uids)
              .where('status', whereIn: ['approved', 'rejected'])
              .snapshots()
        : null;
    _pendingRequestsStream = parentUid.isNotEmpty
        ? FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('targetUid', isEqualTo: parentUid)
              .where('targetRole', isEqualTo: 'parent')
              .where('status', isEqualTo: 'pending')
              .snapshots()
              .handleError((_) {})
        : null;
    _secretariatStreams = _buildSecretariatStreams(uids);
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams(
    List<String> uids,
  ) {
    if (uids.isEmpty) {
      return const <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    }
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    return [
      base
          .where('recipientRole', isEqualTo: 'parent')
          .where('studentUid', isEqualTo: '')
          .snapshots(),
      ...uids.map(
        (childUid) => base
            .where('recipientRole', isEqualTo: 'parent')
            .where('studentUid', isEqualTo: childUid)
            .snapshots(),
      ),
    ];
  }

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
    final lastViewed = widget.inboxLastOpened;
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
    final lastViewed = widget.inboxLastOpened;
    final uniqueDocs = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
      for (final doc in docs) doc.id: doc,
    };
    return uniqueDocs.values.where((doc) {
      final when =
          _readDateTime(doc.data()['createdAt']) ??
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
    final lastViewed = widget.inboxLastOpened;
    return docs.where((doc) {
      final when =
          _readDateTime(doc.data()['requestedAt']) ??
          _readDateTime(doc.data()['createdAt']) ??
          _readDateTime(doc.data()['updatedAt']);
      if (when == null) {
        return lastViewed == null;
      }
      return lastViewed == null || when.isAfter(lastViewed);
    }).length;
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
    // Single set of StreamBuilders — compute unread count once, use for both badge and text.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _pendingRequestsStream,
      builder: (context, pendingSnap) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _decisionStream,
          builder: (context, decisionSnap) {
            return _buildMergedStream(_secretariatStreams, (secretariatDocs) {
              final unread =
                  _countUnreadPendingRequests(
                    pendingSnap.data?.docs ?? const [],
                  ) +
                  _countUnreadDecisions(decisionSnap.data?.docs ?? const []) +
                  _countUnreadSecretariat(secretariatDocs);

              return GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7EDE1),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: const Color(0xFFC8D1C2).withValues(alpha: 0.36),
                      width: 1.1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: _primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.chat_bubble_outline_rounded,
                              color: _primary,
                              size: 24,
                            ),
                          ),
                          if (unread > 0) const SizedBox.shrink(),
                        ],
                      ),
                      const Spacer(),
                      const Text(
                        'Mesaje',
                        style: TextStyle(
                          color: _onSurface,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
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
                            unread > 0 ? '$unread mesaje noi' : 'Vezi rapid',
                            style: TextStyle(
                              color: unread > 0 ? _primary : _outline,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            });
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW (Prezenți + Cereri în așteptare)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentStatsRow extends StatefulWidget {
  final List<String> childrenUids;

  const _ParentStatsRow({required this.childrenUids});

  @override
  State<_ParentStatsRow> createState() => _ParentStatsRowState();
}

class _ParentStatsRowState extends State<_ParentStatsRow> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _childrenStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _requestStream;

  @override
  void initState() {
    super.initState();
    _buildStreams(widget.childrenUids);
  }

  @override
  void didUpdateWidget(_ParentStatsRow old) {
    super.didUpdateWidget(old);
    if (old.childrenUids.join() != widget.childrenUids.join()) {
      _buildStreams(widget.childrenUids);
    }
  }

  void _buildStreams(List<String> uids) {
    if (uids.isEmpty) {
      _childrenStream = null;
      _requestStream = null;
      return;
    }
    _childrenStream = FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: uids)
        .snapshots();
    _requestStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', whereIn: uids)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.childrenUids.length;
    if (total == 0) return const SizedBox();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _childrenStream,
      builder: (context, childSnap) {
        int present = 0;
        if (childSnap.hasData) {
          for (final doc in childSnap.data!.docs) {
            final d = doc.data();
            if (d['isPresent'] == true ||
                d['inSchool'] == true ||
                d['present'] == true) {
              present++;
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _requestStream,
          builder: (context, reqSnap) {
            final pending = reqSnap.data?.docs.length ?? 0;

            return Row(
              children: [
                Expanded(
                  child: _StatBox(
                    label: 'PREZENȚI',
                    value: '$present/$total',
                    valueColor: present > 0 ? _primary : _outline,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatBox(
                    label: 'CERERI',
                    value: '$pending',
                    valueColor: pending > 0 ? _danger : _outline,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4E9),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF717B6E),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PARENT PROFILE PAGE
// ─────────────────────────────────────────────────────────────────────────────
class ParentProfilePage extends StatelessWidget {
  const ParentProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AppSession.uid ?? '';
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _ProfileTopHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(uid)
                    .snapshots(),
                builder: (context, snap) {
                  final data = snap.data?.data() ?? <String, dynamic>{};
                  final fullName = (data['fullName'] ?? '').toString().trim();
                  final username = (data['username'] ?? '').toString().trim();
                  final email = FirebaseAuth.instance.currentUser?.email ?? '';
                  final rawChildren = data['children'];
                  final childCount = rawChildren is List
                      ? rawChildren.length
                      : 0;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: _ParentProfileCard(
                      displayName: fullName.isNotEmpty
                          ? fullName
                          : (AppSession.username ?? 'Parinte'),
                      username: username,
                      email: email,
                      childCount: snap.hasData ? childCount : null,
                      onSettings: () => showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const _SettingsSheet(),
                      ),
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

class _ProfileTopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _ProfileTopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(54),
        bottomRight: Radius.circular(54),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -52,
              child: _Circle(size: 220, opacity: 0.08),
            ),
            Positioned(
              top: 44,
              right: 34,
              child: _Circle(size: 72, opacity: 0.08),
            ),
            Positioned(
              left: 156,
              bottom: -28,
              child: _Circle(size: 82, opacity: 0.08),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onBack,
                      behavior: HitTestBehavior.opaque,
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParentProfileCard extends StatelessWidget {
  final String displayName;
  final String username;
  final String email;
  final int? childCount;
  final VoidCallback onSettings;

  const _ParentProfileCard({
    required this.displayName,
    required this.username,
    required this.email,
    required this.childCount,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(38)),
          boxShadow: [
            BoxShadow(
              color: Color(0x120D631B),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Color(0xFF151A14),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF0D631B),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onSettings,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: _primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(height: 1, color: const Color(0xFFF0F1EA)),
              const SizedBox(height: 18),
              _ProfileInfoBox(
                icon: Icons.mail_outline_rounded,
                label: 'EMAIL',
                value: email.isNotEmpty ? email : 'Nedefinit',
              ),
              const SizedBox(height: 10),
              _ProfileInfoBox(
                icon: Icons.child_care_rounded,
                label: 'NR. COPII',
                value: childCount == null
                    ? '...'
                    : '$childCount ${childCount == 1 ? 'copil' : 'copii'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileInfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: _primary, size: 28),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF717B6E),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151A14),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  @override
  Widget build(BuildContext ctx) {
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
              'Setări cont',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.edit_outlined,
            label: 'Editare profil',
            onTap: () {
              Navigator.pop(ctx);
              showDialog<void>(
                context: ctx,
                barrierDismissible: true,
                builder: (_) => const _ParentAccountSettingsDialog(),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Deconectează-te',
            danger: true,
            onTap: () {
              Navigator.pop(ctx);
              _logout(ctx);
            },
          ),
        ],
      ),
    );
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

// ─────────────────────────────────────────────────────────────────────────────
// ACCOUNT SETTINGS DIALOG  (Email · Parolă)
// ─────────────────────────────────────────────────────────────────────────────
class _ParentAccountSettingsDialog extends StatefulWidget {
  const _ParentAccountSettingsDialog();

  @override
  State<_ParentAccountSettingsDialog> createState() =>
      _ParentAccountSettingsDialogState();
}

class _ParentAccountSettingsDialogState
    extends State<_ParentAccountSettingsDialog> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();
  final _api = AdminApi();

  bool _editingEmail = false;
  bool _editingPassword = false;
  bool _saving = false;
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  bool _obscurePassword = true;
  String? _passwordError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailC.text = user?.email ?? '';
    _passwordC.text = '••••••••••••';
    final uid = user?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) {
          setState(() {
            final email = (doc.data()?['personalEmail'] ?? '').toString();
            if (email.isNotEmpty) _emailC.text = email;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    _verificationCodeC.dispose();
    super.dispose();
  }

  Future<bool> _reauthenticate() async {
    final currentPassword = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _ParentReauthDialog(),
    );
    if (currentPassword == null || currentPassword.isEmpty) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      return true;
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parola actuală este incorectă.')),
        );
      }
      return false;
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    var closed = false;
    try {
      final updates = <String, dynamic>{};
      if (_editingEmail && _emailC.text.trim().isNotEmpty) {
        if (!_emailVerified) {
          setState(() {
            _emailError = 'Verifică mai întâi email-ul nou.';
            _saving = false;
          });
          return;
        }
        updates['personalEmail'] = _emailC.text.trim();
      }
      if (_editingPassword &&
          _passwordC.text.trim().isNotEmpty &&
          _passwordC.text.trim() != '••••••••••••') {
        if (_passwordC.text.trim() != _confirmPasswordC.text.trim()) {
          setState(() {
            _passwordError = 'Parolele nu se potrivesc.';
            _saving = false;
          });
          return;
        }
        if (_passwordC.text.trim().length < 8) {
          setState(() {
            _passwordError = 'Parola trebuie să aibă cel puțin 8 caractere.';
            _saving = false;
          });
          return;
        }
        setState(() => _passwordError = null);
        final ok = await _reauthenticate();
        if (!ok) return;
        await FirebaseAuth.instance.currentUser?.updatePassword(
          _passwordC.text.trim(),
        );
      }
      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updates);
      }
      if (mounted) {
        closed = true;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Setări actualizate.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
      }
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ScrollbarTheme(
          data: const ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(2),
            radius: Radius.circular(2),
            crossAxisMargin: -12,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Setări Cont',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Anulează',
                          style: TextStyle(
                            color: _outline,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Salvează',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFFF0F1EA)),
                  const SizedBox(height: 18),

                  // ── EMAIL ──
                  const Text(
                    'EMAIL',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingEmail
                              ? TextField(
                                  controller: _emailC,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Email',
                                  ),
                                )
                              : Text(
                                  _emailC.text,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            _editingEmail = !_editingEmail;
                            _codeSent = false;
                            _emailVerified = false;
                            _emailError = null;
                            _verificationCodeC.clear();
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingEmail && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: _sendingCode
                            ? null
                            : () async {
                                final email = _emailC.text.trim();
                                if (email.isEmpty || !email.contains('@')) {
                                  setState(
                                    () => _emailError = 'Email invalid.',
                                  );
                                  return;
                                }
                                final uid =
                                    FirebaseAuth.instance.currentUser?.uid;
                                if (uid == null) return;
                                setState(() {
                                  _sendingCode = true;
                                  _emailError = null;
                                });
                                try {
                                  await _api.sendVerificationEmail(
                                    uid: uid,
                                    email: email,
                                  );
                                  if (mounted) {
                                    setState(() {
                                      _codeSent = true;
                                      _sendingCode = false;
                                    });
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    setState(() {
                                      _emailError =
                                          'Nu am putut trimite codul.';
                                      _sendingCode = false;
                                    });
                                  }
                                }
                              },
                        icon: _sendingCode
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 18),
                        label: Text(
                          _codeSent ? 'Retrimite cod' : 'Trimite cod',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (_codeSent && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: _outline,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Am trimis un cod la ${_emailC.text.trim()}. Introdu-l mai jos.',
                            style: const TextStyle(
                              color: _outline,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pin_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _verificationCodeC,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: _outlineVariant,
                                  fontSize: 15,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final code = _verificationCodeC.text.trim();
                              if (code.isEmpty) {
                                setState(() => _emailError = 'Introdu codul.');
                                return;
                              }
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              setState(() => _emailError = null);
                              try {
                                final result = await _api.verifyEmailCode(
                                  uid: uid,
                                  code: code,
                                );
                                if (result['verified'] == true) {
                                  if (mounted) {
                                    setState(() => _emailVerified = true);
                                  }
                                } else {
                                  if (mounted) {
                                    setState(
                                      () => _emailError = 'Cod invalid.',
                                    );
                                  }
                                }
                              } catch (_) {
                                if (mounted) {
                                  setState(() => _emailError = 'Cod invalid.');
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Verifică',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_emailVerified) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: _primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Email verificat cu succes!',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_emailError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _emailError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ── PAROLĂ ──
                  const Text(
                    'PAROLĂ',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingPassword
                              ? TextField(
                                  controller: _passwordC,
                                  autofocus: true,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Parola nouă',
                                  ),
                                )
                              : const Text(
                                  '••••••••••••',
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() {
                            if (!_editingPassword) {
                              _editingPassword = true;
                              _passwordC.clear();
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            } else {
                              _editingPassword = false;
                              _passwordC.text = '••••••••••••';
                              _confirmPasswordC.clear();
                              _passwordError = null;
                            }
                          }),
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editingPassword) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _confirmPasswordC,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Confirmă parola',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_passwordError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _passwordError!,
                      style: const TextStyle(
                        color: _danger,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REAUTH DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _ParentReauthDialog extends StatefulWidget {
  const _ParentReauthDialog();

  @override
  State<_ParentReauthDialog> createState() => _ParentReauthDialogState();
}

class _ParentReauthDialogState extends State<_ParentReauthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirmare identitate',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Introdu parola actuală pentru a continua.',
              style: TextStyle(color: _outline, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: _onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Parola actuală',
                hintStyle: const TextStyle(color: _outline),
                filled: true,
                fillColor: _surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFCED8C8),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFCED8C8),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: _surfaceContainerLow,
                      foregroundColor: _onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Anulează',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Confirmă',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
