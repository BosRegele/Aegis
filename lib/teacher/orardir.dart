import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class OrarDirPage extends StatefulWidget {
  const OrarDirPage({super.key});

  @override
  State<OrarDirPage> createState() => _OrarDirPageState();
}

class _OrarDirPageState extends State<OrarDirPage> {
  DateTime _selectedDay = DateTime.now();

  static const List<String> _dayNames = [
    'Luni',
    'Marți',
    'Miercuri',
    'Joi',
    'Vineri',
    'Sâmbătă',
    'Duminică',
  ];

  String get _selectedDayName => _dayNames[_selectedDay.weekday - 1];

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text('No session')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        title: const Text('Orar', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('users')
            .doc(teacherUid)
            .get(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Eroare: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text('Teacher not found'));
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final classId = (data['classId'] ?? '').toString().trim();
          final displayName =
              (data['fullName'] ?? AppSession.username ?? teacherUid)
                  .toString();

          if (classId.isEmpty) {
            return const Center(child: Text('Nu ai clasa asignata.'));
          }

          return _OrarContent(
            classId: classId,
            displayName: displayName,
            selectedDay: _selectedDay,
            selectedDayName: _selectedDayName,
            formattedDate: _formatDate(_selectedDay),
            onPickDay: () => _pickDay(context),
          );
        },
      ),
    );
  }
}

class _OrarContent extends StatelessWidget {
  final String classId;
  final String displayName;
  final DateTime selectedDay;
  final String selectedDayName;
  final String formattedDate;
  final VoidCallback onPickDay;

  const _OrarContent({
    required this.classId,
    required this.displayName,
    required this.selectedDay,
    required this.selectedDayName,
    required this.formattedDate,
    required this.onPickDay,
  });

  @override
  Widget build(BuildContext context) {
    // Orarul e stocat in Firestore la schedule/{classId}/days/{dayName}
    // unde dayName este ex. "Luni", "Marți" etc.
    // Document contine un array 'lessons': [{subject, startTime, endTime, teacher}, ...]
    final dayDocRef = FirebaseFirestore.instance
        .collection('schedule')
        .doc(classId)
        .collection('days')
        .doc(selectedDayName);

    return FutureBuilder<DocumentSnapshot>(
      future: dayDocRef.get(),
      builder: (context, snap) {
        List<Map<String, dynamic>>? lessons;
        bool loading = !snap.hasData && !snap.hasError;

        if (snap.hasData && snap.data!.exists) {
          final d = snap.data!.data() as Map<String, dynamic>;
          final raw = d['lessons'];
          if (raw is List) {
            lessons = raw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day selector
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: onPickDay,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          color: Color.fromRGBO(122, 175, 91, 1),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '$selectedDayName, $formattedDate',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Orarul clasei — $selectedDayName',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF161616),
                ),
              ),
              const SizedBox(height: 12),
              if (loading)
                const Center(child: CircularProgressIndicator())
              else if (snap.hasError)
                Text('Eroare: ${snap.error}')
              else if (lessons == null || lessons.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'Orarul nu este disponibil',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              else
                ...lessons.map((lesson) {
                  final subject = (lesson['subject'] ?? lesson['materie'] ?? '')
                      .toString();
                  final start =
                      (lesson['startTime'] ?? lesson['ora_inceput'] ?? '')
                          .toString();
                  final end = (lesson['endTime'] ?? lesson['ora_sfarsit'] ?? '')
                      .toString();
                  final teacherName =
                      (lesson['teacher'] ?? lesson['profesor'] ?? '')
                          .toString();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _OrarRow(
                      subject: subject,
                      interval: start.isNotEmpty && end.isNotEmpty
                          ? '$start - $end'
                          : start,
                      teacher: teacherName,
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _OrarRow extends StatelessWidget {
  final String subject;
  final String interval;
  final String teacher;

  const _OrarRow({
    required this.subject,
    required this.interval,
    this.teacher = '',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1C1C1C),
                  ),
                ),
                if (teacher.isNotEmpty)
                  Text(
                    teacher,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
              ],
            ),
          ),
          Text(
            interval,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color.fromRGBO(122, 175, 91, 1),
            ),
          ),
        ],
      ),
    );
  }
}
