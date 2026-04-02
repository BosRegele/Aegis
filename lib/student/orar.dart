import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/student/logout_dialog.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0D631B);
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
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: _surface,
      softSurfaceColor: _surfaceContainerHigh,
      titleColor: _onSurface,
      messageColor: _outline,
      dangerColor: const Color(0xFF8E3557),
    );
    if (!shouldLogout) return;
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
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
            final fullName = (userData['fullName'] ?? '').toString().trim();
            final classId = (userData['classId'] ?? '').toString().trim();
            final className = (userData['className'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty ? fullName : fallbackName;

            final resolvedClassName = className.isNotEmpty
                ? className
                : (classId.isNotEmpty ? classId : 'Clasa necunoscută');

            final classStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .snapshots()
                : null;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData =
                    classSnapshot.data?.data() ?? const <String, dynamic>{};

                final scheduleRows = _buildScheduleRows(classData);
                final teacherUid = (classData['teacherUid'] ?? '')
                    .toString()
                    .trim();
                final teacherUsername = (classData['teacherUsername'] ?? '')
                    .toString()
                    .trim();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrarHeroHeader(onBack: _goBack, onLogout: _logout),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                              child: _ProfileIdentityCard(
                                displayName: displayName,
                                className: resolvedClassName,
                                teacherUid: teacherUid,
                                teacherUsername: teacherUsername,
                                onLogout: _logout,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  18,
                                ),
                                decoration: BoxDecoration(
                                  color: _surfaceLowest,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _outlineVariant.withValues(
                                      alpha: 0.18,
                                    ),
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
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
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

class _OrarHeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Future<void> Function() onLogout;

  const _OrarHeroHeader({required this.onBack, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    final titleSize = compact ? 29.0 : 33.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: headerHeight,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -52,
              child: _Circle(size: 220, opacity: 0.08),
            ),
            Positioned(
              top: 44,
              right: 34,
              child: _Circle(size: 72, opacity: 0.07),
            ),
            Positioned(
              left: 156,
              bottom: -28,
              child: _Circle(size: 82, opacity: 0.08),
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
                        'Profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
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

class _ProfileIdentityCard extends StatelessWidget {
  final String displayName;
  final String className;
  final String teacherUid;
  final String teacherUsername;
  final VoidCallback onLogout;

  const _ProfileIdentityCard({
    required this.displayName,
    required this.className,
    required this.teacherUid,
    required this.teacherUsername,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(38),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D631B),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
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
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 31,
                            fontWeight: FontWeight.w800,
                            height: 1.05,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clasa $className',
                          style: const TextStyle(
                            color: _outline,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showSettingsSheet(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: _primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(height: 1, color: const Color(0xFFF0F1EA)),
              const SizedBox(height: 22),
              _PersonInfoBox(
                label: 'DIRIGINTE',
                icon: Icons.school,
                teacherUid: teacherUid,
                teacherUsername: teacherUsername,
              ),
              const SizedBox(height: 12),
              const _ParentInfoBox(),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(onLogout: onLogout),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final VoidCallback onLogout;
  const _SettingsSheet({required this.onLogout});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Setări cont',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.edit_outlined,
            label: 'Editare profil',
            onTap: () {
              Navigator.pop(ctx);
              _showEditProfileSheet(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Deconectează-te',
            danger: true,
            onTap: () {
              Navigator.pop(ctx);
              onLogout();
            },
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(),
    );
  }
}

class _EditProfileSheet extends StatefulWidget {
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) {
          _controller.text = (doc.data()?['fullName'] ?? '').toString();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'fullName': _controller.text.trim(),
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil actualizat.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text(
            'Editare profil',
            style: TextStyle(
              color: _onSurface,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'NUME COMPLET',
            style: TextStyle(
              color: _outline,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            autofocus: true,
            style: const TextStyle(color: _onSurface, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: _surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Salvează',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFF8E3557) : _primary;
    return Material(
      color: danger
          ? const Color(0xFF8E3557).withValues(alpha: 0.07)
          : _surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: _primary, size: 28),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _outline,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
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
      return _ProfileDetailRow(label: label, value: 'Nedefinit', icon: icon);
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

    return _ProfileDetailRow(label: label, value: displayName, icon: icon);
  }
}

class _ParentInfoBox extends StatelessWidget {
  const _ParentInfoBox();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return const _ProfileDetailRow(
        label: 'PÂRINTE / TUTORE',
        value: 'Nedefinit',
        icon: Icons.family_restroom,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final parentIds = List<String>.from(
          userData['parents'] ?? const <String>[],
        ).where((id) => id.trim().isNotEmpty).toList();
        final legacyParentId =
            (userData['parentUid'] ?? userData['parentId'] ?? '')
                .toString()
                .trim();
        final parentId = parentIds.isNotEmpty
            ? parentIds.first
            : legacyParentId;

        if (parentId.isEmpty) {
          return const _ProfileDetailRow(
            label: 'PÂRINTE / TUTORE',
            value: 'Nedefinit',
            icon: Icons.family_restroom,
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

            return _ProfileDetailRow(
              label: 'PÂRINTE / TUTORE',
              value: displayName,
              icon: Icons.family_restroom,
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

  const dayMap = {1: 'Luni', 2: 'Marți', 3: 'Miercuri', 4: 'Joi', 5: 'Vineri'};

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
