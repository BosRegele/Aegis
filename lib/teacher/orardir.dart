import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kOrarHeaderGreen = Color(0xFF1D5C2B);
const _kOrarPageBg = Color(0xFFFFFFFF);

class OrarDirPage extends StatefulWidget {
  const OrarDirPage({super.key});

  @override
  State<OrarDirPage> createState() => _OrarDirPageState();
}

class _OrarDirPageState extends State<OrarDirPage> {
  static const _dayMap = {
    1: 'Luni',
    2: 'Mar?i',
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
            _OrarTopHeader(
              onBack: () => Navigator.of(context).maybePop(),
              onProfile: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(teacherUid)
                    .get(),
                builder: (context, userSnap) {
                  if (userSnap.hasError) {
                    return Center(child: Text('Eroare: ${userSnap.error}'));
                  }
                  if (!userSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final userData =
                      userSnap.data!.data() as Map<String, dynamic>? ?? {};
                  final classId = (userData['classId'] ?? '').toString().trim();

                  if (classId.isEmpty) {
                    return const Center(child: Text('Nu ai clasa asignata.'));
                  }

                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('classes')
                        .doc(classId)
                        .get(),
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

                      return SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // -- Card clasa ------------------------------
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 22,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F7F1),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFDDE3D6),
                                ),
                              ),
                              child: Text(
                                className.isEmpty ? classId : className,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0E6A1E),
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),
                            // -- Titlu sec?iune + badge modul ------------
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Orar Saptam�nal',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111811),
                                    height: 1,
                                  ),
                                ),
                                const Spacer(),
                                if (modul.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDAEDD9),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      modul,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A601F),
                                        height: 1,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            // -- R�nduri zile ----------------------------
                            if (sortedDays.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 24),
                                child: Center(
                                  child: Text(
                                    'Nu exista orar definit pentru clasa ta.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF5F6771),
                                    ),
                                  ),
                                ),
                              )
                            else
                              for (final dayNum in sortedDays) ...[
                                _OrarRow(
                                  day: _dayMap[dayNum] ?? 'Ziua $dayNum',
                                  interval:
                                      '${schedule[dayNum]!['start']} - ${schedule[dayNum]!['end']}',
                                ),
                                const SizedBox(height: 12),
                              ],
                          ],
                        ),
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

// --- Header ------------------------------------------------------------------

class _OrarTopHeader extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onProfile;

  const _OrarTopHeader({required this.onBack, this.onProfile});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(38)),
      child: SizedBox(
        width: double.infinity,
        height: 90 + topPadding,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Container(color: _kOrarHeaderGreen),
            Positioned(right: -60, top: -60, child: _circle(180)),
            Positioned(right: 120, top: topPadding + 15, child: _circle(55)),
            Positioned(left: -40, bottom: -30, child: _circle(130)),
            if (onProfile != null)
              Positioned(
                top: topPadding,
                right: 14,
                child: Hero(
                  tag: 'teacher-profile-btn',
                  child: GestureDetector(
                    onTap: onProfile,
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
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(4, topPadding - 6, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Orar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      height: 1,
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

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      shape: BoxShape.circle,
    ),
  );
}

// --- R�nd zi ------------------------------------------------------------------

class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;

  const _OrarRow({required this.day, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8DF)),
      ),
      child: Row(
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: Color(0xFF111811),
              height: 1,
            ),
          ),
          const Spacer(),
          Text(
            interval,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w500,
              color: Color(0xFF4A7A52),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}
