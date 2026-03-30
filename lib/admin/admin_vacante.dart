import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key});

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
    await showDialog<void>(
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
              if (!mounted) return;
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
    final displayName = (AppSession.fullName?.trim().isNotEmpty == true)
        ? AppSession.fullName!.trim()
        : ((AppSession.username?.trim().isNotEmpty == true)
              ? AppSession.username!.trim()
              : 'Secretariat');

    return Scaffold(
      backgroundColor: const Color(0xFF0B7A21),
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
                  onStudentsTap: () =>
                      _openSidebarPage(const AdminStudentsPage()),
                  onPersonalTap: () =>
                      _openSidebarPage(const AdminTeachersPage()),
                  onTurnichetiTap: () =>
                      _openSidebarPage(const AdminTurnstilesPage()),
                  onClaseTap: () => _openSidebarPage(const AdminClassesPage()),
                  onVacanteTap: () {},
                  onParintiTap: () =>
                      _openSidebarPage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),
                Expanded(
                  child: Container(
                    color: const Color(0xFFF0F3EC),
                    child: Column(
                      children: [
                        const _TopBar(),
                        Expanded(child: _VacanciesContent()),
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
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime _displayMonth = DateTime.now();
  String? _selectedDocId;

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

  String _formatMonthYear(DateTime date) {
    const months = [
      'ianuarie',
      'februarie',
      'martie',
      'aprilie',
      'mai',
      'iunie',
      'iulie',
      'august',
      'septembrie',
      'octombrie',
      'noiembrie',
      'decembrie',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _startDate = null;
      _endDate = null;
      _displayMonth = DateTime.now();
    });
  }

  void _addVacancy() {
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

    FirebaseFirestore.instance
        .collection('vacancies')
        .add({
          'name': _nameController.text,
          'startDate': _startDate,
          'endDate': _endDate,
          'createdAt': FieldValue.serverTimestamp(),
        })
        .then((_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vacanta adaugata cu succes')),
          );
          _resetForm();
        })
        .catchError((e) {
          final message =
              e is FirebaseException && e.code == 'permission-denied'
              ? 'Nu ai permisiuni sa creezi vacante'
              : 'Eroare la salvare vacanta';
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        });
  }

  void _showModifyDialog() async {
    // If a vacancy is already selected in the right panel, use it directly
    if (_selectedDocId != null) {
      final snap = await FirebaseFirestore.instance
          .collection('vacancies')
          .doc(_selectedDocId)
          .get();
      if (!mounted) return;
      if (!snap.exists) {
        setState(() => _selectedDocId = null);
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final result = await showDateRangePickerDialog(
        context,
        initialStartDate: (data['startDate'] as Timestamp).toDate(),
        initialEndDate: (data['endDate'] as Timestamp).toDate(),
        parent: this,
      );
      if (result != null && mounted) {
        await FirebaseFirestore.instance
            .collection('vacancies')
            .doc(_selectedDocId)
            .update({'startDate': result['start'], 'endDate': result['end']});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vacanta modificata cu succes')),
        );
      }
      return;
    }

    final snap = await FirebaseFirestore.instance
        .collection('vacancies')
        .orderBy('startDate')
        .get();

    if (!mounted) return;

    if (snap.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista vacante de modificat')),
      );
      return;
    }

    final selected = await showDialog<QueryDocumentSnapshot>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Selectați vacanța de modificat'),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final doc in snap.docs)
                ListTile(
                  title: Text(
                    (doc.data() as Map<String, dynamic>)['name'] ?? 'Vacanță',
                  ),
                  onTap: () => Navigator.of(ctx).pop(doc),
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final data = selected.data() as Map<String, dynamic>;
    final result = await showDateRangePickerDialog(
      context,
      initialStartDate: (data['startDate'] as Timestamp).toDate(),
      initialEndDate: (data['endDate'] as Timestamp).toDate(),
      parent: this,
    );

    if (result != null && mounted) {
      await FirebaseFirestore.instance
          .collection('vacancies')
          .doc(selected.id)
          .update({'startDate': result['start'], 'endDate': result['end']});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vacanta modificata cu succes')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Setare Vacante Școlare',
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w800,
                color: Color(0xFF223624),
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configurați perioadele de repaus pentru anul academic 2023-2024.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF5C6D58),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: _buildFormSection()),
                const SizedBox(width: 24),
                Expanded(flex: 3, child: _buildUpcomingVacancies()),
              ],
            ),
            const SizedBox(height: 24),
            _buildImportantMessage(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Configurare Vacanță Nouă',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF223624),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'NUME EVENIMENT / VACANȚĂ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7FA593),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'Ex: Vacanța de Primăvară',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDDE7D7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFDDE7D7)),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF3F7EE),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATA INCEPUT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7FA593),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                            _displayMonth = picked;
                            if (_endDate != null &&
                                _endDate!.isBefore(picked)) {
                              _endDate = null;
                            }
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7EE),
                          border: Border.all(
                            color: const Color(0xFFDDE7D7),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          _startDate == null
                              ? 'Selectati data'
                              : _formatDate(_startDate!),
                          style: TextStyle(
                            color: _startDate == null
                                ? const Color(0xFF999999)
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATA SFARSIT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF7FA593),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate ?? _startDate ?? DateTime.now(),
                          firstDate: _startDate ?? DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                          });
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7EE),
                          border: Border.all(
                            color: const Color(0xFFDDE7D7),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Text(
                          _endDate == null
                              ? 'Selectati data'
                              : _formatDate(_endDate!),
                          style: TextStyle(
                            color: _endDate == null
                                ? const Color(0xFF999999)
                                : Colors.black,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CALENDAR',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7FA593),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              _buildCalendar(),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _addVacancy,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text(
                    'Adaugă Vacanță',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _resetForm,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFBDBDBD), width: 1),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text(
                    'Anulează',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showModifyDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF2E7D32), width: 1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.edit, size: 18),
              label: const Text(
                'Modifică Vacanță',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
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
      'ianuarie',
      'februarie',
      'martie',
      'aprilie',
      'mai',
      'iunie',
      'iulie',
      'august',
      'septembrie',
      'octombrie',
      'noiembrie',
      'decembrie',
    ];
    const dayNames = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];

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
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.1,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: [
              ...List.generate(firstWeekday - 1, (_) => const SizedBox()),
              ...List.generate(daysInMonth, (index) {
                final day = index + 1;
                final date = DateTime(year, month, day);
                final isStart =
                    _startDate != null && _isSameDay(date, _startDate!);
                final isEnd = _endDate != null && _isSameDay(date, _endDate!);
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
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      day.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isStart || isEnd ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }),
            ],
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
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
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
          const Text(
            'Total 5 perioade active',
            style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
          ),
          const SizedBox(height: 20),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('vacancies')
                .orderBy('startDate')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nu exista vacante create',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final vacancies = snapshot.data!.docs.toList();

              if (vacancies.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Nu exista vacante create',
                      style: TextStyle(fontSize: 13, color: Color(0xFF999999)),
                    ),
                  ),
                );
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < vacancies.length; i++)
                      _buildVacancyCard(
                        vacancies[i],
                        i == 0,
                        vacancies[i].id == _selectedDocId,
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
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
          _selectedDocId = _selectedDocId == doc.id ? null : doc.id;
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
            PopupMenuButton<String>(
              icon: Icon(
                Icons.delete_outline,
                size: 18,
                color: isSelected || isFirst
                    ? Colors.white.withValues(alpha: 0.85)
                    : isFinished
                    ? const Color(0xFFAAAAAA)
                    : const Color(0xFFD32F2F),
              ),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFD32F2F),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Șterge',
                        style: TextStyle(color: Color(0xFFD32F2F)),
                      ),
                    ],
                  ),
                ),
              ],
              onSelected: (value) async {
                await Future.delayed(Duration.zero);
                if (!mounted) return;
                if (value == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Confirmați ștergerea'),
                      content: Text(
                        'Sunteți sigur că doriți să ștergeți "$name"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Anulează'),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFD32F2F),
                          ),
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Șterge'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && mounted) {
                    await FirebaseFirestore.instance
                        .collection('vacancies')
                        .doc(doc.id)
                        .delete();
                    if (_selectedDocId == doc.id) {
                      setState(() {
                        _selectedDocId = null;
                      });
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vacanta stearsa cu succes'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportantMessage() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F8E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFC5E1A5), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFF558B2F),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.info, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Informație Importantă',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF558B2F),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Orice modificare adusa calendarului va notifica automat parintii si elevii prin intermediul platformei si aplicatiei mobile.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

Future<Map<String, DateTime>?> showDateRangePickerDialog(
  BuildContext context, {
  required DateTime initialStartDate,
  required DateTime initialEndDate,
  required _VacanciesContentState parent,
}) async {
  // Pick start date
  final start = await showDatePicker(
    context: context,
    initialDate: initialStartDate,
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    helpText: 'Data de început',
  );
  if (start == null || !context.mounted) return null;

  // Pick end date (cannot be before start)
  final end = await showDatePicker(
    context: context,
    initialDate: initialEndDate.isBefore(start) ? start : initialEndDate,
    firstDate: start,
    lastDate: DateTime(2030),
    helpText: 'Data de sfârşit',
  );
  if (end == null) return null;

  return {'start': start, 'end': end};
}
