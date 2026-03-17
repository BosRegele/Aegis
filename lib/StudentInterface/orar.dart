import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

class OrarScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const OrarScreen({super.key, this.onBackToHome});

  @override
  State<OrarScreen> createState() => _OrarScreenState();
}

class _OrarScreenState extends State<OrarScreen> {
  late final Future<_OrarViewData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          backgroundColor: const Color(0xFFE6EBEE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Confirmare logout',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF223127),
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: const [
              SizedBox(height: 4),
              Text(
                'Esti sigur ca vrei sa iesi din cont?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF3A4A3F),
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  height: 1.2,
                ),
              ),
              SizedBox(height: 12),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: 120,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7AAF5B),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                child: const Text('Anuleaza'),
              ),
            ),
            SizedBox(
              width: 120,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7AAF5B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
      AppSession.clear();
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu am putut face logout. Incearca din nou.'),
        ),
      );
    }
  }

  Future<_OrarViewData> _loadData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Utilizator neautentificat');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!userDoc.exists) {
      throw Exception('Profilul utilizatorului nu exista in Firestore');
    }

    final userData = userDoc.data() ?? <String, dynamic>{};
    final username = (userData['username'] ?? '').toString().trim();
    final fullName = (userData['fullName'] ?? '').toString().trim();
    final role = (userData['role'] ?? '').toString().trim();
    final classId = (userData['classId'] ?? '').toString().trim().toUpperCase();
    var teacherName = 'N/A';

    Map<int, Map<String, String>> schedule =
        {}; // {dayNum: {start: "HH:mm", end: "HH:mm"}}

    if (classId.isNotEmpty) {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data() ?? <String, dynamic>{};

        // Try to read new per-day schedule format
        final scheduleData = classData['schedule'];
        if (scheduleData is Map) {
          for (final entry in scheduleData.entries) {
            final dayNum = int.tryParse(entry.key.toString());
            if (dayNum != null && dayNum >= 1 && dayNum <= 5) {
              final times = entry.value;
              if (times is Map) {
                final start = times['start']?.toString() ?? '';
                final end = times['end']?.toString() ?? '';
                if (start.isNotEmpty && end.isNotEmpty) {
                  schedule[dayNum] = {'start': start, 'end': end};
                }
              }
            }
          }
        }

        // Fallback to old format if new format doesn't exist
        if (schedule.isEmpty) {
          final start = (classData['noExitStart'] ?? '').toString().trim();
          final end = (classData['noExitEnd'] ?? '').toString().trim();
          final rawDays = classData['noExitDays'];

          if (start.isNotEmpty && end.isNotEmpty && rawDays is List) {
            for (final day in rawDays) {
              if (day is int && day >= 1 && day <= 5) {
                schedule[day] = {'start': start, 'end': end};
              }
            }
          }
        }

        final teacherUsername = (classData['teacherUsername'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        if (teacherUsername.isNotEmpty) {
          final teacherByUsername = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: teacherUsername)
              .limit(1)
              .get();

          if (teacherByUsername.docs.isNotEmpty) {
            final teacherData = teacherByUsername.docs.first.data();
            final teacherFullName = (teacherData['fullName'] ?? '')
                .toString()
                .trim();
            teacherName = teacherFullName.isNotEmpty
                ? teacherFullName
                : teacherUsername;
          } else {
            final teacherDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(teacherUsername)
                .get();

            if (teacherDoc.exists) {
              final teacherData = teacherDoc.data() ?? <String, dynamic>{};
              final teacherFullName = (teacherData['fullName'] ?? '')
                  .toString()
                  .trim();
              teacherName = teacherFullName.isNotEmpty
                  ? teacherFullName
                  : teacherUsername;
            }
          }
        }
      }
    }

    return _OrarViewData(
      fullName: fullName,
      username: username,
      role: role,
      classId: classId,
      teacherName: teacherName,
      schedule: schedule,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        toolbarHeight: 68,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            if (widget.onBackToHome != null) {
              widget.onBackToHome!();
              return;
            }

            Navigator.of(context).pop();
          },
        ),
        title: const Text(
          'Profil',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFE6EBEE),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: FutureBuilder<_OrarViewData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Text(
                          'Eroare la incarcare profil/orar:\n${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final data = snapshot.data;
                  if (data == null) {
                    return const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: Center(child: Text('Nu exista date disponibile.')),
                    );
                  }

                  final displayName = data.fullName.isNotEmpty
                      ? data.fullName
                      : (data.username.isNotEmpty
                            ? data.username
                            : (AppSession.username ?? '').trim());
                  final scheduleRows = _buildScheduleRows(data);

                  return Column(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 98,
                                    height: 106,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFDCEED5),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 56,
                                      color: Color(0xFF6C7D62),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (displayName.isNotEmpty)
                                          Text(
                                            displayName,
                                            style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w800,
                                              height: 1.0,
                                              color: Color(0xFF171717),
                                            ),
                                          ),
                                        if (data.role.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Statut: ${data.role}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF303030),
                                            ),
                                          ),
                                        ],
                                        if (data.classId.isNotEmpty)
                                          Text(
                                            'Clasa: ${data.classId}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF303030),
                                            ),
                                          ),
                                        if (data.classId.isNotEmpty)
                                          Text(
                                            'Diriginte: ${data.teacherName}',
                                            style: const TextStyle(
                                              fontSize: 20,
                                              color: Color(0xFF303030),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 1,
                                color: const Color(0xFFB8B8B8),
                              ),
                              const SizedBox(height: 8),
                              if (data.username.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Username: ${data.username}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Orar',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF161616),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (scheduleRows.isEmpty)
                        const Text(
                          'Nu exista orar definit pe server pentru clasa ta.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFF333333),
                          ),
                        ),
                      for (final row in scheduleRows) ...[
                        _OrarRow(day: row.dayName, interval: row.intervalText),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

List<_ScheduleRowData> _buildScheduleRows(_OrarViewData data) {
  if (data.schedule.isEmpty) {
    return const [];
  }

  const dayMap = {1: 'Luni', 2: 'Marți', 3: 'Miercuri', 4: 'Joi', 5: 'Vineri'};

  // Sort by day number and build rows
  final sortedDays = data.schedule.keys.toList()..sort();
  return sortedDays.map((dayNum) {
    final dayName = dayMap[dayNum] ?? 'Ziua $dayNum';
    final times = data.schedule[dayNum];
    final start = times?['start'] ?? '07:30';
    final end = times?['end'] ?? '13:00';
    final intervalText = '$start - $end';
    return _ScheduleRowData(dayName: dayName, intervalText: intervalText);
  }).toList();
}

class _ScheduleRowData {
  final String dayName;
  final String intervalText;

  const _ScheduleRowData({required this.dayName, required this.intervalText});
}

class _OrarViewData {
  final String fullName;
  final String username;
  final String role;
  final String classId;
  final String teacherName;
  final Map<int, Map<String, String>> schedule;

  const _OrarViewData({
    required this.fullName,
    required this.username,
    required this.role,
    required this.classId,
    required this.teacherName,
    required this.schedule,
  });
}

class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;

  const _OrarRow({required this.day, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.90,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFBAC7B8),
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Text(
                day,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1C1C1C),
                ),
              ),
              const Spacer(),
              Text(
                interval,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1C1C1C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
