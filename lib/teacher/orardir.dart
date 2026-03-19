import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class OrarDirPage extends StatefulWidget {
  const OrarDirPage({super.key});

  @override
  State<OrarDirPage> createState() => _OrarDirPageState();
}

class _OrarDirPageState extends State<OrarDirPage> {
  static const _dayMap = {
    1: 'Luni',
    2: 'Marți',
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
      backgroundColor: const Color(0xFFE6EBEE),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Orar', style: TextStyle(color: Colors.white)),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
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

          final userData = userSnap.data!.data() as Map<String, dynamic>? ?? {};
          final classId = (userData['classId'] ?? '').toString().trim();

          if (classId.isEmpty) {
            return const Center(child: Text('Nu ai clasa asignată.'));
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('classes')
                .doc(classId)
                .get(),
            builder: (context, classSnap) {
              if (classSnap.hasError) {
                return Center(child: Text('Eroare: ${classSnap.error}'));
              }
              if (!classSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final classData =
                  classSnap.data!.data() as Map<String, dynamic>? ?? {};
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
              final today = DateTime.now().weekday; // 1=Mon..7=Sun
              final todaySchedule = schedule[today];
              final now = DateTime.now();
              final dayNames = {
                1: 'Luni',
                2: 'Marți',
                3: 'Miercuri',
                4: 'Joi',
                5: 'Vineri',
                6: 'Sâmbătă',
                7: 'Duminică',
              };
              final todayName = dayNames[today] ?? '';
              final dateStr =
                  '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  children: [
                    // "Azi" card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7AAF5B), Color(0xFF4E8A3A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7AAF5B).withOpacity(0.30),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.20),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.today_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Azi — $todayName, $dateStr',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  todaySchedule != null
                                      ? '${todaySchedule['start']} – ${todaySchedule['end']}'
                                      : 'Fără orar azi',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.90),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Orar',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E3B4E),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (sortedDays.isEmpty)
                      const Text(
                        'Nu există orar definit pentru clasa ta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF5F6771),
                        ),
                      )
                    else
                      for (final dayNum in sortedDays) ...[
                        _OrarRow(
                          day: _dayMap[dayNum] ?? 'Ziua $dayNum',
                          interval:
                              '${schedule[dayNum]!['start']} - ${schedule[dayNum]!['end']}',
                          isToday: dayNum == today,
                        ),
                        const SizedBox(height: 10),
                      ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;
  final bool isToday;

  const _OrarRow({
    required this.day,
    required this.interval,
    this.isToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isToday ? const Color(0xFF7AAF5B) : const Color(0xFFBAC7B8);
    final textColor = isToday ? Colors.white : const Color(0xFF1C1C1C);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isToday
            ? [
                BoxShadow(
                  color: const Color(0xFF7AAF5B).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          if (isToday) ...[
            const Icon(
              Icons.arrow_right_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 2),
          ],
          Text(
            day,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
          const Spacer(),
          Text(
            interval,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
