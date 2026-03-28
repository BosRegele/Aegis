import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart';
import 'admin_notifications.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;

// ─────────────────────────────────────────────────────────────────────────────
//  AdminParentsPage
// ─────────────────────────────────────────────────────────────────────────────

class AdminParentsPage extends StatefulWidget {
  const AdminParentsPage({super.key});

  @override
  State<AdminParentsPage> createState() => _AdminParentsPageState();
}

class _AdminParentsPageState extends State<AdminParentsPage> {
  bool _sidebarBusy = false;
  String _searchQuery = '';
  final TextEditingController _searchC = TextEditingController();
  int _page = 0;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────────────

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
                // ── Sidebar ──────────────────────────────────────────────────────
                _ParentsSidebar(
                  selected: 'parents',
                  onMenuTap: () => Navigator.of(context).pop(),
                  onStudentsTap: () => _replacePage(const AdminStudentsPage()),
                  onPersonalTap: () => _replacePage(const AdminTeachersPage()),
                  onTurnichetiTap: () =>
                      _replacePage(const AdminTurnstilesPage()),
                  onClaseTap: () => _replacePage(const AdminClassesPage()),
                  onVacanteTap: () =>
                      _replacePage(const admin_vacante.AdminClassesPage()),
                  onParintiTap: () {},
                  onLogoutTap: _showLogoutDialog,
                ),

