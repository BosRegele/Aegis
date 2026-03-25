import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0B7A20);
const _surface = Color(0xFFF7F9F0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFF0F4E9);
const _surfaceContainerHigh = Color(0xFFE7EDE1);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFC8D1C2);
const _onSurface = Color(0xFF151A14);

class OrarScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const OrarScreen({super.key, this.onBackToHome});

  @override
  State<OrarScreen> createState() => _OrarScreenState();
}

class _OrarScreenState extends State<OrarScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
  }

  void _goBack() {
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
      return;
    }
    Navigator.of(context).maybePop();
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
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
            final fullName = (userData['fullName'] ?? '').toString().trim();
            final classId = (userData['classId'] ?? '').toString().trim();
            final className = (userData['className'] ?? '').toString().trim();
            final lastScanRaw = userData['lastScan'] != null
                ? userData['lastScan'] as dynamic
                : null;
            final displayName = fullName.isNotEmpty ? fullName : fallbackName;

            final resolvedClassName = className.isNotEmpty
                ? className
                : (classId.isNotEmpty ? classId : 'Clasa necunoscută');

            String lastScanDisplay = '--';
            if (lastScanRaw != null) {
              try {
                final lastScanTime = lastScanRaw is Timestamp
                    ? lastScanRaw.toDate()
                    : (lastScanRaw is String
                        ? DateTime.parse(lastScanRaw)
                        : null);
                if (lastScanTime != null) {
                  final day = lastScanTime.day.toString().padLeft(2, '0');
                  final month = lastScanTime.month.toString().padLeft(2, '0');
                  final year = lastScanTime.year;
                  final hour = lastScanTime.hour.toString().padLeft(2, '0');
                  final minute = lastScanTime.minute.toString().padLeft(2, '0');
                  lastScanDisplay = '$day.$month.$year $hour:$minute';
                }
              } catch (_) {}
            }

            final classStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .snapshots()
                : null;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData = classSnapshot.data?.data() ??
                    const <String, dynamic>{};

                final scheduleRows = _buildScheduleRows(classData);
                final teacherUid =
                  (classData['teacherUid'] ?? '').toString().trim();
                final teacherUsername =
                    (classData['teacherUsername'] ?? '').toString().trim();

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _OrarHeroHeader(
                        onBack: _goBack,
                        onLogout: _logout,
                      ),
                      Transform.translate(
                        offset: const Offset(0, -48),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                            decoration: BoxDecoration(
                              color: _surfaceLowest,
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x140B7A20),
                                  blurRadius: 34,
                                  offset: Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name aligned left
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                // Class info
                                Text(
                                  'Clasa $resolvedClassName',
                                  style: const TextStyle(
                                    color: _outline,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                // DIRIGINTE section
                                _PersonInfoBox(
                                  label: 'DIRIGINTE',
                                  icon: Icons.school,
                                  teacherUid: teacherUid,
                                  teacherUsername: teacherUsername,
                                ),
                                const SizedBox(height: 12),
                                // PÂRINTE section
                                _ParentInfoBox(),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 38,
                          vertical: 20,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            color: _surfaceContainerLow,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.qr_code_2_rounded,
                                color: _primary,
                                size: 22,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Ultima Scanare',
                                style: TextStyle(
                                  color: _outline,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                lastScanDisplay,
                                style: const TextStyle(
                                  color: _onSurface,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          decoration: BoxDecoration(
                            color: _surfaceLowest,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: _outlineVariant.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Orar Săptămanal',
                                style: TextStyle(
                                  color: _onSurface,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (scheduleRows.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: _surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: const Text(
                                    'Nu există orar definit pe server pentru clasa ta.',
                                    style: TextStyle(
                                      color: _outline,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              for (final row in scheduleRows) ...[
                                _ScheduleRow(
                                  dayName: row.dayName,
                                  intervalText: row.intervalText,
                                  rowDayNumber: row.dayNumber,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        child: _LogoutActionButton(onTap: _logout),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrarHeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Future<void> Function() onLogout;

  const _OrarHeroHeader({
    required this.onBack,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: 180,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              right: -80,
              top: -90,
              child: _Circle(size: 300, opacity: 0.08),
            ),
            Positioned(
              right: 40,
              top: 58,
              child: _Circle(size: 84, opacity: 0.07),
            ),
            Positioned(
              left: -62,
              bottom: -48,
              child: _Circle(size: 188, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      _HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: onBack,
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Profil',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const Spacer(),
                      _HeaderMenuButton(
                        onLogout: onLogout,
                        onProfil: () {},
                      ),
                    ],
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
              border: Border.all(color: const Color(0x660B7A20)),
            ),
            child: const Row(
              children: [
                Icon(Icons.person_outline_rounded, color: _primary, size: 20),
                SizedBox(width: 10),
                Text(
                  'Profil',
                  style: TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.w700,
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
                Text(
                  'Log out',
                  style: TextStyle(
                    color: Color(0xFF8E3557),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: const Color(0x337DE38D),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0x6DC7F4CE),
            width: 1.4,
          ),
        ),
        child: const Icon(Icons.person, color: Colors.white, size: 28),
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
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
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

class _LogoutActionButton extends StatelessWidget {
  final Future<void> Function() onTap;

  const _LogoutActionButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () async {
        await onTap();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _primary.withValues(alpha: 0.24), width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0B7A20),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout_rounded, color: _primary, size: 24),
            SizedBox(width: 12),
            Text(
              'Deconectare',
              style: TextStyle(
                color: _primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonInfoBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final String teacherUid;
  final String teacherUsername;

  const _PersonInfoBox({
    required this.label,
    required this.icon,
    required this.teacherUid,
    required this.teacherUsername,
  });

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty && teacherUsername.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Nedefinit',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (teacherUid.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(teacherUid)
            .snapshots(),
        builder: (context, snapshot) {
          final teacherData = snapshot.data?.data() ?? <String, dynamic>{};
          final teacherName = _resolveDisplayName(
            fullName: teacherData['fullName'],
            username: teacherData['username'],
            fallback: teacherUsername,
          );

          return _buildInfoCard(teacherName);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: teacherUsername.toLowerCase())
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final teacherData = snapshot.hasData && snapshot.data!.docs.isNotEmpty
            ? snapshot.data!.docs.first.data()
            : const <String, dynamic>{};
        final teacherName = _resolveDisplayName(
          fullName: teacherData['fullName'],
          username: teacherData['username'],
          fallback: teacherUsername,
        );

        return _buildInfoCard(teacherName);
      },
    );
  }

  Widget _buildInfoCard(String name) {
    final displayName = name.trim().isEmpty ? 'Nedefinit' : name.trim();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: _outline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayName,
                  style: const TextStyle(
                    color: _onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentInfoBox extends StatelessWidget {
  const _ParentInfoBox();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.family_restroom, color: _primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PÂRINTE / TUTORE',
                    style: TextStyle(
                      color: _outline,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Nedefinit',
                    style: TextStyle(
                      color: _onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final parentIds = List<String>.from(
          userData['parents'] ?? const <String>[],
        ).where((id) => id.trim().isNotEmpty).toList();
        final legacyParentId = (userData['parentUid'] ?? userData['parentId'] ?? '')
            .toString()
            .trim();
        final parentId = parentIds.isNotEmpty ? parentIds.first : legacyParentId;

        if (parentId.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.family_restroom,
                      color: _primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PÂRINTE / TUTORE',
                        style: TextStyle(
                          color: _outline,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Nedefinit',
                        style: TextStyle(
                          color: _onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(parentId)
              .snapshots(),
          builder: (context, parentSnapshot) {
            final parentData =
                parentSnapshot.data?.data() ?? <String, dynamic>{};
            final displayName = _resolveDisplayName(
              fullName: parentData['fullName'],
              username: parentData['username'],
              fallback: parentId,
            );

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.family_restroom,
                        color: _primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PÂRINTE / TUTORE',
                          style: TextStyle(
                            color: _outline,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

String _resolveDisplayName({
  required Object? fullName,
  required Object? username,
  required String fallback,
}) {
  final normalizedFullName = (fullName ?? '').toString().trim();
  if (normalizedFullName.isNotEmpty) {
    return normalizedFullName;
  }

  final normalizedUsername = (username ?? '').toString().trim();
  if (normalizedUsername.isNotEmpty) {
    return normalizedUsername;
  }

  return fallback.trim();
}

class _ScheduleRowData {
  final String dayName;
  final String intervalText;
  final int dayNumber;

  const _ScheduleRowData({
    required this.dayName,
    required this.intervalText,
    required this.dayNumber,
  });
}

List<_ScheduleRowData> _buildScheduleRows(Map<String, dynamic> classData) {
  final result = <_ScheduleRowData>[];
  final schedule = classData['schedule'];

  if (schedule is Map) {
    const dayMap = {
      1: 'Luni',
      2: 'Marți',
      3: 'Miercuri',
      4: 'Joi',
      5: 'Vineri',
    };

    final dayKeys = <int>[];
    for (final key in schedule.keys) {
      final day = int.tryParse(key.toString());
      if (day != null && day >= 1 && day <= 5) {
        dayKeys.add(day);
      }
    }
    dayKeys.sort();

    for (final day in dayKeys) {
      final row = schedule['$day'];
      if (row is Map) {
        final start = (row['start'] ?? '').toString().trim();
        final end = (row['end'] ?? '').toString().trim();
        if (start.isNotEmpty && end.isNotEmpty) {
          result.add(
            _ScheduleRowData(
              dayName: dayMap[day] ?? 'Ziua $day',
              intervalText: '$start - $end',
              dayNumber: day,
            ),
          );
        }
      }
    }
  }

  if (result.isNotEmpty) {
    return result;
  }

  final oldStart = (classData['noExitStart'] ?? '').toString().trim();
  final oldEnd = (classData['noExitEnd'] ?? '').toString().trim();
  final oldDays = classData['noExitDays'];

  if (oldStart.isEmpty || oldEnd.isEmpty || oldDays is! List) {
    return const [];
  }

  const dayMap = {
    1: 'Luni',
    2: 'Marți',
    3: 'Miercuri',
    4: 'Joi',
    5: 'Vineri',
  };

  final normalizedDays = oldDays.whereType<int>().toList()..sort();
  return normalizedDays
      .where((day) => day >= 1 && day <= 5)
      .map(
        (day) => _ScheduleRowData(
          dayName: dayMap[day] ?? 'Ziua $day',
          intervalText: '$oldStart - $oldEnd',
          dayNumber: day,
        ),
      )
      .toList();
}

class _ScheduleRow extends StatelessWidget {
  final String dayName;
  final String intervalText;
  final int rowDayNumber;

  const _ScheduleRow({
    required this.dayName,
    required this.intervalText,
    required this.rowDayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // 1=Mon..7=Sun, but 6=Sat, 7=Sun
    final isToday = rowDayNumber == today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? _primary : _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            intervalText,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
