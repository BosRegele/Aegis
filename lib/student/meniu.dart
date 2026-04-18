import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/student/cereri.dart';
import 'package:firster/student/inbox.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _DampedScrollPhysics extends ScrollPhysics {
  const _DampedScrollPhysics({super.parent});
  @override
  _DampedScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _DampedScrollPhysics(parent: buildParent(ancestor));
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) =>
      super.applyPhysicsToUserOffset(position, offset) * 0.55;
}

const _primary = Color(0xFF0D631B);
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
  final void Function(String docId)? onNavigateToActiveLeave;

  const MeniuScreen({
    super.key,
    this.onNavigateTab,
    this.onNavigateToActiveLeave,
  });

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

  String _formatClassLabel(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return 'Clasă nealocată';
    }

    final normalized = trimmed
        .replaceFirst(RegExp(r'^clasa\s+', caseSensitive: false), '')
        .trim();
    final compact = normalized.replaceAll(RegExp(r'\s+'), '');
    final match = RegExp(r'^(\d{1,2})([A-Za-z])$').firstMatch(compact);
    if (match == null) {
      return trimmed;
    }

    final grade = match.group(1)!;
    final letter = match.group(2)!.toUpperCase();
    return 'Clasa a $grade-a $letter';
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

  Future<void> _openMesaje(BuildContext context) async {
    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(3);
      return;
    }

    final uid = AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'inboxLastOpenedAt': FieldValue.serverTimestamp(),
        'unreadCount': 0,
      }, SetOptions(merge: true));
    }

    if (!context.mounted) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const InboxScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    final media = MediaQuery.of(context);
    final screenHeight = media.size.height;
    final screenWidth = media.size.width;
    final usableHeight =
        screenHeight - media.padding.top - media.padding.bottom;
    final veryCompact = usableHeight < 680 || screenWidth < 340;
    final compact = !veryCompact && usableHeight < 820;

    final headerHeight = veryCompact ? 168.0 : (compact ? 188.0 : 220.0);
    final contentTop = headerHeight - 30.0;
    final spacing = veryCompact ? 9.0 : (compact ? 11.0 : 14.0);
    final horizontalPad = veryCompact ? 14.0 : (compact ? 18.0 : 20.0);

    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.0,
        ),
      ),
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          top: false,
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _userDocStream,
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final fullName = (data['fullName'] ?? '').toString().trim();
              final resolvedName = fullName.isNotEmpty ? fullName : fallbackName;
              final classId = (data['classId'] ?? AppSession.classId ?? '')
                  .toString()
                  .trim();
              final className = (data['className'] ?? '').toString().trim();
              final inboxLastOpenedAt =
                  (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();
              final classStream = classId.isNotEmpty
                  ? FirebaseFirestore.instance
                        .collection('classes')
                        .doc(classId)
                        .snapshots()
                  : _classDocStream;

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: classStream,
                builder: (context, classSnapshot) {
                  final classData =
                      classSnapshot.data?.data() ?? const <String, dynamic>{};
                  final classDocName = (classData['name'] ?? '')
                      .toString()
                      .trim();
                  final rawClassName = className.isNotEmpty
                      ? className
                      : (classDocName.isNotEmpty
                            ? classDocName
                            : (classId.isNotEmpty
                                  ? classId
                                  : 'Clasă nealocată'));
                  final resolvedClassName = _formatClassLabel(rawClassName);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: _surface),
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _TopHeroHeader(
                          displayName: resolvedName,
                          className: resolvedClassName,
                          height: headerHeight,
                          compact: compact || veryCompact,
                        ),
                      ),
                      Positioned(
                        top: contentTop,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SingleChildScrollView(
                          physics: const _DampedScrollPhysics(),
                          padding: EdgeInsets.fromLTRB(
                            horizontalPad,
                            0,
                            horizontalPad,
                            12,
                          ),
                          child: Column(
                            children: [
                              _AccessHubCard(
                                inSchool: (data['inSchool'] as bool?) ?? false,
                                lastInAt: data['lastInAt'],
                                lastScanStream: _lastScanStream,
                                compact: compact,
                                veryCompact: veryCompact,
                              ),
                              SizedBox(height: spacing),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      child: _CereriCard(
                                        onTap: () => _openCereri(context),
                                        compact: compact,
                                        veryCompact: veryCompact,
                                      ),
                                    ),
                                    SizedBox(width: spacing),
                                    Expanded(
                                      child: _MesajeCard(
                                        studentUid:
                                            FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid ??
                                            '',
                                        inboxLastOpenedAt: inboxLastOpenedAt,
                                        onTap: () => _openMesaje(context),
                                        compact: compact,
                                        veryCompact: veryCompact,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: spacing),
                              _LeaveStatusCard(
                                classDocStream: classStream,
                                leaveActiveStream: _leaveActiveStream,
                                isWithinSchedule: _isWithinSchedule,
                                onActiveTap: widget.onNavigateToActiveLeave,
                                compact: compact,
                                veryCompact: veryCompact,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
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
  final double height;
  final bool compact;

  const _TopHeroHeader({
    required this.displayName,
    required this.className,
    this.height = 220,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final titleSize = compact ? 27.0 : 34.0;
    final subSize = compact ? 14.0 : 15.0;
    final hPad = compact ? 23.0 : 28.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: height + topPadding,
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
              padding: EdgeInsets.fromLTRB(hPad, 8 + topPadding, 14, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bine ai venit,\n$displayName',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleSize,
                            height: 1.20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.0,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          className,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: subSize,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
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
// ACCESS HUB CARD
// ────────────────────────────────────────────────────────────────────────────
class _AccessHubCard extends StatefulWidget {
  final bool inSchool;
  final dynamic lastInAt;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? lastScanStream;
  final bool compact;
  final bool veryCompact;

  const _AccessHubCard({
    required this.inSchool,
    required this.lastInAt,
    required this.lastScanStream,
    this.compact = false,
    this.veryCompact = false,
  });

  @override
  State<_AccessHubCard> createState() => _AccessHubCardState();
}

class _AccessHubCardState extends State<_AccessHubCard> {
  static const int _renewIntervalSeconds = 15;
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
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: _renewIntervalSeconds + 1)),
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

  DateTime? _readDateTime(dynamic rawValue) {
    if (rawValue is Timestamp) {
      return rawValue.toDate();
    }
    if (rawValue is DateTime) {
      return rawValue;
    }
    if (rawValue is String) {
      return DateTime.tryParse(rawValue);
    }
    return null;
  }

  String _formatClockTime(DateTime? value) {
    if (value == null) {
      return '--:--';
    }
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final compact = widget.compact;
    final veryCompact = widget.veryCompact;
    final titleSize = veryCompact ? 22.0 : (compact ? 26.0 : 31.0);
    final qrSize = veryCompact
        ? (screenWidth * 0.35).clamp(116.0, 136.0)
        : (compact
              ? (screenWidth * 0.39).clamp(132.0, 156.0)
              : (screenWidth * 0.44).clamp(150.0, 186.0));
    final cardPad = veryCompact
        ? const EdgeInsets.fromLTRB(12, 10, 12, 12)
        : (compact
              ? const EdgeInsets.fromLTRB(14, 12, 14, 13)
              : const EdgeInsets.fromLTRB(16, 14, 16, 16));
    final qrInnerPad = veryCompact ? 8.0 : (compact ? 9.0 : 10.0);
    final qrOuterPad = veryCompact ? 10.0 : (compact ? 11.0 : 12.0);
    final topGap = veryCompact ? 7.0 : (compact ? 9.0 : 12.0);
    final bottomGap = veryCompact ? 17.0 : (compact ? 21.0 : 28.0);

    return Container(
      padding: cardPad,
      decoration: BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180D631B),
            blurRadius: 32,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Acces Campus',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: _onSurface,
            ),
          ),
          SizedBox(height: topGap),

          // QR + timer badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(qrOuterPad),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  width: qrSize,
                  height: qrSize,
                  padding: EdgeInsets.all(qrInnerPad),
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
                        Icon(
                          Icons.qr_code_2_rounded,
                          color: _primary,
                          size: qrSize * 0.55,
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
                bottom: -10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
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

          SizedBox(height: bottomGap),

          // ── STATUS + INTRARE centrate ────────────────────────────
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: widget.lastScanStream,
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final latestDoc = docs.isNotEmpty ? docs.first.data() : null;
              final latestType = (latestDoc?['type'] ?? '').toString().trim();
              final latestTimestamp = _readDateTime(latestDoc?['timestamp']);
              final lastInAt = _readDateTime(widget.lastInAt);

              final statusFromUser = widget.inSchool;
              final fallbackStatusFromEvent = latestType == 'exit'
                  ? false
                  : true;
              final resolvedInSchool = lastInAt != null || latestDoc == null
                  ? statusFromUser
                  : fallbackStatusFromEvent;

              final statusText = resolvedInSchool ? 'Intrat' : 'Ieșit';
              final statusColor = resolvedInSchool ? _primary : _tertiary;
              final timeText = _formatClockTime(lastInAt ?? latestTimestamp);

              return Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Status',
                      value: statusText,
                      valueColor: statusColor,
                      compact: compact,
                      veryCompact: veryCompact,
                    ),
                  ),
                  SizedBox(width: veryCompact ? 10 : (compact ? 12 : 14)),
                  Expanded(
                    child: _StatCard(
                      label: 'Scanare',
                      value: timeText,
                      valueColor: _onSurface,
                      compact: compact,
                      veryCompact: veryCompact,
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
  final bool compact;
  final bool veryCompact;

  const _StatCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.compact = false,
    this.veryCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hPad = veryCompact ? 12.0 : 14.0;
    final vPad = veryCompact ? 10.0 : (compact ? 11.0 : 12.0);
    final labelSize = veryCompact ? 9.5 : 10.0;
    final valueSize = veryCompact ? 14.0 : 15.0;
    final gap = veryCompact ? 6.0 : (compact ? 7.0 : 8.0);

    return Container(
      padding: EdgeInsets.fromLTRB(hPad, vPad, hPad, vPad),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: labelSize,
              fontWeight: FontWeight.w700,
              color: _outline,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: gap),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueSize,
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
  final bool compact;
  final bool veryCompact;
  const _CereriCard({
    required this.onTap,
    this.compact = false,
    this.veryCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = veryCompact ? 134.0 : (compact ? 154.0 : 184.0);
    final iconBox = veryCompact ? 39.0 : (compact ? 45.0 : 52.0);
    final iconSize = veryCompact ? 19.5 : (compact ? 21.5 : 24.0);
    final titleSize = veryCompact ? 16.5 : (compact ? 18.5 : 22.0);
    final subSize = veryCompact ? 11.0 : (compact ? 11.5 : 12.0);
    final pad = veryCompact ? 12.5 : (compact ? 13.5 : 16.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D631B), Color(0xFF19802E)],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x350D631B),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: iconSize,
              ),
            ),
            const Spacer(),
            Text(
              'Cererile de\nînvoire',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: titleSize,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Creează o cerere nouă',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.74),
                fontSize: subSize,
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
  final String studentUid;
  final DateTime? inboxLastOpenedAt;
  final VoidCallback onTap;
  final bool compact;
  final bool veryCompact;
  const _MesajeCard({
    required this.studentUid,
    required this.inboxLastOpenedAt,
    required this.onTap,
    this.compact = false,
    this.veryCompact = false,
  });

  DateTime? _readDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  DateTime? _leaveMessageTime(Map<String, dynamic> data) {
    return _readDateTime(data['reviewedAt']) ??
        _readDateTime(data['requestedAt']);
  }

  bool _isVisibleLeaveMessage(Map<String, dynamic> data) {
    final source = (data['source'] ?? '').toString().trim();
    return source != 'secretariat';
  }

  int _countUnread(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> leaveDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> secretariatDocs,
  ) {
    final lastViewed = inboxLastOpenedAt;
    if (lastViewed == null) {
      return leaveDocs
              .where((doc) => _isVisibleLeaveMessage(doc.data()))
              .length +
          secretariatDocs.length;
    }

    final leaveUnread = leaveDocs.where((doc) {
      final data = doc.data();
      if (!_isVisibleLeaveMessage(data)) {
        return false;
      }
      final when = _leaveMessageTime(data);
      return when != null && when.isAfter(lastViewed);
    }).length;

    final secretariatUnread = secretariatDocs.where((doc) {
      final when = _readDateTime(doc.data()['createdAt']);
      return when != null && when.isAfter(lastViewed);
    }).length;

    return leaveUnread + secretariatUnread;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: studentUid.isEmpty
            ? null
            : FirebaseFirestore.instance
                  .collection('leaveRequests')
                  .where('studentUid', isEqualTo: studentUid)
                  .orderBy('requestedAt', descending: true)
                  .limit(50)
                  .snapshots(),
        builder: (context, leaveSnapshot) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: studentUid.isEmpty
                ? null
                : FirebaseFirestore.instance
                      .collection('secretariatMessages')
                      .where('recipientUid', isEqualTo: studentUid)
                      .where('recipientRole', isEqualTo: 'student')
                      .limit(50)
                      .snapshots(),
            builder: (context, secretariatSnapshot) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: studentUid.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                          .collection('secretariatMessages')
                          .where('recipientUid', isEqualTo: '')
                          .where('recipientRole', isEqualTo: 'student')
                          .limit(50)
                          .snapshots(),
                builder: (context, globalSecretariatSnapshot) {
                  final unreadCount =
                      _countUnread(leaveSnapshot.data?.docs ?? const [], [
                        ...(secretariatSnapshot.data?.docs ?? const []),
                        ...(globalSecretariatSnapshot.data?.docs ?? const []),
                      ]);

                  final cardHeight =
                      veryCompact ? 134.0 : (compact ? 154.0 : 184.0);
                  final iconBox =
                      veryCompact ? 39.0 : (compact ? 45.0 : 52.0);
                  final iconSize =
                      veryCompact ? 19.5 : (compact ? 21.5 : 24.0);
                  final titleSize =
                      veryCompact ? 16.5 : (compact ? 18.5 : 22.0);
                  final subSize =
                      veryCompact ? 11.0 : (compact ? 11.5 : 12.0);
                  final pad = veryCompact ? 12.5 : (compact ? 13.5 : 16.0);

                  return Container(
                    height: cardHeight,
                    padding: EdgeInsets.all(pad),
                    decoration: BoxDecoration(
                      color: _surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _outlineVariant.withValues(alpha: 0.36),
                        width: 1.1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: iconBox,
                          height: iconBox,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.forum_rounded,
                            color: _primary,
                            size: iconSize,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Mesaje',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: titleSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.circle, size: 12, color: _primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$unreadCount mesaje noi',
                                style: TextStyle(
                                  color: _outline,
                                  fontSize: subSize,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
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
  final void Function(String docId)? onActiveTap;
  final bool compact;
  final bool veryCompact;

  const _LeaveStatusCard({
    required this.classDocStream,
    required this.leaveActiveStream,
    required this.isWithinSchedule,
    this.onActiveTap,
    this.compact = false,
    this.veryCompact = false,
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

            // Client-side: filter out requests whose date has passed
            final now = DateTime.now();
            final todayMidnight = DateTime(now.year, now.month, now.day);
            bool isExpiredLocally(Map<String, dynamic> data) {
              final forDate = (data['requestedForDate'] as Timestamp?)
                  ?.toDate();
              if (forDate == null) return false;
              return forDate.isBefore(todayMidnight);
            }

            final activeDoc = inSchedule
                ? docs
                      .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                      .where((doc) {
                        final d = doc.data();
                        return d['status'] == 'approved' &&
                            !isExpiredLocally(d);
                      })
                      .firstOrNull
                : null;
            final pendingDoc = docs
                .cast<QueryDocumentSnapshot<Map<String, dynamic>>>()
                .where((doc) {
                  final d = doc.data();
                  return ['active', 'pending'].contains(d['status']) &&
                      !isExpiredLocally(d);
                })
                .firstOrNull;
            final hasActive = activeDoc != null;
            final hasPending = pendingDoc != null;
            final tapDoc = activeDoc ?? pendingDoc;

            final statusText = hasActive
                ? 'Activă'
                : hasPending
                ? 'În așteptare'
                : 'Inactivă';
            final statusColor = (hasActive || hasPending) ? _primary : _outline;

            final vPad = veryCompact ? 12.0 : (compact ? 13.0 : 14.0);
            final hPad = 14.0;
            final iconBox = veryCompact ? 48.0 : (compact ? 52.0 : 56.0);
            final iconSize = veryCompact ? 24.0 : (compact ? 25.0 : 26.0);
            final titleSize = veryCompact ? 14.0 : 15.0;

            final card = Container(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              decoration: BoxDecoration(
                color: _surfaceLowest,
                borderRadius: BorderRadius.circular(22),
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
                    width: iconBox,
                    height: iconBox,
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.description_rounded,
                      color: _primary,
                      size: iconSize,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cerere Învoire',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _onSurface,
                        fontSize: titleSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
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
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );

            if (tapDoc != null && onActiveTap != null) {
              return GestureDetector(
                onTap: () => onActiveTap!(tapDoc.id),
                child: card,
              );
            }
            return card;
          },
        );
      },
    );
  }
}
