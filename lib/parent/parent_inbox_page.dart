import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class ParentInboxPage extends StatefulWidget {
  const ParentInboxPage({super.key});

  @override
  State<ParentInboxPage> createState() => _ParentInboxPageState();
}

class _ParentInboxPageState extends State<ParentInboxPage> {
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
  }

  String _formatFullDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageDetails(Map<String, dynamic> data) {
    final studentName = data['studentName'] ?? 'Elev necunoscut';
    final targetDate = data['dateText'] ?? '-';
    final targetTime = data['timeText'] ?? '-';
    final message = data['message'] ?? 'Fără motiv';
    final status = data['status'] ?? 'pending';
    final reviewer = data['reviewedByName'] ?? 'Necunoscut';
    final bool approved = status == 'approved';
    final requestedAtTimestamp = data['requestedAt'] as Timestamp?;
    String requestedAtText = '-';
    if (requestedAtTimestamp != null) {
      requestedAtText = _formatFullDate(requestedAtTimestamp.toDate());
    }

    final reviewedAtTimestamp = data['reviewedAt'] as Timestamp?;
    String reviewedAtText = '-';
    if (reviewedAtTimestamp != null) {
      reviewedAtText = _formatFullDate(reviewedAtTimestamp.toDate());
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          approved ? "Cerere acceptată" : "Cerere respinsă",
          style: TextStyle(
            color: approved ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Elev: $studentName",
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 16),
              const Text("Detalii cerere inițială:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Trimisă la: $requestedAtText",
                  style: const TextStyle(fontSize: 16)),
              Text("Pentru data: $targetDate, $targetTime",
                  style: const TextStyle(fontSize: 16, color: Colors.black87)),
              const SizedBox(height: 16),
              const Text("Motiv:",
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              Text(message, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              const Text("Detalii rezolvare:",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text("Rezolvat de: $reviewer", style: const TextStyle(fontSize: 16)),
              Text("La data: $reviewedAtText", style: const TextStyle(fontSize: 16)),
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
              child: const Text("Închide", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
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
          "Mesaje",
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
                            // Nu putem folosi 'whereIn' status aici, filtram local
                            .orderBy('reviewedAt', descending: true)
                            .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text("Eroare: ${snapshot.error}"));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filtram local doar approved/rejected
                final docs = snapshot.data!.docs.where((d) {
                  final s = d['status'];
                  return s == 'approved' || s == 'rejected';
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                  "Nu există mesaje.",
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final studentName = data['studentName'] ?? "Elev necunoscut";
                    final classId = data['classId'] ?? "-";
                    final status = data['status'] ?? "pending";
                    final requestedAt = data['requestedAt'] as Timestamp?;
                    String sentAtString = '-';
                    if (requestedAt != null) {
                      sentAtString = _formatFullDate(requestedAt.toDate());
                    }

                    final reviewedAt =
                        (data['reviewedAt'] as Timestamp?)?.toDate();
                    final timeAgo =
                        reviewedAt != null ? _formatTimeAgo(reviewedAt) : '';

                    final bool approved = status == 'approved';

                    return _BouncingButton(
                      onTap: () => _showMessageDetails(data),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4)),
                        ]),
                        child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8EAF6), // Light Indigo background
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.person,
                                size: 32, color: const Color(0xFF5C6BC0)), // Indigo Icon
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        approved
                                            ? "Cerere acceptată"
                                            : "Cerere respinsă",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: approved
                                              ? Colors.green
                                              : Colors.red,
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
                                Text("Elev: $studentName ($classId)", style: const TextStyle(fontSize: 18, color: Color(0xFF1F252B))),
                                Text("Trimisă la: $sentAtString", style: const TextStyle(fontSize: 16, color: Colors.grey)),
                              ],
                            ),
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
