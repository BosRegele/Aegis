import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);
const _kCardBg = Color(0xFFF8F8F8);
const _kTextPrimary = Color(0xFF121512);
const _kTextMuted = Color(0xFF616962);
const _kDivider = Color(0xFFDFE3DC);
const _kMetaBoxBg = Color(0xFFDCE9DC);

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
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'ACUM';
    if (diff.inMinutes < 60) return 'ACUM ${diff.inMinutes} MIN';
    if (diff.inHours < 24) return 'ACUM ${diff.inHours} ORE';
    if (diff.inDays == 1) return 'IERI';
    if (diff.inDays < 7) return 'ACUM ${diff.inDays} ZILE';
    return _formatDate(dateTime).toUpperCase();
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
              leaveSnap.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reviewerUids = decisionDocs
              .map((doc) => (doc.data()['reviewedByUid'] ?? '').toString().trim())
              .where((reviewerUid) => reviewerUid.isNotEmpty)
              .toSet();

          return FutureBuilder<Map<String, String>>(
            future: _loadUserLabels(reviewerUids),
            builder: (context, usersSnap) {
              final usernames = usersSnap.data ?? const <String, String>{};
              final decisionItems = _mapStudentDecisionItems(decisionDocs, usernames);
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
          return source != 'secretariat' &&
              (status == 'pending' || status == 'approved' || status == 'rejected');
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
          final when = reviewedAt ?? requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

          final state = status == 'approved'
              ? _MessageState.approved
              : (status == 'rejected' ? _MessageState.rejected : _MessageState.pending);

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
          final sender = usernamesByUid[reviewedByUid] ??
              (data['reviewedByName'] ?? 'Diriginte').toString();
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when = reviewedAt ?? requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
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
      separatorBuilder: (_, __) => const SizedBox(height: 14),
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
                    'Mesaje',
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
    final showFooter = !isSystem && item.state != _MessageState.pending;

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E7DD)),
      ),
      child: Row(
        children: [
          Container(
            width: 6,
            decoration: BoxDecoration(
              color: scheme.accent,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StatusPill(
                        label: scheme.badgeLabel,
                        bg: scheme.pillBg,
                        fg: scheme.pillFg,
                      ),
                      const Spacer(),
                      Text(
                        timeAgoLabel,
                        style: const TextStyle(
                          color: _kTextMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: _kTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (!isSystem) ...[
                    const SizedBox(height: 14),
                    _MetaLine(
                      icon: Icons.calendar_today_rounded,
                      iconColor: scheme.accent,
                      text:
                          item.dateLabel?.isNotEmpty == true ? item.dateLabel! : fallbackDate,
                    ),
                    const SizedBox(height: 12),
                    _MetaLine(
                      icon: Icons.access_time_filled_rounded,
                      iconColor: scheme.accent,
                      text: item.timeLabel?.isNotEmpty == true ? item.timeLabel! : '-',
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: scheme.pillBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.description_rounded,
                              size: 28,
                              color: scheme.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'MOTIV SOLICITARE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2F3730),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.message.isEmpty ? '-' : '"${item.message}"',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontStyle: FontStyle.italic,
                                    color: Color(0xFF1A221A),
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Text(
                      item.message.isEmpty ? 'Fără conținut.' : item.message,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF283028),
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (showFooter) ...[
                    const SizedBox(height: 14),
                    const Divider(color: _kDivider, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCE3D8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            scheme.footerIcon,
                            size: 28,
                            color: scheme.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.sender,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF646D63),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      height: 1,
                      color: _kDivider,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _StatusPill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _MetaLine({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 30, color: iconColor),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            fontSize: 17,
            color: Color(0xFF313831),
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ],
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
  final Color accent;
  final Color pillBg;
  final Color pillFg;
  final IconData footerIcon;

  const _CardScheme({
    required this.badgeLabel,
    required this.accent,
    required this.pillBg,
    required this.pillFg,
    required this.footerIcon,
  });
}

_CardScheme _cardScheme(_MessageState state) {
  switch (state) {
    case _MessageState.pending:
      return const _CardScheme(
        badgeLabel: 'ÎN AȘTEPTARE',
        accent: Color(0xFF6E6E6E),
        pillBg: Color(0xFFF4F4F4),
        pillFg: Color(0xFF6D6D6D),
        footerIcon: Icons.hourglass_top_rounded,
      );
    case _MessageState.approved:
      return const _CardScheme(
        badgeLabel: 'APROBATĂ',
        accent: Color(0xFF10762A),
        pillBg: Color(0xFFDCE9DC),
        pillFg: Color(0xFF0F6D25),
        footerIcon: Icons.check_circle_rounded,
      );
    case _MessageState.rejected:
      return const _CardScheme(
        badgeLabel: 'RESPINSĂ',
        accent: Color(0xFF9D1F5F),
        pillBg: Color(0xFFF0E4EB),
        pillFg: Color(0xFF8E2356),
        footerIcon: Icons.cancel_rounded,
      );
    case _MessageState.system:
      return const _CardScheme(
        badgeLabel: 'SISTEM',
        accent: Color(0xFF1565C0),
        pillBg: Color(0xFFDCEEFB),
        pillFg: Color(0xFF0B57A4),
        footerIcon: Icons.info_rounded,
      );
  }
}
