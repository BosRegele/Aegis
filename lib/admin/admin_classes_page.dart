import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';
import 'admin_api.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key});

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  final api = AdminApi();
  final Random _rng = Random.secure();
  bool _sidebarBusy = false;

  String? selectedClassId;
  Map<String, dynamic>? selectedClassData;
  bool _exportBusy = false;

  static const Map<String, String> _dayNames = {
    '1': 'Luni',
    '2': 'Marti',
    '3': 'Miercuri',
    '4': 'Joi',
    '5': 'Vineri',
  };

  int _compareClassLabels(String a, String b) {
    final aTrim = a.trim();
    final bTrim = b.trim();

    final aNumMatch = RegExp(r'^\d+').firstMatch(aTrim);
    final bNumMatch = RegExp(r'^\d+').firstMatch(bTrim);

    final aNum = aNumMatch != null ? int.tryParse(aNumMatch.group(0)!) : null;
    final bNum = bNumMatch != null ? int.tryParse(bNumMatch.group(0)!) : null;

    if (aNum != null && bNum != null && aNum != bNum) {
      return aNum.compareTo(bNum);
    }
    if (aNum != null && bNum == null) return -1;
    if (aNum == null && bNum != null) return 1;

    final aSuffix = aNumMatch != null
        ? aTrim.substring(aNumMatch.end).trim().toUpperCase()
        : aTrim.toUpperCase();
    final bSuffix = bNumMatch != null
        ? bTrim.substring(bNumMatch.end).trim().toUpperCase()
        : bTrim.toUpperCase();

    final suffixCmp = aSuffix.compareTo(bSuffix);
    if (suffixCmp != 0) return suffixCmp;

    return aTrim.toLowerCase().compareTo(bTrim.toLowerCase());
  }

  String _randPassword(int len) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  TimeOfDay _toTimeOfDay(String? value) {
    final raw = (value ?? '').trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(raw);
    if (match == null) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
    final hour = int.tryParse(match.group(1) ?? '8') ?? 8;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  String _fmtTime(TimeOfDay t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Map<String, Map<String, String>> _normalizedSchedule(
    Map<String, dynamic>? schedule,
  ) {
    final out = <String, Map<String, String>>{};
    for (final key in _dayNames.keys) {
      final day =
          (schedule?[key] as Map<String, dynamic>?) ??
          const <String, dynamic>{};
      out[key] = {
        'start': (day['start'] ?? '08:00').toString(),
        'end': (day['end'] ?? '14:00').toString(),
      };
    }
    return out;
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

  void _syncSelectedClass(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      if (selectedClassId != null || selectedClassData != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            selectedClassId = null;
            selectedClassData = null;
          });
        });
      }
      return;
    }

    QueryDocumentSnapshot? selectedDoc;
    if (selectedClassId != null) {
      for (final doc in docs) {
        if (doc.id == selectedClassId) {
          selectedDoc = doc;
          break;
        }
      }
    }
    selectedDoc ??= docs.first;

    final selectedData = selectedDoc.data() as Map<String, dynamic>;
    final shouldUpdate =
        selectedClassId != selectedDoc.id ||
        !_sameMapRef(selectedClassData, selectedData);

    if (!shouldUpdate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedClassId = selectedDoc!.id;
        selectedClassData = Map<String, dynamic>.from(selectedData);
      });
    });
  }

  bool _sameMapRef(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return false;
  }

  String _classLabelFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().trim();
    return name.isEmpty ? doc.id : name;
  }

  Future<void> _pickAndSaveTime({
    required String classId,
    required String dayKey,
    required String field,
    required String currentValue,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _toTimeOfDay(currentValue),
      helpText: field == 'start'
          ? 'Selecteaza ora de intrare'
          : 'Selecteaza ora de iesire',
    );
    if (picked == null) return;

    final newValue = _fmtTime(picked);
    await FirebaseFirestore.instance.collection('classes').doc(classId).set({
      'schedule': {
        dayKey: {field: newValue},
      },
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      final base = Map<String, dynamic>.from(selectedClassData ?? const {});
      final rawSchedule = Map<String, dynamic>.from(
        (base['schedule'] as Map<String, dynamic>?) ?? const {},
      );
      final day = Map<String, dynamic>.from(
        (rawSchedule[dayKey] as Map<String, dynamic>?) ?? const {},
      );
      day[field] = newValue;
      rawSchedule[dayKey] = day;
      base['schedule'] = rawSchedule;
      selectedClassData = base;
    });
  }

  Future<void> _exportSelectedClassStudentsReport() async {
    final classId = selectedClassId;
    if (classId == null || classId.isEmpty) return;
    if (_exportBusy) return;

    setState(() => _exportBusy = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
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
      var resetOk = 0;
      var resetFailed = 0;

      for (final s in students) {
        final fullName = (s['fullName'] ?? '').trim();
        final userId = (s['userId'] ?? '').trim().toLowerCase();

        if (userId.isEmpty) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE EȘUATĂ: lipsă ID utilizator',
          });
          continue;
        }

        final newPassword = _randPassword(10);

        try {
          await api.resetPassword(username: userId, newPassword: newPassword);
          resetOk++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': newPassword,
          });
        } catch (_) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE EȘUATĂ',
          });
        }
      }

      final excel = xls.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      final sheet = excel[defaultSheet ?? 'Elevi'];

      sheet.appendRow([
        xls.TextCellValue('Clasa'),
        xls.TextCellValue('Nume'),
        xls.TextCellValue('ID utilizator'),
        xls.TextCellValue('Parola'),
      ]);

      for (final s in exported) {
        sheet.appendRow([
          xls.TextCellValue(classId),
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
        name: 'student_report_${classId}_$stamp',
        bytes: Uint8List.fromList(bytes),
        ext: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Raport pentru clasa $classId descarcat. Resetate: $resetOk, esuate: $resetFailed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare la export: $e')));
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acces interzis (doar admin).')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B7A21),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClassesSidebar(
                    onMenuTap: () => Navigator.of(context).pop(),
                    onStudentsTap: () =>
                        _replacePage(const AdminStudentsPage()),
                    onPersonalTap: () =>
                        _replacePage(const AdminTeachersPage()),
                    onTurnichetiTap: () =>
                        _replacePage(const AdminTurnstilesPage()),
                    onClaseTap: () {},
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
                          const _ClassesTopBar(),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('classes')
                                  .snapshots(),
                              builder: (context, snap) {
                                if (snap.hasError) {
                                  return Center(
                                    child: SelectableText(
                                      'Eroare clase:\n${snap.error}',
                                    ),
                                  );
                                }
                                if (!snap.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final docs = [...snap.data!.docs]
                                  ..sort(
                                    (a, b) => _compareClassLabels(
                                      _classLabelFromDoc(a),
                                      _classLabelFromDoc(b),
                                    ),
                                  );

                                _syncSelectedClass(docs);

                                final selectedId = selectedClassId;
                                QueryDocumentSnapshot? selectedDoc;
                                for (final d in docs) {
                                  if (d.id == selectedId) {
                                    selectedDoc = d;
                                    break;
                                  }
                                }

                                final activeClassId = selectedDoc?.id;
                                final activeClassData =
                                    selectedDoc?.data()
                                        as Map<String, dynamic>?;
                                final activeClassName = selectedDoc == null
                                    ? null
                                    : _classLabelFromDoc(selectedDoc);

                                if (docs.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Nu exista clase configurate.',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF5B6B58),
                                      ),
                                    ),
                                  );
                                }

                                return SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    18,
                                    22,
                                    24,
                                  ),
                                  child: LayoutBuilder(
                                    builder: (context, constraints) {
                                      final vertical =
                                          constraints.maxWidth < 1080;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Gestiune Clase',
                                            style: TextStyle(
                                              fontSize: 44,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF223624),
                                              letterSpacing: -0.4,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Administrarea elevilor si configurarea programului operational.',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF5C6D58),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (vertical) ...[
                                            _ClassSelectorCard(
                                              selectedClassId: activeClassId,
                                              classDocs: docs,
                                              classLabelBuilder:
                                                  _classLabelFromDoc,
                                              onChanged: (newClassId) {
                                                QueryDocumentSnapshot? doc;
                                                for (final d in docs) {
                                                  if (d.id == newClassId) {
                                                    doc = d;
                                                    break;
                                                  }
                                                }
                                                setState(() {
                                                  selectedClassId = doc?.id;
                                                  selectedClassData =
                                                      doc == null
                                                      ? null
                                                      : Map<
                                                          String,
                                                          dynamic
                                                        >.from(
                                                          doc.data()
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >,
                                                        );
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                            _ClassStudentsCard(
                                              classId: activeClassId,
                                              className: activeClassName,
                                            ),
                                            const SizedBox(height: 14),
                                            _ScheduleCard(
                                              classId: activeClassId,
                                              selectedClassData:
                                                  activeClassData,
                                              dayNames: _dayNames,
                                              scheduleBuilder:
                                                  _normalizedSchedule,
                                              onPickStart: activeClassId == null
                                                  ? null
                                                  : (day, value) =>
                                                        _pickAndSaveTime(
                                                          classId:
                                                              activeClassId,
                                                          dayKey: day,
                                                          field: 'start',
                                                          currentValue: value,
                                                        ),
                                              onPickEnd: activeClassId == null
                                                  ? null
                                                  : (day, value) =>
                                                        _pickAndSaveTime(
                                                          classId:
                                                              activeClassId,
                                                          dayKey: day,
                                                          field: 'end',
                                                          currentValue: value,
                                                        ),
                                            ),
                                          ] else
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  flex: 6,
                                                  child: Column(
                                                    children: [
                                                      _ClassSelectorCard(
                                                        selectedClassId:
                                                            activeClassId,
                                                        classDocs: docs,
                                                        classLabelBuilder:
                                                            _classLabelFromDoc,
                                                        onChanged: (newClassId) {
                                                          QueryDocumentSnapshot?
                                                          doc;
                                                          for (final d
                                                              in docs) {
                                                            if (d.id ==
                                                                newClassId) {
                                                              doc = d;
                                                              break;
                                                            }
                                                          }
                                                          setState(() {
                                                            selectedClassId =
                                                                doc?.id;
                                                            selectedClassData =
                                                                doc == null
                                                                ? null
                                                                : Map<
                                                                    String,
                                                                    dynamic
                                                                  >.from(
                                                                    doc.data()
                                                                        as Map<
                                                                          String,
                                                                          dynamic
                                                                        >,
                                                                  );
                                                          });
                                                        },
                                                      ),
                                                      const SizedBox(
                                                        height: 14,
                                                      ),
                                                      _ClassStudentsCard(
                                                        classId: activeClassId,
                                                        className:
                                                            activeClassName,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                Expanded(
                                                  flex: 5,
                                                  child: _ScheduleCard(
                                                    classId: activeClassId,
                                                    selectedClassData:
                                                        activeClassData,
                                                    dayNames: _dayNames,
                                                    scheduleBuilder:
                                                        _normalizedSchedule,
                                                    onPickStart:
                                                        activeClassId == null
                                                        ? null
                                                        : (
                                                            day,
                                                            value,
                                                          ) => _pickAndSaveTime(
                                                            classId:
                                                                activeClassId,
                                                            dayKey: day,
                                                            field: 'start',
                                                            currentValue: value,
                                                          ),
                                                    onPickEnd:
                                                        activeClassId == null
                                                        ? null
                                                        : (
                                                            day,
                                                            value,
                                                          ) => _pickAndSaveTime(
                                                            classId:
                                                                activeClassId,
                                                            dayKey: day,
                                                            field: 'end',
                                                            currentValue: value,
                                                          ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          const SizedBox(height: 16),
                                          _ExportBar(
                                            enabled: activeClassId != null,
                                            busy: _exportBusy,
                                            onExport:
                                                _exportSelectedClassStudentsReport,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
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
      ),
    );
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String role,
    String? classId,
    required String fullName,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminCreateUser',
    );

    await callable.call({
      'username': username,
      'password': password,
      'role': role,
      'classId': classId,
      'fullName': fullName,
    });
  }
}

class _ClassesTopBar extends StatelessWidget {
  const _ClassesTopBar();

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
            'Clase & Elevi',
            style: TextStyle(
              fontSize: 40,
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
          const AdminNotificationBell(),
        ],
      ),
    );
  }
}

class _ClassesSidebar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _ClassesSidebar({
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
            selected: true,
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Vacante',
            icon: Icons.event_available_rounded,
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

class _ClassSelectorCard extends StatelessWidget {
  final String? selectedClassId;
  final List<QueryDocumentSnapshot> classDocs;
  final String Function(QueryDocumentSnapshot) classLabelBuilder;
  final ValueChanged<String?> onChanged;

  const _ClassSelectorCard({
    required this.selectedClassId,
    required this.classDocs,
    required this.classLabelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECTEAZA CLASA',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF6D7B6A),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: selectedClassId,
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F8F2),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDAE8D0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFDAE8D0)),
              ),
            ),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: classDocs
                .map(
                  (d) => DropdownMenuItem<String>(
                    value: d.id,
                    child: Text(
                      classLabelBuilder(d),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final String? classId;
  final Map<String, dynamic>? selectedClassData;
  final Map<String, String> dayNames;
  final Map<String, Map<String, String>> Function(Map<String, dynamic>?)
  scheduleBuilder;
  final Future<void> Function(String day, String currentValue)? onPickStart;
  final Future<void> Function(String day, String currentValue)? onPickEnd;

  const _ScheduleCard({
    required this.classId,
    required this.selectedClassData,
    required this.dayNames,
    required this.scheduleBuilder,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    final schedule = scheduleBuilder(
      selectedClassData?['schedule'] as Map<String, dynamic>?,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interval Operational',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2819),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            classId == null
                ? 'Configureaza orele de intrare si iesire pentru fiecare zi'
                : 'Configureaza orele de intrare si iesire pentru clasa selectata',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7868),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  'Ziua saptamanii',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D7B6A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Text(
                  'Ora intrare',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D7B6A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: Text(
                  'Ora iesire',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6D7B6A),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...dayNames.entries.map((entry) {
            final dayKey = entry.key;
            final start = schedule[dayKey]?['start'] ?? '08:00';
            final end = schedule[dayKey]?['end'] ?? '14:00';

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE4EEDE)),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E2A1B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: onPickStart == null
                          ? null
                          : () => onPickStart!(dayKey, start),
                      icon: const Icon(Icons.access_time_rounded, size: 14),
                      label: Text(start),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2F7D3A),
                        side: const BorderSide(color: Color(0xFFBDD5B2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 4,
                    child: OutlinedButton.icon(
                      onPressed: onPickEnd == null
                          ? null
                          : () => onPickEnd!(dayKey, end),
                      icon: const Icon(Icons.access_time_rounded, size: 14),
                      label: Text(end),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2F7D3A),
                        side: const BorderSide(color: Color(0xFFBDD5B2)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ClassStudentsCard extends StatelessWidget {
  final String? classId;
  final String? className;

  const _ClassStudentsCard({required this.classId, required this.className});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Lista Elevi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2819),
                  ),
                ),
                const Spacer(),
                if (className != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6E0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC9E1B8)),
                    ),
                    child: Text(
                      className!,
                      style: const TextStyle(
                        color: Color(0xFF2C6E30),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ClassStudentsList(classId: classId),
          ],
        ),
      ),
    );
  }
}

class _ClassStudentsList extends StatelessWidget {
  final String? classId;

  const _ClassStudentsList({required this.classId});

  @override
  Widget build(BuildContext context) {
    if (classId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Selecteaza o clasa pentru a vedea elevii.',
            style: TextStyle(color: Color(0xFF667466)),
          ),
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return SelectableText('Eroare elevi:\n${snap.error}');
        }
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final docs = [...snap.data!.docs];
        docs.sort((a, b) {
          final an = ((a.data() as Map)['fullName'] ?? '')
              .toString()
              .toLowerCase();
          final bn = ((b.data() as Map)['fullName'] ?? '')
              .toString()
              .toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                'Nu exista elevi in aceasta clasa.',
                style: TextStyle(color: Color(0xFF667466)),
              ),
            ),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final username = (data['username'] ?? d.id).toString();
            final fullName = (data['fullName'] ?? username).toString();
            final inSchool = data['inSchool'] as bool? ?? false;

            final initials = fullName
                .trim()
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .take(2)
                .map((p) => p[0].toUpperCase())
                .join();

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4EEDE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4EEA9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3F1E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2F1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Username: $username',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6A7B68),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: inSchool
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: inSchool
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                      ),
                    ),
                    child: Text(
                      inSchool ? 'In incinta' : 'In afara incintei',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: inSchool
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: null,
                    icon: const Icon(Icons.settings, size: 16),
                    color: const Color(0xFF7D8E79),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ExportBar extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final Future<void> Function() onExport;

  const _ExportBar({
    required this.enabled,
    required this.busy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F7422),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.file_download_outlined, color: Colors.white),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Date Academice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Exporta numele, utilizatorul si parola pentru clasa selectata.',
                  style: TextStyle(color: Color(0xFFD8F0D1), fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: !enabled || busy ? null : onExport,
            icon: busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF166B2B),
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 16),
            label: Text(busy ? 'Export...' : 'Exporta Excel'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF145A24),
              disabledBackgroundColor: const Color(0xFFE5E9E1),
              disabledForegroundColor: const Color(0xFF8B9486),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
