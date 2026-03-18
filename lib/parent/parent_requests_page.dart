import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
<<<<<<< HEAD
  late final Future<List<String>> _childrenUidsFuture;
=======
  List<String> _childrenUids = [];
  bool _isLoadingChildren = true;
>>>>>>> origin/main

  @override
  void initState() {
    super.initState();
<<<<<<< HEAD
    _childrenUidsFuture = _loadChildrenUids();
  }

  Future<List<String>> _loadChildrenUids() async {
    final parentUid = AppSession.uid;
    if (parentUid == null || parentUid.isEmpty) {
      throw Exception('Părinte neautentificat.');
    }

    final parentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .get();
    if (!parentDoc.exists) {
      throw Exception('Profilul părintelui nu a fost găsit.');
    }

    final data = parentDoc.data() ?? <String, dynamic>{};
    return List<String>.from(data['children'] ?? const <String>[]);
=======
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (AppSession.uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(AppSession.uid).get();
        final children = doc.data()?['children'];
        if (children is List) {
           _childrenUids = List<String>.from(children);
        }
      } catch (_) {}
    }
    if (mounted) setState(() => _isLoadingChildren = false);
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'acum';
    if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'acum ${diff.inHours} h';
    return '${diff.inDays} zile';
>>>>>>> origin/main
  }

  Future<void> _handleRequest(String docId, bool approved) async {
    final parentName = AppSession.username ?? "Parinte";
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
          content: Text(approved ? 'Cerere aprobată!' : 'Cerere respinsă.'),
          backgroundColor: approved ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
  }

  void _showRequestDetails(Map<String, dynamic> data) {
    final studentName = data['studentName'] ?? 'Elev necunoscut';
    final date = data['dateText'] ?? '-';
    final time = data['timeText'] ?? '-';
    final message = data['message'] ?? 'Fără motiv';

<<<<<<< HEAD
    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text("Cereri de învoire"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: bgGrey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          child: FutureBuilder<List<String>>(
            future: _childrenUidsFuture,
            builder: (context, childrenSnapshot) {
              if (childrenSnapshot.hasError) {
                return Center(child: Text('Eroare: ${childrenSnapshot.error}'));
              }
              if (!childrenSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final childrenUids = childrenSnapshot.data!;
              if (childrenUids.isEmpty) {
                return const Center(
                  child: Text(
                    'Nu ai elevi asociați pe acest cont.',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leaveRequests')
                    .where('studentUid', whereIn: childrenUids)
                    .where('status', isEqualTo: 'pending')
                    .orderBy('requestedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Eroare: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nu există cereri noi.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final studentName =
                          data['studentName'] ?? 'Elev necunoscut';
                      final date = data['dateText'] ?? '-';
                      final message = data['message'] ?? '';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            studentName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Data: $date'),
                              Text(
                                'Motiv: $message',
                                style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () =>
                                        _handleRequest(doc.id, false),
                                    child: const Text(
                                      'Respinge',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _handleRequest(doc.id, true),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryGreen,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Aprobă'),
=======
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          studentName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Data: $date", style: const TextStyle(fontSize: 16)),
              Text("Ora: $time", style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Text("Motiv:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(fontSize: 16)),
            ],
          ),
        ),
        actions: [
          _BouncingButton(
            onTap: () => Navigator.of(ctx).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text("Închide", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          "Cereri",
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
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFF5F7FA), // Background nou
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _isLoadingChildren
                      ? const Center(child: CircularProgressIndicator())
                      : _childrenUids.isEmpty
                          ? const Center(
                              child: Text(
                                "Nu există elevi atribuiți.",
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            )
                          : StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('leaveRequests')
                                  .where('studentUid', whereIn: _childrenUids)
                                  .where('status', isEqualTo: 'pending')
                                  .orderBy('requestedAt', descending: true)
                                  .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Eroare: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            "Nu există cereri noi.",
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 20),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>? ?? {};
                          final studentName =
                              data['studentName'] ?? 'Elev necunoscut';
                          final date = data['dateText'] ?? '-';
                          final time = data['timeText'] ?? '-';
                          final requestedAt =
                              (data['requestedAt'] as Timestamp?)?.toDate();
                          final timeAgo = requestedAt != null
                              ? _formatTimeAgo(requestedAt)
                              : '';

                          return Column(
                            children: [
                              // Cardul principal cu informații (click pentru detalii)
                              _BouncingButton(
                                onTap: () => _showRequestDetails(data),
                                borderRadius: BorderRadius.circular(24),
                                child: Container(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2F1),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.person,
                                            size: 32,
                                            color: Color(0xFF17B5A8)),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    studentName,
                                                    style: const TextStyle(
                                                      fontSize: 22,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF1F252B),
                                                    ),
                                                  ),
                                                ),
                                                if (timeAgo.isNotEmpty)
                                                  Text(
                                                    timeAgo,
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
                                              "Data: $date, Ora: $time",
                                              style: const TextStyle(
                                                  fontSize: 18,
                                                  color: Colors.grey),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Butoanele de acțiune separate (jos)
                              Row(
                                children: [
                                  Expanded(
                                    child: _BouncingButton(
                                      onTap: () => _handleRequest(doc.id, false),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: Colors.red, width: 1.5),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text("Respinge",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.red,
                                                fontSize: 16)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _BouncingButton(
                                      onTap: () => _handleRequest(doc.id, true),
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 12),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF7AAF5B),
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text("Aprobă",
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                                fontSize: 16)),
                                      ),
                                    ),
>>>>>>> origin/main
                                  ),
                                ],
                              ),
                            ],
<<<<<<< HEAD
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
=======
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
>>>>>>> origin/main
          ),
        ),
      ),
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
