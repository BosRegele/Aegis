import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D631B);
const _kPageBg = Color(0xFFF7F9F0);
const _kCardBg = Color(0xFFFFFFFF);

enum _StudentSortMode { presence, name }

/// Placeholder status page for teachers. Currently mirrors the dashboard UI.
class StatusEleviPage extends StatefulWidget {
  const StatusEleviPage({super.key});

  @override
  State<StatusEleviPage> createState() => _StatusEleviPageState();
}

class _StatusEleviPageState extends State<StatusEleviPage> {
  _StudentSortMode _sortMode = _StudentSortMode.presence;

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
                              final aData = a.data() as Map<String, dynamic>;
                              final bData = b.data() as Map<String, dynamic>;
                              final aName =
                                  (aData['fullName'] ??
                                          aData['username'] ??
                                          a.id)
                                      .toString()
                                      .toLowerCase();
                              final bName =
                                  (bData['fullName'] ??
                                          bData['username'] ??
                                          b.id)
                                      .toString()
                                      .toLowerCase();

                              if (_sortMode == _StudentSortMode.name) {
                                return aName.compareTo(bName);
                              }

                              final aIn = aData['inSchool'] == true ? 0 : 1;
                              final bIn = bData['inSchool'] == true ? 0 : 1;
                              final byPresence = aIn.compareTo(bIn);
                              if (byPresence != 0) {
                                return byPresence;
                              }
                              return aName.compareTo(bName);
                            });

                          return Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  18,
                                  16,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Clasa $classId',
                                      style: const TextStyle(
                                        color: Color(0xFF1B231A),
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    PopupMenuButton<_StudentSortMode>(
                                      initialValue: _sortMode,
                                      onSelected: (value) {
                                        if (_sortMode == value) return;
                                        setState(() => _sortMode = value);
                                      },
                                      color: Colors.white,
                                      elevation: 4,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: _StudentSortMode.presence,
                                          child: Text('După prezență'),
                                        ),
                                        PopupMenuItem(
                                          value: _StudentSortMode.name,
                                          child: Text('După nume'),
                                        ),
                                      ],
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFDCE5D6),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.sort_rounded,
                                              size: 18,
                                              color: Color(0xFF0D631B),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _sortMode ==
                                                      _StudentSortMode.presence
                                                  ? 'După prezență'
                                                  : 'După nume',
                                              style: const TextStyle(
                                                color: Color(0xFF1B231A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.keyboard_arrow_down_rounded,
                                              size: 18,
                                              color: Color(0xFF4D5A4A),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    24,
                                  ),
                                  itemCount: sortedStudents.length,
                                  itemBuilder: (context, index) {
                                    final stu = sortedStudents[index];
                                    final ud =
                                        stu.data() as Map<String, dynamic>;
                                    final uid = stu.id;
                                    final name =
                                        (ud['fullName'] ??
                                                ud['username'] ??
                                                uid)
                                            .toString();
                                    final username = (ud['username'] ?? '')
                                        .toString()
                                        .trim();
                                    final email =
                                        (ud['personalEmail'] ??
                                                ud['email'] ??
                                                ud['authEmail'] ??
                                                '')
                                            .toString()
                                            .trim();
                                    final photoUrl =
                                        (ud['profilePictureUrl'] ??
                                                ud['photoUrl'] ??
                                                ud['avatarUrl'] ??
                                                '')
                                            .toString()
                                            .trim();
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
                                          .where(
                                            'status',
                                            isEqualTo: 'approved',
                                          )
                                          .limit(1)
                                          .snapshots(),
                                      builder: (context, permSnap) {
                                        final hasPermission =
                                            permSnap.data?.docs.isNotEmpty ??
                                            false;
                                        final parentsRaw = ud['parents'];
                                        final parentUid = parentsRaw is List
                                            ? parentsRaw
                                                  .map(
                                                    (parent) => parent
                                                        .toString()
                                                        .trim(),
                                                  )
                                                  .firstWhere(
                                                    (parent) =>
                                                        parent.isNotEmpty,
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
                                          avatarSeed: uid,
                                          photoUrl: photoUrl,
                                          initials: initials,
                                          name: name,
                                          inSchool: inSchool,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              PageRouteBuilder(
                                                pageBuilder: (_, _, _) =>
                                                    _StudentDetailPage(
                                                      avatarSeed: uid,
                                                      name: name,
                                                      username: username,
                                                      email: email,
                                                      photoUrl: photoUrl,
                                                      parentUid: parentUid,
                                                      status: statusText,
                                                      lastScanDate:
                                                          lastScanDate,
                                                      lastScanTime:
                                                          lastScanTime,
                                                      lastScanLocation:
                                                          lastScanLocation,
                                                      hasPermission:
                                                          hasPermission,
                                                    ),
                                                transitionDuration:
                                                    Duration.zero,
                                                reverseTransitionDuration:
                                                    Duration.zero,
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
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

  const _TopHeader({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
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
            Positioned(top: -72, right: -52, child: _decorCircle(220)),
            Positioned(top: 44, right: 34, child: _decorCircle(72)),
            Positioned(left: 156, bottom: -28, child: _decorCircle(82)),
            Padding(
              padding: EdgeInsets.zero,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: onBack,
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
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
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
  }

  Widget _decorCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.08),
      ),
    );
  }
}

class _StudentListCard extends StatelessWidget {
  final String avatarSeed;
  final String photoUrl;
  final String initials;
  final String name;
  final bool inSchool;
  final VoidCallback onTap;

  const _StudentListCard({
    required this.avatarSeed,
    required this.photoUrl,
    required this.initials,
    required this.name,
    required this.inSchool,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarBg = _avatarBackgroundColor(avatarSeed);
    final statusText = inSchool ? 'ÎN INCINTĂ' : 'ÎN AFARA INCINTEI';
    final pillBg = inSchool ? const Color(0xFFE2EFE6) : const Color(0xFFF1E4EC);
    final pillBorder = inSchool
        ? const Color(0xFFA6C8B0)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF0D6D1E)
        : const Color(0xFF922255);

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _AvatarInitials(
                              initials: initials,
                              backgroundColor: avatarBg,
                            );
                          },
                        )
                      : _AvatarInitials(
                          initials: initials,
                          backgroundColor: avatarBg,
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
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
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
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECEFE6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
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

  Color _avatarBackgroundColor(String seed) {
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
        : normalized.codeUnits.fold<int>(0, (acc, unit) => acc + unit) %
              palette.length;
    return palette[index];
  }
}

class _AvatarInitials extends StatelessWidget {
  final String initials;
  final Color backgroundColor;

  const _AvatarInitials({
    required this.initials,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 20,
          height: 1,
        ),
      ),
    );
  }
}

