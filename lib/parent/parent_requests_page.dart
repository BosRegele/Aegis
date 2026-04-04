import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

const _kHeaderGreen = Color(0xFF0D6F1C);
const _kPageBg = Color(0xFFF1F5EC);

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
  bool _loadedOnce = false;

  @override
  void initState() {
    super.initState();
    _setupStream();
  }

  void _setupStream() {
    setState(() => _loadedOnce = true);
  }

  @override
  void dispose() => super.dispose();

  Future<void> _handleRequest(String docId, bool approved) async {
    final parentName =
        (AppSession.fullName != null && AppSession.fullName!.isNotEmpty)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Parinte');
    try {
      await FirebaseFirestore.instance
          .collection('leaveRequests')
          .doc(docId)
          .update({
            'status': approved ? 'approved' : 'rejected',
            'reviewedAt': FieldValue.serverTimestamp(),
            'reviewedByUid': AppSession.uid,
            'reviewedByName': parentName,
          });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Cerere aprobata!' : 'Cerere respinsa.'),
          backgroundColor: approved ? Colors.green : const Color(0xFFAD3765),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          children: [
            _TopHeader(onBack: () => Navigator.of(context).pop()),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                child: _loadedOnce
                    ? _buildRequests()
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequests() {
    final parentUid = (AppSession.uid ?? '').trim();

    return FutureBuilder<List<String>>(
      future: _loadLinkedStudentIds(parentUid),
      builder: (context, linkedSnapshot) {
        if (!linkedSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final linkedChildIds = linkedSnapshot.data!;
        final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[
          ..._buildLegacyChildRequestStreams(linkedChildIds),
        ];

        return _buildMergedRequestStream(streams, (mergedDocs) {
          final docs = mergedDocs.where((doc) {
            final data = doc.data();
            final status = (data['status'] ?? '').toString().trim();
            final source = (data['source'] ?? '').toString().trim();
            final studentUid = (data['studentUid'] ?? '').toString().trim();
            final isLegacyLinkedRequest = linkedChildIds.contains(studentUid);

            return status == 'pending' &&
                source != 'secretariat' &&
              isLegacyLinkedRequest;
          }).toList()..sort((a, b) {
            final aTs = a.data()['requestedAt'] as Timestamp?;
            final bTs = b.data()['requestedAt'] as Timestamp?;
            return (bTs?.millisecondsSinceEpoch ?? 0).compareTo(
              aTs?.millisecondsSinceEpoch ?? 0,
            );
          });

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                'Nu exista cereri noi.',
                style: TextStyle(color: Color(0xFF7A8077), fontSize: 16),
              ),
            );
          }

          return ListView.separated(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 2, bottom: 24),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data();
              return _RequestCard(
                data: data,
                onAccept: () => _handleRequest(doc.id, true),
                onReject: () => _handleRequest(doc.id, false),
              );
            },
          );
        });
      },
    );
  }

  Future<List<String>> _loadLinkedStudentIds(String parentUid) async {
    if (parentUid.isEmpty) return const <String>[];

    final users = FirebaseFirestore.instance.collection('users');
    final ids = <String>{};

    try {
      final parentDoc = await users.doc(parentUid).get();
      final parentData = parentDoc.data() ?? const <String, dynamic>{};
      ids.addAll(
        ((parentData['children'] as List? ?? const [])
            .map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty && value != parentUid)),
      );
    } catch (_) {}

    try {
      final byParents = await users
          .where('parents', arrayContains: parentUid)
          .get();
      ids.addAll(byParents.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentUid = await users
          .where('parentUid', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentUid.docs.map((doc) => doc.id));
    } catch (_) {}

    try {
      final byParentId = await users
          .where('parentId', isEqualTo: parentUid)
          .get();
      ids.addAll(byParentId.docs.map((doc) => doc.id));
    } catch (_) {}

    final sorted = ids.toList()..sort();
    return sorted;
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildLegacyChildRequestStreams(
    List<String> studentIds,
  ) {
    if (studentIds.isEmpty) {
      return const <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    }

    const chunkSize = 10;
    final streams = <Stream<QuerySnapshot<Map<String, dynamic>>>>[];
    for (int index = 0; index < studentIds.length; index += chunkSize) {
      final chunk = studentIds.skip(index).take(chunkSize).toList();
      streams.add(
        FirebaseFirestore.instance
            .collection('leaveRequests')
            .where('studentUid', whereIn: chunk)
            .where('status', isEqualTo: 'pending')
            .snapshots(),
      );
    }
    return streams;
  }

  Widget _buildMergedRequestStream(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
    Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)
    onReady,
  ) {
    if (streams.isEmpty) {
      return onReady(const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    Widget step(
      int index,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> acc,
    ) {
      if (index >= streams.length) {
        final unique = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{
          for (final doc in acc) doc.id: doc,
        };
        return onReady(unique.values.toList());
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            // Continue with other streams if one chunk is denied.
            return step(index + 1, acc);
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return step(index + 1, [...acc, ...snapshot.data!.docs]);
        },
      );
    }

    return step(0, const <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }
}

class _TopHeader extends StatelessWidget {
  final VoidCallback onBack;

  const _TopHeader({required this.onBack});

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
            Positioned(top: -72, right: -52, child: _circle(220)),
            Positioned(top: 44, right: 34, child: _circle(72)),
            Positioned(left: 156, bottom: -28, child: _circle(82)),
            Center(
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
                    const Expanded(
                      child: Text(
                        'Cereri de invoire',
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
          ],
        ),
      ),
    );
  }

  Widget _circle(double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  );
}

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.data,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final studentName = (data['studentName'] ?? 'Elev necunoscut')
        .toString()
        .trim();
    final classId = (data['classId'] ?? '').toString().trim();
    final dateText = (data['dateText'] ?? '-').toString();
    final timeText = (data['timeText'] ?? '-').toString();
    final reason = (data['message'] ?? 'Fara motiv').toString().trim();

    final initials = _initials(studentName);
    final classLabel = classId.isEmpty
        ? 'ELEV'
        : 'ELEV • CLASA ${classId.toUpperCase()}';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD0DFD0),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF07731F),
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            color: Color(0xFF111512),
                            fontWeight: FontWeight.w800,
                            height: 1.18,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDDE9DE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            classLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF126D24),
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _InfoLine(
                icon: Icons.calendar_today_rounded,
                text: dateText.isEmpty ? '-' : dateText,
              ),
              const SizedBox(height: 10),
              _InfoLine(
                icon: Icons.access_time_filled_rounded,
                text: timeText.isEmpty ? '-' : timeText,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4EA),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.description_rounded,
                        size: 28,
                        color: Color(0xFF0C6A20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'MOTIV SOLICITARE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF364037),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reason.isEmpty ? '-' : '"$reason"',
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF1D231D),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Acceptă'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D631B),
                          foregroundColor: Colors.white,
                          elevation: 2,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Respinge'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF7E7EE),
                          foregroundColor: const Color(0xFF9C2D62),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF0A7221)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF303730),
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
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
        _scale = 0.96;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        Future.delayed(const Duration(milliseconds: 90), widget.onTap);
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 90),
                opacity: _isPressed ? 0.10 : 0.0,
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
