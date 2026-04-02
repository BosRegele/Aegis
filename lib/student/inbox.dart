import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/student/meniu.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0D631B);
const _surface = Color(0xFFECEFE6);
const _card = Color(0xFFF7F8F3);
const _textDark = Color(0xFF131A14);
const _textMuted = Color(0xFF6F7669);

class InboxScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const InboxScreen({super.key, this.onNavigateTab});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _secretariatStream;

  @override
  void initState() {
    super.initState();
    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      _leaveStream = FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('studentUid', isEqualTo: uid)
          .orderBy('requestedAt', descending: true)
          .limit(50)
          .snapshots();

      _secretariatStream = FirebaseFirestore.instance
          .collection('secretariatMessages')
          .where('recipientUid', isEqualTo: uid)
          .where('recipientRole', isEqualTo: 'student')
          .limit(50)
          .snapshots();
    }
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void _openProfile(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
      return;
    }
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MeniuScreen()));
  }

  String _formatRequestDate(DateTime? date) {
    if (date == null) return '--';
    const months = <String>[
      'Ianuarie',
      'Februarie',
      'Martie',
      'Aprilie',
      'Mai',
      'Iunie',
      'Iulie',
      'August',
      'Septembrie',
      'Octombrie',
      'Noiembrie',
      'Decembrie',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatRequestTitle(DateTime? date) {
    if (date == null) return 'Cerere învoire';
    final dateStr = _formatRequestDate(date);
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return 'Cerere învoire - $dateStr, $hh:$mm';
  }

  String _formatSentLabel(DateTime? sentAt) {
    if (sentAt == null) return '--:--';
    final hour = sentAt.hour.toString().padLeft(2, '0');
    final minute = sentAt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  _InboxCardData _toInboxCardData(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final status = (data['status'] ?? 'pending').toString();
    final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
    final requestedForDate = (data['requestedForDate'] as Timestamp?)?.toDate();
    final message = (data['message'] ?? '').toString().trim();

    switch (status) {
      case 'approved':
        return _InboxCardData(
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a fost aprobată.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFE7EFE2),
          leadingForeground: _primary,
          statusIcon: Icons.check_circle_rounded,
          statusLabel: 'Aprobată',
          statusBackground: const Color(0xFFE4F0E1),
          statusForeground: _primary,
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'rejected':
        return _InboxCardData(
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a fost respinsă.' : message,
          leadingIcon: Icons.description_rounded,
          leadingBackground: const Color(0xFFF2E4EA),
          leadingForeground: const Color(0xFF9D345F),
          statusIcon: Icons.cancel_rounded,
          statusLabel: 'Respinsă',
          statusBackground: const Color(0xFFF4E6EC),
          statusForeground: const Color(0xFF9D345F),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      case 'expired':
        return _InboxCardData(
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty ? 'Cererea a expirat automat.' : message,
          leadingIcon: Icons.history_toggle_off_rounded,
          leadingBackground: const Color(0xFFF2EEDC),
          leadingForeground: const Color(0xFF8A6A1D),
          statusIcon: Icons.hourglass_bottom_rounded,
          statusLabel: 'Expirată',
          statusBackground: const Color(0xFFF6F0D9),
          statusForeground: const Color(0xFF8A6A1D),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
      default:
        return _InboxCardData(
          title: _formatRequestTitle(requestedForDate),
          topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty
              ? 'Cererea este în așteptarea aprobării.'
              : message,
          leadingIcon: Icons.history_rounded,
          leadingBackground: const Color(0xFFE6EBDE),
          leadingForeground: const Color(0xFF707B69),
          statusIcon: Icons.watch_later_rounded,
          statusLabel: 'În așteptare',
          statusBackground: const Color(0xFFE8ECD9),
          statusForeground: const Color(0xFF404A3A),
          sortAt: requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
        );
    }
  }

  _InboxCardData _toSecretariatCardData(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final message = (data['message'] ?? '').toString().trim();
    final senderName = (data['senderName'] ?? 'Secretariat').toString().trim();

    return _InboxCardData(
      title: 'Mesaj Secretariat',
      topLabel: _formatSentLabel(createdAt),
      message: message.isEmpty ? 'Ai primit un mesaj nou.' : message,
      leadingIcon: Icons.campaign_rounded,
      leadingBackground: const Color(0xFFDCEBFF),
      leadingForeground: const Color(0xFF1E5EC8),
      statusIcon: Icons.mark_chat_read_rounded,
      statusLabel: senderName.isEmpty ? 'Secretariat' : senderName,
      statusBackground: const Color(0xFFEAF2FF),
      statusForeground: const Color(0xFF1E5EC8),
      sortAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _InboxHeader(
              onBack: () => _goBack(context),
              onProfile: () => _openProfile(context),
              onLogout: _logout,
            ),
            Expanded(child: _buildInboxBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildInboxBody() {
    if (_leaveStream == null) {
      return const Center(child: Text('Sesiune invalidă.'));
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _leaveStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Eroare: ${snapshot.error}'));
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: _primary),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _secretariatStream,
          builder: (context, secretariatSnap) {
            if (secretariatSnap.hasError) {
              return Center(child: Text('Eroare: ${secretariatSnap.error}'));
            }

            final leaveItems = snapshot.data!.docs
                .where((doc) {
                  final data = doc.data();
                  final source = (data['source'] ?? '').toString().trim();
                  return source != 'secretariat';
                })
                .map(_toInboxCardData)
                .toList();

            final secretariatItems = (secretariatSnap.data?.docs ?? const [])
                .map(_toSecretariatCardData)
                .toList();

            final items = <_InboxCardData>[...leaveItems, ...secretariatItems]
              ..sort((a, b) => b.sortAt.compareTo(a.sortAt));

            final horizontalPadding = MediaQuery.sizeOf(context).width < 390
                ? 14.0
                : 18.0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                18,
                horizontalPadding,
                MediaQuery.paddingOf(context).bottom + 28,
              ),
              children: [
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Text(
                      'Nu există mesaje în inbox momentan.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                for (final item in items) ...[
                  _InboxRequestTile(data: item),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
              ],
            );
          },
        );
      },
    );
  }
}

class _InboxHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onProfile;
  final Future<void> Function() onLogout;

  const _InboxHeader({
    required this.onBack,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    final titleSize = compact ? 29.0 : 33.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              right: -56,
              top: -74,
              child: _HeaderCircle(size: 220, opacity: 0.08),
            ),
            Positioned(
              right: 34,
              top: 46,
              child: _HeaderCircle(size: 72, opacity: 0.07),
            ),
            Positioned(
              left: 156,
              bottom: -28,
              child: _HeaderCircle(size: 82, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Mesaje',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
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

class _InboxRequestTile extends StatelessWidget {
  final _InboxCardData data;

  const _InboxRequestTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF7A8374), // A slightly darker, 3D looking color
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 6),
          ),
        ],
      ),
      // Creating the 3D volume (thickness) by exposing the left and slightly bottom edge
      padding: const EdgeInsets.only(left: 4, bottom: 1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, _card],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                  const Text(
                                    'Cerere învoire',
                                    style: TextStyle(
                                      color: _textDark,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                      height: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    data.title.contains(' - ')
                                        ? data.title.split(' - ').last
                                        : data.title,
                                    style: const TextStyle(
                                      color: _textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data.topLabel,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          data.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _StatusBadge(data: data),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _InboxCardData data;

  const _StatusBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: data.statusBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.statusIcon, color: data.statusForeground, size: 15),
          const SizedBox(width: 6),
          Text(
            data.statusLabel,
            style: TextStyle(
              color: data.statusForeground,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(child: Icon(icon, color: Colors.white, size: 32)),
      ),
    );
  }
}

class _HeaderCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeaderCircle({required this.size, required this.opacity});

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

class _InboxCardData {
  final String title;
  final String topLabel;
  final String message;
  final IconData leadingIcon;
  final Color leadingBackground;
  final Color leadingForeground;
  final IconData statusIcon;
  final String statusLabel;
  final Color statusBackground;
  final Color statusForeground;
  final DateTime sortAt;

  const _InboxCardData({
    required this.title,
    required this.topLabel,
    required this.message,
    required this.leadingIcon,
    required this.leadingBackground,
    required this.leadingForeground,
    required this.statusIcon,
    required this.statusLabel,
    required this.statusBackground,
    required this.statusForeground,
    required this.sortAt,
  });
}
