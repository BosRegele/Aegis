import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0B741D);
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

  void _openCereri(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CereriScreen()));
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
    if (date == null) {
      return '--';
    }
    const months = <String>[
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
    return '${date.day} ${months[date.month - 1]}';
  }

  String _formatSentLabel(DateTime? sentAt) {
    if (sentAt == null) {
      return '--\n--:--';
    }
    final hour = sentAt.hour.toString().padLeft(2, '0');
    final minute = sentAt.minute.toString().padLeft(2, '0');
    return '${_formatRequestDate(sentAt)}\n$hour:$minute';
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
          title: 'Cerere Învoire - ${_formatRequestDate(requestedForDate)}',
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
          title: 'Cerere Învoire - ${_formatRequestDate(requestedForDate)}',
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
          title: 'Cerere Învoire - ${_formatRequestDate(requestedForDate)}',
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
          title: 'Cerere Învoire - ${_formatRequestDate(requestedForDate)}',
            topLabel: _formatSentLabel(requestedAt),
          message: message.isEmpty
              ? 'Cererea este în așteptarea aprobării.'
              : message,
          leadingIcon: Icons.history_rounded,
          leadingBackground: const Color(0xFFE6EBDE),
          leadingForeground: const Color(0xFF707B69),
          statusIcon: Icons.watch_later_rounded,
          statusLabel: 'În analiză',
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

            final horizontalPadding =
                MediaQuery.sizeOf(context).width < 390 ? 14.0 : 18.0;

            return ListView(
              physics: const BouncingScrollPhysics(),
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
                  const SizedBox(height: 18),
                ],
                const SizedBox(height: 14),
                _CreateRequestButton(onTap: () => _openCereri(context)),
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
                    const SizedBox(width: 16),
                    _HeaderMenuButton(onLogout: onLogout, onProfil: onProfile),
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
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final iconBoxSize = compact ? 64.0 : 72.0;
    final titleSize = compact ? 20.0 : 24.0;
    final bodySize = compact ? 16.0 : 18.0;
    final topLabelSize = compact ? 12.0 : 14.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 18,
        compact ? 16 : 18,
        compact ? 16 : 18,
        compact ? 16 : 18,
      ),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B741D),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: iconBoxSize,
            height: iconBoxSize,
            decoration: BoxDecoration(
              color: data.leadingBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              data.leadingIcon,
              color: data.leadingForeground,
              size: compact ? 34 : 38,
            ),
          ),
          SizedBox(width: compact ? 14 : 16),
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
                        style: TextStyle(
                          color: _textDark,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                    ),
                    SizedBox(width: compact ? 8 : 10),
                    Text(
                      data.topLabel,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: topLabelSize,
                        fontWeight: FontWeight.w700,
                        height: 1.22,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: compact ? 8 : 10),
                Text(
                  data.message,
                  style: TextStyle(
                    color: Color(0xFF3A4037),
                    fontSize: bodySize,
                    fontWeight: FontWeight.w500,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: compact ? 16 : 18),
                _StatusBadge(data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final _InboxCardData data;

  const _StatusBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 14 : 16,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: data.statusBackground,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            data.statusIcon,
            color: data.statusForeground,
            size: compact ? 20 : 22,
          ),
          SizedBox(width: compact ? 8 : 10),
          Text(
            data.statusLabel,
            style: TextStyle(
              color: data.statusForeground,
              fontSize: compact ? 15 : 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateRequestButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateRequestButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        height: compact ? 84 : 92,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B741D), Color(0xFF2C983E)],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260B741D),
              blurRadius: 26,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: compact ? 15 : 16,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.add_rounded,
                color: _primary,
                size: compact ? 24 : 28,
              ),
            ),
            SizedBox(width: compact ? 14 : 16),
            Text(
              'Creează Cerere Nouă',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 19 : 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
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
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),
      ),
    );
  }
}

class _HeaderMenuButton extends StatelessWidget {
  final Future<void> Function() onLogout;
  final VoidCallback onProfil;

  const _HeaderMenuButton({required this.onLogout, required this.onProfil});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 64),
      elevation: 12,
      color: const Color(0xFFD8EED9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (value) async {
        if (value == 'profil') {
          onProfil();
        }
        if (value == 'logout') {
          await onLogout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'profil',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFB9DEBC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x660B741D)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: _primary, size: 20),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Profil',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(height: 6),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF1CDD8),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x668E3557)),
            ),
            child: const Row(
              children: [
                Icon(Icons.logout_rounded, color: Color(0xFF8E3557), size: 20),
                SizedBox(width: 10),
                Flexible(
                  child: Text(
                    'Deconecteaza-te',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF8E3557),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0x337DE38D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x6DC7F4CE), width: 1.3),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 22),
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
