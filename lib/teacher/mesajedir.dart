import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D631B);
const _kPageBg = Color(0xFFF7F9F0);
const _kCardBg = Color(0xFFF8F8F8);

class MesajeDirPage extends StatefulWidget {
  const MesajeDirPage({super.key});

  @override
  State<MesajeDirPage> createState() => _MesajeDirPageState();
}

// utilities copied from StudentInterface/inbox.dart for styling and data conversion

String _formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'ACUM';
  if (diff.inMinutes < 60) return 'ACUM ${diff.inMinutes} MIN';
  if (diff.inHours < 24) return 'ACUM ${diff.inHours} ORE';
  if (diff.inDays == 1) return 'IERI';
  return 'ACUM ${diff.inDays} ZILE';
}

_MessageCardData _fromLeaveRequest(Map<String, dynamic> d) {
  final status = (d['status'] ?? 'pending').toString();
  final studentName = (d['studentName'] ?? '').toString().trim();
  final requestedAt = (d['requestedAt'] as Timestamp?)?.toDate();
  final dateText = (d['dateText'] ?? '').toString();
  final timeText = (d['timeText'] ?? '').toString();
  final message = (d['message'] ?? '').toString();

  String title = 'Mesaj';
  String statusLabel = 'SISTEM';
  _MessageItemType type = _MessageItemType.system;
  String sourceLabel = 'Secretariat';

  switch (status) {
    case 'approved':
      title = 'Cerere Aprobată - ${studentName.isEmpty ? 'Elev' : studentName}';
      statusLabel = 'APROBATĂ';
      type = _MessageItemType.success;
      // show same footer as rejected in messages view
      sourceLabel = 'Prof. Diriginte';
      break;
    case 'rejected':
      title = 'Cerere Respinsă - ${studentName.isEmpty ? 'Elev' : studentName}';
      statusLabel = 'RESPINSĂ';
      type = _MessageItemType.error;
      sourceLabel = 'Prof. Diriginte';
      break;
    default:
      title =
          'Cerere în așteptare - ${studentName.isEmpty ? 'Elev' : studentName}';
      statusLabel = 'ÎN AȘTEPTARE';
      // pending requests: detailed layout but neutral/gray styling and no footer
      type = _MessageItemType.pending;
      sourceLabel = '';
  }

  return _MessageCardData(
    statusLabel: statusLabel,
    title: title,
    dateText: dateText,
    timeText: timeText,
    message: message,
    relativeTime: requestedAt == null ? '-' : _formatTimeAgo(requestedAt),
    sourceLabel: sourceLabel,
    type: type,
    createdAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class _MessageCardData {
  final String statusLabel;
  final String title;
  final String dateText;
  final String timeText;
  final String message;
  final String relativeTime;
  final String sourceLabel;
  final _MessageItemType type;
  final DateTime createdAt;

  const _MessageCardData({
    required this.statusLabel,
    required this.title,
    required this.dateText,
    required this.timeText,
    required this.message,
    required this.relativeTime,
    required this.sourceLabel,
    required this.type,
    required this.createdAt,
  });
}

enum _MessageItemType { success, error, system, pending }

class _MessageCard extends StatelessWidget {
  final _MessageCardData data;
  final VoidCallback? onTap;

  const _MessageCard({required this.data, this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isSystem = data.type == _MessageItemType.system;
    final Color accentColor;
    final Color tagBg;
    final Color tagText;
    final IconData sourceIcon;

    switch (data.type) {
      case _MessageItemType.success:
        accentColor = const Color(0xFF10762A);
        tagBg = const Color(0xFFDCE9DC);
        tagText = const Color(0xFF0F6D25);
        sourceIcon = Icons.check_circle_rounded;
        break;
      case _MessageItemType.error:
        accentColor = const Color(0xFF9D1F5F);
        tagBg = const Color(0xFFF0E4EB);
        tagText = const Color(0xFF8E2356);
        sourceIcon = Icons.cancel_rounded;
        break;
      case _MessageItemType.system:
        accentColor = const Color(0xFF1565C0);
        tagBg = const Color(0xFFDCEEFB);
        tagText = const Color(0xFF0B57A4);
        sourceIcon = Icons.info_rounded;
        break;
      case _MessageItemType.pending:
        accentColor = const Color(0xFF6E6E6E);
        tagBg = const Color(0xFFF4F4F4);
        tagText = const Color(0xFF6D6D6D);
        sourceIcon = Icons.hourglass_top_rounded;
        break;
    }

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
              color: accentColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(24),
              ),
            ),
          ),
          Expanded(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              data.statusLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                color: tagText,
                                height: 1,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            data.relativeTime,
                            style: const TextStyle(
                              color: Color(0xFF616962),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        data.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF121512),
                          height: 1.15,
                        ),
                      ),
                      if (!isSystem) ...[
                        const SizedBox(height: 14),
                        _MessageInfoLine(
                          icon: Icons.calendar_today_rounded,
                          text: data.dateText.isEmpty ? '-' : data.dateText,
                          iconColor: accentColor,
                        ),
                        const SizedBox(height: 12),
                        _MessageInfoLine(
                          icon: Icons.access_time_filled_rounded,
                          text: data.timeText.isEmpty ? '-' : data.timeText,
                          iconColor: accentColor,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: tagBg,
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
                                  color: accentColor,
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
                                      data.message.isEmpty
                                          ? '-'
                                          : '"${data.message}"',
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
                          data.message,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF283028),
                            height: 1.55,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (data.sourceLabel.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        const Divider(color: Color(0xFFDFE3DC), height: 1),
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
                                sourceIcon,
                                size: 28,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                data.sourceLabel,
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
                        Container(
                          width: double.infinity,
                          height: 1,
                          color: const Color(0xFFDFE3DC),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _MessageInfoLine({
    required this.icon,
    required this.text,
    required this.iconColor,
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
                        'Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.',
                      ),
                    );
                  }

                  final stream = FirebaseFirestore.instance
                      .collection('leaveRequests')
                      .where('classId', isEqualTo: classId)
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: stream,
                    builder: (context, reqSnap) {
                      if (reqSnap.hasError) {
                        return Center(child: Text('Eroare: ${reqSnap.error}'));
                      }
                      if (!reqSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = reqSnap.data!.docs;

                      final items =
                          docs
                              .map(
                                (doc) => _fromLeaveRequest(
                                  doc.data() as Map<String, dynamic>,
                                ),
                              )
                              .toList()
                            ..sort(
                              (a, b) => b.createdAt.compareTo(a.createdAt),
                            );

                      items.add(
                        _MessageCardData(
                          statusLabel: 'SISTEM',
                          title: 'Update Vacanță',
                          dateText: '',
                          timeText: '',
                          message:
                              'Vă informăm că perioada vacanței de iarnă a fost modificată pentru a include zilele de 22 și 23 decembrie. Programul actualizat este disponibil în secțiunea Vacanțe.',
                          relativeTime: 'IERI',
                          sourceLabel: 'Secretariat',
                          type: _MessageItemType.system,
                          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
                        ),
                      );

                      return Stack(
                        children: [
                          ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                            itemBuilder: (context, index) {
                              final message = items[index];
                              return _MessageCard(data: message, onTap: null);
                            },
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 14),
                            itemCount: items.length,
                          ),
                        ],
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
