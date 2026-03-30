import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;

// ─────────────────────────────────────────────────────────────────────────────
//  AdminTeachersPage
// ─────────────────────────────────────────────────────────────────────────────

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  final AdminApi _api = AdminApi();
  final Random _rng = Random.secure();
  bool _sidebarBusy = false;
  String? _filterClassId;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchC = TextEditingController();
  int _page = 0;
  static const int _pageSize = 8;

  // classId → 'inSchool' | 'outside'  (computed from classes stream)
  Map<String, String> _classScheduleStatus = {};

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

  String _baseFromFullName(String fullName) {
    final parts = fullName
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'user';
    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    return (last.isEmpty ? first : '${first[0]}$last').replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
  }

  String _randDigits(int len) {
    const digits = '0123456789';
    return List.generate(
      len,
      (_) => digits[_rng.nextInt(digits.length)],
    ).join();
  }

  String _randPassword(int len) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<void> _copyCredentials({
    required String username,
    required String password,
  }) async {
    await Clipboard.setData(
      ClipboardData(text: 'username: $username\npassword: $password'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Datele au fost copiate in clipboard.')),
    );
  }

  Future<void> _exportTeachersReport() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();

      final teachers = snap.docs.map((d) {
        final data = d.data();
        return {
          'fullName': (data['fullName'] ?? '').toString(),
          'userId': (data['username'] ?? d.id).toString(),
          'classId': (data['classId'] ?? '').toString(),
        };
      }).toList();

      teachers.sort((a, b) {
        final an = (a['fullName'] ?? '').toLowerCase();
        final bn = (b['fullName'] ?? '').toLowerCase();
        return an.compareTo(bn);
      });

      final exported = <Map<String, String>>[];
      int resetOk = 0;
      int resetFailed = 0;

      for (final t in teachers) {
        final fullName = (t['fullName'] ?? '').trim();
        final userId = (t['userId'] ?? '').trim().toLowerCase();
        final classId = (t['classId'] ?? '').trim();

        if (userId.isEmpty) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'classId': classId,
            'password': 'RESETARE EȘUATĂ: lipsă ID utilizator',
          });
          continue;
        }

        final newPassword = _randPassword(10);

        try {
          await _api.resetPassword(
            username: userId,
            newPassword: newPassword,
          );

          resetOk++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'classId': classId,
            'password': newPassword,
          });
        } catch (_) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'classId': classId,
            'password': 'RESETARE EȘUATĂ',
          });
        }
      }

      final excel = xls.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      final sheet = excel[defaultSheet ?? 'Diriginți'];

      sheet.appendRow([
        xls.TextCellValue('Nume'),
        xls.TextCellValue('ID utilizator'),
        xls.TextCellValue('Clasa'),
        xls.TextCellValue('Parola'),
      ]);

      for (final t in exported) {
        sheet.appendRow([
          xls.TextCellValue(t['fullName'] ?? ''),
          xls.TextCellValue(t['userId'] ?? ''),
          xls.TextCellValue(t['classId'] ?? ''),
          xls.TextCellValue(t['password'] ?? ''),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null) {
        throw Exception('Nu am putut genera fisierul Excel.');
      }

      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

      await FileSaver.instance.saveFile(
        name: 'teacher_report_$stamp',
        bytes: Uint8List.fromList(bytes),
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Raport descarcat. Resetate: $resetOk, esuate: $resetFailed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la export: $e')),
      );
    }
  }

  Future<void> _showCreateProfessorDialog() async {
    final fullNameC = TextEditingController();
    final usernameC = TextEditingController();
    final passwordC = TextEditingController();
    String selectedClassId = '';
    bool isBusy = false;

    final classesFuture = FirebaseFirestore.instance
        .collection('classes')
        .orderBy('name')
        .get();

    Future<void> submit(StateSetter setS) async {
      final fullName = fullNameC.text.trim();
      final username = usernameC.text.trim().toLowerCase();
      final password = passwordC.text;

      if (fullName.isEmpty || username.isEmpty || password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completeaza toate campurile obligatorii.'),
          ),
        );
        return;
      }
      if (username.contains(RegExp(r'\s'))) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID utilizator nu poate contine spatii.'),
          ),
        );
        return;
      }
      if (password.length < 6) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parola trebuie sa aiba minim 6 caractere.'),
          ),
        );
        return;
      }
      if (selectedClassId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecteaza clasa pentru diriginte.')),
        );
        return;
      }

      setS(() => isBusy = true);
      try {
        await _api.createUser(
          username: username,
          password: password,
          fullName: fullName,
          role: 'teacher',
          classId: selectedClassId,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cont diriginte creat cu succes.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eroare la creare cont: $e')));
      } finally {
        if (mounted) setS(() => isBusy = false);
      }
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Adaugă diriginte nou'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: fullNameC,
                    decoration: const InputDecoration(
                      labelText: 'Nume complet - obligatoriu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: usernameC,
                    decoration: const InputDecoration(
                      labelText: 'ID utilizator - obligatoriu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordC,
                    decoration: const InputDecoration(
                      labelText: 'Parola - obligatoriu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<QuerySnapshot>(
                    future: classesFuture,
                    builder: (ctx2, snap) {
                      final classDocs = snap.data?.docs ?? [];
                      final options = classDocs.map((doc) {
                        final d = doc.data() as Map<String, dynamic>? ?? {};
                        return {
                          'id': doc.id,
                          'name': (d['name'] ?? doc.id).toString(),
                        };
                      }).toList();
                      if (options.isEmpty) {
                        return Text(
                          'Nu exista clase definite.',
                          style: TextStyle(color: Colors.grey.shade700),
                        );
                      }
                      final hasCurrent = options.any(
                        (o) => o['id'] == selectedClassId,
                      );
                      return DropdownButtonFormField<String>(
                        value: hasCurrent ? selectedClassId : null,
                        items: options
                            .map(
                              (o) => DropdownMenuItem<String>(
                                value: o['id'],
                                child: Text(o['name']!),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => selectedClassId = v ?? ''),
                        decoration: const InputDecoration(
                          labelText: 'Clasa - obligatoriu',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final fn = fullNameC.text.trim();
                            if (fn.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Completeaza mai intai numele complet.',
                                  ),
                                ),
                              );
                              return;
                            }
                            setS(() {
                              usernameC.text =
                                  '${_baseFromFullName(fn)}${_randDigits(3)}';
                              passwordC.text = _randPassword(10);
                            });
                          },
                          icon: const Icon(Icons.auto_fix_high_rounded),
                          label: const Text('Genereaza'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _copyCredentials(
                            username: usernameC.text.trim(),
                            password: passwordC.text,
                          ),
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Copiaza'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Inchide'),
            ),
            FilledButton(
              onPressed: isBusy ? null : () => submit(setS),
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Creeaza cont'),
            ),
          ],
        ),
      ),
    );

    fullNameC.dispose();
    usernameC.dispose();
    passwordC.dispose();
  }

  // ── Schedule status ─────────────────────────────────────────────────────────

  /// Returns 'inSchool' if the current time is within the class schedule for
  /// today, or 'outside' otherwise.  Ignores disabled users (handled separately).
  static String _scheduleActive(Map<String, dynamic> schedule) {
    if (schedule.isEmpty) return 'outside';
    final now = DateTime.now();
    // DateTime.weekday: Monday=1 … Sunday=7
    // Firestore schedule keys: '1'=Monday … '5'=Friday
    final dayKey = now.weekday.toString();
    final today = schedule[dayKey] as Map<String, dynamic>?;
    if (today == null) return 'outside';

    final startStr = (today['start'] ?? '').toString();
    final endStr = (today['end'] ?? '').toString();

    int? toMin(String s) {
      final p = s.split(':');
      if (p.length != 2) return null;
      final h = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      return (h != null && m != null) ? h * 60 + m : null;
    }

    final sM = toMin(startStr);
    final eM = toMin(endStr);
    if (sM == null || eM == null) return 'outside';

    final nowM = now.hour * 60 + now.minute;
    return (nowM >= sM && nowM <= eM) ? 'inSchool' : 'outside';
  }

  /// Full teacher status: check user `status` field first (disabled), then schedule.
  String _computeTeacherStatus(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userStatus = (data['status'] ?? 'active').toString();
    if (userStatus == 'disabled') return 'disabled';
    final classId = (data['classId'] ?? '').toString().toUpperCase();
    return _classScheduleStatus[classId] ?? 'outside';
  }

  String _teacherStatusLabel(String status) {
    switch (status) {
      case 'inSchool':
        return 'activ';
      case 'disabled':
        return 'dezactivat';
      case 'outside':
      default:
        return 'inactiv';
    }
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
                _TeachersSidebar(
                  selected: 'personal',
                  onMenuTap: () => Navigator.of(context).pop(),
                  onStudentsTap: () => _replacePage(const AdminStudentsPage()),
                  onPersonalTap: () {},
                  onTurnichetiTap: () =>
                      _replacePage(const AdminTurnstilesPage()),
                  onClaseTap: () => _replacePage(const AdminClassesPage()),
                  onVacanteTap: () =>
                      _replacePage(const admin_vacante.AdminClassesPage()),
                  onParintiTap: () => _replacePage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),

                // ── Content ──────────────────────────────────────────────────────
                Expanded(
                  child: Container(
                    color: const Color(0xFFF0F3EC),
                    child: Column(
                      children: [
                        _TeachersTopBar(
                          displayName: AppSession.username ?? 'Admin',
                          searchController: _searchC,
                          onSearch: (v) => setState(() {
                            _searchQuery = v.trim().toLowerCase();
                            _page = 0;
                          }),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                      // Teachers
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('role', isEqualTo: 'teacher')
                          .snapshots(),
                      builder: (context, teacherSnap) {
                        return StreamBuilder<QuerySnapshot>(
                          // Classes (for schedule status)
                          stream: FirebaseFirestore.instance
                              .collection('classes')
                              .snapshots(),
                          builder: (context, classSnap) {
                            // Rebuild classScheduleStatus map from classes
                            final newMap = <String, String>{};
                            for (final cd in classSnap.data?.docs ?? []) {
                              final d = cd.data() as Map<String, dynamic>;
                              final sched =
                                  d['schedule'] as Map<String, dynamic>? ?? {};
                              newMap[cd.id] = _scheduleActive(sched);
                            }
                            if (newMap.isNotEmpty) {
                              _classScheduleStatus = newMap;
                            }

                            final teachers =
                                List<QueryDocumentSnapshot>.from(
                              teacherSnap.data?.docs ?? [],
                            );
                            teachers.sort((a, b) {
                              final an =
                                  ((a.data() as Map)['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              final bn =
                                  ((b.data() as Map)['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                              return an.compareTo(bn);
                            });

                            final availableClasses = teachers
                                .map(
                                  (d) => (d.data() as Map<String, dynamic>)[
                                          'classId']
                                      .toString()
                                      .trim(),
                                )
                                .where((classId) => classId.isNotEmpty)
                                .toSet()
                                .toList()
                              ..sort();

                            if (_filterClassId != null &&
                                !availableClasses.contains(_filterClassId)) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _filterClassId = null;
                                  _page = 0;
                                });
                              });
                            }

                            // Apply search filter
                            final filtered = teachers.where((d) {
                                    final data =
                                        d.data() as Map<String, dynamic>;
                                    final name = (data['fullName'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final user = (data['username'] ?? d.id)
                                        .toString()
                                        .toLowerCase();
                                    final cls = (data['classId'] ?? '')
                                        .toString()
                                        .toLowerCase();
                                    final email = '$user@school.local';
                                    final status = _computeTeacherStatus(d);
                                    final statusDisplay = _teacherStatusLabel(
                                      status,
                                    );

                                    if (_searchQuery.isNotEmpty &&
                                        !name.contains(_searchQuery) &&
                                        !user.contains(_searchQuery) &&
                                        !cls.contains(_searchQuery) &&
                                        !email.contains(_searchQuery) &&
                                        !statusDisplay.contains(_searchQuery)) {
                                      return false;
                                    }

                                    if (_filterClassId != null &&
                                        cls != _filterClassId!.toLowerCase()) {
                                      return false;
                                    }

                                    if (_filterStatus != 'all' &&
                                        status != _filterStatus) {
                                      return false;
                                    }

                                    return true;
                                  }).toList();

                            final activeCount = teachers
                                .where(
                                  (teacher) =>
                                      _computeTeacherStatus(teacher) == 'inSchool',
                                )
                                .length;
                            final inactiveCount = teachers
                                .where(
                                  (teacher) =>
                                      _computeTeacherStatus(teacher) == 'outside',
                                )
                                .length;
                            final disabledCount = teachers
                                .where(
                                  (teacher) =>
                                      _computeTeacherStatus(teacher) == 'disabled',
                                )
                                .length;

                            if (teacherSnap.connectionState ==
                                    ConnectionState.waiting &&
                                teachers.isEmpty) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0A7A21),
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TeachersPageHeader(
                                  onAddTap: _showCreateProfessorDialog,
                                  onExportTap: _exportTeachersReport,
                                ),
                                _TeacherFilterStatsRow(
                                  availableClasses: availableClasses,
                                  selectedClassId: _filterClassId,
                                  selectedStatus: _filterStatus,
                                  totalRegistered: teachers.length,
                                  activeCount: activeCount,
                                  disabledCount: disabledCount,
                                  inactiveCount: inactiveCount,
                                  onClassChanged: (value) => setState(() {
                                    _filterClassId = value;
                                    _page = 0;
                                  }),
                                  onStatusChanged: (value) => setState(() {
                                    _filterStatus = value ?? 'all';
                                    _page = 0;
                                  }),
                                ),
                                Expanded(
                                  child: _TeachersTablePanel(
                                    teachers: filtered,
                                    teacherStatus: _computeTeacherStatus,
                                    page: _page,
                                    pageSize: _pageSize,
                                    onPageChanged: (p) =>
                                        setState(() => _page = p),
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
//  _TeachersSidebar
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersSidebar extends StatelessWidget {
  final String selected;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _TeachersSidebar({
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

          // Logout
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
//  _TeachersTopBar
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersTopBar extends StatelessWidget {
  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _TeachersTopBar({
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
            'Personal',
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
                            hintText: 'Cauta dupa nume, clasa sau email...',
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
//  _TeachersPageHeader
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersPageHeader extends StatelessWidget {
  final VoidCallback onAddTap;
  final VoidCallback onExportTap;

  const _TeachersPageHeader({
    required this.onAddTap,
    required this.onExportTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Diriginți',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2F1E),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gestionează și monitorizează activitatea cadrelor didactice, clasele acestora\n'
                  'și detaliile conturilor într-o vizualizare centrală.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onExportTap,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Exportă raport'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E5C3A),
              side: const BorderSide(color: Color(0xFFBDCEC1)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Adaugă diriginte nou'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0A7A21),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherFilterStatsRow extends StatelessWidget {
  final List<String> availableClasses;
  final String? selectedClassId;
  final String selectedStatus;
  final int totalRegistered;
  final int activeCount;
  final int disabledCount;
  final int inactiveCount;
  final ValueChanged<String?> onClassChanged;
  final ValueChanged<String?> onStatusChanged;

  const _TeacherFilterStatsRow({
    required this.availableClasses,
    required this.selectedClassId,
    required this.selectedStatus,
    required this.totalRegistered,
    required this.activeCount,
    required this.disabledCount,
    required this.inactiveCount,
    required this.onClassChanged,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 180,
              child: _TeacherFilterCard(
                label: 'CLASA',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String?>(
                    value: selectedClassId,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2F1E),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF4A6E52),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toate clasele'),
                      ),
                      for (final classId in availableClasses)
                        DropdownMenuItem<String?>(
                          value: classId,
                          child: Text(classId),
                        ),
                    ],
                    onChanged: onClassChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 220,
              child: _TeacherFilterCard(
                label: 'STATUS',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2F1E),
                    ),
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFF4A6E52),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'all',
                        child: Text('Toti dirigintii'),
                      ),
                      DropdownMenuItem(
                        value: 'inSchool',
                        child: Text('Activi'),
                      ),
                      DropdownMenuItem(
                        value: 'outside',
                        child: Text('Inactivi'),
                      ),
                      DropdownMenuItem(
                        value: 'disabled',
                        child: Text('Dezactivati'),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TeacherFilterCard(
                label: 'STATISTICI PERSONAL',
                centerContent: true,
                backgroundColor: const Color(0xFFF0F9F1),
                child: Row(
                  children: [
                    Expanded(
                      child: _TeacherStatItem(
                        value: totalRegistered,
                        label: 'TOTAL DIRIGINTI',
                      ),
                    ),
                    Expanded(
                      child: _TeacherStatItem(
                        value: activeCount,
                        label: 'ACTIVI ACUM',
                      ),
                    ),
                    Expanded(
                      child: _TeacherStatItem(
                        value: disabledCount,
                        label: 'DEZACTIVATI',
                      ),
                    ),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A7A21),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeacherFilterCard extends StatelessWidget {
  final String label;
  final Widget child;
  final bool centerContent;
  final Color? backgroundColor;

  const _TeacherFilterCard({
    required this.label,
    required this.child,
    this.centerContent = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFDDE8DA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            centerContent ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B9E84),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Align(
              alignment:
                  centerContent ? Alignment.center : Alignment.centerLeft,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherStatItem extends StatelessWidget {
  final int value;
  final String label;

  const _TeacherStatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2F1E),
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF48A15E),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TeachersTablePanel
// ─────────────────────────────────────────────────────────────────────────────

class _TeachersTablePanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> teachers;
  final String Function(QueryDocumentSnapshot) teacherStatus;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const _TeachersTablePanel({
    required this.teachers,
    required this.teacherStatus,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (teachers.length / pageSize).ceil().clamp(1, 99999);
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final end = (start + pageSize).clamp(0, teachers.length);
    final pageItems = teachers.sublist(start, end);

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
                Expanded(flex: 26, child: _TH('NUME DIRIGINTE')),
                Expanded(flex: 12, child: _TH('CLASĂ')),
                Expanded(flex: 20, child: _TH('EMAIL')),
                Expanded(flex: 14, child: _TH('ULTIMA ACTIVITATE')),
                Expanded(flex: 18, child: _TH('STATUS')),
                Expanded(flex: 10, child: _TH('SETĂRI')),
              ],
            ),
          ),

          // Rows
          Expanded(
            child: teachers.isEmpty
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
                          'Nu există diriginți înregistrați.',
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
                    itemBuilder: (_, i) => _TeacherRow(
                      doc: pageItems[i],
                      status: teacherStatus(pageItems[i]),
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
                  teachers.isEmpty
                      ? 'SE AFIȘEAZĂ 0 DIRIGINȚI'
                      : 'SE AFIȘEAZĂ ${start + 1} - $end DIN ${teachers.length} DIRIGINȚI',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF7B9E84),
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                _PageBtn(
                  child: const Icon(Icons.chevron_left_rounded, size: 16),
                  enabled: safePage > 0,
                  onTap: () => onPageChanged(safePage - 1),
                ),
                const SizedBox(width: 4),
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
          color: selected ? const Color(0xFF0A7A21) : Colors.transparent,
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

enum _TeacherRowAction {
  settings,
  deleteUser,
}

// ─────────────────────────────────────────────────────────────────────────────
//  _TeacherRow
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final String status; // 'inSchool' | 'outside' | 'disabled'

  const _TeacherRow({required this.doc, required this.status});

  @override
  State<_TeacherRow> createState() => _TeacherRowState();
}

class _TeacherRowState extends State<_TeacherRow> {
  final AdminApi _api = AdminApi();

  /// null = still loading,  '' = no activity found
  String? _lastActivity;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _loadLastActivity();
  }

  Future<void> _loadLastActivity() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? widget.doc.id).toString();

    try {
      final snap = await FirebaseFirestore.instance
          .collection('leaveRequests')
          .where('reviewedByName', isEqualTo: username)
          .get();

      if (!mounted) return;

      final reviewed = snap.docs.where((d) {
        final m = d.data() as Map<String, dynamic>;
        return m['reviewedAt'] != null;
      }).toList();

      if (reviewed.isEmpty) {
        setState(() => _lastActivity = '');
        return;
      }

      reviewed.sort((a, b) {
        final at =
            ((a.data() as Map<String, dynamic>)['reviewedAt'] as Timestamp)
                .seconds;
        final bt =
            ((b.data() as Map<String, dynamic>)['reviewedAt'] as Timestamp)
                .seconds;
        return bt.compareTo(at);
      });

      final ts = (reviewed.first.data()
          as Map<String, dynamic>)['reviewedAt'] as Timestamp;
      final dt = ts.toDate();
      final now = DateTime.now();
      final diff = now.difference(dt);

      String label;
      if (diff.inDays == 0) {
        label =
            'Azi, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } else if (diff.inDays == 1) {
        label = 'Ieri';
      } else if (diff.inDays < 30) {
        label = 'Acum ${diff.inDays} zile';
      } else {
        label =
            '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
      }

      setState(() => _lastActivity = label);
    } catch (_) {
      if (mounted) setState(() => _lastActivity = '');
    }
  }

  Future<void> _deleteTeacher() async {
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
    var currentClassId = (data['classId'] ?? '').toString().trim();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final fullNameC = TextEditingController(text: currentFullName);
    var selectedClassId = currentClassId;
    var renameBusy = false;
    var moveBusy = false;

    final classesFuture = FirebaseFirestore.instance
        .collection('classes')
        .orderBy('name')
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
            title: const Text('Setări diriginte'),
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
                                if (currentClassId.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Clasa curentă: $currentClassId',
                                    style: const TextStyle(
                                      color: Color(0xFFE8F5EA),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
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
                              labelText: 'Numele utilizatorului',
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
                                            content: Text('Numele dirigintelui a fost actualizat.'),
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
                      'Schimbă clasa',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            future: classesFuture,
                            builder: (context, snapshot) {
                              final docs = snapshot.data?.docs ?? const [];
                              final hasCurrent = docs.any(
                                (doc) => doc.id == selectedClassId,
                              );

                              return DropdownButtonFormField<String>(
                                value: hasCurrent ? selectedClassId : null,
                                items: docs
                                    .map(
                                      (doc) => DropdownMenuItem<String>(
                                        value: doc.id,
                                        child: Text(
                                          (doc.data()['name'] ?? doc.id).toString(),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: moveBusy || renameBusy
                                    ? null
                                    : (value) {
                                        setDialogState(
                                          () => selectedClassId = value ?? '',
                                        );
                                      },
                                decoration: const InputDecoration(
                                  labelText: 'Clasa nouă',
                                  border: OutlineInputBorder(),
                                ),
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
                                      if (selectedClassId.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Selectează o clasă.'),
                                          ),
                                        );
                                        return;
                                      }
                                      if (selectedClassId == currentClassId) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Dirigintele este deja în clasa selectată.'),
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => moveBusy = true);
                                      try {
                                        await _api.moveStudentClass(
                                          username: username,
                                          newClassId: selectedClassId,
                                        );
                                        if (!mounted) return;
                                        setDialogState(() {
                                          currentClassId = selectedClassId;
                                          moveBusy = false;
                                        });
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Clasa dirigintelui a fost actualizată.'),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setDialogState(() => moveBusy = false);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Eroare la schimbarea clasei: $e'),
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
                                moveBusy ? 'Se actualizează...' : 'Actualizează clasa',
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
    final classId = (data['classId'] ?? '').toString();
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();

    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final initials = parts.take(2).map((p) => p[0].toUpperCase()).join();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // ── NUME DIRIGINTE ────────────────────────────────────────────────
          Expanded(
            flex: 26,
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
                        'ID utilizator: $username',
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

          // ── CLASĂ ────────────────────────────────────────────────────────
          Expanded(
            flex: 12,
            child: classId.isEmpty
                ? const Text('-', style: TextStyle(color: Color(0xFF9DB8A0)))
                : Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5EA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        classId,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0A7A21),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
          ),

          // ── EMAIL ────────────────────────────────────────────────────────
          Expanded(
            flex: 20,
            child: Text(
              '$username@school.local',
              style: const TextStyle(fontSize: 13, color: Color(0xFF3A5240)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── ULTIMA ACTIVITATE ────────────────────────────────────────────
          Expanded(
            flex: 14,
            child: _lastActivity == null
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A7A21),
                    ),
                  )
                : _lastActivity!.isEmpty
                    ? const Text(
                        '—',
                        style: TextStyle(
                          color: Color(0xFF9DB8A0),
                          fontSize: 13,
                        ),
                      )
                    : Text(
                        _lastActivity!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4A6E52),
                        ),
                      ),
          ),

          // ── STATUS ──────────────────────────────────────────────────────
          Expanded(
            flex: 18,
            child: _TeacherStatusChip(status: widget.status),
          ),

          // ── SETĂRI ──────────────────────────────────────────────────────
          Expanded(
            flex: 10,
            child: PopupMenuButton<_TeacherRowAction>(
              enabled: !_actionBusy,
              tooltip: 'Setări diriginte',
              offset: const Offset(0, 38),
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                switch (action) {
                  case _TeacherRowAction.settings:
                    _showSettingsDialog();
                    break;
                  case _TeacherRowAction.deleteUser:
                    _deleteTeacher();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_TeacherRowAction>(
                  value: _TeacherRowAction.settings,
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Setări'),
                    ],
                  ),
                ),
                PopupMenuItem<_TeacherRowAction>(
                  value: _TeacherRowAction.deleteUser,
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

// ─────────────────────────────────────────────────────────────────────────────
//  _TeacherStatusChip
// ─────────────────────────────────────────────────────────────────────────────

class _TeacherStatusChip extends StatelessWidget {
  final String status; // 'inSchool' | 'outside' | 'disabled'

  const _TeacherStatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'inSchool':
        bg = const Color(0xFF0A7A21);
        fg = Colors.white;
        label = 'Activ';
        break;
      case 'disabled':
        bg = const Color(0xFF6B1A1A);
        fg = Colors.white;
        label = 'Dezactivat';
        break;
      case 'outside':
      default:
        bg = const Color(0xFFE8F0E8);
        fg = const Color(0xFF4A6E52);
        label = 'Inactiv';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: fg,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
