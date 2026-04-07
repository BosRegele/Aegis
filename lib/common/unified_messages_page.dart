import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);
const _kCardBg = Color(0xFFF8F8F8);
const _kTextPrimary = Color(0xFF121512);
const _kTextMuted = Color(0xFF616962);

enum UnifiedInboxRole { student, parent, teacher }

enum _MessageKind { decision, system }

enum _MessageState { pending, approved, rejected, system }

class UnifiedMessagesPage extends StatefulWidget {
  final UnifiedInboxRole role;
  final VoidCallback? onBack;

  const UnifiedMessagesPage({super.key, required this.role, this.onBack});

  @override
  State<UnifiedMessagesPage> createState() => _UnifiedMessagesPageState();
}

class _UnifiedMessagesPageState extends State<UnifiedMessagesPage> {
  bool _loadingChildren = false;
  List<String> _childrenUids = const <String>[];
  Map<String, String> _childNames = const <String, String>{};

  @override
  void initState() {
    super.initState();
    if (widget.role == UnifiedInboxRole.parent) {
      _loadingChildren = true;
      _loadChildren();
    }
  }

  Future<void> _loadChildren() async {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = const <String>[];
          _childNames = const <String, String>{};
        });
      }
      return;
    }

    try {
      final parentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final parentData = parentDoc.data() ?? const <String, dynamic>{};
      final childIds = await _loadLinkedChildrenUids(uid, parentData);
      final childNames = await _loadUserLabels(childIds.toSet());

      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = childIds;
          _childNames = childNames;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = const <String>[];
          _childNames = const <String, String>{};
        });
      }
    }
  }

  Future<List<String>> _loadLinkedChildrenUids(
    String parentUid,
    Map<String, dynamic> parentData,
  ) async {
    final ids = <String>{
      ...((parentData['children'] as List? ?? const [])
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty && value != parentUid)),
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

    final sorted = ids.toList()..sort();
    return sorted;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildSecretariatStreams(
    String uid,
  ) {
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    switch (widget.role) {
      case UnifiedInboxRole.student:
        return [
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
        ];
      case UnifiedInboxRole.teacher:
        return [
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
        ];
      case UnifiedInboxRole.parent:
        return [
          base
              .where('recipientRole', isEqualTo: 'parent')
              .where('studentUid', isEqualTo: '')
              .snapshots(),
          ..._childrenUids.map(
            (childUid) => base
                .where('recipientRole', isEqualTo: 'parent')
                .where('studentUid', isEqualTo: childUid)
                .snapshots(),
          ),
        ];
    }
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildParentDecisionStreams(
    String uid,
  ) {
    final leave = FirebaseFirestore.instance.collection('leaveRequests');
    return [
      ..._childrenUids.map(
        (childUid) => leave
            .where('studentUid', isEqualTo: childUid)
            .orderBy('requestedAt', descending: true)
            .limit(50)
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
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final doc in acc) {
          byId[doc.id] = doc;
        }
        return onReady(byId.values.toList());
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (snap.hasError) {
            // Do not block the whole inbox if one query is denied by rules.
            return step(index + 1, acc);
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStudentDecisionsStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .limit(80)
        .snapshots();
  }

  Future<Map<String, String>> _loadUserLabels(Set<String> uids) async {
    if (uids.isEmpty) return const <String, String>{};

    final result = <String, String>{};
    const chunkSize = 10;
    final ids = uids.toList();

    for (int index = 0; index < ids.length; index += chunkSize) {
      final chunk = ids.skip(index).take(chunkSize).toList();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final fullName = (data['fullName'] ?? '').toString().trim();
        final username = (data['username'] ?? '').toString().trim();
        final label = fullName.isNotEmpty ? fullName : username;
        if (label.isNotEmpty) {
          result[doc.id] = label;
        }
      }
    }

    return result;
  }

  String _timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final diff = today.difference(msgDay).inDays;
    if (diff == 0) {
      final hh = dateTime.hour.toString().padLeft(2, '0');
      final mm = dateTime.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    if (diff == 1) return 'Ieri';
    return _formatDate(dateTime);
  }

  String _formatDate(DateTime date) {
    const months = [
      'Ian',
      'Feb',
      'Mar',
      'Apr',
      'Mai',
      'Iun',
      'Iul',
      'Aug',
      'Sep',
      'Oct',
      'Noi',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  String _normalizeSender(String sender) {
    final value = sender.trim();
    if (value.isEmpty) return 'Secretariat';
    final lower = value.toLowerCase();
    if (lower.contains('secretariat')) return 'Secretariat';
    if (lower.contains('dirigin') || lower.contains('prof')) {
      return 'Prof. Diriginte';
    }
    if (lower.contains('parinte')) return 'Părinte';
    return value;
  }

  void _goBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Sesiune invalida.')));
    }

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _InboxTopHeader(onBack: () => _goBack(context)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _loadingChildren
                    ? const Center(child: CircularProgressIndicator())
                    : _buildBody(uid),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(String uid) {
    final secretariatStreams = _buildSecretariatStreams(uid);

    return _buildMergedStream(secretariatStreams, (secretariatDocs) {
      final secretariatItems = _mapSecretariatItems(secretariatDocs)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (widget.role == UnifiedInboxRole.parent) {
        final decisionStreams = _buildParentDecisionStreams(uid);
        return _buildMergedStream(decisionStreams, (decisionDocs) {
          final decisionItems = _mapParentDecisionItems(decisionDocs);
          final allItems = <_UnifiedMessageItem>[
            ...decisionItems,
            ...secretariatItems,
          ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return _buildItemsList(allItems);
        });
      }

      if (widget.role != UnifiedInboxRole.student) {
        return _buildItemsList(secretariatItems);
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildStudentDecisionsStream(uid),
        builder: (context, leaveSnap) {
          if (leaveSnap.hasError) {
            return Center(child: Text('Eroare: ${leaveSnap.error}'));
          }

          final decisionDocs =
              leaveSnap.data?.docs ??
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reviewerUids = decisionDocs
              .map(
                (doc) => (doc.data()['reviewedByUid'] ?? '').toString().trim(),
              )
              .where((reviewerUid) => reviewerUid.isNotEmpty)
              .toSet();

          return FutureBuilder<Map<String, String>>(
            future: _loadUserLabels(reviewerUids),
            builder: (context, usersSnap) {
              final usernames = usersSnap.data ?? const <String, String>{};
              final decisionItems = _mapStudentDecisionItems(
                decisionDocs,
                usernames,
              );
              final allItems = <_UnifiedMessageItem>[
                ...decisionItems,
                ...secretariatItems,
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return _buildItemsList(allItems);
            },
          );
        },
      );
    });
  }

  List<_UnifiedMessageItem> _mapSecretariatItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final title = (data['title'] ?? 'Mesaj Secretariat').toString().trim();
      final sender = _normalizeSender(
        (data['senderName'] ?? 'Secretariat').toString(),
      );
      final message = (data['message'] ?? '').toString().trim();
      final createdAt =
          ((data['createdAt'] as Timestamp?)?.toDate() ??
              (data['reviewedAt'] as Timestamp?)?.toDate() ??
              (data['requestedAt'] as Timestamp?)?.toDate()) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return _UnifiedMessageItem(
        kind: _MessageKind.system,
        state: _MessageState.system,
        title: title,
        sender: sender,
        message: message,
        createdAt: createdAt,
      );
    }).toList();
  }

  List<_UnifiedMessageItem> _mapParentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final source = (data['source'] ?? '').toString().trim();
          final targetRole = (data['targetRole'] ?? '').toString().trim();
          return source != 'secretariat' &&
              targetRole == 'parent' &&
              (status == 'pending' ||
                  status == 'approved' ||
                  status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final studentUid = (data['studentUid'] ?? '').toString().trim();
          final studentName = (data['studentName'] ?? '').toString().trim();
          final resolvedStudentName = studentName.isNotEmpty
              ? studentName
              : (_childNames[studentUid] ?? 'Elev');

          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);

          final state = status == 'approved'
              ? _MessageState.approved
              : (status == 'rejected'
                    ? _MessageState.rejected
                    : _MessageState.pending);

          return _UnifiedMessageItem(
            kind: _MessageKind.decision,
            state: state,
            title: state == _MessageState.pending
                ? 'Cerere Nouă - $resolvedStudentName'
                : '${state == _MessageState.approved ? 'Cerere Aprobată' : 'Cerere Respinsă'} - $resolvedStudentName',
            sender: state == _MessageState.pending
                ? 'Necesită aprobarea părintelui'
                : _normalizeSender(
                    (data['reviewedByName'] ?? 'Părinte').toString(),
                  ),
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  List<_UnifiedMessageItem> _mapStudentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, String> usernamesByUid,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final source = (data['source'] ?? '').toString().trim();
          return source != 'secretariat' &&
              (status == 'approved' || status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString().trim();
          final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
          final sender =
              usernamesByUid[reviewedByUid] ??
              (data['reviewedByName'] ?? 'Diriginte').toString();
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final approved = status == 'approved';

          return _UnifiedMessageItem(
            kind: _MessageKind.decision,
            state: approved ? _MessageState.approved : _MessageState.rejected,
            title: approved ? 'Cerere Aprobată' : 'Cerere Respinsă',
            sender: _normalizeSender(sender),
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  Widget _buildItemsList(List<_UnifiedMessageItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Nu exista mesaje.',
          style: TextStyle(color: Color(0xFF7A8077), fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 2, bottom: 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return _MessageCard(
          item: items[index],
          timeAgoLabel: _timeAgo(items[index].createdAt),
          fallbackDate: _formatDate(items[index].createdAt),
        );
      },
    );
  }
}

class _InboxTopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _InboxTopHeader({required this.onBack});

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
        color: _kHeaderGreen,
        child: Stack(
          children: [
            Positioned(top: -72, right: -52, child: _circle(220, 0.08)),
            Positioned(top: 44, right: 34, child: _circle(72, 0.08)),
            Positioned(left: 156, bottom: -28, child: _circle(82, 0.08)),
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
                        'Mesaje',
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

class _MessageCard extends StatelessWidget {
  final _UnifiedMessageItem item;
  final String timeAgoLabel;
  final String fallbackDate;

  const _MessageCard({
    required this.item,
    required this.timeAgoLabel,
    required this.fallbackDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = _cardScheme(item.state);
    final isSystem = item.kind == _MessageKind.system;

    final titleParts = item.title.split(' - ');
    final mainTitle = titleParts.first;
    final nameSubtitle = titleParts.length > 1
        ? titleParts.skip(1).join(' - ')
        : null;

    // Compact date+time for leave requests
    String? metaText;
    if (!isSystem) {
      final datePart = item.dateLabel?.isNotEmpty == true
          ? item.dateLabel!
          : fallbackDate;
      final timePart = item.timeLabel?.isNotEmpty == true
          ? item.timeLabel
          : null;
      metaText = timePart != null ? '$datePart, $timePart' : datePart;
    }

    return Container(
      decoration: BoxDecoration(
        color: scheme.accent,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.only(left: 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, _kCardBg],
              ),
            ),
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
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
                            mainTitle,
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          if (nameSubtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              nameSubtitle,
                              style: const TextStyle(
                                color: _kTextMuted,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeAgoLabel,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _kTextMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (metaText != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    metaText,
                    style: const TextStyle(
                      color: _kTextMuted,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  item.message.isEmpty ? 'Fără conținut.' : item.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kTextMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                _StatusPill(
                  label: scheme.badgeLabel,
                  icon: scheme.badgeIcon,
                  bg: scheme.pillBg,
                  fg: scheme.pillFg,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color bg;
  final Color fg;

  const _StatusPill({
    required this.label,
    this.icon,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 15),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnifiedMessageItem {
  final _MessageKind kind;
  final _MessageState state;
  final String title;
  final String sender;
  final String message;
  final DateTime createdAt;
  final String? dateLabel;
  final String? timeLabel;

  const _UnifiedMessageItem({
    required this.kind,
    required this.state,
    required this.title,
    required this.sender,
    required this.message,
    required this.createdAt,
    this.dateLabel,
    this.timeLabel,
  });
}

class _CardScheme {
  final String badgeLabel;
  final IconData badgeIcon;
  final Color accent;
  final Color pillBg;
  final Color pillFg;

  const _CardScheme({
    required this.badgeLabel,
    required this.badgeIcon,
    required this.accent,
    required this.pillBg,
    required this.pillFg,
  });
}

_CardScheme _cardScheme(_MessageState state) {
  switch (state) {
    case _MessageState.pending:
      return const _CardScheme(
        badgeLabel: 'În așteptare',
        badgeIcon: Icons.watch_later_rounded,
        accent: Color(0xFF6E6E6E),
        pillBg: Color(0xFFF4F4F4),
        pillFg: Color(0xFF6D6D6D),
      );
    case _MessageState.approved:
      return const _CardScheme(
        badgeLabel: 'Aprobată',
        badgeIcon: Icons.check_circle_rounded,
        accent: Color(0xFF10762A),
        pillBg: Color(0xFFDCE9DC),
        pillFg: Color(0xFF0F6D25),
      );
    case _MessageState.rejected:
      return const _CardScheme(
        badgeLabel: 'Respinsă',
        badgeIcon: Icons.cancel_rounded,
        accent: Color(0xFF9D1F5F),
        pillBg: Color(0xFFF0E4EB),
        pillFg: Color(0xFF8E2356),
      );
    case _MessageState.system:
      return const _CardScheme(
        badgeLabel: 'Sistem',
        badgeIcon: Icons.campaign_rounded,
        accent: Color(0xFF1565C0),
        pillBg: Color(0xFFDCEEFB),
        pillFg: Color(0xFF0B57A4),
      );
  }
}
