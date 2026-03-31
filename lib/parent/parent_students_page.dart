import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);

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
  // All child UIDs accumulated from parallel streams.
  final Set<String> _studentUids = {};
  // True once the parent-doc stream has emitted at least once.
  bool _loadedOnce = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _parentDocSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _parentsArraySub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _legacyUidSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _legacyIdSub;

  @override
  void initState() {
    super.initState();
    _setupStreams();
  }

  void _setupStreams() {
    final parentUid = (AppSession.uid ?? '').trim();
    if (parentUid.isEmpty) {
      setState(() => _loadedOnce = true);
      return;
    }

    final users = FirebaseFirestore.instance.collection('users');

    // 1) Parent's own document — read the 'children' array.
    _parentDocSub = users.doc(parentUid).snapshots().listen(
      (snap) {
        if (!mounted) return;
        final data = snap.data() ?? {};
        final children = (data['children'] as List? ?? [])
            .map((v) => v.toString().trim())
            .where((v) => v.isNotEmpty)
            .toSet();
        setState(() {
          _studentUids.addAll(children);
          _loadedOnce = true;
        });
      },
      onError: (_) {
        if (mounted) setState(() => _loadedOnce = true);
      },
    );

    // 2) Modern schema: students whose 'parents' array contains parentUid.
    _parentsArraySub = users
        .where('parents', arrayContains: parentUid)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _studentUids.addAll(snap.docs.map((d) => d.id)));
      },
      onError: (_) {},
    );

    // 3) Legacy schema: students with 'parentUid' == parentUid.
    _legacyUidSub = users
        .where('parentUid', isEqualTo: parentUid)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _studentUids.addAll(snap.docs.map((d) => d.id)));
      },
      onError: (_) {},
    );

    // 4) Legacy schema: students with 'parentId' == parentUid.
    _legacyIdSub = users
        .where('parentId', isEqualTo: parentUid)
        .snapshots()
        .listen(
      (snap) {
        if (!mounted) return;
        setState(() => _studentUids.addAll(snap.docs.map((d) => d.id)));
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _parentDocSub?.cancel();
    _parentsArraySub?.cancel();
    _legacyUidSub?.cancel();
    _legacyIdSub?.cancel();
    super.dispose();
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

  Future<void> _openStudentDetails(BuildContext context, String studentUid) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await _loadStudentData(studentUid);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StudentDetailsPage(data: data)),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Nu am putut încărca profilul elevului: $error')),
      );
    }
  }

  _StudentProfileData _summaryDataFromDoc(
    String studentUid,
    Map<String, dynamic> userData,
  ) {
    return _StudentProfileData(
      uid: studentUid,
      fullName: (userData['fullName'] ?? '').toString().trim(),
      username: (userData['username'] ?? '').toString().trim(),
      role: (userData['role'] ?? '').toString().trim(),
      classId: (userData['classId'] ?? '').toString().trim().toUpperCase(),
      teacherName: 'N/A',
      schedule: const <int, Map<String, String>>{},
      inSchool: userData['inSchool'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentUid = (AppSession.uid ?? '').trim();

    if (parentUid.isEmpty) {
      return const Scaffold(
        backgroundColor: _kPageBg,
        body: Center(
          child: Text(
            'Sesiune invalidă.',
            style: TextStyle(fontSize: 16, color: Color(0xFF7A8077)),
          ),
        ),
      );
    }

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
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (!_loadedOnce) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter out any UIDs that belong to the parent account itself.
    final parentUid = (AppSession.uid ?? '').trim();
    final validIds = _studentUids
        .where((uid) => uid.isNotEmpty && uid != parentUid)
        .toList()
      ..sort();

    if (validIds.isEmpty) {
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
      itemCount: validIds.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final studentUid = validIds[index];
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(studentUid)
              .snapshots(),
          builder: (context, childSnapshot) {
            if (!childSnapshot.hasData) return const _StudentCardSkeleton();
            if (!childSnapshot.data!.exists) return const SizedBox.shrink();
            final childData = childSnapshot.data!.data() ?? <String, dynamic>{};
            final summaryData = _summaryDataFromDoc(studentUid, childData);
            return _StudentSummaryButton(
              data: summaryData,
              onTap: () => _openStudentDetails(context, studentUid),
            );
          },
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
            Positioned(right: 24, top: 40 + topPadding, child: _circle(66, 0.14)),
            Padding(
              padding: EdgeInsets.fromLTRB(22, topPadding + 38, 22, 24),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 34),
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

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.14);
    const spacing = 28.0;
    for (double y = 16; y < size.height; y += spacing) {
      for (double x = 14; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StudentSummaryButton extends StatelessWidget {
  final _StudentProfileData data;
  final VoidCallback onTap;

  const _StudentSummaryButton({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = data.fullName.isNotEmpty ? data.fullName : data.username;

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
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(data.uid).snapshots(),
              builder: (context, snapshot) {
                bool isInSchool = data.inSchool;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final d = snapshot.data!.data() as Map<String, dynamic>;
                  isInSchool = d['inSchool'] == true;
                }

                final avatarBg = isInSchool ? const Color(0xFF258635) : const Color(0xFFB84777);
                final statusText = isInSchool ? 'IN INCINTA' : 'IN AFARA INCINTEI';
                final statusColor = isInSchool ? const Color(0xFF0C6F1D) : const Color(0xFF952E5C);
                final statusBg = isInSchool ? const Color(0xFFDBEBDD) : const Color(0xFFF0E1E8);
                final statusBorder = isInSchool ? const Color(0xFFA9CCAE) : const Color(0xFFD2A9BF);

                return Row(
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
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                );
              },
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

class _StudentCardSkeleton extends StatelessWidget {
  const _StudentCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3E8DF)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 116,
            height: 116,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFDDE5D8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFDDE5D8),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: SizedBox(width: 180, height: 22),
                ),
                SizedBox(height: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE7ECE1),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: SizedBox(width: 140, height: 18),
                ),
                SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0xFFE7ECE1),
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  child: SizedBox(width: 160, height: 34),
                ),
              ],
            ),
          ),
          SizedBox(width: 12),
          SizedBox(
            width: 74,
            height: 74,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFD5DBD1),
                borderRadius: BorderRadius.all(Radius.circular(18)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}