import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  AdminStudentsPage
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final AdminApi _api = AdminApi();
  final Random _rng = Random.secure();
  bool _sidebarBusy = false;

  int? _filterGrade;
  String _filterStatus = 'all';
  String _searchQuery = '';
  final TextEditingController _searchC = TextEditingController();
  int _page = 0;
  static const int _pageSize = 8;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // â”€â”€ Navigation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€ Create-account helpers (identical to SecretariatRawPage) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  Future<void> _exportStudentsReport() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final students = snap.docs.map((d) {
        final data = d.data();
        return {
          'fullName': (data['fullName'] ?? '').toString(),
          'userId': (data['username'] ?? d.id).toString(),
        };
      }).toList();

      students.sort((a, b) {
        final an = (a['fullName'] ?? '').toLowerCase();
        final bn = (b['fullName'] ?? '').toLowerCase();
        return an.compareTo(bn);
      });

      final exported = <Map<String, String>>[];
      int resetOk = 0;
      int resetFailed = 0;

      for (final s in students) {
        final fullName = (s['fullName'] ?? '').trim();
        final userId = (s['userId'] ?? '').trim().toLowerCase();

        if (userId.isEmpty) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE ESUATA: lipsa ID utilizator',
          });
          continue;
        }

        final newPassword = _randPassword(10);

        try {
          await _api.resetPassword(username: userId, newPassword: newPassword);

          resetOk++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': newPassword,
          });
        } catch (e) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE ESUATA',
          });
        }
      }

      final excel = xls.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      final sheet = excel[defaultSheet ?? 'Elevi'];

      sheet.appendRow([
        xls.TextCellValue('Nume'),
        xls.TextCellValue('ID utilizator'),
        xls.TextCellValue('Parola'),
      ]);

      for (final s in exported) {
        sheet.appendRow([
          xls.TextCellValue(s['fullName'] ?? ''),
          xls.TextCellValue(s['userId'] ?? ''),
          xls.TextCellValue(s['password'] ?? ''),
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
        name: 'student_report_$stamp',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare la export: $e')));
    }
  }

  Future<void> _showCreateAccountDialog() async {
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
          const SnackBar(content: Text('Selecteaza clasa pentru elev.')),
        );
        return;
      }

      setS(() => isBusy = true);
      try {
        await _api.createUser(
          username: username,
          password: password,
          fullName: fullName,
          role: 'student',
          classId: selectedClassId,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cont elev creat cu succes.')),
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
          title: const Text('Adauga Elev Nou'),
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

  // â”€â”€ Grade extraction â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  int? _extractGrade(String classId) {
    final m = RegExp(r'^(\d+)').firstMatch(classId);
    if (m == null) return null;
    final n = int.tryParse(m.group(1)!);
    return (n != null && n >= 5 && n <= 12) ? n : null;
  }

  // â”€â”€ Student status â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  String _studentStatus(bool inSchool, bool scannedEntryToday) {
    if (inSchool) return 'active';
    if (scannedEntryToday) return 'inactive';
    return 'absent';
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acces interzis (doar admin).')),
      );
    }

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    return Scaffold(
      backgroundColor: const Color(0xFF0B7A21),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              children: [
                // â”€â”€ Sidebar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                _StudentsSidebar(
                  selected: 'students',
                  onMenuTap: () {
                    if (!mounted) return;
                    Navigator.of(context).pop();
                  },
                  onStudentsTap: () {},
                  onPersonalTap: () => _replacePage(const AdminTeachersPage()),
                  onTurnichetiTap: () =>
                      _replacePage(const AdminTurnstilesPage()),
                  onClaseTap: () => _replacePage(const AdminClassesPage()),
                  onVacanteTap: () =>
                      _replacePage(const admin_vacante.AdminClassesPage()),
                  onParintiTap: () => _replacePage(const AdminParentsPage()),
                  onLogoutTap: _showLogoutDialog,
                ),

                // â”€â”€ Content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                Expanded(
                  child: Container(
                    color: const Color(0xFFF0F3EC),
                    child: Column(
                      children: [
                        _StudentsTopBar(
                          displayName: AppSession.username ?? 'Admin',
                          searchController: _searchC,
                          onSearch: (v) => setState(() {
                            _searchQuery = v.trim().toLowerCase();
                            _page = 0;
                          }),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where('role', isEqualTo: 'student')
                                .snapshots(),
                            builder: (context, studSnap) {
                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('accessEvents')
                                    .where(
                                      'timestamp',
                                      isGreaterThanOrEqualTo:
                                          Timestamp.fromDate(todayStart),
                                    )
                                    .snapshots(),
                                builder: (context, evSnap) {
                                  final allStudents =
                                      List<QueryDocumentSnapshot>.from(
                                        studSnap.data?.docs ?? [],
                                      );
                                  final todayEvents = evSnap.data?.docs ?? [];

                                  // Construieste setul de userId-uri care au scanat intrarea azi
                                  final entryTodaySet = <String>{};
                                  for (final ev in todayEvents) {
                                    final d = ev.data() as Map<String, dynamic>;
                                    final type =
                                        (d['type'] ?? d['scanType'] ?? '')
                                            .toString()
                                            .toLowerCase();
                                    if (type == 'entry') {
                                      final uid = (d['userId'] ?? '')
                                          .toString();
                                      if (uid.isNotEmpty)
                                        entryTodaySet.add(uid);
                                    }
                                  }

                                  // Statistici campus
                                  final totalRegistered = allStudents.length;
                                  int presentToday = 0;
                                  int onLeaveCount = 0;
                                  for (final s in allStudents) {
                                    final d = s.data() as Map<String, dynamic>;
                                    final inSchool =
                                        d['inSchool'] as bool? ?? false;
                                    if (inSchool) {
                                      presentToday++;
                                    } else if (entryTodaySet.contains(s.id)) {
                                      onLeaveCount++;
                                    }
                                  }

                                  // Available grades (5-12 only)
                                  final gradeSet = <int>{};
                                  for (final s in allStudents) {
                                    final classId =
                                        ((s.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >)['classId'] ??
                                                '')
                                            .toString();
                                    final g = _extractGrade(classId);
                                    if (g != null) gradeSet.add(g);
                                  }
                                  final availableGrades = gradeSet.toList()
                                    ..sort();

                                  // Filter (grade + status + search)
                                  final filtered = allStudents.where((s) {
                                    final d = s.data() as Map<String, dynamic>;
                                    // Grade filter
                                    if (_filterGrade != null) {
                                      final classId = (d['classId'] ?? '')
                                          .toString();
                                      if (_extractGrade(classId) !=
                                          _filterGrade) {
                                        return false;
                                      }
                                    }
                                    // Status filter
                                    if (_filterStatus != 'all') {
                                      final inSchool =
                                          d['inSchool'] as bool? ?? false;
                                      final st = _studentStatus(
                                        inSchool,
                                        entryTodaySet.contains(s.id),
                                      );
                                      if (st != _filterStatus) return false;
                                    }
                                    // Text search
                                    if (_searchQuery.isNotEmpty) {
                                      final name = (d['fullName'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                      final username = (d['username'] ?? s.id)
                                          .toString()
                                          .toLowerCase();
                                      final classId = (d['classId'] ?? '')
                                          .toString()
                                          .toLowerCase();
                                      final parentIds = List<String>.from(
                                        d['parents'] ?? [],
                                      );
                                      final parentEmails = parentIds
                                          .map(
                                            (id) => '$id@school.local'
                                                .toLowerCase(),
                                          )
                                          .join(' ');
                                      // status label search
                                      final inSchool =
                                          d['inSchool'] as bool? ?? false;
                                      final statusLabel = _studentStatus(
                                        inSchool,
                                        entryTodaySet.contains(s.id),
                                      ).toLowerCase();
                                      if (!name.contains(_searchQuery) &&
                                          !username.contains(_searchQuery) &&
                                          !classId.contains(_searchQuery) &&
                                          !parentEmails.contains(
                                            _searchQuery,
                                          ) &&
                                          !statusLabel.contains(_searchQuery)) {
                                        return false;
                                      }
                                    }
                                    return true;
                                  }).toList();

                                  // Sort by full name
                                  filtered.sort((a, b) {
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

                                  // Paginate (5 per page)
                                  final totalFiltered = filtered.length;
                                  final maxPage = (totalFiltered / _pageSize)
                                      .ceil();
                                  final safePage = maxPage == 0
                                      ? 0
                                      : _page.clamp(0, maxPage - 1);
                                  final pageStart = safePage * _pageSize;
                                  final pageEnd = (pageStart + _pageSize).clamp(
                                    0,
                                    totalFiltered,
                                  );
                                  final pageStudents = filtered.sublist(
                                    pageStart,
                                    pageEnd,
                                  );

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      _PageHeader(
                                        onAddTap: _showCreateAccountDialog,
                                        onExportTap: _exportStudentsReport,
                                      ),
                                      _FilterStatsRow(
                                        availableGrades: availableGrades,
                                        selectedGrade: _filterGrade,
                                        selectedStatus: _filterStatus,
                                        totalRegistered: totalRegistered,
                                        presentToday: presentToday,
                                        onLeaveCount: onLeaveCount,
                                        onGradeChanged: (v) => setState(() {
                                          _filterGrade = v;
                                          _page = 0;
                                        }),
                                        onStatusChanged: (v) => setState(() {
                                          _filterStatus = v ?? 'all';
                                          _page = 0;
                                        }),
                                      ),
                                      Expanded(
                                        child: _StudentsTablePanel(
                                          students: pageStudents,
                                          entryTodaySet: entryTodaySet,
                                          studentStatus: _studentStatus,
                                          pageStart: pageStart,
                                          pageEnd: pageEnd,
                                          totalFiltered: totalFiltered,
                                          totalAll: totalRegistered,
                                          safePage: safePage,
                                          maxPage: maxPage,
                                          onPageTap: (p) =>
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

class _StudentsTopBar extends StatelessWidget {
  final String displayName;
  final TextEditingController searchController;
  final ValueChanged<String> onSearch;

  const _StudentsTopBar({
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
            'Elevi',
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
                            hintText:
                                'Cauta dupa nume, ID, clasa, email parinte sau status...',
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _StudentsSidebar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StudentsSidebar extends StatelessWidget {
  final String selected;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _StudentsSidebar({
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
//  _PageHeader
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PageHeader extends StatelessWidget {
  final VoidCallback onAddTap;
  final VoidCallback onExportTap;

  const _PageHeader({required this.onAddTap, required this.onExportTap});

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
                  'Catalog Elevi',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A2F1E),
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gestioneaza si monitorizeaza inscrierile elevilor, statusul prezentei si\n'
                  'comunicarea cu parintii dintr-o vedere centrala.',
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
          // Export raport
          OutlinedButton.icon(
            onPressed: onExportTap,
            icon: const Icon(Icons.download_rounded, size: 16),
            label: const Text('Exporta raport'),
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
          // Adauga elev nou - deschide dialogul de creare
          FilledButton.icon(
            onPressed: onAddTap,
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Adauga elev nou'),
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

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _FilterStatsRow
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FilterStatsRow extends StatelessWidget {
  final List<int> availableGrades;
  final int? selectedGrade;
  final String selectedStatus;
  final int totalRegistered;
  final int presentToday;
  final int onLeaveCount;
  final ValueChanged<int?> onGradeChanged;
  final ValueChanged<String?> onStatusChanged;

  const _FilterStatsRow({
    required this.availableGrades,
    required this.selectedGrade,
    required this.selectedStatus,
    required this.totalRegistered,
    required this.presentToday,
    required this.onLeaveCount,
    required this.onGradeChanged,
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
            // AN CLASA
            SizedBox(
              width: 180,
              child: _FilterCard(
                label: 'AN CLASA',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: selectedGrade,
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
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Toate clasele'),
                      ),
                      for (final g in availableGrades)
                        DropdownMenuItem<int?>(
                          value: g,
                          child: Text('Clasa $g'),
                        ),
                    ],
                    onChanged: onGradeChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // STATUS INSCRIERE
            SizedBox(
              width: 220,
              child: _FilterCard(
                label: 'STATUS INSCRIERE',
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
                        child: Text('Toti elevii'),
                      ),
                      DropdownMenuItem(value: 'active', child: Text('Activi')),
                      DropdownMenuItem(value: 'absent', child: Text('Absenti')),
                      DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Invoiti'),
                      ),
                    ],
                    onChanged: onStatusChanged,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // STATISTICI CAMPUS
            Expanded(
              child: _FilterCard(
                label: 'STATISTICI CAMPUS',
                centerContent: true,
                backgroundColor: const Color(0xFFF0F9F1),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        value: totalRegistered,
                        label: 'TOTAL INREGISTRATI',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        value: presentToday,
                        label: 'PREZENTI AZI',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(value: onLeaveCount, label: 'INVOITI'),
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

class _FilterCard extends StatelessWidget {
  final String label;
  final Widget child;
  final bool centerContent;
  final Color? backgroundColor;

  const _FilterCard({
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
        mainAxisAlignment: centerContent
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7B9E84),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final int value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1A2F1E),
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4A8C5C),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _StudentsTablePanel
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StudentsTablePanel extends StatelessWidget {
  final List<QueryDocumentSnapshot> students;
  final Set<String> entryTodaySet;
  final String Function(bool, bool) studentStatus;
  final int pageStart;
  final int pageEnd;
  final int totalFiltered;
  final int totalAll;
  final int safePage;
  final int maxPage;
  final ValueChanged<int> onPageTap;

  const _StudentsTablePanel({
    required this.students,
    required this.entryTodaySet,
    required this.studentStatus,
    required this.pageStart,
    required this.pageEnd,
    required this.totalFiltered,
    required this.totalAll,
    required this.safePage,
    required this.maxPage,
    required this.onPageTap,
  });

  @override
  Widget build(BuildContext context) {
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
                Expanded(flex: 30, child: _TH('NUME ELEV')),
                Expanded(flex: 18, child: _TH('CLASA')),
                Expanded(flex: 28, child: _TH('CONTACT PARINTE')),
                Expanded(flex: 14, child: _TH('STATUS')),
                Expanded(flex: 10, child: _TH('ACTIUNI')),
              ],
            ),
          ),

          // Rows â€” expands to fill available space, pagination pinned below
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Nu exista elevi cu filtrele selectate.',
                          style: TextStyle(
                            color: Color(0xFF7B9E84),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF4EE)),
                    itemBuilder: (_, i) => _StudentRow(
                      doc: students[i],
                      entryTodaySet: entryTodaySet,
                      studentStatus: studentStatus,
                    ),
                  ),
          ),

          // Pagination bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFFF0F5F0))),
            ),
            child: Row(
              children: [
                Text(
                  totalFiltered == 0
                      ? 'SE AFISEAZA 0 ELEVI'
                      : 'SE AFISEAZA ${pageStart + 1} - $pageEnd DIN $totalAll ELEVI',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7B9E84),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: safePage > 0
                      ? () => onPageTap(safePage - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  color: const Color(0xFF0A7A21),
                  disabledColor: Colors.grey.shade300,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
                const SizedBox(width: 4),
                ...List.generate(maxPage, (i) {
                  final sel = i == safePage;
                  return GestureDetector(
                    onTap: () => onPageTap(i),
                    child: Container(
                      width: 30,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: sel
                            ? const Color(0xFF0A7A21)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: sel
                            ? null
                            : Border.all(color: const Color(0xFFCCD9C8)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : const Color(0xFF4A5E4D),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: safePage < maxPage - 1
                      ? () => onPageTap(safePage + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                  color: const Color(0xFF0A7A21),
                  disabledColor: Colors.grey.shade300,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
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
//  _TH  â€” table header label
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

enum _StudentRowAction { settings, deleteUser }

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _StudentRow
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StudentRow extends StatefulWidget {
  final QueryDocumentSnapshot doc;
  final Set<String> entryTodaySet;
  final String Function(bool, bool) studentStatus;

  const _StudentRow({
    required this.doc,
    required this.entryTodaySet,
    required this.studentStatus,
  });

  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow> {
  final AdminApi _api = AdminApi();
  List<Map<String, dynamic>>? _parents;
  bool _actionBusy = false;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    final data = widget.doc.data() as Map<String, dynamic>;
    final parentIds = List<String>.from(data['parents'] ?? []);
    if (parentIds.isEmpty) {
      if (mounted) setState(() => _parents = []);
      return;
    }
    try {
      final snaps = await Future.wait(
        parentIds.map(
          (id) => FirebaseFirestore.instance.collection('users').doc(id).get(),
        ),
      );
      if (!mounted) return;
      setState(() {
        _parents = snaps.map((s) {
          final d = s.data() ?? <String, dynamic>{};
          return {'username': (d['username'] ?? s.id).toString()};
        }).toList();
      });
    } catch (_) {
      if (mounted) setState(() => _parents = []);
    }
  }

  Future<void> _deleteStudent() async {
    if (_actionBusy) return;

    final data = widget.doc.data() as Map<String, dynamic>;
    final username = (data['username'] ?? widget.doc.id).toString();

    setState(() => _actionBusy = true);
    try {
      await _api.deleteUser(username: username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Utilizatorul $username a fost șters.')),
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
            title: const Text('Setări elev'),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Introdu un nume valid.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (newFullName == currentFullName) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Numele este deja setat.',
                                            ),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Numele elevului a fost actualizat.',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setDialogState(
                                          () => renameBusy = false,
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Eroare la actualizarea numelui: $e',
                                            ),
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
                                renameBusy
                                    ? 'Se salvează...'
                                    : 'Salvează numele',
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
                                          (doc.data()['name'] ?? doc.id)
                                              .toString(),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Selectează o clasă.',
                                            ),
                                          ),
                                        );
                                        return;
                                      }
                                      if (selectedClassId == currentClassId) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Elevul este deja în clasa selectată.',
                                            ),
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
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Clasa elevului a fost actualizată.',
                                            ),
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        setDialogState(() => moveBusy = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Eroare la schimbarea clasei: $e',
                                            ),
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
                                moveBusy
                                    ? 'Se actualizează...'
                                    : 'Actualizează clasa',
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
    final inSchool = data['inSchool'] as bool? ?? false;
    final photoUrl = (data['photoUrl'] ?? data['avatarUrl'] ?? '').toString();
    final status = widget.studentStatus(
      inSchool,
      widget.entryTodaySet.contains(widget.doc.id),
    );

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
          // Nume elev + avatar
          Expanded(
            flex: 30,
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
                        'ID: $username',
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

          // Eticheta clasa
          Expanded(
            flex: 18,
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

          // Contact parinte
          Expanded(flex: 28, child: _buildParentContact()),

          // Eticheta status
          Expanded(flex: 14, child: _StatusChip(status: status)),

          // Actiuni (inactive)
          Expanded(
            flex: 10,
            child: PopupMenuButton<_StudentRowAction>(
              enabled: !_actionBusy,
              tooltip: 'Setări elev',
              offset: const Offset(0, 38),
              color: Colors.white,
              elevation: 10,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onSelected: (action) {
                switch (action) {
                  case _StudentRowAction.settings:
                    _showSettingsDialog();
                    break;
                  case _StudentRowAction.deleteUser:
                    _deleteStudent();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<_StudentRowAction>(
                  value: _StudentRowAction.settings,
                  child: Row(
                    children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Setări'),
                    ],
                  ),
                ),
                PopupMenuItem<_StudentRowAction>(
                  value: _StudentRowAction.deleteUser,
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

  Widget _buildParentContact() {
    if (_parents == null) {
      return const SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (_parents!.isEmpty) {
      return const Text(
        '-',
        style: TextStyle(color: Color(0xFF9DB8A0), fontSize: 13),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: _parents!.map((p) {
        final email = '${p['username']}@school.local';
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.email_outlined,
                size: 12,
                color: Color(0xFF7B9E84),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3A5240),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
//  _StatusChip
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'active':
        bg = const Color(0xFF0A7A21);
        fg = Colors.white;
        label = 'Activ';
        break;
      case 'inactive':
        bg = const Color(0xFFE8F0E8);
        fg = const Color(0xFF4A6E52);
        label = 'Inactiv';
        break;
      case 'absent':
      default:
        bg = const Color(0xFF6B1A1A);
        fg = Colors.white;
        label = status == 'absent' ? 'Absent' : status;
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    );
  }
}
