import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'account_bottom_sheet.dart';

const _kOrarHeaderGreen = Color(0xFF0D631B);
const _kOrarPageBg = Color(0xFFF7F9F0);

// ─── Roman numeral helpers ────────────────────────────────────────────────────

String _toRoman(int n) {
  if (n <= 0) return n.toString();
  const vals = [10, 9, 5, 4, 1];
  const syms = ['X', 'IX', 'V', 'IV', 'I'];
  var result = '';
  var num = n;
  for (var i = 0; i < vals.length; i++) {
    while (num >= vals[i]) {
      result += syms[i];
      num -= vals[i];
    }
  }
  return result;
}

String _classToRoman(String classId) {
  final match = RegExp(r'^(\d+)([A-Za-z]*)$').firstMatch(classId.trim());
  if (match == null) return classId;
  final num = int.tryParse(match.group(1) ?? '') ?? 0;
  final letter = (match.group(2) ?? '').toUpperCase();
  final roman = _toRoman(num);
  return letter.isNotEmpty ? 'a $roman-a $letter' : 'a $roman-a';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class OrarDirPage extends StatefulWidget {
  const OrarDirPage({super.key});

  @override
  State<OrarDirPage> createState() => _OrarDirPageState();
}

class _OrarDirPageState extends State<OrarDirPage> {
  static const _dayMap = {
    1: 'Luni',
    2: 'Marti',
    3: 'Miercuri',
    4: 'Joi',
    5: 'Vineri',
  };

  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: _kOrarPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _OrarTopHeader(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(teacherUid)
                    .snapshots(),
                builder: (context, userSnap) {
                  if (userSnap.hasError) {
                    return Center(child: Text('Eroare: ${userSnap.error}'));
                  }
                  if (!userSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final fullName = (userData['fullName'] ?? '')
                      .toString()
                      .trim();
                  final classId = (userData['classId'] ?? '').toString().trim();
                  final email = (userData['personalEmail'] ?? '')
                      .toString()
                      .trim();
                  final username = (userData['username'] ?? '')
                      .toString()
                      .trim();
                  final displayName = fullName.isNotEmpty
                      ? fullName
                      : (AppSession.username ?? 'Profesor');

                  if (classId.isEmpty) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                      child: _TeacherProfileCard(
                        displayName: displayName,
                        classRoman: '',
                        email: email,
                        username: username,
                        studentCount: null,
                        onSettings: () => showAccountBottomSheet(context),
                      ),
                    );
                  }

                  return StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classes')
                        .doc(classId)
                        .snapshots(),
                    builder: (context, classSnap) {
                      if (classSnap.hasError) {
                        return Center(
                          child: Text('Eroare: ${classSnap.error}'),
                        );
                      }
                      if (!classSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final classData =
                          classSnap.data!.data() as Map<String, dynamic>? ?? {};
                      final className = (classData['name'] ?? classId)
                          .toString()
                          .trim();
                      final modul =
                          (classData['modul'] ?? classData['module'] ?? '')
                              .toString()
                              .trim();
                      final scheduleRaw = classData['schedule'];

                      final Map<int, Map<String, String>> schedule = {};
                      if (scheduleRaw is Map) {
                        for (final entry in scheduleRaw.entries) {
                          final dayNum = int.tryParse(entry.key.toString());
                          if (dayNum != null && dayNum >= 1 && dayNum <= 5) {
                            final times = entry.value;
                            if (times is Map) {
                              final start = (times['start'] ?? '').toString();
                              final end = (times['end'] ?? '').toString();
                              if (start.isNotEmpty && end.isNotEmpty) {
                                schedule[dayNum] = {'start': start, 'end': end};
                              }
                            }
                          }
                        }
                      }

                      final sortedDays = schedule.keys.toList()..sort();
                      final rawId = className.isNotEmpty ? className : classId;
                      final classRoman = _classToRoman(rawId);

                      return FutureBuilder<QuerySnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('users')
                            .where('classId', isEqualTo: classId)
                            .where('role', isEqualTo: 'student')
                            .get(),
                        builder: (context, studentsSnap) {
                          final studentCount = studentsSnap.hasData
                              ? studentsSnap.data!.docs.length
                              : null;

                          return SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _TeacherProfileCard(
                                  displayName: displayName,
                                  classRoman: classRoman,
                                  email: email,
                                  username: username,
                                  studentCount: studentCount,
                                  onSettings: () =>
                                      showAccountBottomSheet(context),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    18,
                                    18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFC8D1C2,
                                      ).withValues(alpha: 0.18),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            classRoman.isNotEmpty
                                                ? 'Orar Clasa $classRoman'
                                                : 'Orar Săptămanal',
                                            style: const TextStyle(
                                              color: Color(0xFF151A14),
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const Spacer(),
                                          if (modul.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 7,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFDAEDD9),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                modul,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF1A601F),
                                                  height: 1,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 14),
                                      if (sortedDays.isEmpty)
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF0F4E9),
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: const Text(
                                            'Nu există orar definit pentru clasa ta.',
                                            style: TextStyle(
                                              color: Color(0xFF717B6E),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        )
                                      else
                                        for (final dayNum in sortedDays) ...[
                                          _OrarRow(
                                            day:
                                                _dayMap[dayNum] ??
                                                'Ziua $dayNum',
                                            interval:
                                                '${schedule[dayNum]!['start']} - ${schedule[dayNum]!['end']}',
                                          ),
                                          const SizedBox(height: 10),
                                        ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Teacher Profile Card ─────────────────────────────────────────────────────

class _TeacherProfileCard extends StatelessWidget {
  final String displayName;
  final String classRoman;
  final String email;
  final String username;
  final int? studentCount;
  final VoidCallback onSettings;

  const _TeacherProfileCard({
    required this.displayName,
    required this.classRoman,
    required this.email,
    required this.username,
    required this.studentCount,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(38)),
          boxShadow: [
            BoxShadow(
              color: Color(0x120D631B),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top row: name + settings ──────────────────────────────────
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
                            color: Color(0xFF151A14),
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        if (username.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: Color(0xFF0D631B),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onSettings,
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4E9),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: Color(0xFF0D631B),
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Container(height: 1, color: const Color(0xFFF0F1EA)),
              const SizedBox(height: 18),
              // ── Info boxes ────────────────────────────────────────────────
              _InfoBox(
                icon: Icons.mail_outline_rounded,
                label: 'EMAIL',
                value: email.isNotEmpty ? email : 'Nedefinit',
              ),
              const SizedBox(height: 10),
              _InfoBox(
                icon: Icons.group_rounded,
                label: 'NR. ELEVI',
                value: studentCount == null ? '...' : '$studentCount elevi',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBox({
    required this.icon,
    required this.label,
    required this.value,
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
            color: const Color(0xFF0D631B).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: const Color(0xFF0D631B), size: 28),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF717B6E),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF151A14),
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

// ─── Header ───────────────────────────────────────────────────────────────────

class _OrarTopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _OrarTopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(54),
        bottomRight: Radius.circular(54),
      ),
      child: Container(
        height: headerHeight,
        width: double.infinity,
        color: _kOrarHeaderGreen,
        child: Stack(
          children: [
            Positioned(top: -72, right: -52, child: _circle(220)),
            Positioned(top: 44, right: 34, child: _circle(72)),
            Positioned(left: 156, bottom: -28, child: _circle(82)),
            Padding(
              padding: EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onBack,
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Center(
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Profil',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 29,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

// ─── Rând zi ──────────────────────────────────────────────────────────────────

class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;

  const _OrarRow({required this.day, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111811),
              height: 1,
            ),
          ),
          const Spacer(),
          Text(
            interval,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D631B),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
