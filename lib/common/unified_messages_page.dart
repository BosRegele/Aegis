import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../session.dart';

enum UnifiedInboxRole { student, parent, teacher }

class UnifiedMessagesPage extends StatefulWidget {
  final UnifiedInboxRole role;
  final VoidCallback? onBack;

  const UnifiedMessagesPage({super.key, required this.role, this.onBack});

  @override
  State<UnifiedMessagesPage> createState() => _UnifiedMessagesPageState();
}

class _UnifiedMessagesPageState extends State<UnifiedMessagesPage> {
  bool _loadingChildren = false;

  @override
  void initState() {
    super.initState();
    if (widget.role == UnifiedInboxRole.parent) {
      _loadingChildren = true;
      _loadChildren();
    }
  }

  Future<void> _loadChildren() async {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
        });
      }
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (mounted) {
        setState(() {
          _loadingChildren = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingChildren = false;
        });
      }
    }
  }

  List<Stream<QuerySnapshot<Map<String, dynamic>>>> _buildStreams(String uid) {
    final base = FirebaseFirestore.instance.collection('secretariatMessages');
    switch (widget.role) {
      case UnifiedInboxRole.student:
        return [
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'student')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
        ];
      case UnifiedInboxRole.teacher:
        return [
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: '')
              .snapshots(),
          base
              .where('recipientRole', isEqualTo: 'teacher')
              .where('recipientUid', isEqualTo: uid)
              .snapshots(),
        ];
      case UnifiedInboxRole.parent:
        return [
          base
              .where('recipientRole', isEqualTo: 'parent')
              .where('studentUid', isEqualTo: '')
              .snapshots(),
        ];
    }
  }

  Widget _buildMergedSecretariatStream(
    List<Stream<QuerySnapshot<Map<String, dynamic>>>> streams,
    Widget Function(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs)
    onReady,
  ) {
    if (streams.isEmpty) {
      return onReady(<QueryDocumentSnapshot<Map<String, dynamic>>>[]);
    }

    Widget step(
      int index,
      List<QueryDocumentSnapshot<Map<String, dynamic>>> acc,
    ) {
      if (index >= streams.length) {
        final byId = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
        for (final doc in acc) {
          byId[doc.id] = doc;
        }
        return onReady(byId.values.toList());
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: streams[index],
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Eroare: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return step(index + 1, [...acc, ...snap.data!.docs]);
        },
      );
    }

    return step(0, <QueryDocumentSnapshot<Map<String, dynamic>>>[]);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _buildStudentDecisionsStream(
    String uid,
  ) {
    return FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: uid)
        .orderBy('requestedAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<Map<String, String>> _loadUsernames(Set<String> uids) async {
    if (uids.isEmpty) return const <String, String>{};

    final result = <String, String>{};
    const chunkSize = 10;
    final ids = uids.toList();

    for (int i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.skip(i).take(chunkSize).toList();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final username = (data['username'] ?? '').toString().trim();
        if (username.isNotEmpty) {
          result[doc.id] = username;
        }
      }
    }

    return result;
  }

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'acum';
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours} h';
    return '${diff.inDays} zile';
  }

  String _audienceFallback() {
    switch (widget.role) {
      case UnifiedInboxRole.student:
        return 'Destinatari: Elevi';
      case UnifiedInboxRole.parent:
        return 'Destinatari: Părinți';
      case UnifiedInboxRole.teacher:
        return 'Destinatari: Diriginți';
    }
  }

  void _goBack(BuildContext context) {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final uid = (AppSession.uid ?? '').trim();
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Sesiune invalidă.')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        toolbarHeight: 68,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => _goBack(context),
        ),
        title: const Text(
          'Mesaje',
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
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: _loadingChildren
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(uid),
        ),
      ),
    );
  }

  Widget _buildBody(String uid) {
    final streams = _buildStreams(uid);
    return _buildMergedSecretariatStream(streams, (secretariatDocs) {
      final secretariatItems = _mapSecretariatItems(secretariatDocs)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (widget.role != UnifiedInboxRole.student) {
        return _buildItemsList(secretariatItems);
      }

      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _buildStudentDecisionsStream(uid),
        builder: (context, leaveSnap) {
          if (leaveSnap.hasError) {
            return Center(child: Text('Eroare: ${leaveSnap.error}'));
          }

          final decisionDocs =
              leaveSnap.data?.docs ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final reviewerUids = decisionDocs
              .map(
                (doc) => (doc.data()['reviewedByUid'] ?? '').toString().trim(),
              )
              .where((uid) => uid.isNotEmpty)
              .toSet();

          return FutureBuilder<Map<String, String>>(
            future: _loadUsernames(reviewerUids),
            builder: (context, usersSnap) {
              final usernames = usersSnap.data ?? const <String, String>{};
              final decisionItems = _mapStudentDecisionItems(
                decisionDocs,
                usernames,
              );
              final allItems = <_UnifiedMessageItem>[
                ...secretariatItems,
                ...decisionItems,
              ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return _buildItemsList(allItems);
            },
          );
        },
      );
    });
  }

  List<_UnifiedMessageItem> _mapSecretariatItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return docs.map((doc) {
      final data = doc.data();
      final title = (data['title'] ?? 'Mesaj Secretariat').toString();
      final sender = (data['senderName'] ?? 'Secretariat').toString();
      final message = (data['message'] ?? '').toString();
      final classId = (data['classId'] ?? '').toString();
      final studentName = (data['studentName'] ?? '').toString();
      final audienceLabel = (data['audienceLabel'] ?? '').toString().trim();
      final createdAt =
          ((data['createdAt'] as Timestamp?)?.toDate() ??
              (data['reviewedAt'] as Timestamp?)?.toDate() ??
              (data['requestedAt'] as Timestamp?)?.toDate()) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final legacyLine = widget.role == UnifiedInboxRole.parent
          ? (studentName.isEmpty && classId.isEmpty
                ? ''
                : 'Elev: ${studentName.isEmpty ? '-' : studentName}${classId.isEmpty ? '' : ' ($classId)'}')
          : (classId.isEmpty ? '' : 'Clasa $classId');

      final audienceLine = audienceLabel.isNotEmpty
          ? audienceLabel
          : (legacyLine.isNotEmpty ? legacyLine : _audienceFallback());

      return _UnifiedMessageItem(
        title: title,
        audienceLine: audienceLine,
        sender: sender,
        message: message,
        createdAt: createdAt,
        icon: Icons.campaign_rounded,
        accent: const Color(0xFF1E5EC8),
        iconBg: const Color(0xFFDCEBFF),
      );
    }).toList();
  }

  List<_UnifiedMessageItem> _mapStudentDecisionItems(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Map<String, String> usernamesByUid,
  ) {
    return docs
        .where((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final source = (data['source'] ?? '').toString();
          return source != 'secretariat' &&
              (status == 'approved' || status == 'rejected');
        })
        .map((doc) {
          final data = doc.data();
          final status = (data['status'] ?? '').toString();
          final dateText = (data['dateText'] ?? '').toString();
          final timeText = (data['timeText'] ?? '').toString();
          final reviewedByUid = (data['reviewedByUid'] ?? '').toString().trim();
          final sender =
              usernamesByUid[reviewedByUid] ??
              (data['reviewedByName'] ?? 'Diriginte').toString();
          final message = (data['message'] ?? '').toString();
          final reviewedAt = (data['reviewedAt'] as Timestamp?)?.toDate();
          final requestedAt = (data['requestedAt'] as Timestamp?)?.toDate();
          final when =
              reviewedAt ??
              requestedAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final approved = status == 'approved';

          final audience = timeText.trim().isEmpty
              ? 'Cerere: $dateText'
              : 'Cerere: $dateText, $timeText';

          return _UnifiedMessageItem(
            title: approved ? 'Cerere aprobată' : 'Cerere respinsă',
            audienceLine: audience,
            sender: sender,
            message: message,
            createdAt: when,
            icon: approved ? Icons.check_circle_rounded : Icons.cancel_rounded,
            accent: approved
                ? const Color(0xFF2E7D32)
                : const Color(0xFFC62828),
            iconBg: approved
                ? const Color(0xFFE4F3E5)
                : const Color(0xFFF8E1E1),
          );
        })
        .toList();
  }

  Widget _buildItemsList(List<_UnifiedMessageItem> items) {
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'Nu există mesaje.',
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      );
    }

    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, size: 32, color: item.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                              color: item.accent,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(item.createdAt),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF90A4AE),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.audienceLine,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF1F252B),
                      ),
                    ),
                    Text(
                      'De la: ${item.sender}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF3B4350),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.message,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnifiedMessageItem {
  final String title;
  final String audienceLine;
  final String sender;
  final String message;
  final DateTime createdAt;
  final IconData icon;
  final Color accent;
  final Color iconBg;

  const _UnifiedMessageItem({
    required this.title,
    required this.audienceLine,
    required this.sender,
    required this.message,
    required this.createdAt,
    required this.icon,
    required this.accent,
    required this.iconBg,
  });
}
