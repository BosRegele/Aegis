import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_vacante.dart' as admin_vacante;

// ─── Helpers ──────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
//  AdminTurnstilesPage
// ─────────────────────────────────────────────────────────────────────────────

class AdminTurnstilesPage extends StatefulWidget {
  const AdminTurnstilesPage({super.key});

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
          pageBuilder: (_, __, ___) => page,
        ),
      );
    } finally {
      _sidebarBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await showDialog<void>(
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
              onClaseTap: () => _replacePage(const AdminClassesPage()),
              onVacanteTap: () =>
                  _replacePage(const admin_vacante.AdminClassesPage()),
              onParintiTap: () => _replacePage(const AdminParentsPage()),
              onLogoutTap: _showLogoutDialog,
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF0F3EC),
                child: Column(
                  children: [
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

// ─────────────────────────────────────────────────────────────────────────────
//  _TurnstileBody
// ─────────────────────────────────────────────────────────────────────────────

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
              .collection('accessEvents')
              .orderBy('timestamp', descending: true)
              .limit(200)
              .snapshots(),
          builder: (context, eventSnap) {
            final gates = List<QueryDocumentSnapshot>.from(
              gateSnap.data?.docs ?? [],
            );
            final allEvents = List<QueryDocumentSnapshot>.from(
              eventSnap.data?.docs ?? [],
            );

            // gate UID → name map
            final gateMap = <String, String>{};
            for (final g in gates) {
              final d = g.data() as Map<String, dynamic>;
              gateMap[g.id] =
                  (d['fullName'] ?? d['username'] ?? g.id).toString();
            }

            // Filter gates by search query
            final searchLower = searchQuery.toLowerCase().trim();
            final filteredGates = gates.where((g) {
              final d = g.data() as Map<String, dynamic>;
              final name =
                  (d['fullName'] ?? d['username'] ?? g.id).toString();
              return name.toLowerCase().contains(searchLower);
            }).toList();

            final activeCount = filteredGates.where((g) {
              final d = g.data() as Map<String, dynamic>;
              return (d['status'] ?? '') != 'disabled';
            }).length;

            // Daily stats (client-side filter)
            final now = DateTime.now();
            final todayStart = DateTime(now.year, now.month, now.day);
            final yesterdayStart =
                todayStart.subtract(const Duration(days: 1));

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
              return !dt.isBefore(yesterdayStart) && dt.isBefore(todayStart);
            }).length;

            final liveEvents = allEvents.take(30).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                  child: Row(
                    children: [
                      Expanded(
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
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCCDDCC)),
                          foregroundColor: const Color(0xFF1A2F1E),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'Actualizează statusul',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Two-column content ────────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stanga: hub-uri active
                        Expanded(
                          flex: 6,
                          child: _ActiveHubsPanel(
                            gates: filteredGates,
                            activeCount: activeCount,
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
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ActiveHubsPanel
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveHubsPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> gates;
  final List<QueryDocumentSnapshot> allEvents;
  final int activeCount;

  const _ActiveHubsPanel({
    required this.gates,
    required this.allEvents,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAE0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                const Icon(
                  Icons.device_hub_rounded,
                  color: Color(0xFF0A7A21),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Hub-uri active',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2F1E),
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A7A21),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$activeCount active',
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
            child: gates.isEmpty
                ? const Center(
                    child: Text(
                      'Nu există turnichete înregistrate.',
                      style: TextStyle(color: Color(0xFF7B9E84), fontSize: 14),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: gates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _GateCard(key: ValueKey(gates[i].id), doc: gates[i], allEvents: allEvents),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _GateCard
// ─────────────────────────────────────────────────────────────────────────────

class _GateCard extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final List<QueryDocumentSnapshot> allEvents;

  const _GateCard({super.key, required this.doc, required this.allEvents});

  @override
  State<_GateCard> createState() => _GateCardState();
}

enum _GateCardAction {
  settings,
  deleteTurnstile,
}

class _GateCardState extends State<_GateCard> {
  final AdminApi _api = AdminApi();
  bool _isExpanded = false;
  bool _actionBusy = false;

  Future<void> _deleteTurnstile() async {
    if (_actionBusy) return;

    final data = widget.doc.data() as Map<String, dynamic>;
    final username =
        (data['username'] ?? data['fullName'] ?? widget.doc.id).toString();

    setState(() => _actionBusy = true);
    try {
      await _api.deleteUser(username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Turnicheta $username a fost ștearsă.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la ștergerea turnichetei: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showSettingsDialog() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final username =
        (data['username'] ?? data['fullName'] ?? widget.doc.id).toString();
    var currentName =
        (data['fullName'] ?? data['username'] ?? widget.doc.id).toString();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final nameC = TextEditingController(text: currentName);
    var renameBusy = false;

    Widget buildSection(String title, Widget child) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDE8DA)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2F1E),
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      );
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final initials = currentName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

          return AlertDialog(
            title: const Text('Setări turnichetă'),
            content: SizedBox(
              width: 640,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF0A7A21), Color(0xFF07681C)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: const Color(0xFFD9EDDE),
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl) as ImageProvider
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    initials.isNotEmpty ? initials : '?',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A7A21),
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'ID: $username',
                                  style: const TextStyle(
                                    color: Color(0xFFC9E6CE),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    buildSection(
                      'Redenumire',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: nameC,
                            decoration: const InputDecoration(
                              labelText: 'Numele turnichetei',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: renameBusy
                                  ? null
                                  : () async {
                                      final newName = nameC.text.trim();
                                      if (newName.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Introdu un nume valid.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (newName == currentName) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Numele este deja setat.'),
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => renameBusy = true);
                                      try {
                                        await _api.updateUserFullName(
                                          username: username,
                                          fullName: newName,
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          currentName = newName;
                                          renameBusy = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Numele turnichetei a fost actualizat.'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setDialogState(() => renameBusy = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Eroare la actualizarea numelui: $e'),
                                          ),
                                        );
                                      }
                                    },
                              icon: renameBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.edit_rounded),
                              label: Text(
                                renameBusy ? 'Se salvează...' : 'Salvează numele',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    buildSection(
                      'Informații',
                      Text(
                        'Tip: Turnichetă de acces\nUsername: $username',
                        style: const TextStyle(
                          color: Color(0xFF3A5240),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: renameBusy ? null : () => Navigator.of(ctx).pop(),
                child: const Text('Închide'),
              ),
            ],
          );
        },
      ),
    );

    nameC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final gateName =
        (data['fullName'] ?? data['username'] ?? widget.doc.id).toString();
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
      decoration: BoxDecoration(
        color: const Color(0xFFF9FCF9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EAE0)),
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gate header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
              child: Row(
                children: [
                  // ── Tappable left area: icon + info ──────────────────────
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: toggle,
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEBF5ED),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.door_front_door_rounded,
                              color: Color(0xFF0A7A21),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                          color: Color(0xFF1A2F1E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Badge activ/inactiv
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isOnline
                                            ? const Color(0xFFE8F5EA)
                                            : const Color(0xFFF5F0E8),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: isOnline
                                              ? const Color(0xFFB8D9BE)
                                              : const Color(0xFFD9C8A8),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: isOnline
                                                  ? const Color(0xFF0A7A21)
                                                  : const Color(0xFFA08030),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            isOnline ? 'ACTIV' : 'INACTIV',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isOnline
                                                  ? const Color(0xFF0A7A21)
                                                  : const Color(0xFFA08030),
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_rounded,
                                      size: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      'Tudor Vianu, intrare elevi',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ── Right action buttons (independent of expand) ──────────
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0A7A21),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      side: const BorderSide(color: Color(0xFFB8D9BE)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Testează conexiunea',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    iconSize: 18,
                    color: const Color(0xFF7B9E84),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                  PopupMenuButton<_GateCardAction>(
                    enabled: !_actionBusy,
                    tooltip: 'Setări turnichetă',
                    offset: const Offset(0, 32),
                    color: Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (action) {
                      switch (action) {
                        case _GateCardAction.settings:
                          _showSettingsDialog();
                          break;
                        case _GateCardAction.deleteTurnstile:
                          _deleteTurnstile();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem<_GateCardAction>(
                        value: _GateCardAction.settings,
                        child: Row(
                          children: [
                            Icon(Icons.settings_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Setări'),
                          ],
                        ),
                      ),
                      PopupMenuItem<_GateCardAction>(
                        value: _GateCardAction.deleteTurnstile,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFFB3261E),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Șterge turnicheta',
                              style: TextStyle(color: Color(0xFFB3261E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: Center(
                        child: _actionBusy
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Icons.settings_rounded,
                                size: 18,
                                color: Color(0xFF7B9E84),
                              ),
                      ),
                    ),
                  ),
                  // Expand/collapse chevron button
                  IconButton(
                    icon: AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: Color(0xFF7B9E84),
                      ),
                    ),
                    onPressed: toggle,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),

            // Ultimele 3 scanari - vizibile doar cand este extins
              if (_isExpanded && gateScans.isNotEmpty) _LastScansSection(docs: gateScans),
            // Rand de actiuni jos
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
              child: Row(
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A7A21),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {},
                    child: const Text(
                      'Repornește dispozitivul',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.settings_rounded),
                    iconSize: 18,
                    color: const Color(0xFF7B9E84),
                    onPressed: () {},
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 28, minHeight: 28),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _LastScansSection
// ─────────────────────────────────────────────────────────────────────────────

class _LastScansSection extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;

  const _LastScansSection({required this.docs});

  @override
  Widget build(BuildContext context) {
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: Color(0xFFEEF4EE)),
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
              final isDenied =
                  (d['type'] ?? '') == 'deny' || fullName.isEmpty;
              final parts = fullName
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((p) => p.isNotEmpty)
                  .toList();
              final initials =
                  parts.take(2).map((p) => p[0].toUpperCase()).join();

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

// ─────────────────────────────────────────────────────────────────────────────
//  _LiveTrafficPanel
// ─────────────────────────────────────────────────────────────────────────────

class _LiveTrafficPanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> events;
  final Map<String, String> gateMap;
  final List<QueryDocumentSnapshot> allEvents;

  const _LiveTrafficPanel({
    required this.events,
    required this.gateMap,
    required this.allEvents,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth < 360
          ? 0.95
          : (constraints.maxWidth < 420
              ? 1.0
              : (constraints.maxWidth < 520 ? 1.08 : 1.12));
        double s(double v) => v * scale;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(s(16)),
            border: Border.all(color: const Color(0xFFE2EAE0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: s(8),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(s(16), s(14), s(16), s(10)),
                child: Row(
                  children: [
                    Text(
                      'Trafic în timp real',
                      style: TextStyle(
                        fontSize: s(16),
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A2F1E),
                      ),
                    ),
                    SizedBox(width: s(6)),
                    Container(
                      width: s(8),
                      height: s(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE57373),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFEEF4EE)),

              // Events list
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Text(
                          'Nu există activitate recentă.',
                          style: TextStyle(
                            color: const Color(0xFF7B9E84),
                            fontSize: s(13),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(vertical: s(8)),
                        itemCount: events.length,
                        itemBuilder: (_, i) {
                          final d = events[i].data() as Map<String, dynamic>;
                          final gateUid = (d['gateUid'] ?? '').toString();
                          final gateName =
                              gateMap[gateUid] ?? 'Poartă necunoscută';
                          final fullName = (d['fullName'] ?? '').toString();
                          final ts = d['timestamp'] as Timestamp?;
                          final isDenied =
                              (d['type'] ?? '') == 'deny' || fullName.isEmpty;
                          final classId = (d['classId'] ?? '').toString();
                          final String roleLabel;
                          if (isDenied) {
                            roleLabel = '';
                          } else if (classId.isNotEmpty) {
                            roleLabel = 'Elev';
                          } else {
                            roleLabel = 'Personal';
                          }

                          return _TrafficEntry(
                            gateName: gateName,
                            personName: fullName.isEmpty
                              ? 'Mediu neînregistrat detectat'
                                : fullName,
                            roleLabel: roleLabel,
                            timeAgo: ts != null ? _timeAgo(ts) : '',
                            isDenied: isDenied,
                            showConnector: i != events.length - 1,
                            scale: scale,
                          );
                        },
                      ),
              ),

              // Buton pentru toate jurnalele
              Padding(
                padding: EdgeInsets.fromLTRB(s(12), 0, s(12), s(12)),
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size(double.infinity, s(40)),
                    side: const BorderSide(color: Color(0xFFCCDDCC)),
                    foregroundColor: const Color(0xFF1A2F1E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(s(8)),
                    ),
                  ),
                  onPressed: () =>
                      _showAllLogsDialog(context, allEvents, gateMap),
                  child: Text(
                    'Vezi toate jurnalele',
                    style: TextStyle(
                      fontSize: s(13),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TrafficEntry
// ─────────────────────────────────────────────────────────────────────────────

class _TrafficEntry extends StatelessWidget {
  final String gateName;
  final String personName;
  final String roleLabel;
  final String timeAgo;
  final bool isDenied;
  final bool showConnector;
  final double scale;

  const _TrafficEntry({
    required this.gateName,
    required this.personName,
    required this.roleLabel,
    required this.timeAgo,
    required this.isDenied,
    this.showConnector = false,
    this.scale = 1,
  });

  @override
  Widget build(BuildContext context) {
    double s(double v) => v * scale;

    return Padding(
      padding: EdgeInsets.fromLTRB(s(14), s(6), s(14), s(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: s(10),
            child: Column(
              children: [
                Container(
                  width: s(6),
                  height: s(6),
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFB04068)
                        : const Color(0xFF0A7A21),
                    shape: BoxShape.circle,
                  ),
                ),
                if (showConnector)
                  Container(
                    width: s(2),
                    height: s(44),
                    margin: EdgeInsets.only(top: s(4)),
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
          SizedBox(width: s(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        gateName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: s(13),
                          color: const Color(0xFF1A2F1E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: s(10),
                        color: const Color(0xFF7B9E84),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: s(6)),
                Container(
                  padding: EdgeInsets.fromLTRB(s(10), s(8), s(10), s(8)),
                  decoration: BoxDecoration(
                    color: isDenied
                        ? const Color(0xFFF7EEF2)
                        : const Color(0xFFF1F5ED),
                    borderRadius: BorderRadius.circular(s(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: s(12),
                            color: const Color(0xFF2F4837),
                          ),
                          children: [
                            if (roleLabel.isNotEmpty)
                              TextSpan(
                                text: '$roleLabel: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2F4837),
                                ),
                              ),
                            TextSpan(text: personName),
                          ],
                        ),
                      ),
                      SizedBox(height: s(5)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDenied
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline_rounded,
                            size: s(12),
                            color: isDenied
                                ? const Color(0xFFB04068)
                                : const Color(0xFF0A7A21),
                          ),
                          SizedBox(width: s(4)),
                          Text(
                            isDenied ? 'ACCES RESPINS' : 'ACCES ACORDAT',
                            style: TextStyle(
                              fontSize: s(10),
                              fontWeight: FontWeight.w700,
                              color: isDenied
                                  ? const Color(0xFFB04068)
                                  : const Color(0xFF0A7A21),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
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

// ─────────────────────────────────────────────────────────────────────────────
//  _DailyScansCard
// ─────────────────────────────────────────────────────────────────────────────

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
        borderRadius: BorderRadius.circular(16),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Dialog Toate Jurnalele
// ─────────────────────────────────────────────────────────────────────────────

void _showAllLogsDialog(
  BuildContext context,
  List<QueryDocumentSnapshot> fallbackEvents,
  Map<String, String> gateMap,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        constraints:
            const BoxConstraints(maxWidth: 600, maxHeight: 620),
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
                  if (snap.connectionState ==
                          ConnectionState.waiting &&
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
                      final gateUid =
                          (d['gateUid'] ?? '').toString();
                      final gateName =
                          gateMap[gateUid] ?? 'Poartă necunoscută';
                      final fullName =
                          (d['fullName'] ?? '').toString();
                      final ts = d['timestamp'] as Timestamp?;
                      final isDenied =
                          (d['type'] ?? '') == 'deny' ||
                              fullName.isEmpty;
                      final classId = (d['classId'] ?? '').toString();
                      final String roleLabel;
                      if (isDenied) {
                        roleLabel = '';
                      } else if (classId.isNotEmpty) {
                        roleLabel = 'Elev';
                      } else {
                        roleLabel = 'Personal';
                      }

                      return _TrafficEntry(
                        gateName: gateName,
                        personName: fullName.isEmpty
                          ? 'Mediu neînregistrat detectat'
                            : fullName,
                        roleLabel: roleLabel,
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

// ─────────────────────────────────────────────────────────────────────────────
//  _TurnstilesSidebar
// ─────────────────────────────────────────────────────────────────────────────

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
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : 'A',
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

// ─────────────────────────────────────────────────────────────────────────────
//  _SidebarTile
// ─────────────────────────────────────────────────────────────────────────────

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
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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

// ─────────────────────────────────────────────────────────────────────────────
//  _TurnstilesTopBar
// ─────────────────────────────────────────────────────────────────────────────

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
