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
      return 'Clasa nealocata';
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

    return Scaffold(
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
            final inboxLastOpenedAt = (data['inboxLastOpenedAt'] as Timestamp?)
                ?.toDate();
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
                          : (classId.isNotEmpty ? classId : 'Clasa nealocata'));
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
                      ),
                    ),
                    Positioned(
                      top: 190.0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SingleChildScrollView(
                        physics: const _DampedScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Column(
                          children: [
                            _AccessHubCard(
                              inSchool: (data['inSchool'] as bool?) ?? false,
                              lastInAt: data['lastInAt'],
                              lastScanStream: _lastScanStream,
                            ),
                            const SizedBox(height: 14),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: _CereriCard(
                                      onTap: () => _openCereri(context),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
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
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _LeaveStatusCard(
                              classDocStream: classStream,
                              leaveActiveStream: _leaveActiveStream,
                              isWithinSchedule: _isWithinSchedule,
                              onActiveTap: widget.onNavigateToActiveLeave,
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
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// HEADER
// ────────────────────────────────────────────────────────────────────────────
class _TopHeroHeader extends StatelessWidget {
  final String displayName;
  final String className;

  const _TopHeroHeader({required this.displayName, required this.className});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: 220 + topPadding,
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
              padding: EdgeInsets.fromLTRB(28, 8 + topPadding, 14, 0),
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
                            fontSize: 34,
                            height: 1.20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.0,
                          ),
                        ),
                        const SizedBox(height: 0),
                        Text(
                          className,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: 15,
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

  const _AccessHubCard({
    required this.inSchool,
    required this.lastInAt,
    required this.lastScanStream,
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
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          const Text(
            'Acces Campus',
            style: TextStyle(
              fontSize: 31,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: _onSurface,
            ),
          ),
          const SizedBox(height: 12),

          // QR + timer badge
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  width: 176,
                  height: 176,
                  padding: const EdgeInsets.all(10),
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
                          size: 96,
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

          const SizedBox(height: 28),

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
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _StatCard(
                      label: 'Scanare',
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
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
              fontSize: 15,
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
        height: 184,
        padding: const EdgeInsets.all(16),
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.description_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const Spacer(),
            const Text(
              'Cererile de\nînvoire',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                height: 1.18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
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
  final String studentUid;
  final DateTime? inboxLastOpenedAt;
  final VoidCallback onTap;
  const _MesajeCard({
    required this.studentUid,
    required this.inboxLastOpenedAt,
    required this.onTap,
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

                  return Container(
                    height: 184,
                    padding: const EdgeInsets.all(16),
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
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: _primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.forum_rounded,
                            color: _primary,
                            size: 24,
                          ),
                        ),
                        const Spacer(),
                        const Text(
                          'Mesaje',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 22,
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

  const _LeaveStatusCard({
    required this.classDocStream,
    required this.leaveActiveStream,
    required this.isWithinSchedule,
    this.onActiveTap,
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

            final card = Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: _primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Cerere Învoire',
                      style: TextStyle(
                        color: _onSurface,
                        fontSize: 15,
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
