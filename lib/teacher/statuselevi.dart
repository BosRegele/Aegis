import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF1D5C2B);
const _kPageBg = Color(0xFFFFFFFF);
const _kCardBg = Color(0xFFF7F7F7);

/// Placeholder status page for teachers. Currently mirrors the dashboard UI.
class StatusEleviPage extends StatefulWidget {
  const StatusEleviPage({super.key});

  @override
  State<StatusEleviPage> createState() => _StatusEleviPageState();
}

class _StatusEleviPageState extends State<StatusEleviPage> {
  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid);

    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(
              title: 'Clasa Mea',
              onBack: () => Navigator.of(context).maybePop(),
              onProfile: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
            Expanded(
              child: FutureBuilder<DocumentSnapshot>(
                future: teacherDoc.get(),
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

                  if (classId.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  final studentsStream = FirebaseFirestore.instance
                      .collection('users')
                      .where('classId', isEqualTo: classId)
                      .where('role', isEqualTo: 'student')
                      .orderBy('fullName')
                      .snapshots();

                  final eventsStream = FirebaseFirestore.instance
                      .collection('accessEvents')
                      .where('classId', isEqualTo: classId)
                      .orderBy('timestamp', descending: true)
                      .snapshots();

                  return StreamBuilder<QuerySnapshot>(
                    stream: studentsStream,
                    builder: (context, stuSnap) {
                      if (stuSnap.hasError) {
                        return Center(
                          child: Text('Eroare elevi: ${stuSnap.error}'),
                        );
                      }
                      if (!stuSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final students = stuSnap.data!.docs;
                      if (students.isEmpty) {
                        return const Center(
                          child: Text('Nu exista elevi in clasa.'),
                        );
                      }

                      return StreamBuilder<QuerySnapshot>(
                        stream: eventsStream,
                        builder: (context, evSnap) {
                          if (evSnap.hasError) {
                            return Center(
                              child: Text('Eroare evenimente: ${evSnap.error}'),
                            );
                          }
                          if (!evSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final lastEvent = <String, Map<String, dynamic>>{};
                          for (final doc in evSnap.data!.docs) {
                            final d = doc.data() as Map<String, dynamic>;
                            final uid = (d['userId'] ?? '').toString();
                            if (uid.isEmpty || lastEvent.containsKey(uid)) {
                              continue;
                            }
                            lastEvent[uid] = d;
                          }

                          final sortedStudents = [...students]
                            ..sort((a, b) {
                              final aIn =
                                  (a.data()
                                          as Map<
                                            String,
                                            dynamic
                                          >)['inSchool'] ==
                                      true
                                  ? 0
                                  : 1;
                              final bIn =
                                  (b.data()
                                          as Map<
                                            String,
                                            dynamic
                                          >)['inSchool'] ==
                                      true
                                  ? 0
                                  : 1;
                              return aIn.compareTo(bIn);
                            });

                          return ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                            itemCount: sortedStudents.length,
                            itemBuilder: (context, index) {
                              final stu = sortedStudents[index];
                              final ud = stu.data() as Map<String, dynamic>;
                              final uid = stu.id;
                              final name =
                                  (ud['fullName'] ?? ud['username'] ?? uid)
                                      .toString();
                              final inSchool = ud['inSchool'] == true;
                              final statusText = inSchool
                                  ? 'in incinta'
                                  : 'in afara incintei';

                              String lastScanDate = '';
                              String lastScanTime = '';
                              String lastScanLocation = '';
                              final ev = lastEvent[uid];
                              if (ev != null) {
                                final ts = ev['timestamp'] as Timestamp?;
                                if (ts != null) {
                                  final dt = ts.toDate().toLocal();
                                  lastScanDate =
                                      '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
                                  lastScanTime =
                                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                                }
                                lastScanLocation =
                                    (ev['location'] ?? ev['gate'] ?? '')
                                        .toString();
                              }

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('leaveRequests')
                                    .where('studentUid', isEqualTo: uid)
                                    .where('classId', isEqualTo: classId)
                                    .where('status', isEqualTo: 'approved')
                                    .limit(1)
                                    .snapshots(),
                                builder: (context, permSnap) {
                                  final hasPermission =
                                      permSnap.data?.docs.isNotEmpty ?? false;
                                  final parentsRaw = ud['parents'];
                                  final parentUid = parentsRaw is List
                                      ? parentsRaw
                                            .map(
                                              (parent) =>
                                                  parent.toString().trim(),
                                            )
                                            .firstWhere(
                                              (parent) => parent.isNotEmpty,
                                              orElse: () => '',
                                            )
                                      : (ud['parentUid'] ?? '')
                                            .toString()
                                            .trim();
                                  final initials = name
                                      .trim()
                                      .split(' ')
                                      .where((w) => w.isNotEmpty)
                                      .take(2)
                                      .map((w) => w[0].toUpperCase())
                                      .join();

                                  return _StudentListCard(
                                    initials: initials,
                                    name: name,
                                    classLabel: 'Clasa a $classId',
                                    inSchool: inSchool,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          pageBuilder: (_, __, ___) =>
                                              _StudentDetailPage(
                                                name: name,
                                                classLabel: 'Clasa a $classId',
                                                parentUid: parentUid,
                                                status: statusText,
                                                lastScanDate: lastScanDate,
                                                lastScanTime: lastScanTime,
                                                lastScanLocation:
                                                    lastScanLocation,
                                                hasPermission: hasPermission,
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
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onProfile;

  const _TopHeader({required this.title, required this.onBack, this.onProfile});

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(38)),
      child: SizedBox(
        height: 90 + topPadding,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.none,
          children: [
            Container(color: _kHeaderGreen),
            Positioned(right: -60, top: -60, child: _decorCircle(180)),
            Positioned(
              right: 120,
              top: topPadding + 15,
              child: _decorCircle(55),
            ),
            Positioned(left: -40, bottom: -30, child: _decorCircle(130)),
            if (onProfile != null)
              Positioned(
                top: topPadding,
                right: 14,
                child: Hero(
                  tag: 'teacher-profile-btn',
                  child: GestureDetector(
                    onTap: onProfile,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0x337DE38D),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0x6DC7F4CE),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(4, topPadding - 6, 18, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: onBack,
                    splashRadius: 22,
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
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
    );
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.10),
      ),
    );
  }
}

class _StudentListCard extends StatelessWidget {
  final String initials;
  final String name;
  final String classLabel;
  final bool inSchool;
  final VoidCallback onTap;

  const _StudentListCard({
    required this.initials,
    required this.name,
    required this.classLabel,
    required this.inSchool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = inSchool
        ? const Color(0xFF268A34)
        : const Color(0xFFB84A7A);
    final avatarText = inSchool
        ? const Color(0xFFB4EDB8)
        : const Color(0xFFFCE9F3);
    final statusText = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool ? const Color(0xFFE2EFE6) : const Color(0xFFF1E4EC);
    final pillBorder = inSchool
        ? const Color(0xFFA6C8B0)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF0D6D1E)
        : const Color(0xFF922255);

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6DE)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    initials,
                    style: TextStyle(
                      color: avatarText,
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101310),
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          classLabel,
                          style: const TextStyle(
                            color: Color(0xFF273027),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: pillBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: pillText,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  statusText,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: pillText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E4DB),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    size: 26,
                    color: Color(0xFF1B231A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Student detail page ──────────────────────────────────────────────────────

class _StudentDetailPage extends StatelessWidget {
  final String name;
  final String classLabel;
  final String parentUid;
  final String status;
  final String lastScanDate;
  final String lastScanTime;
  final String lastScanLocation;
  final bool hasPermission;

  const _StudentDetailPage({
    required this.name,
    required this.classLabel,
    required this.parentUid,
    required this.status,
    required this.lastScanDate,
    required this.lastScanTime,
    required this.lastScanLocation,
    required this.hasPermission,
  });

  @override
  Widget build(BuildContext context) {
    final hasScan = lastScanDate.isNotEmpty || lastScanTime.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F4),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(38),
            ),
            child: Container(
              color: _kHeaderGreen,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 18, 16),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Detalii Elev',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          right: -10,
                          top: -10,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Color(0xFFF0F4EC),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111811),
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              classLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF5A6B5C),
                              ),
                            ),
                            const SizedBox(height: 18),
                            _ParentTutorRow(parentUid: parentUid),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _DetailCard(
                    icon: Icons.qr_code_scanner_rounded,
                    iconBg: const Color(0xFFE8F2E8),
                    iconColor: const Color(0xFF1D5C2B),
                    label: 'Ultima Scanare',
                    trailing: hasScan
                        ? Text(
                            '$lastScanDate${lastScanTime.isNotEmpty ? '  $lastScanTime' : ''}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1D5C2B),
                            ),
                          )
                        : const Text(
                            'Nicio scanare înregistrată',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8A9A8C),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  _DetailCard(
                    icon: Icons.description_outlined,
                    iconBg: const Color(0xFFE8F2E8),
                    iconColor: const Color(0xFF1D5C2B),
                    label: 'Cerere Învoire',
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: hasPermission
                            ? const Color(0xFFDCF0DC)
                            : const Color(0xFFF0EDED),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: hasPermission
                                  ? const Color(0xFF1D5C2B)
                                  : const Color(0xFF9E4040),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasPermission ? 'ACTIVĂ' : 'INACTIVĂ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasPermission
                                  ? const Color(0xFF1D5C2B)
                                  : const Color(0xFF9E4040),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParentTutorRow extends StatelessWidget {
  final String parentUid;

  const _ParentTutorRow({required this.parentUid});

  @override
  Widget build(BuildContext context) {
    if (parentUid.isEmpty) {
      return const _PersonMetaRow(
        icon: Icons.family_restroom_rounded,
        label: 'PĂRINTE / TUTORE',
        value: 'Neasignat',
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(parentUid)
          .get(),
      builder: (context, snapshot) {
        final parentData = snapshot.data?.data() ?? const <String, dynamic>{};
        final parentName =
            (parentData['fullName'] ?? parentData['username'] ?? 'Neasignat')
                .toString()
                .trim();

        return _PersonMetaRow(
          icon: Icons.family_restroom_rounded,
          label: 'PĂRINTE / TUTORE',
          value: parentName.isEmpty ? 'Neasignat' : parentName,
        );
      },
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
          child: Icon(icon, color: const Color(0xFF1D5C2B), size: 24),
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

class _DetailCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final Widget trailing;

  const _DetailCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const Spacer(),
          Flexible(
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}
