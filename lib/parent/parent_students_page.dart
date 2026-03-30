import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

// Data model similar to _OrarViewData from orar.dart
class _StudentProfileData {
  final String uid;
  final String fullName;
  final String username;
  final String role;
  final String classId;
  final String teacherName;
  final Map<int, Map<String, String>> schedule;
  final bool inSchool;

  const _StudentProfileData({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.role,
    required this.classId,
    required this.teacherName,
    required this.schedule,
    required this.inSchool,
  });

}

class ParentStudentsPage extends StatefulWidget {
  const ParentStudentsPage({super.key});

  @override
  State<ParentStudentsPage> createState() => _ParentStudentsPageState();
}

class _ParentStudentsPageState extends State<ParentStudentsPage> {
  late final Future<List<_StudentProfileData>> _childrenDataFuture;

  @override
  void initState() {
    super.initState();
    _childrenDataFuture = _loadChildrenData();
  }

  // This function is almost identical to _loadData in orar.dart, but takes a uid
  Future<_StudentProfileData> _loadStudentData(String studentUid) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .get();
    if (!userDoc.exists) {
      throw Exception('Profilul elevului cu UID $studentUid nu a fost găsit.');
    }

    final userData = userDoc.data() ?? <String, dynamic>{};
    final username = (userData['username'] ?? '').toString().trim();
    final fullName = (userData['fullName'] ?? '').toString().trim();
    final role = (userData['role'] ?? '').toString().trim();
    final classId = (userData['classId'] ?? '').toString().trim().toUpperCase();
    final inSchool = (userData['inSchool'] ?? false) as bool;
    var teacherName = 'N/A';

    Map<int, Map<String, String>> schedule = {};

    if (classId.isNotEmpty) {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data() ?? <String, dynamic>{};

        // New schedule format
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

        // Fallback to old format
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

        final teacherUsername =
            (classData['teacherUsername'] ?? '').toString().trim().toLowerCase();
        if (teacherUsername.isNotEmpty) {
          final teacherQuery = await FirebaseFirestore.instance
              .collection('users')
              .where('username', isEqualTo: teacherUsername)
              .limit(1)
              .get();
          if (teacherQuery.docs.isNotEmpty) {
            final teacherData = teacherQuery.docs.first.data();
            teacherName =
                (teacherData['fullName'] ?? teacherUsername).toString();
          }
        }
      }
    }

    return _StudentProfileData(
      uid: studentUid,
      fullName: fullName,
      username: username,
      role: role,
      classId: classId,
      teacherName: teacherName,
      schedule: schedule,
      inSchool: inSchool,
    );
  }

  Future<List<_StudentProfileData>> _loadChildrenData() async {
    final parentUid = AppSession.uid;
    if (parentUid == null || parentUid.isEmpty) {
      throw Exception('Părinte neautentificat.');
    }

    final parentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .get();
    if (!parentDoc.exists) {
      throw Exception('Profilul părintelui nu a fost găsit.');
    }

    final parentData = parentDoc.data() ?? {};
    final childrenUids = List<String>.from(parentData['children'] ?? []);

    if (childrenUids.isEmpty) {
      return [];
    }

    final childrenFutures =
        childrenUids.map((uid) => _loadStudentData(uid)).toList();
    return await Future.wait(childrenFutures);
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Elevi',
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA), // Background nou
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: FutureBuilder<List<_StudentProfileData>>(
            future: _childrenDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Eroare: ${snapshot.error}',
                      textAlign: TextAlign.center),
                ));
              }
              final childrenData = snapshot.data;
              if (childrenData == null || childrenData.isEmpty) {
                return const Center(
                    child: Text('Nu este atribuit niciun elev.', style: TextStyle(fontSize: 18, color: Colors.grey)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: childrenData.length,
                separatorBuilder: (context, index) => const SizedBox(height: 24),
                itemBuilder: (context, index) {
                  return _StudentSummaryButton(
                    data: childrenData[index],
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudentDetailsPage(data: childrenData[index]),
                        ),
                      );
                    },
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

class _StudentSummaryButton extends StatelessWidget {
  final _StudentProfileData data;
  final VoidCallback onTap;

  const _StudentSummaryButton({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName =
        data.fullName.isNotEmpty ? data.fullName : data.username;

    return _BouncingButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E3B4E).withOpacity(0.09),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Icon + Name + Class
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCEED5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person, size: 32, color: Color(0xFF6C7D62)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F252B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Clasa: ${data.classId.isNotEmpty ? data.classId : 'N/A'}",
                        style: const TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
              ],
            ),

            Divider(
              color: const Color(0xFF2E3B4E).withOpacity(0.18),
              thickness: 2,
              height: 32,
            ),

            // Statusul elevului
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Statusul elevului:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E3B4E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(data.uid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        bool isInSchool = false;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          final d = snapshot.data!.data() as Map<String, dynamic>;
                          isInSchool = d['inSchool'] == true;
                        }

                        final color = isInSchool ? const Color(0xFF4B78D2) : Colors.red;
                        final text = isInSchool ? 'În incintă' : 'În afara incintei';
                        final icon = isInSchool ? Icons.school_rounded : Icons.logout_rounded;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: color, size: 15),
                              const SizedBox(width: 5),
                              Text(
                                text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  double _scale = 1.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {
        _scale = 0.95;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        Future.delayed(const Duration(milliseconds: 100), widget.onTap);
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _isPressed ? 0.2 : 0.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}




class StudentDetailsPage extends StatelessWidget {
  final _StudentProfileData data;

  const StudentDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty ? data.fullName : data.username;

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        toolbarHeight: 68,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA), // Background nou
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _StudentProfileCard(data: data),
          ),
        ),
      ),
    );
  }
}

