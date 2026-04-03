import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);
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
      sourceLabel = 'Părinte';
      break;
    case 'rejected':
      title = 'Cerere Respinsă - ${studentName.isEmpty ? 'Elev' : studentName}';
      statusLabel = 'RESPINSĂ';
      type = _MessageItemType.error;
      sourceLabel = 'Prof. Diriginte';
      break;
    default:
      title =
          'Cerere in asteptare - ${studentName.isEmpty ? 'Elev' : studentName}';
      statusLabel = 'SISTEM';
      type = _MessageItemType.system;
      sourceLabel = 'Secretariat';
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

enum _MessageItemType { success, error, system }

class _MessageCard extends StatelessWidget {
  final _MessageCardData data;
  final VoidCallback onTap;

  const _MessageCard({required this.data, required this.onTap});

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
        accentColor = const Color(0xFF7C8679);
        tagBg = const Color(0xFFE1E6DB);
        tagText = const Color(0xFF3E473F);
        sourceIcon = Icons.info_rounded;
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
                        ),
                        const SizedBox(height: 12),
                        _MessageInfoLine(
                          icon: Icons.access_time_filled_rounded,
                          text: data.timeText.isEmpty ? '-' : data.timeText,
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4EA),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.description_rounded,
                                  size: 28,
                                  color: Color(0xFF0D6F1C),
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

  const _MessageInfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF0D6F1C)),
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
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(painter: _TopDotsPainter()),
                            ),
                          ),
                          ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                            itemBuilder: (context, index) {
                              final message = items[index];
                              return _MessageCard(data: message, onTap: () {});
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
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
      child: SizedBox(
        width: double.infinity,
        height: 164,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: _kHeaderGreen),
            CustomPaint(painter: _HeaderDotsPainter()),
            Positioned(right: 74, top: -44, child: _decorCircle(126)),
            Positioned(left: 178, bottom: -36, child: _decorCircle(82)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 22, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1,
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

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.14);
    const spacing = 18.0;
    for (double y = 14; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TopDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC8D8C4);
    const spacing = 32.0;
    for (double y = 12; y < 82; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2.1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
