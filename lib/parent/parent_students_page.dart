import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);

class ParentStudentViewData {
  final String uid;
  final String fullName;
  final String username;
  final String role;
  final String classId;
  final String teacherName;
  final Map<int, Map<String, String>> schedule;
  final bool inSchool;

  const ParentStudentViewData({
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

class ParentStudentsPage extends StatelessWidget {
  final List<ParentStudentViewData> students;

  const ParentStudentsPage({super.key, this.students = const []});

  @override
  Widget build(BuildContext context) {
    final validStudents = students
        .where((student) => student.uid.trim().isNotEmpty)
        .toList(growable: false);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: validStudents.isNotEmpty
                    ? _buildContent(context, validStudents)
                    : _buildFirebaseContent(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirebaseContent(BuildContext context) {
    final parentUid = (AppSession.uid ?? '').trim();
    if (parentUid.isEmpty) {
      return const Center(
        child: Text(
          'Sesiune invalidă.',
          style: TextStyle(fontSize: 16, color: Color(0xFF7A8077)),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .snapshots(),
      builder: (context, parentSnapshot) {
        if (parentSnapshot.hasError) {
          return const Center(
            child: Text(
              'Nu am putut încărca elevii asignați.',
              style: TextStyle(fontSize: 16, color: Color(0xFF7A8077)),
              textAlign: TextAlign.center,
            ),
          );
        }

        if (!parentSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final parentData =
            parentSnapshot.data?.data() ?? const <String, dynamic>{};

        final studentIds =
            ((parentData['children'] as List? ?? const [])
                  .map((value) => value.toString().trim())
                  .where((value) => value.isNotEmpty && value != parentUid)
                  .toSet()
                  .toList())
              ..sort();

        if (studentIds.isEmpty) {
          return _buildContent(context, const <ParentStudentViewData>[]);
        }

        return FutureBuilder<List<ParentStudentViewData>>(
          future: _loadAssignedStudents(studentIds),
          builder: (context, studentsSnapshot) {
            if (studentsSnapshot.hasError) {
              return const Center(
                child: Text(
                  'Nu am putut încărca datele elevilor.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF7A8077)),
                  textAlign: TextAlign.center,
                ),
              );
            }

            if (!studentsSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return _buildContent(context, studentsSnapshot.data!);
          },
        );
      },
    );
  }

  Future<List<ParentStudentViewData>> _loadAssignedStudents(
    List<String> studentUids,
  ) async {
    final users = FirebaseFirestore.instance.collection('users');
    final teacherNameCache = <String, String>{};
    final resultByUid = <String, ParentStudentViewData>{};

    for (final rawUid in studentUids) {
      final studentUid = rawUid.trim();
      if (studentUid.isEmpty) {
        continue;
      }

      final studentSnapshot = await _resolveStudentDocument(users, studentUid);
      if (studentSnapshot == null || !studentSnapshot.exists) {
        continue;
      }

      final studentData = studentSnapshot.data() ?? <String, dynamic>{};
      final classId = (studentData['classId'] ?? '')
          .toString()
          .trim()
          .toUpperCase();
      final classData = await _loadClassData(classId);
      final displayName = _displayNameFromUserData(
        studentData,
        fallback: studentUid,
      );
      final fullName = (studentData['fullName'] ?? '').toString().trim();
      final username = (studentData['username'] ?? '').toString().trim();

      resultByUid[studentUid] = ParentStudentViewData(
        uid: studentSnapshot.id,
        fullName: fullName.isNotEmpty ? fullName : displayName,
        username: username.isNotEmpty ? username : studentSnapshot.id,
        role: (studentData['role'] ?? '').toString().trim(),
        classId: classId,
        teacherName: await _resolveTeacherName(classData, teacherNameCache),
        schedule: _parseSchedule(classData),
        inSchool: studentData['inSchool'] == true,
      );
    }

    return studentUids
        .map((uid) => resultByUid[uid.trim()])
        .whereType<ParentStudentViewData>()
        .toList(growable: false);
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _resolveStudentDocument(
    CollectionReference<Map<String, dynamic>> users,
    String studentUid,
  ) async {
    try {
      final direct = await users.doc(studentUid).get();
      if (direct.exists) {
        return direct;
      }
    } catch (_) {
      // Try legacy fallbacks below.
    }

    try {
      final byUid = await users
          .where('uid', isEqualTo: studentUid)
          .limit(1)
          .get();
      if (byUid.docs.isNotEmpty) {
        return byUid.docs.first;
      }
    } catch (_) {
      // Continue with other fallbacks.
    }

    try {
      final byUsername = await users
          .where('username', isEqualTo: studentUid)
          .limit(1)
          .get();
      if (byUsername.docs.isNotEmpty) {
        return byUsername.docs.first;
      }
    } catch (_) {
      // No more fallbacks.
    }

    return null;
  }

  Future<Map<String, dynamic>> _loadClassData(String classId) async {
    final normalized = classId.trim().toUpperCase();
    if (normalized.isEmpty) {
      return const <String, dynamic>{};
    }

    final classes = FirebaseFirestore.instance.collection('classes');

    try {
      final directDoc = await classes.doc(normalized).get();
      if (directDoc.exists) {
        return directDoc.data() ?? const <String, dynamic>{};
      }
    } catch (_) {
      // Fall back to query lookup below.
    }

    try {
      final query = await classes
          .where('classId', isEqualTo: normalized)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
    } catch (_) {
      return const <String, dynamic>{};
    }

    return const <String, dynamic>{};
  }

  Future<String> _resolveTeacherName(
    Map<String, dynamic> classData,
    Map<String, String> cache,
  ) async {
    final directName = (classData['teacherName'] ?? '').toString().trim();
    if (directName.isNotEmpty) {
      return directName;
    }

    final teacherUid = (classData['teacherUid'] ?? '').toString().trim();
    if (teacherUid.isNotEmpty) {
      final cached = cache[teacherUid];
      if (cached != null) {
        return cached;
      }

      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherUid)
            .get();
        final teacherData = teacherDoc.data() ?? const <String, dynamic>{};
        final resolved = _displayNameFromUserData(
          teacherData,
          fallback: teacherUid,
        );
        cache[teacherUid] = resolved;
        return resolved;
      } catch (_) {
        return teacherUid;
      }
    }

    final teacherUsername = (classData['teacherUsername'] ?? '')
        .toString()
        .trim();
    if (teacherUsername.isNotEmpty) {
      final cached = cache[teacherUsername];
      if (cached != null) {
        return cached;
      }

      try {
        final teacherDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherUsername)
            .get();

        if (teacherDoc.exists) {
          final resolved = _displayNameFromUserData(
            teacherDoc.data() ?? const <String, dynamic>{},
            fallback: teacherUsername,
          );
          cache[teacherUsername] = resolved;
          return resolved;
        }

        final teacherQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: teacherUsername)
            .limit(1)
            .get();

        if (teacherQuery.docs.isNotEmpty) {
          final resolved = _displayNameFromUserData(
            teacherQuery.docs.first.data(),
            fallback: teacherUsername,
          );
          cache[teacherUsername] = resolved;
          return resolved;
        }
      } catch (_) {
        cache[teacherUsername] = teacherUsername;
        return teacherUsername;
      }

      cache[teacherUsername] = teacherUsername;
      return teacherUsername;
    }

    return 'N/A';
  }

  String _displayNameFromUserData(
    Map<String, dynamic> userData, {
    required String fallback,
  }) {
    final fullName = (userData['fullName'] ?? '').toString().trim();
    if (fullName.isNotEmpty) {
      return fullName;
    }

    final username = (userData['username'] ?? '').toString().trim();
    if (username.isNotEmpty) {
      return username;
    }

    return fallback;
  }

  Map<int, Map<String, String>> _parseSchedule(Map<String, dynamic> classData) {
    final schedule = <int, Map<String, String>>{};
    final rawSchedule = classData['schedule'];

    if (rawSchedule is Map) {
      for (final entry in rawSchedule.entries) {
        final dayNum = int.tryParse(entry.key.toString());
        if (dayNum == null || dayNum < 1 || dayNum > 5) {
          continue;
        }

        final times = entry.value;
        if (times is! Map) {
          continue;
        }

        final start = (times['start'] ?? '').toString().trim();
        final end = (times['end'] ?? '').toString().trim();
        if (start.isEmpty || end.isEmpty) {
          continue;
        }

        schedule[dayNum] = {'start': start, 'end': end};
      }
    }

    if (schedule.isNotEmpty) {
      return schedule;
    }

    final oldStart = (classData['noExitStart'] ?? '').toString().trim();
    final oldEnd = (classData['noExitEnd'] ?? '').toString().trim();
    final oldDays = classData['noExitDays'];
    if (oldStart.isEmpty || oldEnd.isEmpty || oldDays is! List) {
      return schedule;
    }

    for (final day in oldDays) {
      final dayNum = day is int ? day : int.tryParse(day.toString());
      if (dayNum == null || dayNum < 1 || dayNum > 5) {
        continue;
      }
      schedule[dayNum] = {'start': oldStart, 'end': oldEnd};
    }

    return schedule;
  }

  Widget _buildContent(
    BuildContext context,
    List<ParentStudentViewData> validStudents,
  ) {
    if (validStudents.isEmpty) {
      return const Center(
        child: Text(
          'Nu este atribuit niciun elev.',
          style: TextStyle(fontSize: 16, color: Color(0xFF7A8077)),
        ),
      );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 6, bottom: 24),
      itemCount: validStudents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final student = validStudents[index];
        return _StudentSummaryButton(
          data: student,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailsPage(data: student),
            ),
          ),
        );
      },
    );
  }
}

class _TopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TopHeader({required this.onBack});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(46),
        bottomRight: Radius.circular(46),
      ),
      child: SizedBox(
        width: double.infinity,
        height: topPadding + 148,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: _kHeaderGreen)),
            Positioned(right: -46, top: -34, child: _circle(122, 0.12)),
            Positioned(left: 182, top: 104, child: _circle(78, 0.11)),
            Positioned(
              right: 24,
              top: 40 + topPadding,
              child: _circle(66, 0.14),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(22, topPadding + 38, 22, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Copiii mei',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
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

  Widget _circle(double size, double opacity) {
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

class _StudentSummaryButton extends StatelessWidget {
  final ParentStudentViewData data;
  final VoidCallback onTap;

  const _StudentSummaryButton({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty
        ? data.fullName
        : data.username;
    final avatarBg = data.inSchool
        ? const Color(0xFF258635)
        : const Color(0xFFB84777);
    final statusText = data.inSchool ? 'IN INCINTA' : 'IN AFARA INCINTEI';
    final statusColor = data.inSchool
        ? const Color(0xFF0C6F1D)
        : const Color(0xFF952E5C);
    final statusBg = data.inSchool
        ? const Color(0xFFDBEBDD)
        : const Color(0xFFF0E1E8);
    final statusBorder = data.inSchool
        ? const Color(0xFFA9CCAE)
        : const Color(0xFFD2A9BF);

    return _BouncingButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE3E8DF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(displayName),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAEE8AF),
                        height: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111811),
                          height: 1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _classLabel(data.classId),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2A352A),
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusBorder, width: 1.4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 13,
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
              ],
            ),
            const SizedBox(width: 12),
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: const Color(0xFFD5DBD1),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                size: 44,
                color: Color(0xFF111811),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _classLabel(String classId) {
    final c = classId.trim();
    if (c.isEmpty) return 'Clasa N/A';
    final parts = c.split('-');
    if (parts.length >= 2) {
      return 'Clasa a ${parts.first}-a ${parts.sublist(1).join('-')}';
    }
    return 'Clasa $c';
  }

  String _initials(String name) {
    final parts = name
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p.trim())
        .toList();
    if (parts.isEmpty) return 'E';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
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
  final ParentStudentViewData data;

  const StudentDetailsPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty
        ? data.fullName
        : data.username;

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
  final ParentStudentViewData data;

  const _StudentProfileCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty
        ? data.fullName
        : data.username;
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
                color: Colors.black.withValues(alpha: 0.10),
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
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 8),
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
                Container(height: 1, color: const Color(0xFFB8B8B8)),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: const Color(0xFF2E3B4E).withValues(alpha: 0.22),
              width: 2.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E3B4E).withValues(alpha: 0.09),
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
                  _DetailChip(
                    icon: data.inSchool
                        ? Icons.school_rounded
                        : Icons.logout_rounded,
                    text: data.inSchool ? 'În incintă' : 'În afara incintei',
                    color: data.inSchool ? const Color(0xFF4B78D2) : Colors.red,
                  ),
                ],
              ),
              Divider(
                color: const Color(0xFF2E3B4E).withValues(alpha: 0.18),
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
                    child: Text(
                      'Nu este disponibil pe această pagină.',
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF2E3B4E).withValues(alpha: 0.45),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              Divider(
                color: const Color(0xFF2E3B4E).withValues(alpha: 0.18),
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
                    child: Text(
                      'Nu este disponibil pe această pagină.',
                      style: TextStyle(
                        fontSize: 15,
                        color: const Color(0xFF2E3B4E).withValues(alpha: 0.45),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
            'Nu exista orar definit pentru acest elev.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Color(0xFF333333)),
          ),
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

List<_ScheduleRowData> _buildScheduleRows(ParentStudentViewData data) {
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

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _DetailChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
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
  }
}
