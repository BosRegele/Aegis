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

    final primaryColor = approved ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    final icon = approved ? Icons.check_circle_outline_rounded : Icons.highlight_off_rounded;
    final statusText = approved ? "Cerere acceptată" : "Cerere respinsă";
    final resolvedByLabel = approved ? "Acceptat de:" : "Respins de:";
    final resolvedAtLabel = approved ? "Acceptată la:" : "Respinsă la:";

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
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: const BorderRadius.only(
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
                      child: Icon(icon, size: 40, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      statusText,
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
                    _buildDetailRow(Icons.person_outline_rounded, 'Elev:', studentName, primaryColor),
                    const SizedBox(height: 16),
                    _buildDetailRow(Icons.send_rounded, 'Trimisă la:', requestedAtText, primaryColor),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildDetailRow(Icons.calendar_today_rounded, 'Data:', targetDate, primaryColor)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildDetailRow(Icons.access_time_rounded, 'Ora:', targetTime, primaryColor)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.admin_panel_settings_outlined, resolvedByLabel, reviewer, primaryColor),
                    const SizedBox(height: 12),
                    _buildDetailRow(Icons.done_all_rounded, resolvedAtLabel, reviewedAtText, primaryColor),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Motiv:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
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
                        style: const TextStyle(fontSize: 16, color: Color(0xFF2D3142), height: 1.4),
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
                    child: Text(
                      'Închide',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
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

  Widget _buildDetailRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2D3142)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
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
            color: Color(0xFFF5F7FA),
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
                      'Nu există elevi atribuiți.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('leaveRequests')
                        .where('studentUid', whereIn: _childrenUids)
                        .orderBy('reviewedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Eroare: ${snapshot.error}'));
                      }

                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final status = (data['status'] ?? '').toString();
                        return status == 'approved' || status == 'rejected';
                      }).toList();

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text(
                            'Nu există mesaje.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        );
                      }

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final data =
                              docs[index].data() as Map<String, dynamic>;

                          final studentName =
                              data['studentName'] ?? 'Elev necunoscut';
                          final classId = data['classId'] ?? '-';
                          final targetDate = data['dateText'] ?? '-';
                          final targetTime = data['timeText'] ?? '-';
                          final status = data['status'] ?? 'pending';
                          final reviewedAt = (data['reviewedAt'] as Timestamp?)
                              ?.toDate();
                          final timeAgo = reviewedAt != null
                              ? _formatTimeAgo(reviewedAt)
                              : '';

                          final approved = status == 'approved';

                          return _BouncingButton(
                            onTap: () => _showMessageDetails(data),
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
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8EAF6),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Color(0xFF5C6BC0),
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
                                              MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                approved
                                                    ? 'Cerere acceptată'
                                                    : 'Cerere respinsă',
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
                                        Text(
                                          'Elev: $studentName ($classId)',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            color: Color(0xFF1F252B),
                                          ),
                                        ),
                                        Text(
                                          'Data: $targetDate, Ora: $targetTime',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey,
                                          ),
                                        ),
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
