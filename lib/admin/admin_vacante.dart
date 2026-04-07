import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';

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

Widget _wrapBlurredPopupBackground(Widget child) {
  return Stack(
    children: [
      Positioned.fill(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(color: Colors.black.withValues(alpha: 0.3)),
        ),
      ),
      child,
    ],
  );
}

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  bool _sidebarNavigationBusy = false;

  Future<void> _openSidebarPage(Widget page) async {
    if (_sidebarNavigationBusy || !mounted) return;
    _sidebarNavigationBusy = true;
    try {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (context, animation, secondaryAnimation) => page,
        ),
      );
    } finally {
      _sidebarNavigationBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await _showBlurDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Deconectare'),
        content: const Text('Esti sigur ca vrei sa te deloghezi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Nu'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Da'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    final content = Container(
      color: const Color(0xFFF8FFF5),
      child: Column(
        children: [
          if (!widget.embedded) const _TopBar(),
          const Expanded(child: _VacanciesContent()),
        ],
      ),
    );

    if (widget.embedded) return content;

    final displayName = (AppSession.fullName?.trim().isNotEmpty == true)
        ? AppSession.fullName!.trim()
        : ((AppSession.username?.trim().isNotEmpty == true)
              ? AppSession.username!.trim()
              : 'Secretariat');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                _Sidebar(
                  displayName: displayName,
                  onMenuTap: () {},
                  onStudentsTap: () => _openSidebarPage(
                    const AdminStudentsPage(key: ValueKey('students-page-v2')),
                  ),
                  onPersonalTap: () =>
                      _openSidebarPage(const AdminTeachersPage()),
                  onTurnichetiTap: () =>
                      _openSidebarPage(AdminTurnstilesPage()),
                  onClaseTap: () => _openSidebarPage(const AdminClassesPage()),
                  onVacanteTap: () {},
                  onParintiTap: () =>
                      _openSidebarPage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),
                Expanded(child: content),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String displayName;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _Sidebar({
    required this.displayName,
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
            selected: false,
            onTap: onMenuTap,
          ),
          _SidebarTile(
            label: 'Elevi',
            icon: Icons.school_rounded,
            onTap: onStudentsTap,
          ),
          _SidebarTile(
            label: 'Personal',
            icon: Icons.badge_rounded,
            onTap: onPersonalTap,
          ),
          _SidebarTile(
            label: 'Parinti',
            icon: Icons.family_restroom_rounded,
            onTap: onParintiTap,
          ),
          _SidebarTile(
            label: 'Clase',
            icon: Icons.table_chart_rounded,
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Vacante',
            icon: Icons.event_available_rounded,
            selected: true,
            onTap: onVacanteTap,
          ),
          _SidebarTile(
            label: 'Turnicheti',
            icon: Icons.door_front_door_rounded,
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

class _TopBar extends StatelessWidget {
  const _TopBar();

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
            'Vacante Școlare',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228A37),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFF9FDCAD), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cauta inregistrari...',
                          style: TextStyle(
                            color: Color(0xFF9FDCAD),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _VacanciesContent extends StatefulWidget {
  const _VacanciesContent();

  @override
  State<_VacanciesContent> createState() => _VacanciesContentState();
}

class _VacanciesContentState extends State<_VacanciesContent> {
  final _nameController = TextEditingController();
  int _currentPage = 0;
  static const int _pageSize = 6;
  bool _monthTransitionForward = true;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _displayMonth = DateTime.now();
  String? _selectedDocId;
  String? _selectedVacancyName;
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;
  bool _editing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateLong(DateTime date) {
    const months = [
      'ian',
      'feb',
      'mar',
      'apr',
      'mai',
      'iun',
      'iul',
      'aug',
      'sep',
      'oct',
      'noi',
      'dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  void _resetForm() {
    _nameController.clear();
    _startDate = null;
    _endDate = null;
    _displayMonth = DateTime.now();
    _selectedDocId = null;
    _selectedVacancyName = null;
    _selectedStartDate = null;
    _selectedEndDate = null;
    _editing = false;
  }

  void _startCreatingVacancy() {
    setState(() {
      _nameController.clear();
      _startDate = null;
      _endDate = null;
      _displayMonth = DateTime.now();
      _selectedDocId = null;
      _selectedVacancyName = null;
      _selectedStartDate = null;
      _selectedEndDate = null;
      _editing = true;
    });
  }

  void _startEditingSelectedVacancy() {
    if (_selectedDocId == null) return;
    setState(() {
      _nameController.text = _selectedVacancyName ?? '';
      _startDate = _selectedStartDate;
      _endDate = _selectedEndDate;
      if (_selectedStartDate != null) {
        _displayMonth = _selectedStartDate!;
      }
      _editing = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      if (_selectedDocId != null) {
        _nameController.text = _selectedVacancyName ?? '';
        _startDate = _selectedStartDate;
        _endDate = _selectedEndDate;
        if (_selectedStartDate != null) {
          _displayMonth = _selectedStartDate!;
        }
      } else {
        _nameController.clear();
        _startDate = null;
        _endDate = null;
        _displayMonth = DateTime.now();
      }
      _editing = false;
    });
  }

  Future<void> _saveVacancy() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Va rugam introduceti numele vacantei')),
      );
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Va rugam selectati data de inceput si de sfarsit'),
        ),
      );
      return;
    }

    final name = _nameController.text.trim();
    final isUpdating = _selectedDocId != null;

    try {
      if (isUpdating) {
        await FirebaseFirestore.instance
            .collection('vacancies')
            .doc(_selectedDocId)
            .update({
              'name': name,
              'startDate': _startDate,
              'endDate': _endDate,
            });
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('vacancies')
            .add({
              'name': name,
              'startDate': _startDate,
              'endDate': _endDate,
              'createdAt': FieldValue.serverTimestamp(),
            });
        _selectedDocId = doc.id;
      }

      if (!mounted) return;

      setState(() {
        _selectedVacancyName = name;
        _selectedStartDate = _startDate;
        _selectedEndDate = _endDate;
        _nameController.text = name;
        if (_startDate != null) {
          _displayMonth = _startDate!;
        }
        _editing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUpdating
                ? 'Vacanta salvata cu succes'
                : 'Vacanta adaugata cu succes',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is FirebaseException && e.code == 'permission-denied'
          ? 'Nu ai permisiuni sa creezi vacante. Verifica rolul contului si regulile Firestore publicate.'
          : 'Eroare la salvare vacanta';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool> _confirmDeleteVacancy({required String name}) async {
    final result = await _showBlurDialog<bool>(
      context: context,
      barrierLabel: 'Confirmare stergere vacanta',
      transitionDuration: const Duration(milliseconds: 180),
      builder: (ctx) {
        return SafeArea(
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
                                    'Sterge vacanta',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A2E1A),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Actiunea este permanenta si va elimina vacanta din lista salvata.',
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
                                'Vacanta selectata',
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
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB42318),
                                  ),
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
                                onPressed: () => Navigator.of(ctx).pop(false),
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
                                onPressed: () => Navigator.of(ctx).pop(true),
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
                                child: const Text('Sterge vacanta'),
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
        );
      },
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Setare Vacante Școlare',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A2E1A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Configureaza perioadele de repaus si gestioneaza vacantele scolare.',
            style: TextStyle(fontSize: 13, color: Color(0xFF5A8040)),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 2, child: _buildFormSection()),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: _buildUpcomingVacancies()),
              ],
            ),
          ),
          const SizedBox(height: 112),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    final hasSelectedVacancy = _selectedDocId != null;
    final isCreatingVacancy = _editing && !hasSelectedVacancy;
    final displayedName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : (_selectedVacancyName ?? 'Nicio vacanta selectata');
    final displayedStart = _editing ? _startDate : _selectedStartDate;
    final displayedEnd = _editing ? _endDate : _selectedEndDate;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Gestionare Vacanță',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2819),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              !_editing
                  ? hasSelectedVacancy
                        ? 'Poti modifica vacanta selectata si salva rapid schimbarile.'
                        : 'Creeaza o vacanta noua si configureaza intervalul din calendar.'
                  : hasSelectedVacancy
                  ? 'Actualizeaza numele si perioada, apoi salveaza vacanta.'
                  : 'Completeaza campurile si salveaza vacanta noua.',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B7868),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Visibility(
            visible: !isCreatingVacancy,
            maintainState: true,
            maintainAnimation: true,
            maintainSize: true,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _startCreatingVacancy,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Creeaza vacanta'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7422),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (!_editing && !hasSelectedVacancy)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: const Center(
                  child: Text(
                    'Selecteaza o vacanta din lista din dreapta sau apasa pe "Creeaza vacanta" pentru a adauga una noua.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: Color(0xFF8A9487),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          if (_editing || hasSelectedVacancy) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing
                          ? 'Completeaza perioada vacantei'
                          : 'Detalii vacanta selectata',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6D7B6A),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Visibility(
                      visible: !_editing && hasSelectedVacancy,
                      maintainState: true,
                      maintainAnimation: true,
                      maintainSize: true,
                      child: OutlinedButton.icon(
                        onPressed: _startEditingSelectedVacancy,
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifica'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1, color: Color(0xFFE2EBDD)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'NUME EVENIMENT / VACANȚĂ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Color(0xFF2A5C30),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: TextField(
                            controller: _nameController,
                            enabled: _editing,
                            onChanged: _editing ? (_) => setState(() {}) : null,
                            decoration: InputDecoration(
                              hintText: 'Ex: Vacanța de Primăvară',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              disabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF4F9F3),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DATA INCEPUT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFF2A5C30),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: !_editing
                                          ? null
                                          : () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _startDate ??
                                                    DateTime.now(),
                                                firstDate: DateTime(2020),
                                                lastDate: DateTime(2030),
                                                builder: (context, child) =>
                                                    _wrapBlurredPopupBackground(
                                                      child ??
                                                          const SizedBox.shrink(),
                                                    ),
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _startDate = picked;
                                                  _displayMonth = picked;
                                                  if (_endDate != null &&
                                                      _endDate!.isBefore(
                                                        picked,
                                                      )) {
                                                    _endDate = null;
                                                  }
                                                });
                                              }
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F9F3),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _startDate == null
                                                    ? 'dd/mm/yyyy'
                                                    : _formatDate(_startDate!),
                                                style: TextStyle(
                                                  color: _startDate == null
                                                      ? const Color(0xFF999999)
                                                      : const Color(0xFF0D0D0D),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16,
                                              color: Color(0xFF7A9070),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DATA SFARSIT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1,
                                        color: Color(0xFF2A5C30),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    GestureDetector(
                                      onTap: !_editing
                                          ? null
                                          : () async {
                                              final picked = await showDatePicker(
                                                context: context,
                                                initialDate:
                                                    _endDate ??
                                                    _startDate ??
                                                    DateTime.now(),
                                                firstDate:
                                                    _startDate ??
                                                    DateTime(2020),
                                                lastDate: DateTime(2030),
                                                builder: (context, child) =>
                                                    _wrapBlurredPopupBackground(
                                                      child ??
                                                          const SizedBox.shrink(),
                                                    ),
                                              );
                                              if (picked != null) {
                                                setState(() {
                                                  _endDate = picked;
                                                });
                                              }
                                            },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF4F9F3),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _endDate == null
                                                    ? 'dd/mm/yyyy'
                                                    : _formatDate(_endDate!),
                                                style: TextStyle(
                                                  color: _endDate == null
                                                      ? const Color(0xFF999999)
                                                      : const Color(0xFF0D0D0D),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const Icon(
                                              Icons.calendar_today_outlined,
                                              size: 16,
                                              color: Color(0xFF7A9070),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF6FAF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2EBDD),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rezumat',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                    color: Color(0xFF6D7B6A),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  displayedName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1B2819),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  displayedStart != null && displayedEnd != null
                                      ? '${_formatDateLong(displayedStart)} - ${_formatDateLong(displayedEnd)}'
                                      : 'Selecteaza intervalul din calendar.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF667466),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                          child: SizedBox(
                            height: 48,
                            child: Visibility(
                              visible: _editing,
                              maintainState: true,
                              maintainAnimation: true,
                              maintainSize: true,
                              child: Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: _cancelEditing,
                                    child: const Text('Anuleaza'),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: _saveVacancy,
                                      icon: Icon(
                                        _editing
                                            ? Icons.save_outlined
                                            : Icons.calendar_month_outlined,
                                        size: 18,
                                      ),
                                      label: Text(
                                        _editing
                                            ? 'Salveaza vacanta'
                                            : 'Creeaza vacanta',
                                      ),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0F7422,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 14,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
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
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: _buildCalendar()),
                        SizedBox(
                          height: 28,
                          child: Center(
                            child: Visibility(
                              visible:
                                  _selectedVacancyName != null ||
                                  _nameController.text.isNotEmpty,
                              maintainState: true,
                              maintainAnimation: true,
                              maintainSize: true,
                              child: Text(
                                '* Previzualizare: $displayedName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E7D32),
                                  fontStyle: FontStyle.italic,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final year = _displayMonth.year;
    final month = _displayMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday;

    const monthNames = [
      'Ianuarie',
      'Februarie',
      'Martie',
      'Aprilie',
      'Mai',
      'Iunie',
      'Iulie',
      'August',
      'Septembrie',
      'Octombrie',
      'Noiembrie',
      'Decembrie',
    ];
    const dayNames = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7EE),
        border: Border.all(color: const Color(0xFFDDE7D7), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () {
                  setState(() {
                    _monthTransitionForward = false;
                    _displayMonth = DateTime(
                      _displayMonth.year,
                      _displayMonth.month - 1,
                    );
                  });
                },
              ),
              Text(
                '${monthNames[_displayMonth.month - 1]} ${_displayMonth.year}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37513B),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () {
                  setState(() {
                    _monthTransitionForward = true;
                    _displayMonth = DateTime(
                      _displayMonth.year,
                      _displayMonth.month + 1,
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in dayNames)
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF7FA593),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: [...previousChildren, ?currentChild],
                );
              },
              transitionBuilder: (child, animation) {
                final beginOffset = _monthTransitionForward
                    ? const Offset(0.08, 0)
                    : const Offset(-0.08, 0);

                return ClipRect(
                  child: FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: beginOffset,
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                );
              },
              child: KeyedSubtree(
                key: ValueKey('${_displayMonth.year}-${_displayMonth.month}'),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final rows = ((firstWeekday - 1 + daysInMonth) / 7).ceil();
                    const crossSpacing = 8.0;
                    const mainSpacing = 8.0;
                    final squareSize = [
                      (constraints.maxWidth - crossSpacing * 6) / 7,
                      (constraints.maxHeight - mainSpacing * (rows - 1)) / rows,
                    ].reduce((a, b) => a < b ? a : b);
                    final gridWidth = squareSize * 7 + crossSpacing * 6;
                    final gridHeight =
                        squareSize * rows + mainSpacing * (rows - 1);

                    return Center(
                      child: SizedBox(
                        width: gridWidth,
                        height: gridHeight,
                        child: GridView.count(
                          crossAxisCount: 7,
                          shrinkWrap: false,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1,
                          mainAxisSpacing: mainSpacing,
                          crossAxisSpacing: crossSpacing,
                          children: [
                            ...List.generate(
                              firstWeekday - 1,
                              (_) => const SizedBox.expand(),
                            ),
                            ...List.generate(daysInMonth, (index) {
                              final day = index + 1;
                              final date = DateTime(year, month, day);
                              final isStart =
                                  _startDate != null &&
                                  _isSameDay(date, _startDate!);
                              final isEnd =
                                  _endDate != null &&
                                  _isSameDay(date, _endDate!);
                              final isBetween =
                                  _startDate != null &&
                                  _endDate != null &&
                                  date.isAfter(_startDate!) &&
                                  date.isBefore(_endDate!);

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (_startDate == null) {
                                      _startDate = date;
                                    } else if (_endDate == null) {
                                      if (date.isBefore(_startDate!)) {
                                        _endDate = _startDate;
                                        _startDate = date;
                                      } else {
                                        _endDate = date;
                                      }
                                    } else {
                                      _startDate = date;
                                      _endDate = null;
                                    }
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isStart || isEnd
                                        ? const Color(0xFF2E7D32)
                                        : isBetween
                                        ? const Color(0xFFC8E6C9)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    day.toString(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: isStart || isEnd
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingVacancies() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('vacancies')
            .orderBy('startDate')
            .snapshots(),
        builder: (context, snapshot) {
          final vacancies = snapshot.hasData
              ? snapshot.data!.docs.toList()
              : <QueryDocumentSnapshot>[];
          final totalPages = vacancies.isEmpty
              ? 0
              : (vacancies.length / _pageSize).ceil();
          final currentPage = totalPages == 0
              ? 0
              : _currentPage.clamp(0, totalPages - 1);
          final visibleVacancies = totalPages == 0
              ? <QueryDocumentSnapshot>[]
              : vacancies
                    .skip(currentPage * _pageSize)
                    .take(_pageSize)
                    .toList();

          Widget listWidget;
          if (snapshot.hasError) {
            listWidget = const Center(
              child: Text(
                'Nu exista vacante create',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            );
          } else if (!snapshot.hasData) {
            listWidget = const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(),
              ),
            );
          } else if (vacancies.isEmpty) {
            listWidget = const Center(
              child: Text(
                'Nu exista vacante create',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
            );
          } else {
            listWidget = ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: visibleVacancies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 0),
              itemBuilder: (context, index) {
                final vacancy = visibleVacancies[index];
                return _buildVacancyCard(
                  vacancy,
                  currentPage == 0 && index == 0,
                  vacancy.id == _selectedDocId,
                );
              },
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vacante Salvate',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF223624),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${vacancies.length} vacante inregistrate',
                style: const TextStyle(fontSize: 13, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 20),
              Expanded(child: listWidget),
              if (totalPages > 1) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 0),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFFE8E8E8))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      _PaginationButton(
                        icon: Icons.chevron_left_rounded,
                        enabled: currentPage > 0,
                        onTap: () =>
                            setState(() => _currentPage = currentPage - 1),
                      ),
                      const SizedBox(width: 4),
                      ..._buildPageButtons(totalPages, currentPage),
                      const SizedBox(width: 4),
                      _PaginationButton(
                        icon: Icons.chevron_right_rounded,
                        enabled: currentPage < totalPages - 1,
                        onTap: () =>
                            setState(() => _currentPage = currentPage + 1),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

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

      if (currentPage > 2) {
        addEllipsis();
      }

      final start = (currentPage - 1).clamp(1, totalPages - 2);
      final end = (currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }

      if (currentPage < totalPages - 3) {
        addEllipsis();
      }

      addPage(totalPages - 1);
    }

    return pages;
  }

  Widget _buildVacancyCard(
    QueryDocumentSnapshot doc,
    bool isFirst,
    bool isSelected,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate = (data['endDate'] as Timestamp).toDate();
    final name = data['name'] ?? 'Vacanță';

    final now = DateTime.now();
    final isFinished = endDate.isBefore(DateTime(now.year, now.month, now.day));

    final Color cardColor;
    final Color nameColor;
    final Color iconColor;
    final Color dateColor;
    final Border? border;

    if (isSelected) {
      cardColor = const Color(0xFF0A7A21);
      nameColor = Colors.white;
      iconColor = Colors.white;
      dateColor = Colors.white.withValues(alpha: 0.85);
      border = Border.all(color: const Color(0xFF07681C), width: 2);
    } else if (isFinished) {
      cardColor = const Color(0xFFF0F0F0);
      nameColor = const Color(0xFF888888);
      iconColor = const Color(0xFFAAAAAA);
      dateColor = const Color(0xFFAAAAAA);
      border = Border.all(color: const Color(0xFFDDDDDD), width: 1);
    } else if (isFirst) {
      cardColor = const Color(0xFF2E7D32);
      nameColor = Colors.white;
      iconColor = Colors.white;
      dateColor = Colors.white;
      border = null;
    } else {
      cardColor = const Color(0xFFE8F5E9);
      nameColor = const Color(0xFF2E7D32);
      iconColor = const Color(0xFFD32F2F);
      dateColor = const Color(0xFF666666);
      border = Border.all(color: const Color(0xFFC8E6C9), width: 1);
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_selectedDocId == doc.id) {
            _selectedDocId = null;
            _selectedVacancyName = null;
            _selectedStartDate = null;
            _selectedEndDate = null;
            _nameController.clear();
            _startDate = null;
            _endDate = null;
            _displayMonth = DateTime.now();
            _editing = false;
          } else {
            _selectedDocId = doc.id;
            _selectedVacancyName = name;
            _selectedStartDate = startDate;
            _selectedEndDate = endDate;
            _nameController.text = name;
            _startDate = startDate;
            _endDate = endDate;
            _displayMonth = startDate;
            _editing = false;
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isFinished ? '$name - Terminat' : name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: nameColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 12, color: iconColor),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDateLong(startDate)} - ${_formatDateLong(endDate)}',
                        style: TextStyle(fontSize: 11, color: dateColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () async {
                final confirmed = await _confirmDeleteVacancy(name: name);
                if (!confirmed || !mounted) return;

                await FirebaseFirestore.instance
                    .collection('vacancies')
                    .doc(doc.id)
                    .delete();
                if (!mounted) return;

                if (_selectedDocId == doc.id) {
                  setState(() {
                    _resetForm();
                  });
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Vacanta stearsa cu succes')),
                );
              },
              icon: const Icon(
                Icons.delete_outline,
                size: 18,
                color: Color(0xFFD32F2F),
              ),
              splashRadius: 18,
              tooltip: 'Sterge vacanta',
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
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