                // ── Content ──────────────────────────────────────────────────────
                Expanded(
                  child: Container(
                    color: const Color(0xFFF0F3EC),
                    child: Column(
                      children: [
                        _ParentsTopBar(
                          displayName: AppSession.username ?? 'Admin',
                          searchController: _searchC,
                          onSearch: (value) => setState(() {
                            _searchQuery = value.trim().toLowerCase();
                            _page = 0;
                          }),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where('role', isEqualTo: 'parent')
                                .snapshots(),
                            builder: (context, parentSnap) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('users')
                                    .where('role', isEqualTo: 'student')
                                    .snapshots(),
                                builder: (context, studentSnap) {
                                  final studentMap = <String, String>{};
                                  for (final student in
                                      studentSnap.data?.docs ?? []) {
                                    final data =
                                        student.data() as Map<String, dynamic>;
                                    studentMap[student.id] =
                                        (data['fullName'] ??
                                                data['username'] ??
                                                student.id)
                                            .toString();
                                  }

                                  final parents =
                                      List<QueryDocumentSnapshot>.from(
                                    parentSnap.data?.docs ?? [],
                                  );
                                  parents.sort((a, b) {
                                    final aName =
                                        ((a.data() as Map)['fullName'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    final bName =
                                        ((b.data() as Map)['fullName'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    return aName.compareTo(bName);
                                  });

                                  final filtered = _searchQuery.isEmpty
                                      ? parents
                                      : parents.where((parent) {
                                          final data = parent.data()
                                              as Map<String, dynamic>;
                                          final name = (data['fullName'] ?? '')
                                              .toString()
                                              .toLowerCase();
                                          final user =
                                              (data['username'] ?? parent.id)
                                                  .toString()
                                                  .toLowerCase();
                                          final email = '$user@school.local';
                                          final childIds = List<String>.from(
                                            data['children'] ?? [],
                                          );
                                          final childNames = childIds
                                              .map(
                                                (id) =>
                                                    (studentMap[id] ?? id)
                                                        .toLowerCase(),
                                              )
                                              .join(' ');
                                          return name.contains(_searchQuery) ||
                                              user.contains(_searchQuery) ||
                                              email.contains(_searchQuery) ||
                                              childNames.contains(_searchQuery);
                                        }).toList();

                                  if (parentSnap.connectionState ==
                                          ConnectionState.waiting &&
                                      parents.isEmpty) {
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF0A7A21),
                                      ),
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const _ParentsPageHeader(),
                                      Expanded(
                                        child: _ParentsTablePanel(
                                          parents: filtered,
                                          studentMap: studentMap,
                                          page: _page,
                                          pageSize: _pageSize,
                                          onPageChanged: (page) =>
                                              setState(() => _page = page),
                                        ),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ParentsSidebar
// ─────────────────────────────────────────────────────────────────────────────

class _ParentsSidebar extends StatelessWidget {
  final String selected;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _ParentsSidebar({
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

          // Logout button
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

// ─────────────────────────────────────────────────────────────────────────────
//  _ParentsTopBar
// ─────────────────────────────────────────────────────────────────────────────

class _ParentsTopBar extends StatelessWidget {
  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _ParentsTopBar({
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
            'Parinti',
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
                      const Icon(Icons.search, color: Color(0xFF9FDCAD), size: 18),
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
                            hintText:
                                'Cauta dupa nume, ID, elevi asignati sau email...',
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

// ─────────────────────────────────────────────────────────────────────────────
//  _ParentsPageHeader
// ─────────────────────────────────────────────────────────────────────────────

class _ParentsPageHeader extends StatelessWidget {
  const _ParentsPageHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Părinți',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2F1E),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Gestionează și monitorizează activitatea părinților, copiii înscriși\n'
            'și detaliile de contact într-o vizualizare centrală.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ParentsTablePanel
// ─────────────────────────────────────────────────────────────────────────────

class _ParentsTablePanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> parents;
  final Map<String, String> studentMap;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const _ParentsTablePanel({
    required this.parents,
    required this.studentMap,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (parents.length / pageSize).ceil().clamp(1, 99999);
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final end = (start + pageSize).clamp(0, parents.length);
    final pageItems = parents.sublist(start, end);

    return Container(
      margin: const EdgeInsets.fromLTRB(32, 0, 32, 24),
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
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FCF9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFFE2EAE0))),
            ),
            child: const Row(
              children: [
                Expanded(flex: 28, child: _TH('NUME PĂRINTE')),
                Expanded(flex: 30, child: _TH('ELEVI')),
                Expanded(flex: 28, child: _TH('EMAIL')),
                Expanded(flex: 14, child: _TH('SETĂRI')),
              ],
            ),
          ),

          // Rows
          Expanded(
            child: parents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person_search_rounded,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nu există părinți înregistrați.',
                          style: TextStyle(
                            color: Color(0xFF7B9E84),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: pageItems.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF4EE)),
                    itemBuilder: (_, i) => _ParentRow(
                      doc: pageItems[i],
                      studentMap: studentMap,
                    ),
                  ),
          ),

          // Pagination bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF9FCF9),
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Color(0xFFE2EAE0))),
            ),
            child: Row(
              children: [
                Text(
                  parents.isEmpty
                      ? 'SE AFIȘEAZĂ 0 PĂRINȚI'
                      : 'SE AFIȘEAZĂ ${start + 1} - $end DIN ${parents.length} PĂRINȚI',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B9E84),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                // Prev arrow
                _PageBtn(
                  child: const Icon(Icons.chevron_left_rounded, size: 16),
                  enabled: safePage > 0,
                  onTap: () => onPageChanged(safePage - 1),
                ),
                const SizedBox(width: 4),
                // Page number buttons (show up to 5 around current)
                ...List.generate(totalPages, (i) => i)
                    .where((i) =>
                        i == 0 ||
                        i == totalPages - 1 ||
                        (i - safePage).abs() <= 1)
                    .fold<List<Widget>>([], (acc, i) {
                  if (acc.isNotEmpty) {
                    final prev = int.parse(
                      (acc.last as _PageBtn).key
                          .toString()
                          .replaceAll(RegExp(r'[^0-9]'), ''),
                    );
                    if (i - prev > 1) {
                      acc.add(const SizedBox(
                        width: 28,
                        child: Center(
                          child: Text('…',
                              style: TextStyle(
                                  color: Color(0xFF7B9E84), fontSize: 12)),
                        ),
                      ));
                    }
                  }
                  acc.add(_PageBtn(
                    key: ValueKey('pb$i'),
                    child: Text('${i + 1}',
                        style: const TextStyle(fontSize: 12)),
                    selected: i == safePage,
                    onTap: () => onPageChanged(i),
                  ));
                  return acc;
                }),
                const SizedBox(width: 4),
                // Next arrow
                _PageBtn(
                  child: const Icon(Icons.chevron_right_rounded, size: 16),
                  enabled: safePage < totalPages - 1,
                  onTap: () => onPageChanged(safePage + 1),
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
//  _TH  — table header label
// ─────────────────────────────────────────────────────────────────────────────

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Color(0xFF0A7A21),
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _PageBtn
// ─────────────────────────────────────────────────────────────────────────────

class _PageBtn extends StatelessWidget {
  final Widget child;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _PageBtn({
    super.key,
    required this.child,
    required this.onTap,
    this.selected = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !selected ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF0A7A21)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? const Color(0xFF0A7A21)
                : (!enabled
                    ? const Color(0xFFDDE8DD)
                    : const Color(0xFFCCDDCC)),
          ),
        ),
        child: DefaultTextStyle(
          style: TextStyle(
            color: selected
                ? Colors.white
                : (!enabled
                    ? const Color(0xFFBBCDBE)
                    : const Color(0xFF3A5240)),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          child: IconTheme(
            data: IconThemeData(
              color: selected
                  ? Colors.white
                  : (!enabled
                      ? const Color(0xFFBBCDBE)
                      : const Color(0xFF3A5240)),
              size: 16,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

enum _ParentRowAction {
  settings,
  deleteUser,
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ParentRow
// ─────────────────────────────────────────────────────────────────────────────

class _ParentRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Map<String, String> studentMap;

  const _ParentRow({required this.doc, required this.studentMap});

  @override
  State<_ParentRow> createState() => _ParentRowState();
}

class _ParentRowState extends State<_ParentRow> {
  final AdminApi _api = AdminApi();
  bool _actionBusy = false;

  Future<void> _deleteParent() async {
    if (_actionBusy) return;

    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? widget.doc.id).toString();

    setState(() => _actionBusy = true);
    try {
      await _api.deleteUser(username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Utilizatorul $username a fost șters.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la ștergerea utilizatorului: $e')),
      );
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _showSettingsDialog() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? widget.doc.id).toString();
    var currentFullName = (data['fullName'] ?? '').toString().trim();
    if (currentFullName.isEmpty) currentFullName = username;
    var currentChildIds = List<String>.from(data['children'] ?? []);
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final fullNameC = TextEditingController(text: currentFullName);
    var selectedChildIds = List<String>.from(currentChildIds);
    var renameBusy = false;
    var moveBusy = false;

    final studentsFuture = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get();
    final parentsFuture = FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'parent')
      .get();

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
          final initials = currentFullName
              .split(RegExp(r'\s+'))
              .where((part) => part.isNotEmpty)
              .take(2)
              .map((part) => part[0].toUpperCase())
              .join();

          return AlertDialog(
            title: const Text('Setări părintele'),
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
                                  currentFullName,
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
                            controller: fullNameC,
                            decoration: const InputDecoration(
                              labelText: 'Numele părintelui',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: renameBusy || moveBusy
                                  ? null
                                  : () async {
                                      final newFullName = fullNameC.text.trim();
                                      if (newFullName.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Introdu un nume valid.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (newFullName == currentFullName) {
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
                                          fullName: newFullName,
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          currentFullName = newFullName;
                                          renameBusy = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Numele părintelui a fost actualizat.'),
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
                      'Schimbă elevii',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<List<QuerySnapshot<Map<String, dynamic>>>>(
                            future: Future.wait([studentsFuture, parentsFuture]),
                            builder: (context, snapshot) {
                              final docs = snapshot.data?[0].docs ?? const [];
                              final parentDocs = snapshot.data?[1].docs ?? const [];
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 8),
                                  child: LinearProgressIndicator(minHeight: 2),
                                );
                              }
                              if (snapshot.hasError) {
                                return Text(
                                  'Eroare la încărcarea elevilor: ${snapshot.error}',
                                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
                                );
                              }

                              final takenByOtherParent = <String, String>{};
                              for (final parentDoc in parentDocs) {
                                if (parentDoc.id == widget.doc.id) continue;
                                final pd = parentDoc.data();
                                final parentName =
                                    (pd['fullName'] ?? pd['username'] ?? parentDoc.id)
                                        .toString();
                                final children = List<String>.from(pd['children'] ?? const []);
                                for (final childId in children) {
                                  takenByOtherParent.putIfAbsent(childId, () => parentName);
                                }
                              }

                              var searchQuery = '';
                              var showDropdown = false;

                              return StatefulBuilder(
                                builder: (ctx, setSearchState) {
                                  final filtered = docs.where((doc) {
                                    final d = doc.data();
                                    final fullName = (d['fullName'] ?? '').toString().toLowerCase();
                                    final username = (d['username'] ?? '').toString().toLowerCase();
                                    final id = doc.id.toLowerCase();
                                    final q = searchQuery.toLowerCase();
                                    return fullName.contains(q) || username.contains(q) || id.contains(q);
                                  }).toList();

                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Casuța de căutare
                                      TextField(
                                        onChanged: (value) {
                                          setSearchState(() {
                                            searchQuery = value;
                                            showDropdown = value.isNotEmpty;
                                          });
                                        },
                                        onTap: () {
                                          setSearchState(() => showDropdown = true);
                                        },
                                        decoration: const InputDecoration(
                                          labelText: 'Cauta elev...',
                                          border: OutlineInputBorder(),
                                          prefixIcon: Icon(Icons.search_rounded),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      // Dropdown cu elevi care se potrivesc
                                      if (showDropdown && filtered.isNotEmpty)
                                        Container(
                                          constraints: const BoxConstraints(maxHeight: 200),
                                          decoration: BoxDecoration(
                                            border: Border.all(color: const Color(0xFFDDE8DA)),
                                            borderRadius: BorderRadius.circular(8),
                                            color: Colors.white,
                                          ),
                                          child: ListView.builder(
                                            shrinkWrap: true,
                                            itemCount: filtered.length,
                                            itemBuilder: (_, i) {
                                              final doc = filtered[i];
                                              final fullName = (doc.data()['fullName'] ?? doc.id).toString();
                                              final isSelected = selectedChildIds.contains(doc.id);
                                              final assignedParentName = takenByOtherParent[doc.id];
                                              final isLocked = assignedParentName != null;

                                              return InkWell(
                                                onTap: () {
                                                  if (isLocked) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Elevul este deja asignat părintelui $assignedParentName.',
                                                        ),
                                                      ),
                                                    );
                                                    return;
                                                  }
                                                  setSearchState(() {
                                                    if (isSelected) {
                                                      selectedChildIds.remove(doc.id);
                                                    } else {
                                                      selectedChildIds.add(doc.id);
                                                    }
                                                    showDropdown = false;
                                                    searchQuery = '';
                                                  });
                                                },
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                  color: isLocked
                                                      ? const Color(0xFFF6F0F0)
                                                      : (isSelected ? const Color(0xFFF0F3EC) : null),
                                                  child: Row(
                                                    children: [
                                                      if (isLocked)
                                                        const Icon(Icons.lock_rounded, color: Color(0xFFB3261E), size: 20)
                                                      else if (isSelected)
                                                        const Icon(Icons.check_rounded, color: Color(0xFF0A7A21), size: 20)
                                                      else
                                                        const SizedBox(width: 20),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          isLocked
                                                              ? '$fullName (deja asignat)'
                                                              : fullName,
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: isLocked
                                                                ? const Color(0xFF9A6A6A)
                                                                : const Color(0xFF1A2F1E),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      if (showDropdown && filtered.isEmpty && searchQuery.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Text(
                                            'Nu s-au găsit elevi cu "$searchQuery"',
                                            style: const TextStyle(color: Color(0xFF7B9E84), fontSize: 12),
                                          ),
                                        ),
                                      // Elevi selectati
                                      if (selectedChildIds.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: selectedChildIds.map((studentId) {
                                            QueryDocumentSnapshot<Map<String, dynamic>>? studentDoc;
                                            try {
                                              studentDoc = docs.firstWhere(
                                                (doc) => doc.id == studentId,
                                              );
                                            } catch (_) {
                                              studentDoc = null;
                                            }
                                            final studentName = studentDoc != null
                                                ? (studentDoc.data()['fullName'] ?? studentId).toString()
                                                : studentId;

                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0A7A21),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    studentName,
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  GestureDetector(
                                                    onTap: () {
                                                      setSearchState(() => selectedChildIds.remove(studentId));
                                                    },
                                                    child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 16,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: moveBusy || renameBusy
                                  ? null
                                  : () async {
                                      if (selectedChildIds.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Selectează cel puțin un elev.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (selectedChildIds.length == currentChildIds.length &&
                                          selectedChildIds.every((id) => currentChildIds.contains(id))) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Elevii sunt deja asignați părintelui.'),
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => moveBusy = true);
                                      try {
                                        final parentsSnap = await FirebaseFirestore.instance
                                            .collection('users')
                                            .where('role', isEqualTo: 'parent')
                                            .get();
                                        final conflictingIds = <String>[];
                                        for (final parentDoc in parentsSnap.docs) {
                                          if (parentDoc.id == widget.doc.id) continue;
                                          final children = List<String>.from(
                                            parentDoc.data()['children'] ?? const [],
                                          );
                                          for (final id in selectedChildIds) {
                                            if (children.contains(id)) {
                                              conflictingIds.add(id);
                                            }
                                          }
                                        }
                                        if (conflictingIds.isNotEmpty) {
                                          final firstConflict =
                                            widget.studentMap[conflictingIds.first] ??
                                              conflictingIds.first;
                                          setDialogState(() => moveBusy = false);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Elevul $firstConflict este deja asignat altui părinte.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(widget.doc.id)
                                            .update({
                                          'children': selectedChildIds,
                                        });
                                        if (!mounted) return;
                                        setDialogState(() {
                                          currentChildIds = selectedChildIds;
                                          moveBusy = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Elevii părintelui au fost actualizați.'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setDialogState(() => moveBusy = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Eroare la schimbarea elevilor: $e'),
                                          ),
                                        );
                                      }
                                    },
                              icon: moveBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.swap_horiz_rounded),
                              label: Text(
                                moveBusy ? 'Se actualizează...' : 'Actualizează elevii',
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
            actions: [
              TextButton(
                onPressed: renameBusy || moveBusy
                    ? null
                    : () => Navigator.of(ctx).pop(),
                child: const Text('Închide'),
              ),
            ],
          );
        },
      ),
    );

    fullNameC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.doc.data() as Map<String, dynamic>;
    final fullName = (data['fullName'] ?? '').toString();
    final username = (data['username'] ?? widget.doc.id).toString();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();
    final childIds = List<String>.from(data['children'] ?? []);
    final email = '$username@school.local';

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── NUME PĂRINTE ─────────────────────────────────────────────────
          Expanded(
            flex: 28,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFD9EDDE),
                  backgroundImage: photoUrl.isNotEmpty
                      ? NetworkImage(photoUrl) as ImageProvider
                      : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          initials.isNotEmpty ? initials : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0A7A21),
                            fontSize: 13,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A2F1E),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Username: $username',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF7B9E84),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── ELEVI ────────────────────────────────────────────────────────
          Expanded(
            flex: 30,
            child: childIds.isEmpty
                ? const Text(
                    '—',
                    style: TextStyle(color: Color(0xFF9DB8A0), fontSize: 13),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: childIds.map((id) {
                      final name = widget.studentMap[id] ?? id;
                      // Extract first name only to keep chips short
                      final firstName = name.trim().split(' ').first;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5EA),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFB8D9BE)),
                        ),
                        child: Text(
                          firstName,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0A7A21),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // ── EMAIL ────────────────────────────────────────────────────────
          Expanded(
            flex: 28,
            child: Text(
              email,
              style: const TextStyle(fontSize: 13, color: Color(0xFF3A5240)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── SETĂRI ──────────────────────────────────────────────────────
          Expanded(
            flex: 14,
            child: PopupMenuButton<_ParentRowAction>(
              enabled: !_actionBusy,
              tooltip: 'Setări părintele',
              offset: const Offset(0, 38),
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                switch (action) {
                  case _ParentRowAction.settings:
                    _showSettingsDialog();
                    break;
                  case _ParentRowAction.deleteUser:
                    _deleteParent();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_ParentRowAction>(
                  value: _ParentRowAction.settings,
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Setări'),
                    ],
                  ),
                ),
                PopupMenuItem<_ParentRowAction>(
                  value: _ParentRowAction.deleteUser,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFB3261E),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Șterge utilizator',
                        style: TextStyle(color: Color(0xFFB3261E)),
                      ),
                    ],
                  ),
                ),
              ],
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: _actionBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.settings_rounded,
                          color: Color(0xFF5E7663),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
