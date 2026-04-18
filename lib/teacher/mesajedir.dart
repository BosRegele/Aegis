import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);
const _kCardBg = Color(0xFFF8F8F8);
const _kTextPrimary = Color(0xFF121512);
const _kTextMuted = Color(0xFF616962);

enum _MsgState { pending, approved, rejected, system }

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

_CardScheme _cardScheme(_MsgState state) {
  switch (state) {
    case _MsgState.pending:
      return const _CardScheme(
        badgeLabel: 'În așteptare',
        badgeIcon: Icons.watch_later_rounded,
        accent: Color(0xFF6E6E6E),
        pillBg: Color(0xFFF4F4F4),
        pillFg: Color(0xFF6D6D6D),
      );
    case _MsgState.approved:
      return const _CardScheme(
        badgeLabel: 'Aprobată',
        badgeIcon: Icons.check_circle_rounded,
        accent: Color(0xFF10762A),
        pillBg: Color(0xFFDCE9DC),
        pillFg: Color(0xFF0F6D25),
      );
    case _MsgState.rejected:
      return const _CardScheme(
        badgeLabel: 'Respinsă',
        badgeIcon: Icons.cancel_rounded,
        accent: Color(0xFF9D1F5F),
        pillBg: Color(0xFFF0E4EB),
        pillFg: Color(0xFF8E2356),
      );
    case _MsgState.system:
      return const _CardScheme(
        badgeLabel: 'Sistem',
        badgeIcon: Icons.campaign_rounded,
        accent: Color(0xFF1565C0),
        pillBg: Color(0xFFDCEEFB),
        pillFg: Color(0xFF0B57A4),
      );
  }
}

class _MessageItem {
  final _MsgState state;
  final String title;
  final String? subtitle;
  final String message;
  final String? metaText;
  final DateTime createdAt;

