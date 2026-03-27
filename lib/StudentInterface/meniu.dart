import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
import 'package:firster/StudentInterface/logout_dialog.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

const _primary = Color(0xFF0B7A20);
const _surface = Color(0xFFF7F9F0);
const _surfaceContainerLow = Color(0xFFF0F4E9);
const _surfaceContainerHigh = Color(0xFFE7EDE1);
const _surfaceLowest = Color(0xFFFFFFFF);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFC8D1C2);
const _onSurface = Color(0xFF151A14);
const _tertiary = Color(0xFF8E3557);

class MeniuScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const MeniuScreen({super.key, this.onNavigateTab});

  @override
  State<MeniuScreen> createState() => _MeniuScreenState();
}

class _MeniuScreenState extends State<MeniuScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _lastScanStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _leaveActiveStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _classDocStream;

  @override
  void initState() {
    super.initState();
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .snapshots();

    _lastScanStream = FirebaseFirestore.instance
        .collection('accessEvents')
        .where('userId', isEqualTo: currentUser.uid)
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots();

    _leaveActiveStream = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: currentUser.uid)
        .where('status', whereIn: ['approved', 'active', 'pending'])
        .snapshots();

    final classId = AppSession.classId;
    if (classId != null && classId.isNotEmpty) {
      _classDocStream = FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .snapshots();
    }
  }

  bool _isWithinSchedule(Map<String, dynamic> classData) {
    final now = DateTime.now();
    final weekday = now.weekday;
    if (weekday > 5) return false;

    final schedule = (classData['schedule'] as Map?) ?? {};
    final daySchedule = schedule[weekday.toString()] as Map?;
    if (daySchedule == null) return false;

    int parseMinutes(String value) {
      final parts = value.split(':');
      if (parts.length != 2) return -1;
      final hour = int.tryParse(parts[0]) ?? -1;
      final minute = int.tryParse(parts[1]) ?? -1;
      if (hour < 0 || minute < 0) return -1;
      return hour * 60 + minute;
    }

    final start = parseMinutes('${daySchedule['start'] ?? ''}');
    final end = parseMinutes('${daySchedule['end'] ?? ''}');
    if (start < 0 || end < 0) return false;

    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= start && nowMinutes <= end;
  }

  void _openCereri(BuildContext context) {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(2);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CereriScreen()),
    );
  }

  Future<void> _openMesaje(BuildContext context) async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
      return;
    }

    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {
          'inboxLastOpenedAt': FieldValue.serverTimestamp(),
          'unreadCount': 0,
        },
        SetOptions(merge: true),
      );
    }

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InboxScreen()),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: _surface,
      softSurfaceColor: _surfaceContainerHigh,
      titleColor: _onSurface,
      messageColor: _outline,
      dangerColor: _tertiary,
    );
    if (!shouldLogout) return;
    await FirebaseAuth.instance.signOut();
  }

  void _openProfil(BuildContext context) {
    // Dacă ai o pagină de profil/orar, navighezi către ea
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(1);
      return;
    }
    // Fallback: poți înlocui cu pagina ta de profil
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const _ProfilPlaceholderScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final fullName = (data['fullName'] ?? '').toString().trim();
            final resolvedName = fullName.isNotEmpty ? fullName : fallbackName;
            final className = (data['className'] ?? '').toString().trim();
            final unreadCount = (data['unreadCount'] as int?) ?? 0;

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER ──────────────────────────────────────────
                  _TopHeroHeader(
                    displayName: resolvedName,
                    className:
                        className.isNotEmpty ? className : 'Clasa a XII-a B',
                    onLogout: _logout,
                    onProfil: () => _openProfil(context),
                  ),

                  // ── ACCESS CARD ──────────────────────────────────────
                  Transform.translate(
                    offset: const Offset(0, -48),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _AccessHubCard(
                        lastScanStream: _lastScanStream,
                      ),
                    ),
                  ),

                  // ── CERERI + MESAJE ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Transform.translate(
                      offset: const Offset(0, -32),
                      child: Column(
                        children: [
                          IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: _CereriCard(
                                    onTap: () => _openCereri(context),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _MesajeCard(
                                    unreadCount: unreadCount,
                                    onTap: () => _openMesaje(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          _LeaveStatusCard(
                            classDocStream: _classDocStream,
                            leaveActiveStream: _leaveActiveStream,
                            isWithinSchedule: _isWithinSchedule,
                            onTap: () => _openCereri(context),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatelessWidget {
  final String displayName;
  final String className;
  final Future<void> Function() onLogout;
  final VoidCallback onProfil;

  const _TopHeroHeader({
    required this.displayName,
    required this.className,
    required this.onLogout,
    required this.onProfil,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: 240,
        color: _primary,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -80,
              top: -90,
              child: _Circle(size: 290, opacity: 0.08),
            ),
            Positioned(
              right: 38,
              top: 54,
              child: _Circle(size: 78, opacity: 0.07),
            ),
            Positioned(
              left: -60,
              bottom: -44,
              child: _Circle(size: 186, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bine ai venit,\n$displayName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 33,
                            height: 1.10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          className,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ProfileMenuButton(
                    onLogout: onLogout,
                    onProfil: onProfil,
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

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;
  const _Circle({required this.size, required this.opacity});

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

// ────────────────────────────────────────────────────────────────────────────
// PROFILE MENU BUTTON — cu Profil + Log out
// ────────────────────────────────────────────────────────────────────────────
class _ProfileMenuButton extends StatelessWidget {
  final Future<void> Function() onLogout;
  final VoidCallback onProfil;

  const _ProfileMenuButton({
    required this.onLogout,
    required this.onProfil,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '',
      offset: const Offset(0, 64),
      elevation: 12,
      color: const Color(0xFFD8EED9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (value) async {
        if (value == 'logout') await onLogout();
        if (value == 'profil') onProfil();
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
              border: Border.all(color: const Color(0x660B7A20)),
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
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0x337DE38D),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0x6DC7F4CE),
            width: 1,
          ),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 21),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// ACCESS HUB CARD
// ────────────────────────────────────────────────────────────────────────────
class _AccessHubCard extends StatefulWidget {
  final Stream<QuerySnapshot<Map<String, dynamic>>>? lastScanStream;

  const _AccessHubCard({required this.lastScanStream});

  @override
  State<_AccessHubCard> createState() => _AccessHubCardState();
}

class _AccessHubCardState extends State<_AccessHubCard> {
  static const int _renewIntervalSeconds = 5;
  Timer? _regenTimer;
  Timer? _countdownTimer;
  String _token = '';
  bool _loading = false;
  int _secondsLeft = _renewIntervalSeconds;

  @override
  void initState() {
    super.initState();
    _regenerateToken();
    _regenTimer = Timer.periodic(
      const Duration(seconds: _renewIntervalSeconds),
      (_) => _regenerateToken(),
    );
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _secondsLeft = _secondsLeft > 0 ? _secondsLeft - 1 : 0);
    });
  }

  @override
  void dispose() {
    _regenTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _regenerateToken() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    if (mounted) setState(() => _loading = true);

    try {
      final random = Random();
      final tokenId = List.generate(16, (_) => random.nextInt(10)).join();
      final expiresAt = DateTime.now().add(
        const Duration(seconds: _renewIntervalSeconds + 1),
      );

      await FirebaseFirestore.instance.collection('qrTokens').doc(tokenId).set({
        'userId': uid,
        'expiresAt': expiresAt,
        'used': false,
      });

      if (!mounted) return;
      setState(() {
        _token = tokenId;
        _secondsLeft = _renewIntervalSeconds;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _timerText {
    final m = (_secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s SEC';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180B7A20),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Acces Campus',
            style: TextStyle(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 24),

          // QR + timer badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Container(
                  width: 232,
                  height: 232,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_token.isNotEmpty)
                        QrImageView(
                          data: _token,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: _primary,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: _primary,
                          ),
                        )
                      else
                        const Icon(
                          Icons.qr_code_2_rounded,
                          color: _primary,
                          size: 132,
                        ),
                      if (_loading)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: _primary,
                              strokeWidth: 2.2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: -14,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: _primary,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x25000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.80),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        _timerText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // ── STATUS + INTRARE centrate ────────────────────────────
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.lastScanStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              String statusText = 'Intrat';
              String timeText = '--:--';
              Color statusColor = _primary;

              if (docs.isNotEmpty) {
                final doc = docs.first;
                final type = (doc.data()['type'] ?? '').toString();
                final ts = doc.data()['timestamp'] as Timestamp?;
                if (type == 'exit') {
                  statusText = 'Ieșit';
                  statusColor = _tertiary;
                }
                if (ts != null) {
                  final dt = ts.toDate();
                  timeText =
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                }
              }

              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Status',
                      value: statusText,
                      valueColor: statusColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      label: 'Intrare',
                      value: timeText,
                      valueColor: _onSurface,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// STAT CARD
// ────────────────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _outline,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// CERERI CARD
// ────────────────────────────────────────────────────────────────────────────
class _CereriCard extends StatelessWidget {
  final VoidCallback onTap;
  const _CereriCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 232,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B7A20), Color(0xFF2D9640)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x350B7A20),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 34,
              ),
            ),
            const Spacer(),
            const Text(
              'Cererile de\nînvoire',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Creează o cerere nouă',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// MESAJE CARD
// ────────────────────────────────────────────────────────────────────────────
class _MesajeCard extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;
  const _MesajeCard({required this.unreadCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 232,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: _surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: _outlineVariant.withValues(alpha: 0.36),
            width: 1.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.forum_rounded,
                color: _primary,
                size: 34,
              ),
            ),
            const Spacer(),
            const Text(
              'Mesaje',
              style: TextStyle(
                color: _onSurface,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.circle, size: 12, color: _primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$unreadCount mesaje noi',
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
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

// ────────────────────────────────────────────────────────────────────────────
// LEAVE STATUS CARD
// ────────────────────────────────────────────────────────────────────────────
class _LeaveStatusCard extends StatelessWidget {
  final Stream<DocumentSnapshot<Map<String, dynamic>>>? classDocStream;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? leaveActiveStream;
  final bool Function(Map<String, dynamic>) isWithinSchedule;
  final VoidCallback onTap;

  const _LeaveStatusCard({
    required this.classDocStream,
    required this.leaveActiveStream,
    required this.isWithinSchedule,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: classDocStream,
      builder: (context, classSnapshot) {
        final classData =
            classSnapshot.data?.data() ?? const <String, dynamic>{};
        final inSchedule = isWithinSchedule(classData);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: leaveActiveStream,
          builder: (context, snapshot) {
            final docs = snapshot.data?.docs ?? [];

            final hasActive = inSchedule &&
                docs.any((doc) => doc.data()['status'] == 'approved');
            final hasPending = docs.any(
              (doc) => ['active', 'pending'].contains(doc.data()['status']),
            );

            final statusText = hasActive
                ? 'Activă'
                : hasPending
                    ? 'În așteptare'
                    : 'Inactivă';
            final statusColor =
                (hasActive || hasPending) ? _primary : _outline;

            return GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: _surfaceLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _outlineVariant.withValues(alpha: 0.18),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x09000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: _primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Cerere Învoire',
                        style: TextStyle(
                          color: _onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: _primary.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            statusText.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// PROFIL PLACEHOLDER — înlocuiește cu pagina ta reală de profil/orar
// ────────────────────────────────────────────────────────────────────────────
class _ProfilPlaceholderScreen extends StatelessWidget {
  const _ProfilPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        title: const Text(
          'Profil & Orar',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Profil / Logout',
            offset: const Offset(0, 64),
            icon: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0x337DE38D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0x6DC7F4CE),
                  width: 1,
                ),
              ),
              child: const Icon(
                Icons.person,
                color: Colors.white,
                size: 21,
              ),
            ),
            onSelected: (value) async {
              if (value == 'logout') {
                final shouldLogout = await showStudentLogoutDialog(
                  context,
                  accentColor: _primary,
                  surfaceColor: _surface,
                  softSurfaceColor: _surfaceContainerHigh,
                  titleColor: _onSurface,
                  messageColor: _outline,
                  dangerColor: _tertiary,
                );
                if (!shouldLogout) return;
                await FirebaseAuth.instance.signOut();
                return;
              }

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ești deja în pagina de profil.')),
              );
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.person_outline_rounded),
                  title: Text('Profil'),
                ),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Deconecteaza-te'),
                ),
              ),
            ],
          ),
        ],
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Pagina de profil',
          style: TextStyle(color: _outline, fontSize: 16),
        ),
      ),
    );
  }
}