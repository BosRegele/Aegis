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
                                  final viewData = _toStudentViewData(
                                    studentSnap.data!.id,
                                    data,
                                  );
                                  return _StudentCard(
                                    data: viewData,
                                    index: index,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (_, __, ___) =>
                                              _StudentDetailPage(
                                                avatarSeed: viewData.uid,
                                                name: viewData.fullName,
                                                username: viewData.username,
                                                email: (data['email'] ?? '')
                                                    .toString()
                                                    .trim(),
                                                classId: viewData.classId,
                                                status: viewData.inSchool
                                                    ? 'IN INCINTA'
                                                    : 'IN AFARA INCINTEI',
                                              ),
                                          transitionDuration: Duration.zero,
                                          reverseTransitionDuration:
                                              Duration.zero,
                                        ),
                                      );
                                    },
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
  final VoidCallback onTap;

  const _StudentCard({
    required this.data,
    required this.index,
    required this.onTap,
  });

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

    return GestureDetector(
      onTap: onTap,
      child: Container(
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

class _StudentDetailPage extends StatelessWidget {
  final String avatarSeed;
  final String name;
  final String username;
  final String email;
  final String classId;
  final String status;

  const _StudentDetailPage({
    required this.avatarSeed,
    required this.name,
    required this.username,
    required this.email,
    required this.classId,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F0),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Builder(
            builder: (context) {
              final topPadding = MediaQuery.of(context).padding.top;
              final compact = MediaQuery.sizeOf(context).width < 390;
              final headerHeight = compact ? 138.0 : 146.0;
              return ClipRRect(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(54),
                  bottomRight: Radius.circular(54),
                ),
                child: Container(
                  height: headerHeight,
                  width: double.infinity,
                  color: _kHeaderGreen,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -72,
                        right: -52,
                        child: _decorCircle(220),
                      ),
                      Positioned(
                        top: 44,
                        right: 34,
                        child: _decorCircle(72),
                      ),
                      Positioned(
                        left: 156,
                        bottom: -28,
                        child: _decorCircle(82),
                      ),
                      Padding(
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                GestureDetector(
                                  onTap: () => Navigator.of(context).maybePop(),
                                  behavior: HitTestBehavior.opaque,
                                  child: const SizedBox(
                                    width: 34,
                                    height: 34,
                                    child: Center(
                                      child: Icon(
                                        Icons.arrow_back_rounded,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Text(
                                    'Detalii Elev',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 29,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(38),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120D631B),
                          blurRadius: 28,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DetailAvatarFallback(
                              avatarSeed: avatarSeed,
                              name: name,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111811),
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  if (username.isNotEmpty)
                                    Text(
                                      '@$username',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0D631B),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        Container(height: 1, color: const Color(0xFFF0F1EA)),
                        const SizedBox(height: 22),
                        _PersonMetaRow(
                          icon: Icons.alternate_email_rounded,
                          label: 'EMAIL',
                          value: email.isNotEmpty ? email : 'Nedefinit',
                        ),
                        const SizedBox(height: 12),
                        _PersonMetaRow(
                          icon: Icons.school_rounded,
                          label: 'CLASĂ',
                          value: classId.isNotEmpty ? 'Clasa $classId' : 'Nedefinit',
                        ),
                        const SizedBox(height: 18),
                        _StatusMetaRow(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _decorCircle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

class _DetailAvatarFallback extends StatelessWidget {
  final String avatarSeed;
  final String name;

  const _DetailAvatarFallback({
    required this.avatarSeed,
    required this.name,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _detailAvatarColor(avatarSeed),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

Color _detailAvatarColor(String seed) {
  const palette = [
    Color(0xFF4F8CFF),
    Color(0xFF00A896),
    Color(0xFFF4A261),
    Color(0xFFE76F51),
    Color(0xFF7B61FF),
    Color(0xFF2A9D8F),
    Color(0xFFC04D83),
    Color(0xFF6C8A3B),
  ];
  final normalized = seed.trim();
  final index = normalized.isEmpty
      ? 0
      : normalized.codeUnits.fold<int>(0, (sum, unit) => sum + unit) %
            palette.length;
  return palette[index];
}

class _StatusMetaRow extends StatelessWidget {
  final String status;

  const _StatusMetaRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final inSchool =
        normalized.contains('incinta') && !normalized.contains('afara');
    final label = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool ? const Color(0xFFE2EFE6) : const Color(0xFFF1E4EC);
    final pillBorder =
        inSchool ? const Color(0xFFA6C8B0) : const Color(0xFFDCB1C5);
    final pillText =
        inSchool ? const Color(0xFF0D6D1E) : const Color(0xFF922255);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: pillBg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: pillBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: pillText,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: pillText,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonMetaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PersonMetaRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFE8F2E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF0D631B), size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF6E7C70),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111811),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