  const _MessageItem({
    required this.state,
    required this.title,
    this.subtitle,
    required this.message,
    this.metaText,
    required this.createdAt,
  });
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
  final d = dateTime.day.toString().padLeft(2, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  return '$d/$m/${dateTime.year}';
}

_MessageItem _fromSecretariatMessage(Map<String, dynamic> d) {
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final message = (d['message'] ?? '').toString().trim();
  final senderName = (d['senderName'] ?? '').toString().trim();
  final title = (d['title'] ?? '').toString().trim();
  return _MessageItem(
    state: _MsgState.system,
    title: title.isEmpty ? 'Mesaj Secretariat' : title,
    subtitle: senderName.isEmpty ? 'Secretariat' : senderName,
    message: message,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

_MessageItem _fromLeaveRequest(Map<String, dynamic> d) {
  final status = (d['status'] ?? 'pending').toString();
  final studentName = (d['studentName'] ?? '').toString().trim();
  final requestedAt = (d['requestedAt'] as Timestamp?)?.toDate();
  final dateText = (d['dateText'] ?? '').toString();
  final timeText = (d['timeText'] ?? '').toString();
  final message = (d['message'] ?? '').toString();

  _MsgState state;
  String title;
  switch (status) {
    case 'approved':
      state = _MsgState.approved;
      title = 'Cerere Aprobată';
      break;
    case 'rejected':
      state = _MsgState.rejected;
      title = 'Cerere Respinsă';
      break;
    default:
      state = _MsgState.pending;
      title = 'Cerere în așteptare';
  }

  final name = studentName.isEmpty ? 'Elev' : studentName;
  String? meta;
  if (dateText.isNotEmpty || timeText.isNotEmpty) {
    final parts = <String>[];
    if (dateText.isNotEmpty) parts.add(dateText);
    if (timeText.isNotEmpty) parts.add(timeText);
    meta = parts.join(', ');
  }

  return _MessageItem(
    state: state,
    title: title,
    subtitle: name,
    message: message,
    metaText: meta,
    createdAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

// ──────────────────────────────────────────────────────────────────────────────

class MesajeDirPage extends StatefulWidget {
  const MesajeDirPage({super.key});

  @override
  State<MesajeDirPage> createState() => _MesajeDirPageState();
}

class _MessageCard extends StatelessWidget {
  final _MessageItem item;

  const _MessageCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = _cardScheme(item.state);
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
                            item.title,
                            style: const TextStyle(
                              color: _kTextPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                          ),
                          if (item.subtitle != null &&
                              item.subtitle!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.subtitle!,
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
                      _timeAgo(item.createdAt),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _kTextMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (item.metaText != null && item.metaText!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.metaText!,
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

class _MesajeDirPageState extends State<MesajeDirPage> {
  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              title: 'Mesaje',
              onBack: () => Navigator.of(context).maybePop(),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: teacherDoc.get(),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(child: Text('Eroare: ${snap.error}'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.data!.exists) {
                    return const Center(child: Text('Teacher not found'));
                  }

                  final data = snap.data!.data() as Map<String, dynamic>;
                  final classId = (data['classId'] ?? '').toString().trim();
                  if (classId.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nu ai clasa asignată.\nCere secretariatului să-ți seteze classId.',
                      ),
                    );
                  }

                  final messages = FirebaseFirestore.instance.collection(
                    'secretariatMessages',
                  );
                  final leaveStream = FirebaseFirestore.instance
                      .collection('leaveRequests')
                      .where('classId', isEqualTo: classId)
                      .snapshots();
                  final secretariatTargetedStream = messages
                      .where('recipientRole', isEqualTo: 'teacher')
                      .where('recipientUid', isEqualTo: teacherUid)
                      .snapshots();
                  final secretariatGlobalStream = messages
                      .where('recipientRole', isEqualTo: 'teacher')
                      .where('recipientUid', isEqualTo: '')
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: leaveStream,
                    builder: (context, reqSnap) {
                      if (reqSnap.hasError) {
                        return Center(child: Text('Eroare: ${reqSnap.error}'));
                      }
                      if (!reqSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: secretariatTargetedStream,
                        builder: (context, targetedSnap) {
                          if (targetedSnap.hasError) {
                            return Center(
                              child: Text('Eroare: ${targetedSnap.error}'),
                            );
                          }
                          return StreamBuilder<QuerySnapshot>(
                            stream: secretariatGlobalStream,
                            builder: (context, globalSnap) {
                              if (globalSnap.hasError) {
                                return Center(
                                  child: Text('Eroare: ${globalSnap.error}'),
                                );
                              }

                              final leaveItems = reqSnap.data!.docs.map(
                                (doc) => _fromLeaveRequest(
                                  doc.data() as Map<String, dynamic>,
                                ),
                              );

                              final secretariatDocs =
                                  <QueryDocumentSnapshot>[
                                    ...(targetedSnap.data?.docs ??
                                        const <QueryDocumentSnapshot>[]),
                                    ...(globalSnap.data?.docs ??
                                        const <QueryDocumentSnapshot>[]),
                                  ].fold<
                                    Map<String, QueryDocumentSnapshot>
                                  >({}, (acc, doc) {
                                    acc[doc.id] = doc;
                                    return acc;
                                  });
                              final secretariatItems = secretariatDocs.values
                                  .map(
                                    (doc) => _fromSecretariatMessage(
                                      doc.data() as Map<String, dynamic>,
                                    ),
                                  );

                              final items =
                                  <_MessageItem>[
                                    ...leaveItems,
                                    ...secretariatItems,
                                  ]..sort(
                                    (a, b) =>
                                        b.createdAt.compareTo(a.createdAt),
                                  );

                              if (items.isEmpty) {
                                return const Center(
                                  child: Text(
                                    'Niciun mesaj.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: _kTextMuted,
                                    ),
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  22,
                                ),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  return _MessageCard(item: items[index]);
                                },
                              );
                            },
                          );
                        },
                      );
                    },
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

class _TopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;

  const _TopHeader({required this.title, required this.onBack});

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
            Positioned(top: -72, right: -52, child: _decorCircle(220)),
            Positioned(top: 44, right: 34, child: _decorCircle(72)),
            Positioned(left: 156, bottom: -28, child: _decorCircle(82)),
            Padding(
              padding: EdgeInsets.zero,
              child: Center(
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
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}
