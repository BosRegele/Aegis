import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  late final Future<List<_ChildViewData>> _childrenFuture;

  @override
  void initState() {
    super.initState();
    _childrenFuture = _loadChildrenData();
  }

  Future<DocumentSnapshot?> _getParentDoc() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? AppSession.uid;
    if (uid != null && uid.isNotEmpty) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) return doc;
    }

    // fallback: try by username field
    final username = AppSession.username ?? '';
    if (username.isNotEmpty) {
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) return q.docs.first;
    }

    return null;
  }

  Future<List<_ChildViewData>> _loadChildrenData() async {
    final parentDoc = await _getParentDoc();
    if (parentDoc == null) return [];

    final parentData = parentDoc.data() as Map<String, dynamic>? ?? {};
    final rawChildren = parentData['children'] ?? [];
    final List<String> childIds = List<String>.from(rawChildren);

    final results = <_ChildViewData>[];

    for (final cid in childIds) {
      // try doc by id
      DocumentSnapshot childDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(cid)
          .get();
      if (!childDoc.exists) {
        // fallback: try where username == cid
        final q = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: cid)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) childDoc = q.docs.first;
      }

      if (!childDoc.exists) continue;

      final childData = childDoc.data() as Map<String, dynamic>? ?? {};
      final childFullName =
          (childData['fullName'] ?? childData['username'] ?? childDoc.id)
              .toString();
      final childUsername = (childData['username'] ?? childDoc.id).toString();
      final classId = (childData['classId'] ?? '')
          .toString()
          .trim()
          .toUpperCase();

      String teacherName = 'N/A';
      Map<String, Map<String, String>> schedule = {};

      if (classId.isNotEmpty) {
        final classDoc = await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .get();
        if (classDoc.exists) {
          final classData = classDoc.data() as Map<String, dynamic>? ?? {};

          // parse schedule (same logic as OrarScreen)
          final scheduleData = classData['schedule'];
          if (scheduleData is Map) {
            for (final entry in scheduleData.entries) {
              final dayNum = int.tryParse(entry.key.toString());
              if (dayNum != null && dayNum >= 1 && dayNum <= 7) {
                final times = entry.value;
                if (times is Map) {
                  final start = times['start']?.toString() ?? '';
                  final end = times['end']?.toString() ?? '';
                  if (start.isNotEmpty && end.isNotEmpty) {
                    schedule[dayNum.toString()] = {'start': start, 'end': end};
                  }
                }
              }
            }
          }

          if (schedule.isEmpty) {
            final start = (classData['noExitStart'] ?? '').toString().trim();
            final end = (classData['noExitEnd'] ?? '').toString().trim();
            final rawDays = classData['noExitDays'];
            if (start.isNotEmpty && end.isNotEmpty && rawDays is List) {
              for (final day in rawDays) {
                if (day is int && day >= 1 && day <= 7)
                  schedule[day.toString()] = {'start': start, 'end': end};
              }
            }
          }

          final teacherUsername = (classData['teacherUsername'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          if (teacherUsername.isNotEmpty) {
            final tq = await FirebaseFirestore.instance
                .collection('users')
                .where('username', isEqualTo: teacherUsername)
                .limit(1)
                .get();
            if (tq.docs.isNotEmpty) {
              final td = tq.docs.first.data() as Map<String, dynamic>;
              final tname = (td['fullName'] ?? '').toString().trim();
              teacherName = tname.isNotEmpty ? tname : teacherUsername;
            } else {
              final tdoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(teacherUsername)
                  .get();
              if (tdoc.exists) {
                final td = tdoc.data() as Map<String, dynamic>? ?? {};
                final tname = (td['fullName'] ?? '').toString().trim();
                teacherName = tname.isNotEmpty ? tname : teacherUsername;
              }
            }
          }
        }
      }

      results.add(
        _ChildViewData(
          id: childDoc.id,
          fullName: childFullName,
          username: childUsername,
          classId: classId,
          teacherName: teacherName,
          schedule: schedule,
        ),
      );
    }

    return results;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color.fromARGB(255, 94, 184, 78);
    const Color lightGreen = Color(0xFFF0F4E8);

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text('Parent · Home'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: FutureBuilder<List<_ChildViewData>>(
          future: _childrenFuture,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Eroare: ${snap.error}'));
            }
            final children = snap.data ?? [];
            if (children.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Nu ai copii asignați în sistem.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('Session'),
                            content: Text(
                              'uid: ${AppSession.uid}\nusername: ${AppSession.username}\nrole: ${AppSession.role}',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('Vezi contul meu'),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: children.length,
              itemBuilder: (context, i) {
                final c = children[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.fullName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text('username: ${c.username} | clasă: ${c.classId}'),
                        const SizedBox(height: 8),
                        Text('Diriginte: ${c.teacherName}'),
                        const SizedBox(height: 8),
                        if (c.schedule.isEmpty)
                          const Text('Orar: (nu este setat)')
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Orar:'),
                              const SizedBox(height: 6),
                              ...c.schedule.entries
                                  .toList()
                                  .map(
                                    (e) => Text(
                                      'Zi ${e.key}: ${e.value['start']} - ${e.value['end']}',
                                    ),
                                  )
                                  .toList(),
                            ],
                          ),
                      ],
                    ),
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

class _ChildViewData {
  final String id;
  final String fullName;
  final String username;
  final String classId;
  final String teacherName;
  final Map<String, Map<String, String>> schedule;

  _ChildViewData({
    required this.id,
    required this.fullName,
    required this.username,
    required this.classId,
    required this.teacherName,
    required this.schedule,
  });
}
