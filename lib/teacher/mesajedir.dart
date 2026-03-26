import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firster/common/unified_messages_page.dart';
import '../session.dart';

class MesajeDirPage extends StatefulWidget {
  const MesajeDirPage({super.key});

  @override
  State<MesajeDirPage> createState() => _MesajeDirPageState();
}

// utilities copied from StudentInterface/inbox.dart for styling and data conversion

String _formatTimeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'acum';
  if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'acum ${diff.inHours} h';
  return '${diff.inDays} zile';
}

_InboxItemData _fromSecretariatMessage(Map<String, dynamic> d) {
  final createdAt = (d['createdAt'] as Timestamp?)?.toDate();
  final classId = (d['classId'] ?? '').toString().trim();
  final senderName = (d['senderName'] ?? 'Secretariat').toString().trim();
  final message = (d['message'] ?? '').toString();

  final classText = classId.isEmpty ? '' : 'Clasa $classId\n';
  final senderText = senderName.isEmpty ? '' : 'De la: $senderName\n';

  return _InboxItemData(
    title: 'Mesaj Secretariat',
    subtitle: '$classText$senderText$message',
    time: createdAt == null ? '-' : _formatTimeAgo(createdAt),
    type: _InboxItemType.info,
    createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

class _InboxItemData {
  final String title;
  final String subtitle;
  final String time;
  final _InboxItemType type;
  final DateTime createdAt;

  const _InboxItemData({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.type,
    required this.createdAt,
  });
}

enum _InboxItemType { success, error, info }

class _InboxMessageTile extends StatelessWidget {
  final _InboxItemData data;
  final VoidCallback onTap;

  const _InboxMessageTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor;
    final IconData leadingIcon;
    final Color iconContainerColor;
    final Color iconColor;

    switch (data.type) {
      case _InboxItemType.success:
        backgroundColor = const Color(0xFFE5F0DE);
        leadingIcon = Icons.check_rounded;
        iconContainerColor = const Color(0xFF5C9E49);
        iconColor = Colors.white;
        break;
      case _InboxItemType.error:
        backgroundColor = const Color(0xFFF5D5D5);
        leadingIcon = Icons.close_rounded;
        iconContainerColor = const Color(0xFFC54844);
        iconColor = Colors.white;
        break;
      case _InboxItemType.info:
        backgroundColor = const Color(0xFFF4F5F7);
        leadingIcon = Icons.send_rounded;
        iconContainerColor = const Color(0xFFD5DBE2);
        iconColor = const Color(0xFF7D8790);
        break;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD0D5D9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconContainerColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(leadingIcon, color: iconColor, size: 34),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            data.title,
                            style: const TextStyle(
                              fontSize: 17,
                              height: 1.0,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A2E33),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          data.time,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5E6670),
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF2F353B),
                        height: 1.06,
                        fontWeight: FontWeight.w500,
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

class _MesajeDirPageState extends State<MesajeDirPage> {
  @override
  Widget build(BuildContext context) {
    return const UnifiedMessagesPage(role: UnifiedInboxRole.teacher);
  }
}
