import 'dart:ui';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart' show AdminClassesPage;
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_vacante.dart' as admin_vacante;

// â”€â”€â”€ Helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

String _timeAgo(Timestamp ts) {
  final diff = DateTime.now().difference(ts.toDate());
  if (diff.inSeconds < 60) return 'acum ${diff.inSeconds} sec';
  if (diff.inMinutes < 60) return 'acum ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'acum ${diff.inHours} ore';
  return 'acum ${diff.inDays} zile';
}

String _hhmm(Timestamp ts) {
  final dt = ts.toDate();
  final h = dt.hour;
  final m = dt.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '$h12:$m $ampm';
}

final Random _passwordRng = Random.secure();

String _randPassword(int len) {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
  return List.generate(
    len,
    (_) => chars[_passwordRng.nextInt(chars.length)],
  ).join();
}

String _humanizeAccessReason(String reason) {
  switch (reason.trim().toUpperCase()) {
    case 'ALREADY_IN_SCHOOL':
      return 'Elevul era deja în școală.';
    case 'ALREADY_USED':
      return 'Codul QR a fost deja folosit.';
    case 'EXPIRED':
      return 'Codul QR a expirat.';
    case 'NOT_FOUND':
      return 'Codul QR nu a fost găsit.';
    case 'USER_NOT_FOUND':
      return 'Utilizatorul nu a fost găsit.';
    case 'USER_DISABLED':
      return 'Contul elevului este dezactivat.';
    case 'NO_CLASS_ASSIGNED':
      return 'Elevul nu are clasă atribuită.';
    case 'NO_SCHEDULE':
      return 'Nu există orar pentru clasa elevului.';
    case 'BAD_SCHEDULE':
      return 'Orarul clasei este invalid.';
    case 'BAD_EXPIRES':
      return 'Codul QR nu are o expirare validă.';
    default:
      return reason.isEmpty ? 'Fără motiv suplimentar.' : reason;
  }
}

String _eventActionLabel(Map<String, dynamic> data) {
  final type = (data['type'] ?? '').toString();
  switch (type) {
    case 'entry':
      return 'Elevul a intrat';
    case 'exit':
      return 'Elevul a ieșit';
    case 'deny':
      return 'Acces respins';
    default:
      return 'Acces procesat';
  }
}

String _eventReasonText(Map<String, dynamic> data) {
  final reason = (data['reason'] ?? '').toString().trim();
  if (reason.isNotEmpty) {
    return _humanizeAccessReason(reason);
  }

  final type = (data['type'] ?? '').toString();
  if (type == 'entry') return 'Acces acordat pentru intrare în școală.';
  if (type == 'exit') return 'Acces acordat pentru ieșire din școală.';
  return 'Eveniment înregistrat fără detalii suplimentare.';
}

String _eventMetaText(Map<String, dynamic> data, {String? fallbackClassId}) {
  final parts = <String>[];
  final classId = (data['classId'] ?? '').toString().trim();
  final scanResult = (data['scanResult'] ?? '').toString().trim();

  final effectiveClassId = classId.isNotEmpty
      ? classId
      : (fallbackClassId ?? '');

  if (effectiveClassId.isNotEmpty) parts.add('Clasa $effectiveClassId');
  if (scanResult.isNotEmpty) {
    parts.add(
      scanResult == 'allowed' ? 'Scanare acceptată' : 'Scanare respinsă',
    );
  }

  return parts.join(' · ');
}

Future<T?> _showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 220),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel:
        barrierLabel ??
        MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return builder(dialogContext);
    },
    transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
      );

      return AnimatedBuilder(
        animation: curvedAnimation,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 14 * curvedAnimation.value,
                    sigmaY: 14 * curvedAnimation.value,
                  ),
                  child: Container(
                    color: Colors.black.withValues(
                      alpha: 0.55 * curvedAnimation.value,
                    ),
                  ),
                ),
              ),
              FadeTransition(opacity: curvedAnimation, child: child),
            ],
          );
        },
      );
    },
  );
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  AdminTurnstilesPage
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AdminTurnstilesPage extends StatefulWidget {
  const AdminTurnstilesPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminTurnstilesPage> createState() => _AdminTurnstilesPageState();
}

