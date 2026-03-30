import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
  List<String> _childrenUids = [];
  bool _isLoadingChildren = true;

  @override
  void initState() {
    super.initState();
    _loadChildren();
  }

  Future<void> _loadChildren() async {
    if (AppSession.uid != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(AppSession.uid)
            .get();
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
  }

  String _formatFullDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleRequest(String docId, bool approved) async {
    final parentName =
        (AppSession.fullName != null && AppSession.fullName!.isNotEmpty)
        ? AppSession.fullName!
        : (AppSession.username ?? "Parinte");
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

  void _showRequestDetails(String docId, Map<String, dynamic> data) {
    // Mark as viewed so the badge decreases
    FirebaseFirestore.instance.collection('leaveRequests').doc(docId).update({
      'viewedByParent': true,
    });

    final studentName = data['studentName'] ?? 'Elev necunoscut';
    final date = data['dateText'] ?? '-';
    final time = data['timeText'] ?? '-';
    final message = data['message'] ?? 'Fără motiv';
    final requestedAtTimestamp = data['requestedAt'] as Timestamp?;
    String requestedAtText = '-';
    if (requestedAtTimestamp != null) {
      requestedAtText = _formatFullDate(requestedAtTimestamp.toDate());
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 20,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF7AAF5B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.assignment_ind_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildDetailRow(
                      Icons.send_rounded,
                      'Trimisă la:',
                      requestedAtText,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(
                      Icons.calendar_today_rounded,
                      'Data:',
                      date,
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.access_time_rounded, 'Ora:', time),
                    const SizedBox(height: 16),
                    const Divider(height: 24),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Motiv:',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2D3142),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: _BouncingButton(
                  onTap: () => Navigator.of(ctx).pop(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F7FA),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'Închide',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7AAF5B),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF7AAF5B).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: const Color(0xFF7AAF5B)),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2D3142),
              ),
            ),
          ],
        ),
      ],
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
                          stream: _childrenUids.isEmpty
                              ? null
                              : FirebaseFirestore.instance
                                    .collection('leaveRequests')
                                    .where('studentUid', whereIn: _childrenUids)
                                    .snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasError) {
                              return Center(
                                child: Text('Eroare reală: ${snapshot.error}'),
                              );
                            }
                            if (!snapshot.hasData) {
                              return const SizedBox();
                            }

                            final docs =
                                snapshot.data!.docs.where((doc) {
                                  final data =
                                      doc.data() as Map<String, dynamic>;
                                  final targetRole = (data['targetRole'] ?? '')
                                      .toString();
                                  final status = (data['status'] ?? '')
                                      .toString();
                                  final source = (data['source'] ?? '')
                                      .toString();
                                  return targetRole == 'parent' &&
                                      status == 'pending' &&
                                      source != 'secretariat';
                                }).toList()..sort((a, b) {
                                  final aTs =
                                      (a.data()
                                              as Map<
                                                String,
                                                dynamic
                                              >)['requestedAt']
                                          as Timestamp?;
                                  final bTs =
                                      (b.data()
                                              as Map<
                                                String,
                                                dynamic
                                              >)['requestedAt']
                                          as Timestamp?;
                                  final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                                  final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                                  return bMs.compareTo(aMs);
                                });
                            if (docs.isEmpty) {
                              return const Center(
                                child: Text(
                                  "Nu există cereri noi.",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              );
                            }

                            return ListView.separated(
                              itemCount: docs.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 20),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data =
                                    doc.data() as Map<String, dynamic>? ?? {};
                                final studentName =
                                    data['studentName'] ?? 'Elev necunoscut';
                                final date = data['dateText'] ?? '-';
                                final time = data['timeText'] ?? '-';
                                final requestedAt =
                                    (data['requestedAt'] as Timestamp?)
                                        ?.toDate();
                                final timeAgo = requestedAt != null
                                    ? _formatTimeAgo(requestedAt)
                                    : '';

                                return Column(
                                  children: [
                                    // Cardul principal cu informații (click pentru detalii)
                                    _BouncingButton(
                                      onTap: () =>
                                          _showRequestDetails(doc.id, data),
                                      borderRadius: BorderRadius.circular(24),
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.08,
                                              ),
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
                                              child: const Icon(
                                                Icons.person,
                                                size: 32,
                                                color: Color(0xFF17B5A8),
                                              ),
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
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                  0xFF1F252B,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                      if (timeAgo.isNotEmpty)
                                                        Text(
                                                          timeAgo,
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                                color: Color(
                                                                  0xFF90A4AE,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                              ),
                                                        ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    "Data: $date, Ora: $time",
                                                    style: const TextStyle(
                                                      fontSize: 18,
                                                      color: Colors.grey,
                                                    ),
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
                                            onTap: () =>
                                                _handleRequest(doc.id, false),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.red,
                                                  width: 1.5,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                "Respinge",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.red,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _BouncingButton(
                                            onTap: () =>
                                                _handleRequest(doc.id, true),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF7AAF5B),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              alignment: Alignment.center,
                                              child: const Text(
                                                "Aprobă",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              },
                            );
                          },
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
