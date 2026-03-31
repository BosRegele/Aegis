import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _heroGreen = Color(0xFF0C6A1D);
const _surface = Color(0xFFF7F9EE);
const _surfaceTint = Color(0xFFEFF4E3);
const _cardColor = Color(0xFFFFFFFF);
const _textPrimary = Color(0xFF111712);
const _textSecondary = Color(0xFF657063);
const _dividerColor = Color(0xFFE5EBDD);

enum UnifiedInboxRole { student, parent, teacher }

enum _InboxItemKind { announcement, decision }

enum _InboxDecisionState { approved, rejected, system }

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
      final rawChildren = parentData['children'];
      final children = rawChildren is List
          ? List<String>.from(rawChildren)
              .where((childUid) => childUid.trim().isNotEmpty)
              .toList()
          : <String>[];
      final childNames = await _loadUsernames(children.toSet());

      if (mounted) {
        setState(() {
          _loadingChildren = false;
          _childrenUids = children;
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

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildParentDecisionStreams() {
    return _childrenUids
        .map(
          (childUid) => FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('studentUid', isEqualTo: childUid)
              .where('status', whereIn: ['approved', 'rejected'])
              .orderBy('reviewedAt', descending: true)
              .limit(30)
              .snapshots(),
        )
        .toList();
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
            return Center(child: Text('Eroare: ${snap.error}'));
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
        .limit(50)
        .snapshots();
  }

  Future<Map<String, String>> _loadUsernames(Set<String> uids) async {
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
    if (diff.inDays < 7) return '${diff.inDays} ZILE';
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

  String _audienceFallback() {
    switch (widget.role) {
      case UnifiedInboxRole.student:
        return 'Elevi';
      case UnifiedInboxRole.parent:
        return 'Părinți';
      case UnifiedInboxRole.teacher:
        return 'Diriginți';
    }
  }

  String _normalizeSenderLabel(String sender) {
    final normalized = sender.trim();
    if (normalized.isEmpty) return 'Secretariat';
    final lower = normalized.toLowerCase();
    if (lower.contains('secretariat')) return 'Secretariat';
    if (lower.contains('parinte')) return 'Părinte';
    if (lower.contains('dirigin') || lower.contains('prof')) {
      return 'Prof. Diriginte';
    }
    return normalized;
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
      return const Scaffold(body: Center(child: Text('Sesiune invalidă.')));
    }

    return Scaffold(
      backgroundColor: _surface,
      body: Column(
        children: [
          _InboxHeroHeader(onBack: () => _goBack(context)),
          Expanded(
            child: Transform.translate(
              offset: const Offset(0, 10),
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(34),
                    topRight: Radius.circular(34),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x190C6A1D),
                      blurRadius: 26,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 34, 16, 0),
                  child: _loadingChildren
                      ? const Center(child: CircularProgressIndicator())
                      : _buildBody(uid),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(String uid) {
    final streams = _buildSecretariatStreams(uid);
    return _buildMergedStream(streams, (secretariatDocs) {
      final secretariatItems = _mapSecretariatItems(secretariatDocs)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (widget.role == UnifiedInboxRole.parent) {
        return _buildMergedStream(_buildParentDecisionStreams(), (decisionDocs) {
          final decisionItems = _mapParentDecisionItems(decisionDocs);
          final allItems = <_UnifiedMessageItem>[
            ...secretariatItems,
            ...decisionItems,
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
            future: _loadUsernames(reviewerUids),
            builder: (context, usersSnap) {
              final usernames = usersSnap.data ?? const <String, String>{};
              final decisionItems = _mapStudentDecisionItems(
                decisionDocs,
                usernames,
              );
              final allItems = <_UnifiedMessageItem>[
                ...secretariatItems,
                ...decisionItems,
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
      final sender = _normalizeSenderLabel(
        (data['senderName'] ?? 'Secretariat').toString(),
      );
      final message = (data['message'] ?? '').toString().trim();
      final classId = (data['classId'] ?? '').toString().trim();
      final studentName = (data['studentName'] ?? '').toString().trim();
      final audienceLabel = (data['audienceLabel'] ?? '').toString().trim();
      final createdAt =
          ((data['createdAt'] as Timestamp?)?.toDate() ??
              (data['reviewedAt'] as Timestamp?)?.toDate() ??
              (data['requestedAt'] as Timestamp?)?.toDate()) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final targetLine = audienceLabel.isNotEmpty
          ? audienceLabel
          : (studentName.isNotEmpty
                ? 'Elev: $studentName${classId.isEmpty ? '' : ' ($classId)'}'
                : (classId.isNotEmpty ? 'Clasa $classId' : _audienceFallback()));

      return _UnifiedMessageItem(
        kind: _InboxItemKind.announcement,
        state: _InboxDecisionState.system,
        title: title,
        message: message,
        createdAt: createdAt,
        sender: sender,
        subtitle: targetLine,
      );
    }).toList();
  }

  List<_UnifiedMessageItem> _mapStudentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, String> usernamesByUid,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final source = (data['source'] ?? '').toString();
          return source != 'secretariat' &&
              (status == 'approved' || status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
          final sender = usernamesByUid[reviewedByUid] ??
              (data['reviewedByName'] ?? 'Diriginte').toString();
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ?? requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final approved = status == 'approved';

          return _UnifiedMessageItem(
            kind: _InboxItemKind.decision,
            state: approved
                ? _InboxDecisionState.approved
                : _InboxDecisionState.rejected,
            title: approved ? 'Cerere Aprobată' : 'Cerere Respinsă',
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            sender: _normalizeSenderLabel(sender),
            dateLabel: (data['dateText'] ?? '').toString().trim(),
            timeLabel: (data['timeText'] ?? '').toString().trim(),
          );
        })
        .toList();
  }

  List<_UnifiedMessageItem> _mapParentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final source = (data['source'] ?? '').toString();
          return source != 'secretariat' &&
              (status == 'approved' || status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final studentUid = (data['studentUid'] ?? '').toString().trim();
          final studentName = (data['studentName'] ?? '').toString().trim();
          final sender = _normalizeSenderLabel(
            (data['reviewedByName'] ?? 'Diriginte').toString(),
          );
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ?? requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final approved = status == 'approved';
          final resolvedStudentName = studentName.isNotEmpty
              ? studentName
              : (_childNames[studentUid] ?? 'Elev');

          return _UnifiedMessageItem(
            kind: _InboxItemKind.decision,
            state: approved
                ? _InboxDecisionState.approved
                : _InboxDecisionState.rejected,
            title:
                '${approved ? 'Cerere Aprobată' : 'Cerere Respinsă'} - $resolvedStudentName',
            message: (data['message'] ?? '').toString().trim(),
            createdAt: when,
            sender: sender,
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
          'Nu există mesaje.',
          style: TextStyle(
            color: _textSecondary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 30, bottom: 28),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _InboxCard(
        item: items[index],
        timeAgoLabel: _timeAgo(items[index].createdAt),
        fallbackDate: _formatDate(items[index].createdAt),
      ),
    );
  }
}

class _InboxHeroHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _InboxHeroHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(46),
        bottomRight: Radius.circular(46),
      ),
      child: Container(
        height: topPadding + 148,
        color: _heroGreen,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -46,
              top: -34,
              child: _HeroBubble(size: 122, opacity: 0.12),
            ),
            Positioned(
              left: 182,
              top: 104,
              child: _HeroBubble(size: 78, opacity: 0.11),
            ),
            Positioned(
              right: 24,
              top: 40 + topPadding,
              child: _HeroBubble(size: 66, opacity: 0.14),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, topPadding + 38, 22, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 34,
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
}

class _HeroBubble extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeroBubble({required this.size, required this.opacity});

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

class _InboxCard extends StatelessWidget {
  final _UnifiedMessageItem item;
  final String timeAgoLabel;
  final String fallbackDate;

  const _InboxCard({
    required this.item,
    required this.timeAgoLabel,
    required this.fallbackDate,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = _cardScheme(item.state);

    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border(left: BorderSide(color: scheme.accent, width: 4)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A0C6A1D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StatusPill(
                  label: scheme.label,
                  background: scheme.pillBg,
                  foreground: scheme.pillFg,
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    timeAgoLabel,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.title,
              style: const TextStyle(
                color: _textPrimary,
                fontSize: 20,
                height: 1.18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (item.kind == _InboxItemKind.decision) ...[
              const SizedBox(height: 18),
              _MetaRow(
                icon: Icons.calendar_today_rounded,
                iconColor: scheme.accent,
                text: item.dateLabel?.isNotEmpty == true
                    ? item.dateLabel!
                    : fallbackDate,
              ),
              const SizedBox(height: 16),
              _MetaRow(
                icon: Icons.access_time_filled_rounded,
                iconColor: scheme.accent,
                text: item.timeLabel?.isNotEmpty == true ? item.timeLabel! : '-',
              ),
              const SizedBox(height: 18),
              _ReasonCard(
                accent: scheme.accent,
                text: item.message.isNotEmpty ? item.message : 'Fără detalii.',
              ),
            ] else ...[
              const SizedBox(height: 12),
              if (item.subtitle?.isNotEmpty == true) ...[
                Text(
                  item.subtitle!,
                  style: const TextStyle(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Text(
                item.message.isNotEmpty ? item.message : 'Fără conținut.',
                style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: _dividerColor),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.iconBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(scheme.footerIcon, color: scheme.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.sender,
                    style: const TextStyle(
                      color: _textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
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

class _StatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _StatusPill({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _MetaRow({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 28, color: iconColor),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReasonCard extends StatelessWidget {
  final Color accent;
  final String text;

  const _ReasonCard({required this.accent, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: _surfaceTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.description_rounded, color: accent, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MOTIV SOLICITARE',
                  style: TextStyle(
                    color: _textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '"$text"',
                  style: const TextStyle(
                    color: _textPrimary,
                    fontSize: 17,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
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

class _UnifiedMessageItem {
  final _InboxItemKind kind;
  final _InboxDecisionState state;
  final String title;
  final String message;
  final DateTime createdAt;
  final String sender;
  final String? dateLabel;
  final String? timeLabel;
  final String? subtitle;

  const _UnifiedMessageItem({
    required this.kind,
    required this.state,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.sender,
    this.dateLabel,
    this.timeLabel,
    this.subtitle,
  });
}

class _CardScheme {
  final String label;
  final Color accent;
  final Color pillBg;
  final Color pillFg;
  final Color iconBg;
  final IconData footerIcon;

  const _CardScheme({
    required this.label,
    required this.accent,
    required this.pillBg,
    required this.pillFg,
    required this.iconBg,
    required this.footerIcon,
  });
}

_CardScheme _cardScheme(_InboxDecisionState state) {
  switch (state) {
    case _InboxDecisionState.approved:
      return const _CardScheme(
        label: 'APROBATĂ',
        accent: Color(0xFF0E7A2D),
        pillBg: Color(0xFFE7F0E4),
        pillFg: Color(0xFF0E6A1F),
        iconBg: Color(0xFFE7F0E4),
        footerIcon: Icons.check_circle_rounded,
      );
    case _InboxDecisionState.rejected:
      return const _CardScheme(
        label: 'RESPINSĂ',
        accent: Color(0xFFAF2C68),
        pillBg: Color(0xFFF6E7EE),
        pillFg: Color(0xFFAF2C68),
        iconBg: Color(0xFFE7EDE1),
        footerIcon: Icons.cancel_rounded,
      );
    case _InboxDecisionState.system:
      return const _CardScheme(
        label: 'SISTEM',
        accent: Color(0xFF7E8B7A),
        pillBg: Color(0xFFE5EBDD),
        pillFg: Color(0xFF495445),
        iconBg: Color(0xFFE5EBDD),
        footerIcon: Icons.info_rounded,
      );
  }
}