// ─── Student detail page ──────────────────────────────────────────────────────

class _StudentDetailPage extends StatelessWidget {
  final String avatarSeed;
  final String name;
  final String username;
  final String email;
  final String photoUrl;
  final String parentUid;
  final String status;
  final String lastScanDate;
  final String lastScanTime;
  final String lastScanLocation;
  final bool hasPermission;

  const _StudentDetailPage({
    required this.avatarSeed,
    required this.name,
    required this.username,
    required this.email,
    required this.photoUrl,
    required this.parentUid,
    required this.status,
    required this.lastScanDate,
    required this.lastScanTime,
    required this.lastScanLocation,
    required this.hasPermission,
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
                        child: _decorCircleDetail(220),
                      ),
                      Positioned(
                        top: 44,
                        right: 34,
                        child: _decorCircleDetail(72),
                      ),
                      Positioned(
                        left: 156,
                        bottom: -28,
                        child: _decorCircleDetail(82),
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
                            GestureDetector(
                              onTap: photoUrl.isNotEmpty
                                  ? () => _openDetailImage(context, photoUrl)
                                  : null,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(18),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) =>
                                              _DetailAvatarFallback(
                                                avatarSeed: avatarSeed,
                                                name: name,
                                              ),
                                        )
                                      : _DetailAvatarFallback(
                                          avatarSeed: avatarSeed,
                                          name: name,
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
                        _ParentTutorRow(parentUid: parentUid),
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

  Widget _decorCircleDetail(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

void _openDetailImage(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      pageBuilder: (_, _, _) => _DetailFullScreenImage(url: url),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _DetailFullScreenImage extends StatelessWidget {
  final String url;

  const _DetailFullScreenImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white70,
                    size: 56,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
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

class _DetailAvatarFallback extends StatelessWidget {
  final String avatarSeed;
  final String name;

  const _DetailAvatarFallback({required this.avatarSeed, required this.name});

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
      : normalized.codeUnits.fold<int>(0, (acc, unit) => acc + unit) %
            palette.length;
  return palette[index];
}

class _ParentTutorRow extends StatelessWidget {
  final String parentUid;

  const _ParentTutorRow({required this.parentUid});

  @override
  Widget build(BuildContext context) {
    if (parentUid.isEmpty) {
      return const _PersonMetaRow(
        icon: Icons.family_restroom_rounded,
        label: 'PĂRINȚI / TUTORI',
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
          label: 'PĂRINȚI / TUTORI',
          value: parentName.isEmpty ? 'Neasignat' : parentName,
        );
      },
    );
  }
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
    final pillBorder = inSchool
        ? const Color(0xFFA6C8B0)
        : const Color(0xFFDCB1C5);
    final pillText = inSchool
        ? const Color(0xFF0D6D1E)
        : const Color(0xFF922255);

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

// ignore: unused_element
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
            color: Colors.black.withValues(alpha: 0.04),
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