class _StudentProfileCard extends StatelessWidget {
  final _StudentProfileData data;

  const _StudentProfileCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty ? data.fullName : data.username;
    final scheduleRows = _buildScheduleRows(data);

    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
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
                      child: const Icon(Icons.person,
                          size: 56, color: Color(0xFF6C7D62)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (displayName.isNotEmpty)
                            Text(
                              displayName,
                              style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
                                  color: Color(0xFF171717)),
                            ),
                          const SizedBox(height: 8),
                          if (data.classId.isNotEmpty)
                            Text('Clasa: ${data.classId}',
                                style: const TextStyle(
                                    fontSize: 20, color: Color(0xFF303030))),
                          if (data.classId.isNotEmpty)
                            Text('Diriginte: ${data.teacherName}',
                                style: const TextStyle(
                                    fontSize: 20, color: Color(0xFF303030))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: const Color(0xFFB8B8B8)),
                const SizedBox(height: 8),
                if (data.username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Username: ${data.username}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF333333))),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF2E3B4E).withOpacity(0.22),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E3B4E).withOpacity(0.09),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status elevului
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Statusul elevului:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3B4E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(data.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                      final inSchool = userData['inSchool'] == true;
                      
                      final color = inSchool ? const Color(0xFF4B78D2) : Colors.red;
                      final text = inSchool ? 'În incintă' : 'În afara incintei';
                      final icon = inSchool ? Icons.school_rounded : Icons.logout_rounded;

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, color: color, size: 15),
                            const SizedBox(width: 5),
                            Text(
                              text,
                              style: TextStyle(
                                fontSize: 14,
                                color: color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              Divider(
                color: const Color(0xFF2E3B4E).withOpacity(0.18),
                thickness: 2,
                height: 16,
              ),
              // Ultima scanare
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Ultima scanare:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3B4E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('accessEvents')
                          .where('userId', isEqualTo: data.uid)
                          .orderBy('timestamp', descending: true)
                          .limit(1)
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Text(
                            'Niciuna',
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF2E3B4E).withOpacity(0.45),
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        }
                        final doc = docs.first;
                        final docData = doc.data() as Map<String, dynamic>;
                        final type = (docData['type'] ?? '').toString();
                        final ts = (docData['timestamp'] as Timestamp?);
                        final dateStr = ts != null
                            ? '${ts.toDate().day.toString().padLeft(2, '0')}.${ts.toDate().month.toString().padLeft(2, '0')}.${ts.toDate().year} ${ts.toDate().hour.toString().padLeft(2, '0')}:${ts.toDate().minute.toString().padLeft(2, '0')}'
                            : '';
                        final scanColor = type == 'entry'
                            ? const Color(0xFF17B5A8)
                            : type == 'exit'
                                ? const Color(0xFFE47E2D)
                                : const Color(0xFF4B78D2);
                        final scanIcon = type == 'entry'
                            ? Icons.login_rounded
                            : type == 'exit'
                                ? Icons.logout_rounded
                                : Icons.qr_code_scanner_rounded;

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scanColor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: scanColor, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(scanIcon, color: scanColor, size: 15),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scanColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Divider(
                color: const Color(0xFF2E3B4E).withOpacity(0.18),
                thickness: 2,
                height: 16,
              ),
              // Cereri de învoire
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Cereri de învoire:',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E3B4E),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leaveRequests')
                          .where('studentUid', isEqualTo: data.uid)
                          .where('status', whereIn: ['approved', 'pending'])
                          .snapshots(),
                      builder: (context, snapshot) {
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.any((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'approved')) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF4CAF50), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Color(0xFF4CAF50), size: 15),
                                const SizedBox(width: 5),
                                const Flexible(
                                  child: Text(
                                    'Invoire activă',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF388E3C),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else if (docs.isNotEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF17B5A8).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF17B5A8), width: 1.2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.hourglass_top_rounded, color: Color(0xFF17B5A8), size: 15),
                                const SizedBox(width: 5),
                                const Flexible(
                                  child: Text(
                                    'Cerere în așteptare',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF17B5A8),
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return Text(
                            'Niciuna',
                            style: TextStyle(
                              fontSize: 15,
                              color: const Color(0xFF2E3B4E).withOpacity(0.45),
                              fontWeight: FontWeight.w400,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text('Orar',
            style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w800,
                color: Color(0xFF161616))),
        const SizedBox(height: 12),
        if (scheduleRows.isEmpty)
          const Text('Nu exista orar definit pentru acest elev.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Color(0xFF333333))),
        for (final row in scheduleRows) ...[
          _OrarRow(day: row.dayName, interval: row.intervalText),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _ScheduleRowData {
  final String dayName;
  final String intervalText;
  const _ScheduleRowData({required this.dayName, required this.intervalText});
}

List<_ScheduleRowData> _buildScheduleRows(_StudentProfileData data) {
  if (data.schedule.isEmpty) return const [];
  const dayMap = {1: 'Luni', 2: 'Marți', 3: 'Miercuri', 4: 'Joi', 5: 'Vineri'};
  final sortedDays = data.schedule.keys.toList()..sort();
  return sortedDays.map((dayNum) {
    final dayName = dayMap[dayNum] ?? 'Ziua $dayNum';
    final times = data.schedule[dayNum];
    final start = times?['start'] ?? 'N/A';
    final end = times?['end'] ?? 'N/A';
    return _ScheduleRowData(dayName: dayName, intervalText: '$start - $end');
  }).toList();
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
              Text(day,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1C1C1C))),
              const Spacer(),
              Text(interval,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1C1C1C))),
            ],
          ),
        ),
      ),
    );
  }
}