class _AdminTurnstilesPageState extends State<AdminTurnstilesPage> {
  int _refreshKey = 0;
  bool _sidebarBusy = false;
  final TextEditingController _searchC = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _replacePage(Widget page) async {
    if (_sidebarBusy || !mounted) return;
    _sidebarBusy = true;
    try {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => page,
        ),
      );
    } finally {
      _sidebarBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await _showBlurDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deconectare'),
        content: const Text('Esti sigur ca vrei sa te deloghezi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Nu'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
            child: const Text('Da'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Container(
      color: const Color(0xFFF8FFF5),
      child: Column(
        children: [
          if (!widget.embedded)
            _TurnstilesTopBar(
              displayName: AppSession.username ?? 'Admin',
              searchController: _searchC,
              onSearch: (value) => setState(() => _searchQuery = value),
            ),
          Expanded(
            child: _TurnstileBody(
              key: ValueKey(_refreshKey),
              onRefresh: () => setState(() => _refreshKey++),
              searchQuery: _searchQuery,
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFF0B7A21),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _TurnstilesSidebar(
                  selected: 'turnstiles',
                  onMenuTap: () => Navigator.of(context).pop(),
                  onStudentsTap: () => _replacePage(const AdminStudentsPage()),
                  onPersonalTap: () => _replacePage(const AdminTeachersPage()),
                  onTurnichetiTap: () {},
                  onClaseTap: () =>
                      _replacePage(const AdminClassesPage() as Widget),
                  onVacanteTap: () =>
                      _replacePage(const admin_vacante.AdminClassesPage()),
                  onParintiTap: () => _replacePage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _TurnstileBody
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TurnstileBody extends StatelessWidget {
  final VoidCallback onRefresh;
  final String searchQuery;

  const _TurnstileBody({
    super.key,
    required this.onRefresh,
    this.searchQuery = '',
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'gate')
          .snapshots(),
      builder: (context, gateSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .snapshots(),
          builder: (context, studentSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('accessEvents')
                  .orderBy('timestamp', descending: true)
                  .limit(200)
                  .snapshots(),
              builder: (context, eventSnap) {
                final gates = List<QueryDocumentSnapshot>.from(
                  gateSnap.data?.docs ?? [],
                );
                final students = List<QueryDocumentSnapshot>.from(
                  studentSnap.data?.docs ?? [],
                );
                final allEvents = List<QueryDocumentSnapshot>.from(
                  eventSnap.data?.docs ?? [],
                );

                // gate UID â†’ name map
                final gateMap = <String, String>{};
                for (final g in gates) {
                  final d = g.data() as Map<String, dynamic>;
                  gateMap[g.id] = (d['username'] ?? d['fullName'] ?? g.id)
                      .toString();
                }

                final studentClassMap = <String, String>{};
                final studentNameMap = <String, String>{};
                for (final student in students) {
                  final d = student.data() as Map<String, dynamic>;
                  studentClassMap[student.id] = (d['classId'] ?? '').toString();
                  studentNameMap[student.id] =
                      (d['fullName'] ?? d['username'] ?? student.id).toString();
                }

                // Filter gates by search query
                final searchLower = searchQuery.toLowerCase().trim();
                final filteredGates = gates.where((g) {
                  final d = g.data() as Map<String, dynamic>;
                  final name = (d['fullName'] ?? d['username'] ?? g.id)
                      .toString();
                  return name.toLowerCase().contains(searchLower);
                }).toList();

                // Daily stats (client-side filter)
                final now = DateTime.now();
                final todayStart = DateTime(now.year, now.month, now.day);
                final yesterdayStart = todayStart.subtract(
                  const Duration(days: 1),
                );

                final todayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  return !ts.toDate().isBefore(todayStart);
                }).length;

                final yesterdayCount = allEvents.where((e) {
                  final d = e.data() as Map<String, dynamic>;
                  final ts = d['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  final dt = ts.toDate();
                  return !dt.isBefore(yesterdayStart) &&
                      dt.isBefore(todayStart);
                }).length;

                final liveEvents = allEvents.take(30).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // â”€â”€ Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Control Turnicheți',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2F1E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Gestionează punctele de acces și jurnalele live de securitate.',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(0xFF5A8040),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // â”€â”€ Two-column content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Stanga: turnichete
                            Expanded(
                              flex: 6,
                              child: _ActiveHubsPanel(
                                gates: filteredGates,
                                allEvents: allEvents,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Dreapta: trafic live + scanari zilnice
                            Expanded(
                              flex: 4,
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _LiveTrafficPanel(
                                      events: liveEvents,
                                      gateMap: gateMap,
                                      studentClassMap: studentClassMap,
                                      studentNameMap: studentNameMap,
                                      allEvents: allEvents,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _DailyScansCard(
                                    todayCount: todayCount,
                                    yesterdayCount: yesterdayCount,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _ActiveHubsPanel
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActiveHubsPanel extends StatefulWidget {
  final List<QueryDocumentSnapshot> gates;
  final List<QueryDocumentSnapshot> allEvents;

  const _ActiveHubsPanel({required this.gates, required this.allEvents});

  @override
  State<_ActiveHubsPanel> createState() => _ActiveHubsPanelState();
}

class _ActiveHubsPanelState extends State<_ActiveHubsPanel> {
  static const int _pageSize = 6;
  int _currentPage = 0;

  List<Widget> _buildPageButtons(int totalPages, int currentPage) {
    final pages = <Widget>[];
    const maxVisible = 5;

    void addPage(int index) {
      pages.add(
        GestureDetector(
          onTap: () => setState(() => _currentPage = index),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: currentPage == index
                  ? const Color(0xFF424242)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: currentPage == index
                    ? const Color(0xFF424242)
                    : const Color(0xFFD0D0D0),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: currentPage == index
                    ? Colors.white
                    : const Color(0xFF333333),
              ),
            ),
          ),
        ),
      );
    }

    void addEllipsis() {
      pages.add(
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    if (totalPages <= maxVisible) {
      for (int i = 0; i < totalPages; i++) {
        addPage(i);
      }
    } else {
      addPage(0);

      if (currentPage > 2) addEllipsis();

      final start = (currentPage - 1).clamp(1, totalPages - 2);
      final end = (currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }

      if (currentPage < totalPages - 3) addEllipsis();

      addPage(totalPages - 1);
    }

    return pages;
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = widget.gates.isEmpty
        ? 0
        : (widget.gates.length / _pageSize).ceil();
    final currentPage = totalPages == 0
        ? 0
        : _currentPage.clamp(0, totalPages - 1);
    final visibleGates = totalPages == 0
        ? <QueryDocumentSnapshot>[]
        : widget.gates.skip(currentPage * _pageSize).take(_pageSize).toList();

    if (currentPage != _currentPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentPage = currentPage);
      });
    }

    return Container(
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F5E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Row(
              children: [
                const Icon(
                  Icons.door_front_door_rounded,
                  color: Color(0xFF0A7A21),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Turnichete',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2E1A),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A7A21),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${widget.gates.length} turnichete',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEF4EE)),
          Expanded(
            child: widget.gates.isEmpty
                ? const Center(
                    child: Text(
                      'Nu există turnichete înregistrate.',
                      style: TextStyle(color: Color(0xFF7B9E84), fontSize: 14),
                    ),
                  )
                : Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            const listPadding = EdgeInsets.fromLTRB(
                              16,
                              12,
                              16,
                              12,
                            );
                            const separatorHeight = 10.0;
                            final visibleCount = visibleGates.length;
                            final availableHeight =
                                constraints.maxHeight -
                                listPadding.vertical -
                                (max(visibleCount - 1, 0) * separatorHeight);
                            final collapsedHeight =
                                visibleCount == _pageSize && visibleCount > 0
                                ? availableHeight / visibleCount
                                : null;

                            return ListView.separated(
                              padding: listPadding,
                              itemCount: visibleCount,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: separatorHeight),
                              itemBuilder: (_, i) => _GateCard(
                                key: ValueKey(visibleGates[i].id),
                                doc: visibleGates[i],
                                allEvents: widget.allEvents,
                                collapsedHeight: collapsedHeight,
                              ),
                            );
                          },
                        ),
                      ),
                      if (totalPages > 1)
                        Container(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          decoration: const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: Color(0xFFE8E8E8)),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _PaginationButton(
                                icon: Icons.chevron_left_rounded,
                                enabled: currentPage > 0,
                                onTap: () => setState(
                                  () => _currentPage = currentPage - 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              ..._buildPageButtons(totalPages, currentPage),
                              const SizedBox(width: 4),
                              _PaginationButton(
                                icon: Icons.chevron_right_rounded,
                                enabled: currentPage < totalPages - 1,
                                onTap: () => setState(
                                  () => _currentPage = currentPage + 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _GateCard
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _GateCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final List<QueryDocumentSnapshot> allEvents;
  final double? collapsedHeight;

  const _GateCard({
    super.key,
    required this.doc,
    required this.allEvents,
    this.collapsedHeight,
  });

  @override
  State<_GateCard> createState() => _GateCardState();
}

class _GateCardState extends State<_GateCard> {
  final AdminApi _api = AdminApi();
  bool _isExpanded = false;
  bool _actionBusy = false;

  Future<void> _showSettingsDialog() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? data['fullName'] ?? widget.doc.id)
        .toString();
    var currentName = (data['fullName'] ?? data['username'] ?? widget.doc.id)
        .toString();
    final email = (data['email'] ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final nameC = TextEditingController(text: currentName);
    var busy = false;
    String? msg;
    bool msgIsError = false;

    Future<void> saveName(StateSetter setDialogState) async {
      final newName = nameC.text.trim();
      if (newName.isEmpty || newName == currentName) return;

      setDialogState(() {
        busy = true;
        msg = null;
      });
      setState(() => _actionBusy = true);

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.doc.id)
            .update({
              'fullName': newName,
              'updatedAt': FieldValue.serverTimestamp(),
            });
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          currentName = newName;
          msg = 'Numele a fost schimbat în "$newName".';
          msgIsError = false;
        });
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) {
          setState(() => _actionBusy = false);
        }
      }
    }

    Future<void> deleteTurnstile(
      BuildContext dialogContext,
      StateSetter setDialogState,
    ) async {
      final confirmed = await _showBlurDialog<bool>(
        context: dialogContext,
        barrierDismissible: true,
        barrierLabel: 'Confirmare stergere turnicheta',
        builder: (confirmContext) => SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFDEBEB),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Color(0xFFD92D20),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sterge turnicheta',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A2E1A),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Confirmarea este permanenta si va sterge contul turnichetei si datele asociate acesteia.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF7B8A77),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBF6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE1ECDB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Turnicheta selectata',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFF6D7B6A),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE9E7),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  currentName,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB42318),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                username,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667466),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(false),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFD7E5D2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Anuleaza'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFD92D20),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: () =>
                                    Navigator.of(confirmContext).pop(true),
                                child: const Text('Sterge turnicheta'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      if (confirmed != true) return;

      setDialogState(() {
        busy = true;
        msg = null;
      });
      // Capture navigator before the async gap so it stays valid
      // even after the Firestore stream triggers a rebuild.
      final nav = Navigator.of(context);
      setState(() => _actionBusy = true);
      try {
        await _api.deleteUser(username: username);
        nav.pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Turnicheta $username a fost ștearsă.')),
        );
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) setState(() => _actionBusy = false);
      }
    }

    Future<void> resetPassword(StateSetter setDialogState) async {
      final newPass = _randPassword(10);

      setDialogState(() {
        busy = true;
        msg = null;
      });
      setState(() => _actionBusy = true);

      try {
        final excel = xls.Excel.createExcel();
        final sheet = excel['Turnicheta'];
        sheet.appendRow([
          xls.TextCellValue('Nume Complet'),
          xls.TextCellValue('Username'),
          xls.TextCellValue('Email'),
          xls.TextCellValue('Parolă Nouă'),
        ]);
        sheet.appendRow([
          xls.TextCellValue(currentName),
          xls.TextCellValue(username),
          xls.TextCellValue(email.isEmpty ? '-' : email),
          xls.TextCellValue(newPass),
        ]);

        final bytes = excel.encode();
        if (bytes != null) {
          await FileSaver.instance.saveFile(
            name: 'turnicheta_$username',
            bytes: Uint8List.fromList(bytes),
            ext: 'xlsx',
            mimeType: MimeType.microsoftExcel,
          );
        }

        await _api.resetPassword(username: username, newPassword: newPass);
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = 'Date exportate și parola a fost resetată automat.';
          msgIsError = false;
        });
      } catch (e) {
        if (!mounted) return;

        setDialogState(() {
          busy = false;
          msg = e.toString().replaceFirst('Exception: ', '');
          msgIsError = true;
        });
      } finally {
        if (mounted) {
          setState(() => _actionBusy = false);
        }
      }
    }

    await _showBlurDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          InputDecoration fieldDeco(String hint) => InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: const Color(0xFFF4F9F3),
          );

          final initials = currentName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

          return PopScope(
            canPop: !busy,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 55,
                vertical: 16,
              ),
              child: Container(
                constraints: const BoxConstraints(
                  maxWidth: 860,
                  minHeight: 620,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(28, 18, 30, 18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Text(
                            'Setări Utilizator',
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1A2E1A),
                            ),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: busy ? null : () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF5F6771),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            child: const Text(
                              'Anulează',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          ElevatedButton(
                            onPressed: busy
                                ? null
                                : () async {
                                    final newName = nameC.text.trim();
                                    if (newName.isNotEmpty &&
                                        newName != currentName) {
                                      await saveName(setDialogState);
                                      return;
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E6B2E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Salvează modificările',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 18, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (msg != null) ...[
                                          ConstrainedBox(
                                            constraints: const BoxConstraints(
                                              maxWidth: 560,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: msgIsError
                                                    ? const Color(0xFFFFEBEB)
                                                    : const Color(0xFFE8F5E0),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                border: Border.all(
                                                  color: msgIsError
                                                      ? const Color(0xFFE57373)
                                                      : const Color(0xFF81C784),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    msgIsError
                                                        ? Icons.error_outline
                                                        : Icons
                                                              .check_circle_outline,
                                                    size: 16,
                                                    color: msgIsError
                                                        ? const Color(
                                                            0xFFE53935,
                                                          )
                                                        : const Color(
                                                            0xFF388E3C,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: SelectableText(
                                                      msg!,
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: msgIsError
                                                            ? const Color(
                                                                0xFFB71C1C,
                                                              )
                                                            : const Color(
                                                                0xFF1B5E20,
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                        ],
                                        const Text(
                                          'Detalii Turnichetă',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF1A2E1A),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        const Text(
                                          'Poți actualiza numele afișat și poți gestiona rapid accesul contului din acțiunile de mai jos.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.45,
                                            color: Color(0xFF6A7768),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        const Text(
                                          'NUME COMPLET',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 1,
                                            color: Color(0xFF2A5C30),
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEBEFE5),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: TextField(
                                            controller: nameC,
                                            enabled: !busy,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            textAlignVertical:
                                                TextAlignVertical.center,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF000000),
                                            ),
                                            decoration: InputDecoration(
                                              hintText: currentName,
                                              hintStyle: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF000000),
                                              ),
                                              border: InputBorder.none,
                                              isDense: true,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 14,
                                                  ),
                                            ),
                                            onSubmitted: (val) async {
                                              if (busy) return;
                                              final newName = val.trim();
                                              if (newName.isEmpty ||
                                                  newName == currentName) {
                                                return;
                                              }
                                              await saveName(setDialogState);
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'USERNAME',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1,
                                                      color: Color(0xFF2A5C30),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextField(
                                                    enabled: false,
                                                    controller:
                                                        TextEditingController(
                                                          text: username,
                                                        ),
                                                    decoration: fieldDeco(''),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF555555),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'TIP UTILIZATOR',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 1,
                                                      color: Color(0xFF2A5C30),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  TextField(
                                                    enabled: false,
                                                    controller:
                                                        TextEditingController(
                                                          text:
                                                              'Turnichetă de acces',
                                                        ),
                                                    decoration: fieldDeco(''),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      color: Color(0xFF555555),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 132,
                                  child: Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(
                                              alpha: 0.12,
                                            ),
                                            blurRadius: 16,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      padding: const EdgeInsets.all(3),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundColor: const Color(
                                          0xFFD8E7D3,
                                        ),
                                        backgroundImage: photoUrl.isNotEmpty
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child: photoUrl.isEmpty
                                            ? Text(
                                                initials.isNotEmpty
                                                    ? initials
                                                    : '?',
                                                style: const TextStyle(
                                                  color: Color(0xFF1A1A1A),
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 27,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              child: Center(
                                child: ElevatedButton.icon(
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.download_outlined,
                                          size: 18,
                                        ),
                                  label: const Text(
                                    'Extrage Date / Resetează Parola',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF7B2D5E),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 36,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => resetPassword(setDialogState),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: Center(
                                child: TextButton.icon(
                                  icon: busy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Color(0xFFD92D20),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.delete_outline,
                                          size: 22,
                                        ),
                                  label: const Text('Șterge Utilizator'),
                                  style: ButtonStyle(
                                    foregroundColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.disabled,
                                          )) {
                                            return const Color(0xFFED8F88);
                                          }
                                          return const Color(0xFFD92D20);
                                        }),
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                            WidgetState.hovered,
                                          )) {
                                            return const Color(0xFFF8E4E2);
                                          }
                                          if (states.contains(
                                            WidgetState.pressed,
                                          )) {
                                            return const Color(0xFFF3D6D3);
                                          }
                                          return Colors.transparent;
                                        }),
                                    overlayColor:
                                        WidgetStateProperty.resolveWith((
                                          states,
                                        ) {
                                          if (states.contains(
                                                WidgetState.hovered,
                                              ) ||
                                              states.contains(
                                                WidgetState.pressed,
                                              )) {
                                            return Colors.transparent;
                                          }
                                          return null;
                                        }),
                                    elevation: const WidgetStatePropertyAll(0),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
                                      ),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    textStyle: const WidgetStatePropertyAll(
                                      TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  onPressed: busy
                                      ? null
                                      : () => deleteTurnstile(
                                          ctx,
                                          setDialogState,
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    nameC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final gateName = (data['fullName'] ?? data['username'] ?? widget.doc.id)
        .toString();
    final gateUsername = (data['username'] ?? widget.doc.id).toString();
    final isOnline = (data['status'] ?? 'active') != 'disabled';

    final gateScans = widget.allEvents
        .where((e) {
          final d = e.data() as Map<String, dynamic>;
          return (d['gateUid'] ?? '') == widget.doc.id;
        })
        .take(3)
        .toList();

    void toggle() => setState(() => _isExpanded = !_isExpanded);

    return Container(
      constraints: widget.collapsedHeight == null
          ? null
          : BoxConstraints(minHeight: widget.collapsedHeight!),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8F0E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gate header row
            InkWell(
              onTap: toggle,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFFE8F5EA)
                            : const Color(0xFFF5F0E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.door_front_door_rounded,
                        color: isOnline
                            ? const Color(0xFF0A7A21)
                            : const Color(0xFFA08030),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  gateName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: Color(0xFF1A2E1A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'username: $gateUsername',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      onPressed: _actionBusy ? null : _showSettingsDialog,
                      tooltip: 'Setări turnichetă',
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFF4F9F3),
                        foregroundColor: const Color(0xFF5A8040),
                        minimumSize: const Size(36, 36),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: _actionBusy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF7B9E84),
                              ),
                            )
                          : const Icon(Icons.settings_rounded, size: 18),
                    ),
                    const SizedBox(width: 2),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 22,
                        color: Color(0xFF7B9E84),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Ultimele 3 scanari
            if (_isExpanded && gateScans.isNotEmpty)
              _LastScansSection(docs: gateScans),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _LastScansSection
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _LastScansSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _LastScansSection({required this.docs});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, color: Color(0xFFE8F5E0)),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            'ULTIMELE 3 SCANĂRI',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B9E84),
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...docs.map((e) {
          final d = e.data() as Map<String, dynamic>;
          final fullName = (d['fullName'] ?? '').toString();
          final ts = d['timestamp'] as Timestamp?;
          final isDenied = (d['type'] ?? '') == 'deny' || fullName.isEmpty;
          final parts = fullName
              .trim()
              .split(RegExp(r'\s+'))
              .where((p) => p.isNotEmpty)
              .toList();
          final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                isDenied
                    ? Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8E8),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.block_rounded,
                          size: 14,
                          color: Color(0xFF6B1A1A),
                        ),
                      )
                    : Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9EDDE),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A7A21),
                          ),
                        ),
                      ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fullName.isEmpty ? 'Etichetă ID necunoscută' : fullName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDenied
                          ? const Color(0xFF6B1A1A)
                          : const Color(0xFF1A2F1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDenied)
                  const Text(
                    'RESPINS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6B1A1A),
                    ),
                  )
                else if (ts != null)
                  Text(
                    _hhmm(ts),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7B9E84),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _LiveTrafficPanel
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _LiveTrafficPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> events;
  final Map<String, String> gateMap;
  final Map<String, String> studentClassMap;
  final Map<String, String> studentNameMap;
  final List<QueryDocumentSnapshot> allEvents;

  const _LiveTrafficPanel({
    required this.events,
    required this.gateMap,
    required this.studentClassMap,
    required this.studentNameMap,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8F5E0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Row(
              children: [
                const Text(
                  'Trafic în timp real',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2E1A),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE57373),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE8F5E0)),

          // Events list
          Expanded(
            child: events.isEmpty
                ? const Center(
                    child: Text(
                      'Nu există activitate recentă.',
                      style: TextStyle(color: Color(0xFF7B9E84), fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: events.length,
                    itemBuilder: (_, i) {
                      final d = events[i].data() as Map<String, dynamic>;
                      final gateUid = (d['gateUid'] ?? '').toString();
                      final gateName = gateMap[gateUid] ?? 'Poartă necunoscută';
                      final userId = (d['userId'] ?? '').toString();
                      final fullName = (d['fullName'] ?? '').toString();
                      final fallbackName = studentNameMap[userId] ?? '';
                      final fallbackClassId = studentClassMap[userId] ?? '';
                      final ts = d['timestamp'] as Timestamp?;
                      final isDenied =
                          (d['type'] ?? '') == 'deny' || fullName.isEmpty;

                      return _TrafficEntry(
                        gateName: gateName,
                        personName: fullName.isEmpty
                            ? (fallbackName.isEmpty
                                  ? 'Mediu neînregistrat detectat'
                                  : fallbackName)
                            : fullName,
                        actionLabel: _eventActionLabel(d),
                        reasonText: _eventReasonText(d),
                        metaText: _eventMetaText(
                          d,
                          fallbackClassId: fallbackClassId,
                        ),
                        timeAgo: ts != null ? _timeAgo(ts) : '',
                        isDenied: isDenied,
                        showConnector: i != events.length - 1,
                      );
                    },
                  ),
          ),

          // Buton pentru toate jurnalele
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: const BorderSide(color: Color(0xFFCCDDCC)),
                foregroundColor: const Color(0xFF1A2E1A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => _showAllLogsDialog(
                context,
                allEvents,
                gateMap,
                studentClassMap,
                studentNameMap,
              ),
              child: const Text(
                'Vezi toate jurnalele',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _TrafficEntry
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TrafficEntry extends StatelessWidget {
  final String gateName;
  final String personName;
  final String actionLabel;
  final String reasonText;
  final String metaText;
  final String timeAgo;
  final bool isDenied;
  final bool showConnector;

  const _TrafficEntry({
    required this.gateName,
    required this.personName,
    required this.actionLabel,
    required this.reasonText,
    required this.metaText,
    required this.timeAgo,
    required this.isDenied,
    this.showConnector = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                const SizedBox(height: 6),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFB04068)
                        : const Color(0xFF0A7A21),
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Container(
                    width: 2,
                    height: 86,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: isDenied
                          ? const Color(0xFFE7C8D3)
                          : const Color(0xFFCDE8D2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gateName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: Color(0xFF1A2E1A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7B9E84),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFFDF2F4)
                        : const Color(0xFFF4F9F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF2F4837),
                          ),
                          children: [
                            const TextSpan(
                              text: 'Utilizator: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2F4837),
                              ),
                            ),
                            TextSpan(text: personName),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            isDenied
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            size: 14,
                            color: isDenied
                                ? const Color(0xFFB04068)
                                : const Color(0xFF0A7A21),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isDenied
                                    ? const Color(0xFFB04068)
                                    : const Color(0xFF0A7A21),
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        reasonText,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: Color(0xFF5F7162),
                        ),
                      ),
                      if (metaText.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: Color(0xFF7B9E84),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                metaText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF7B9E84),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _DailyScansCard
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DailyScansCard extends StatelessWidget {
  final int todayCount;
  final int yesterdayCount;

  const _DailyScansCard({
    required this.todayCount,
    required this.yesterdayCount,
  });

  static String _fmt(int n) {
    if (n < 1000) return '$n';
    final t = n ~/ 1000;
    final r = n % 1000;
    return '$t,${r.toString().padLeft(3, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final double pct;
    if (yesterdayCount == 0) {
      pct = todayCount > 0 ? 100.0 : 0.0;
    } else {
      pct = ((todayCount - yesterdayCount) / yesterdayCount * 100).abs();
    }

    final isUp = todayCount >= yesterdayCount;
    final pctStr = '${pct.toStringAsFixed(0)}%';

    String trendText;
    if (pct < 0.5) {
      trendText = 'Fără schimbare față de ieri';
    } else if (isUp) {
      trendText = 'Creștere cu $pctStr față de ieri';
    } else {
      trendText = 'Scădere cu $pctStr față de ieri';
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A5C18),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOTAL SCANĂRI ZILNICE',
            style: TextStyle(
              color: Color(0xFF9FDCAD),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(todayCount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                pct < 0.5
                    ? Icons.trending_flat_rounded
                    : (isUp
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded),
                color: pct < 0.5
                    ? const Color(0xFF9FDCAD)
                    : (isUp
                          ? const Color(0xFF6FDFBF)
                          : const Color(0xFFFF8080)),
                size: 16,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  trendText,
                  style: TextStyle(
                    color: pct < 0.5
                        ? const Color(0xFF9FDCAD)
                        : (isUp
                              ? const Color(0xFF6FDFBF)
                              : const Color(0xFFFF8080)),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  Dialog Toate Jurnalele
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void _showAllLogsDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> fallbackEvents,
  Map<String, String> gateMap,
  Map<String, String> studentClassMap,
  Map<String, String> studentNameMap,
) {
  _showBlurDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 620),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
              child: Row(
                children: [
                  const Text(
                    'Toate jurnalele',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A2F1E),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: const Color(0xFF7B9E84),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEF4EE)),

            // Logs
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('accessEvents')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snap) {
                  final docs = List<QueryDocumentSnapshot>.from(
                    snap.data?.docs ?? fallbackEvents,
                  );
                  if (snap.connectionState == ConnectionState.waiting &&
                      docs.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF0A7A21),
                      ),
                    );
                  }
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        'Nu există înregistrări.',
                        style: TextStyle(
                          color: Color(0xFF7B9E84),
                          fontSize: 14,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final gateUid = (d['gateUid'] ?? '').toString();
                      final gateName = gateMap[gateUid] ?? 'Poartă necunoscută';
                      final userId = (d['userId'] ?? '').toString();
                      final fullName = (d['fullName'] ?? '').toString();
                      final fallbackName = studentNameMap[userId] ?? '';
                      final fallbackClassId = studentClassMap[userId] ?? '';
                      final ts = d['timestamp'] as Timestamp?;
                      final isDenied =
                          (d['type'] ?? '') == 'deny' || fullName.isEmpty;

                      return _TrafficEntry(
                        gateName: gateName,
                        personName: fullName.isEmpty
                            ? (fallbackName.isEmpty
                                  ? 'Mediu neînregistrat detectat'
                                  : fallbackName)
                            : fullName,
                        actionLabel: _eventActionLabel(d),
                        reasonText: _eventReasonText(d),
                        metaText: _eventMetaText(
                          d,
                          fallbackClassId: fallbackClassId,
                        ),
                        timeAgo: ts != null ? _timeAgo(ts) : '',
                        isDenied: isDenied,
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
  );
}

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFD0D0D0) : const Color(0xFFE8E8E8),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _TurnstilesSidebar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TurnstilesSidebar extends StatelessWidget {
  final String selected;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _TurnstilesSidebar({
    required this.selected,
    required this.onMenuTap,
    required this.onStudentsTap,
    required this.onPersonalTap,
    required this.onTurnichetiTap,
    required this.onClaseTap,
    required this.onVacanteTap,
    required this.onParintiTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.fullName?.isNotEmpty ?? false)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Admin');

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B7A21), Color(0xFF0C651D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Secretariat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SidebarTile(
            label: 'Meniu',
            icon: Icons.grid_view_rounded,
            selected: selected == 'menu',
            onTap: onMenuTap,
          ),
          _SidebarTile(
            label: 'Elevi',
            icon: Icons.school_rounded,
            selected: selected == 'students',
            onTap: onStudentsTap,
          ),
          _SidebarTile(
            label: 'Personal',
            icon: Icons.badge_rounded,
            selected: selected == 'personal',
            onTap: onPersonalTap,
          ),
          _SidebarTile(
            label: 'Parinti',
            icon: Icons.family_restroom_rounded,
            selected: selected == 'parents',
            onTap: onParintiTap,
          ),
          _SidebarTile(
            label: 'Clase',
            icon: Icons.table_chart_rounded,
            selected: selected == 'classes',
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Vacante',
            icon: Icons.event_available_rounded,
            selected: selected == 'vacante',
            onTap: onVacanteTap,
          ),
          _SidebarTile(
            label: 'Turnicheti',
            icon: Icons.door_front_door_rounded,
            selected: selected == 'turnstiles',
            onTap: onTurnichetiTap,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4A16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Delogheaza-te'),
              ),
            ),
          ),

          const SizedBox(height: 10),
          // User card at bottom
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E2C5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A4A10),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Liceul Central',
                        style: TextStyle(
                          color: Color(0xFFC9E6CE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _SidebarTile
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SidebarTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.17)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFCEF0D8), size: 18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE6F6EA),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _TurnstilesTopBar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TurnstilesTopBar extends StatelessWidget {
  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _TurnstilesTopBar({
    required this.displayName,
    required this.searchController,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A7A21), Color(0xFF07681C)],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Turnicheti',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228A37),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        color: Color(0xFF9FDCAD),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearch,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isCollapsed: true,
                            hintText: 'Cauta dupa nume...',
                            hintStyle: TextStyle(
                              color: Color(0xFF9FDCAD),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          cursorColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const AdminNotificationBell(),
        ],
      ),
    );
  }
}
