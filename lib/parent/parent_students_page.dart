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
    final users = FirebaseFirestore.instance.collection('users');

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

                          final childIds = _extractChildUids(
                            parentData,
                            parentUid,
                          );
                          if (childIds.isEmpty) {
                            return const Center(
                              child: Text('Nu exista copii asignati.'),
                            );
                          }

                          return ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.only(top: 2, bottom: 24),
                            itemCount: childIds.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 14),
                            itemBuilder: (context, index) {
                              final uid = childIds[index];

                              return StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: users.doc(uid).snapshots(),
                                builder: (context, studentSnap) {
                                  if (!studentSnap.hasData ||
                                      !studentSnap.data!.exists) {
                                    return const SizedBox();
                                  }

                                  final data = studentSnap.data!.data()!;
                                  return _StudentCard(
                                    data: _toStudentViewData(
                                      studentSnap.data!.id,
                                      data,
                                    ),
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

  List<String> _extractChildUids(
    Map<String, dynamic> parentData,
    String parentUid,
  ) {
    final raw = (parentData['children'] as List?) ?? const [];
    final idsSet = <String>{};

    for (final value in raw) {
      if (value is String) {
        final id = value.trim();
        if (id.isNotEmpty) {
          idsSet.add(id);
        }
        continue;
      }

      if (value is Map<String, dynamic>) {
        final id = ((value['uid'] ?? value['studentUid'] ?? value['id']) ?? '')
            .toString()
            .trim();
        if (id.isNotEmpty) {
          idsSet.add(id);
        }
      }
    }

    final ids = idsSet.toList()..sort();
    return ids;
  }

  ParentStudentViewData _toStudentViewData(
    String uid,
    Map<String, dynamic> data,
  ) {
    return ParentStudentViewData(
      uid: uid,
      fullName: (data['fullName'] ?? data['name'] ?? '').toString(),
      username: (data['username'] ?? data['uid'] ?? '').toString(),
      role: (data['role'] ?? 'student').toString(),
      classId: (data['classId'] ?? '').toString(),
      inSchool: data['inSchool'] == true,
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
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
                  fontWeight: FontWeight.w700,
                  color: initialsColor,
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
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(classLabel, style: const TextStyle(fontSize: 16)),
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
                      Icon(Icons.circle, size: 9, color: statusTextColor),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
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
          const Icon(Icons.chevron_right_rounded, size: 34),
        ],
      ),
    );
  }

  String _initials(String value) {
    final parts = value.split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  String _classLabel(String classId) {
    if (classId.trim().isEmpty) return 'Clasa necunoscuta';
    return 'Clasa $classId';
  }
}
