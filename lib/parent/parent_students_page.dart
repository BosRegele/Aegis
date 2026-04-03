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
  final bool inSchool;

  const ParentStudentViewData({
    required this.uid,
    required this.fullName,
    required this.username,
    required this.role,
    required this.classId,
    required this.inSchool,
  });
}

class ParentStudentsPage extends StatelessWidget {
  const ParentStudentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final parentUid = (AppSession.uid ?? '').trim();

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: parentUid.isEmpty
                    ? const Center(child: Text('Sesiune invalidă'))
                    : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(parentUid)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final parentData = snapshot.data!.data();
                          if (parentData == null) {
                            return const Center(child: Text('Nu exista date.'));
                          }

                          final childIds = _extractChildUids(parentData);

                          if (childIds.isEmpty) {
                            return const Center(
                              child: Text('Nu exista copii asignati.'),
                            );
                          }

                          return FutureBuilder<List<ParentStudentViewData>>(
                            future: _loadStudentsByChildUids(childIds),
                            builder: (context, studentSnapshot) {
                              if (!studentSnapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              final students = studentSnapshot.data!;

                              if (students.isEmpty) {
                                return const Center(
                                  child: Text('Nu exista copii asignati.'),
                                );
                              }

                              return ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.only(
                                  top: 2,
                                  bottom: 24,
                                ),
                                itemCount: students.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 14),
                                itemBuilder: (context, index) {
                                  return _StudentCard(
                                    data: students[index],
                                    index: index,
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _extractChildUids(Map<String, dynamic> parentData) {
    final raw = (parentData['children'] as List?) ??
        (parentData['childrens'] as List?) ??
        const [];

    final ids = raw
        .map((value) => value.toString().trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return ids.toSet().toList();
  }

  Future<List<ParentStudentViewData>> _loadStudentsByChildUids(
    List<String> childUids,
  ) async {
    final usersRef = FirebaseFirestore.instance.collection('users');
    final result = <ParentStudentViewData>[];

    for (final uid in childUids) {
      try {
        DocumentSnapshot<Map<String, dynamic>>? foundDoc;

        final byDocId = await usersRef.doc(uid).get();
        if (byDocId.exists) {
          foundDoc = byDocId;
        }

        if (foundDoc == null) {
          final byUid = await usersRef
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get();
          if (byUid.docs.isNotEmpty) {
            foundDoc = byUid.docs.first;
          }
        }

        if (foundDoc == null) {
          result.add(
            ParentStudentViewData(
              uid: uid,
              fullName: 'Elev lipsa',
              username: uid,
              role: 'student',
              classId: '',
              inSchool: false,
            ),
          );
          continue;
        }

        final data = foundDoc.data() ?? const <String, dynamic>{};
        result.add(
          ParentStudentViewData(
            uid: foundDoc.id,
            fullName: (data['fullName'] ?? data['name'] ?? '').toString(),
            username: (data['username'] ?? data['uid'] ?? '').toString(),
            role: (data['role'] ?? 'student').toString(),
            classId: (data['classId'] ?? '').toString(),
            inSchool: data['inSchool'] == true,
          ),
        );
      } catch (_) {
        result.add(
          ParentStudentViewData(
            uid: uid,
            fullName: 'Elev lipsa',
            username: uid,
            role: 'student',
            classId: '',
            inSchool: false,
          ),
        );
      }
    }

    return result;
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
            Positioned(
              right: -46,
              top: -34,
              child: _circle(122, const Color(0x33BFEAB8)),
            ),
            Positioned(
              left: 182,
              top: 104,
              child: _circle(78, const Color(0x33D3F0C2)),
            ),
            Positioned(
              right: 24,
              top: 40 + topPadding,
              child: _circle(66, const Color(0x33A4D39A)),
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
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Elevii Mei',
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

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final ParentStudentViewData data;
  final int index;

  const _StudentCard({required this.data, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = data.fullName.trim().isNotEmpty
        ? data.fullName.trim()
        : data.username.trim().isNotEmpty
            ? data.username.trim()
            : 'Elev necunoscut';
    final initials = _initials(name);
    final classLabel = _classLabel(data.classId);

    final useGreenAvatar = index.isEven;
    final avatarColor = useGreenAvatar
      ? const Color(0xFF2D8A37)
      : const Color(0xFFB64A78);
    final initialsColor = useGreenAvatar
      ? const Color(0xFFBFE8B8)
      : const Color(0xFFF3D5E2);
    final statusBg = data.inSchool
        ? const Color(0xFFDCEBDC)
        : const Color(0xFFEDE3E8);
    final statusBorder = data.inSchool
        ? const Color(0xFFA8CDB0)
        : const Color(0xFFD7BEC9);
    final statusText = data.inSchool ? 'IN INCINTA' : 'IN AFARA INCINTEI';
    final statusTextColor = data.inSchool
        ? const Color(0xFF0C6C1D)
        : const Color(0xFF9A2D5D);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE5E9E0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatarColor,
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 35,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: initialsColor,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF101510),
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  classLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF2A322A),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: statusBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 9,
                        color: statusTextColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: statusTextColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF101510),
            size: 34,
          ),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value
        .split(' ')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final txt = parts.first;
      return txt.substring(0, txt.length >= 2 ? 2 : 1).toUpperCase();
    }
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  String _classLabel(String classId) {
    final value = classId.trim();
    if (value.isEmpty) return 'Clasa necunoscuta';
    final lower = value.toLowerCase();
    if (lower.startsWith('clasa')) return value;
    return 'Clasa $value';
  }
}