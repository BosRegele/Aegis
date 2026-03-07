import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class InboxScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const InboxScreen({super.key, this.onNavigateTab});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'acum';
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours} h';
    return '${diff.inDays} zile';
  }

  String _formatLeaveTitle(String status) {
    switch (status) {
      case 'approved':
        return 'Cerere aprobata';
      case 'rejected':
        return 'Cerere respinsa';
      default:
        return 'Cerere in asteptare';
    }
  }

  _InboxItemType _leaveType(String status) {
    switch (status) {
      case 'approved':
        return _InboxItemType.success;
      case 'rejected':
        return _InboxItemType.error;
      default:
        return _InboxItemType.info;
    }
  }

  _InboxItemData _fromLeaveRequest(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final status = (d['status'] ?? 'pending').toString();
    final requestedAt = (d['requestedAt'] as Timestamp?)?.toDate();
    final reviewedBy = (d['reviewedByName'] ?? '').toString();
    final reviewedSuffix = reviewedBy.isNotEmpty ? ' de $reviewedBy' : '';

    return _InboxItemData(
      title: _formatLeaveTitle(status),
      subtitle:
          '${(d['dateText'] ?? '-').toString()} ${((d['timeText'] ?? '-').toString())}\n${(d['message'] ?? '').toString()}$reviewedSuffix',
      time: requestedAt == null ? '-' : _formatTimeAgo(requestedAt),
      type: _leaveType(status),
      createdAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  _InboxItemData _fromAccessEvent(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final result = (d['result'] ?? 'deny').toString();
    final reason = (d['reason'] ?? '').toString();
    final scanType = (d['scanType'] ?? 'entry').toString();
    final scannedAt = (d['timestamp'] as Timestamp?)?.toDate();

    final isAllow = result == 'allow';
    final title = isAllow ? 'Acces permis' : 'Acces respins';
    final subtitle = scanType == 'entry'
        ? (isAllow
              ? 'Intrare confirmata la poarta'
              : 'Intrare respinsa${reason.isNotEmpty ? ' ($reason)' : ''}')
        : (isAllow
              ? 'Iesire confirmata la poarta'
              : 'Iesire respinsa${reason.isNotEmpty ? ' ($reason)' : ''}');

    return _InboxItemData(
      title: title,
      subtitle: subtitle,
      time: scannedAt == null ? '-' : _formatTimeAgo(scannedAt),
      type: isAllow ? _InboxItemType.success : _InboxItemType.error,
      createdAt: scannedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  void _goBack(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(0);
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MeniuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 6, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _goBack(context),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Inbox',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE9EDF0),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: _buildInboxList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxList() {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      return const Center(child: Text('Sesiune invalida.'));
    }

    final leaveRequestsStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: uid)
        .snapshots();

    final accessEventsStream = FirebaseFirestore.instance
        .collection('accessEvents')
        .where('userId', isEqualTo: uid)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: leaveRequestsStream,
      builder: (context, leaveSnap) {
        if (leaveSnap.hasError) {
          return Center(child: Text('Eroare cereri: ${leaveSnap.error}'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: accessEventsStream,
          builder: (context, accessSnap) {
            if (accessSnap.hasError) {
              return Center(
                child: Text('Eroare notificari acces: ${accessSnap.error}'),
              );
            }

            if (!leaveSnap.hasData || !accessSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final leaveItems = leaveSnap.data!.docs
                .map(_fromLeaveRequest)
                .toList();
            final accessItems = accessSnap.data!.docs
                .map(_fromAccessEvent)
                .toList();

            final all = <_InboxItemData>[...leaveItems, ...accessItems]
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (all.isEmpty) {
              return const Center(child: Text('Nu ai notificari momentan.'));
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              itemBuilder: (context, index) {
                final message = all[index];
                return _InboxMessageTile(data: message, onTap: () {});
              },
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemCount: all.length,
            );
          },
        );
      },
    );
  }
}

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
                              fontSize: 31,
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
                            fontSize: 27,
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
                        fontSize: 31,
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
