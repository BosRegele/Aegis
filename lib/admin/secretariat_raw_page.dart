import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firster/utils/csv_download.dart';
import 'services/admin_api.dart';
import 'services/admin_store.dart';
import 'admin_classes_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_parents_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;
// import 'secretariat_global_messages_page.dart'; // unused after menu cleanup
import '../services/security_flags_service.dart';
import '../core/session.dart';

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final api = AdminApi();
  final store = AdminStore();
  String activeSidebarLabel = "Meniu";

  // create user
  final fullNameC = TextEditingController();
  final usernameC = TextEditingController();
  final passwordC = TextEditingController();
  String selectedCreateUserClassId = "";

  String role = "student";

  // orar
  String selectedScheduleClassId = "";
  TimeOfDay noExitStart = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay noExitEnd = const TimeOfDay(hour: 12, minute: 30);
  final List<String> weekDays = ['Luni', 'Marți', 'Miercuri', 'Joi', 'Vineri'];
  late Map<String, bool> selectedDays;
  late Map<String, Map<String, TimeOfDay>>
  dayTimes; // {day: {start: TimeOfDay, end: TimeOfDay}}

  // actions
  final targetUserC = TextEditingController();
  final targetUserFullNameC = TextEditingController();
  final targetUserNewPasswordC = TextEditingController();
  String selectedMoveClassId = "";

  // assign parents
  Map<String, String>? selectedAssignStudent; // {'id': uid, 'name': display}
  Map<String, String>? selectedAssignParent; // {'id': uid, 'name': display}

  // class
  int selectedNumber = 9;
  String selectedLetter = "A";

  String log = "";
  final _rng = Random.secure();
  final Set<String> _busyActions = <String>{};

  // global messaging
  final _globalMsgController = TextEditingController();
  bool _msgToStudents = true;
  bool _msgToParents = true;
  bool _msgToTeachers = true;
  bool _sendingGlobalMsg = false;

  int _classDistPage = 0;

  // Web-only in-memory CSV buffer (no file system on web).
  final StringBuffer _webCsvBuffer = StringBuffer();
  bool _webCsvHasHeader = false;

  void _log(String s) => setState(() => log = "$s\n$log");

  void _logSuccess(String message) {
    _log("OK: $message");
  }

  void _logFailure(String message) {
    _log("EROARE: $message");
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(String operation) {
    switch (operation) {
      case 'create-user':
        return 'Utilizatorul nu a putut fi creat.';
      case 'create-class':
        return 'Clasa nu a putut fi creată.';
      case 'delete-class':
        return 'Clasa nu a putut fi ștearsă.';
      case 'reset-password':
        return 'Parola nu a putut fi resetată.';
      case 'disable-user':
        return 'Contul nu a putut fi dezactivat.';
      case 'enable-user':
        return 'Contul nu a putut fi activat.';
      case 'move-user':
        return 'Utilizatorul nu a putut fi mutat la clasa selectată.';
      case 'delete-user':
        return 'Utilizatorul nu a putut fi șters.';
      case 'rename-user':
        return 'Numele utilizatorului nu a putut fi actualizat.';
      case 'save-schedule':
        return 'Orarul nu a putut fi salvat.';
      case 'delete-schedule':
        return 'Orarul nu a putut fi șters.';
      case 'assign-parent':
        return 'Părintele nu a putut fi atribuit elevului.';
      case 'remove-parent':
        return 'Părintele nu a putut fi eliminat din elev.';
      case 'toggle-onboarding-global':
        return 'Setarea globală pentru onboarding nu a putut fi actualizată.';
      case 'toggle-2fa-global':
        return 'Setarea globală pentru 2FA nu a putut fi actualizată.';
      default:
        return 'Operațiunea nu a putut fi finalizată.';
    }
  }

  String _friendlyCreateClassError(Object error, String classId) {
    final raw = error.toString().toLowerCase();
    final alreadyExists =
        raw.contains('deja') && raw.contains('exista') ||
        raw.contains('already exists') ||
        (raw.contains('class') && raw.contains('exists'));

    if (alreadyExists) {
      return 'Clasa $classId există deja.';
    }

    return _friendlyError('create-class');
  }

  String _friendlyCreateUserError(Object error, String role, String? classId) {
    final raw = error.toString().toLowerCase();

    if (role == 'teacher') {
      if (raw.contains('deja') && raw.contains('diriginte')) {
        final cid = (classId ?? '').trim().toUpperCase();
        if (cid.isNotEmpty) {
          return 'Clasa $cid are deja diriginte.';
        }
        return 'Clasa selectată are deja diriginte.';
      }
      if (raw.contains('trebuie selectata o clasa') ||
          raw.contains('class') && raw.contains('required')) {
        return 'Selectează o clasă pentru profesor.';
      }
    }

    return _friendlyError('create-user');
  }

  String _friendlyMoveUserError(Object error, String classId) {
    final raw = error.toString().toLowerCase();
    if (raw.contains('deja') && raw.contains('diriginte')) {
      final cid = classId.trim().toUpperCase();
      if (cid.isNotEmpty) {
        return 'Clasa $cid are deja un diriginte. Utilizatorul nu poate fi mutat.';
      }
      return 'Clasa selectată are deja un diriginte. Utilizatorul nu poate fi mutat.';
    }
    return _friendlyError('move-user');
  }

  bool _isActionBusy(String key) => _busyActions.contains(key);

  Future<void> _runGuarded(String key, Future<void> Function() action) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
    } finally {
      _busyActions.remove(key);
      if (mounted) setState(() {});
    }
  }

  String _normalizeName(String s) {
    return s.trim().toLowerCase();
  }

  String _baseFromFullName(String fullName) {
    final n = _normalizeName(fullName);
    if (n.isEmpty) return "user";

    final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return "user";

    final first = parts.first;
    final last = parts.length > 1 ? parts.last : "";
    final base = (last.isEmpty) ? first : "${first[0]}$last";
    return base.replaceAll(RegExp(r'[^a-z0-9]'), "");
  }

  String _randDigits(int len) {
    const digits = "0123456789";
    return List.generate(
      len,
      (_) => digits[_rng.nextInt(digits.length)],
    ).join();
  }

  String _randPassword(int len) {
    const chars =
        "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#";
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _logSuccess('Datele au fost copiate în clipboard.');
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copiat în clipboard ✅")));
  }

  Future<Directory> _getCredentialsExportDirectory() async {
    if (kIsWeb) {
      throw UnsupportedError('Exportul CSV nu este disponibil pe web.');
    }

    Directory? baseDir;
    if (defaultTargetPlatform == TargetPlatform.android) {
      baseDir = await getExternalStorageDirectory();
    }
    baseDir ??= await getApplicationDocumentsDirectory();

    final exportDir = Directory(
      '${baseDir.path}${Platform.pathSeparator}exports',
    );
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    return exportDir;
  }

  Future<File> _getCredentialsCsvFile() async {
    final exportDir = await _getCredentialsExportDirectory();
    return File(
      '${exportDir.path}${Platform.pathSeparator}credentiale_utilizatori.csv',
    );
  }

  String _csvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(RegExp(r'[",\n\r]'))) {
      return '"$escaped"';
    }
    return escaped;
  }

  Future<String> _appendCreatedUserToCsv({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? classId,
  }) async {
    final row = [
      DateTime.now().toIso8601String(),
      username,
      password,
      fullName,
      role,
      classId ?? '',
    ].map(_csvCell).join(',');

    if (kIsWeb) {
      if (!_webCsvHasHeader) {
        _webCsvBuffer.writeln(
          'created_at,username,password,full_name,role,class_id',
        );
        _webCsvHasHeader = true;
      }
      _webCsvBuffer.writeln(row);
      return '(browser memory)';
    }

    final file = await _getCredentialsCsvFile();
    final exists = await file.exists();
    final isEmpty = !exists || await file.length() == 0;

    final sink = file.openWrite(mode: FileMode.append);
    if (isEmpty) {
      sink.writeln('created_at,username,password,full_name,role,class_id');
    }
    sink.writeln(row);
    await sink.flush();
    await sink.close();

    return file.path;
  }

  Future<void> _shareCredentialsCsv() async {
    try {
      if (kIsWeb) {
        if (!_webCsvHasHeader) {
          _logFailure('CSV-ul cu credențiale este gol sau nu există încă.');
          _showInfoMessage('Nu există încă un CSV cu utilizatori generați.');
          return;
        }
        await downloadCsvWeb(
          _webCsvBuffer.toString(),
          'credentiale_utilizatori.csv',
        );
        _logSuccess('CSV descărcat în browser.');
        _showInfoMessage('CSV descărcat în browser. ✅');
        return;
      }

      final file = await _getCredentialsCsvFile();
      if (!await file.exists() || await file.length() == 0) {
        _logFailure('CSV-ul cu credențiale este gol sau nu există încă.');
        _showInfoMessage('Nu există încă un CSV cu utilizatori generați.');
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'CSV cu utilizatori și parole generate din secretariat.',
          subject: 'Credențiale utilizatori',
        ),
      );

      _logSuccess('CSV exportat: ${file.path}');
      _showInfoMessage('CSV pregătit pentru trimitere.');
    } catch (error) {
      _logFailure('CSV-ul nu a putut fi exportat: $error');
      _showInfoMessage('CSV-ul nu a putut fi exportat.');
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _generateCreds() {
    final full = fullNameC.text.trim();
    if (full.isEmpty) {
      _logFailure('Completează Numele Complet înainte de generare.');
      _showInfoMessage('Completează Numele Complet înainte de generare.');
      return;
    }
    final base = _baseFromFullName(full);
    final uname = "$base${_randDigits(3)}";
    final pass = _randPassword(10);

    setState(() {
      usernameC.text = uname;
      passwordC.text = pass;
    });

    _log("GENERATED: $uname / $pass");
  }

  Future<void> _showLogoutDialog() async {
    const Color accentColor = Color(0xFF5A9641);
    const Color dangerColor = Color(0xFFB3261E);

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * animation.value,
            sigmaY: 10 * animation.value,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.48 * animation.value),
            child: FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(
                      parent: animation, curve: Curves.easeOutCubic),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
              border: Border.all(
                color: accentColor.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.16),
                    ),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: accentColor,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Deconectare',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ești sigur că dorești să te deconectezi?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor:
                              accentColor.withValues(alpha: 0.06),
                          foregroundColor: Colors.black87,
                          side: BorderSide(
                            color: accentColor.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Anulează'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.of(dialogContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: dangerColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Deconectare'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );

    if (confirmed == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<bool> _confirmMajorAction({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nu'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Da'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  @override
  void initState() {
    super.initState();
    selectedDays = {
      'Luni': true,
      'Marți': true,
      'Miercuri': true,
      'Joi': true,
      'Vineri': true,
    };
    // Initialize dayTimes for each day with default hours
    dayTimes = {
      'Luni': {
        'start': const TimeOfDay(hour: 7, minute: 30),
        'end': const TimeOfDay(hour: 13, minute: 0),
      },
      'Marți': {
        'start': const TimeOfDay(hour: 7, minute: 30),
        'end': const TimeOfDay(hour: 13, minute: 0),
      },
      'Miercuri': {
        'start': const TimeOfDay(hour: 7, minute: 30),
        'end': const TimeOfDay(hour: 13, minute: 0),
      },
      'Joi': {
        'start': const TimeOfDay(hour: 7, minute: 30),
        'end': const TimeOfDay(hour: 13, minute: 0),
      },
      'Vineri': {
        'start': const TimeOfDay(hour: 7, minute: 30),
        'end': const TimeOfDay(hour: 13, minute: 0),
      },
    };
  }

  @override
  void dispose() {
    fullNameC.dispose();
    usernameC.dispose();
    passwordC.dispose();
    targetUserC.dispose();
    targetUserFullNameC.dispose();
    targetUserNewPasswordC.dispose();
    _globalMsgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color surfaceColor = Color(0xFFF8FFF5);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 270,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: const Color(0xFF0A6B1C)),
                  ),
                  Positioned(left: -45, top: -45, child: _bubble(160, 0.09)),
                  Positioned(right: -60, bottom: 60, child: _bubble(200, 0.06)),
                  Positioned(left: -20, bottom: 180, child: _bubble(90, 0.07)),
                  Container(
                    width: 270,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height: 60,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Secretariat',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                Column(
                                  children: [
                                    _buildSidebarItem(
                                      icon: Icons.grid_view_rounded,
                                      label: "Meniu",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = "Meniu";
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.school_rounded,
                                      label: "Elevi",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = 'Elevi';
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.badge_rounded,
                                      label: "Dirigin\u021bi",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = 'Dirigin\u021bi';
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.family_restroom_rounded,
                                      label: "P\u0103rin\u021bi",
                                      onTap: () => setState(() {
                                        activeSidebarLabel =
                                            'P\u0103rin\u021bi';
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.table_chart_rounded,
                                      label: "Clase",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = 'Clase';
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.event_available_rounded,
                                      label: "Vacan\u021be",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = 'Vacan\u021be';
                                      }),
                                    ),
                                    _buildSidebarItem(
                                      icon: Icons.door_front_door_rounded,
                                      label: "Turnichete",
                                      onTap: () => setState(() {
                                        activeSidebarLabel = 'Turnichete';
                                      }),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: _showLogoutDialog,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: Colors.white24,
                                  width: 0.5,
                                ),
                              ),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Deconectare',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
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
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 60,
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(color: const Color(0xFF0A6B1C)),
                        ),
                        Positioned(
                          right: -25,
                          top: -35,
                          child: _bubble(100, 0.07),
                        ),
                        Positioned(
                          right: 120,
                          bottom: -30,
                          child: _bubble(70, 0.05),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child:
                      activeSidebarLabel != 'Meniu'
                      ? _buildEmbeddedPage(activeSidebarLabel)
                      : Container(
                          color: surfaceColor,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(26, 26, 26, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // ── STATISTICI ──────────────────────────
                                if (activeSidebarLabel == 'Meniu') ...[
                                  const SizedBox(height: 12),
                                  _buildStatsRow(),
                                  const SizedBox(height: 36),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: _buildCleanCreateUserCard(),
                                  ),
                                  const SizedBox(height: 36),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 46,
                                    ),
                                    child: IntrinsicHeight(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: _buildGlobalMessagingCard(),
                                          ),
                                          const SizedBox(width: 40),
                                          Expanded(
                                            flex: 1,
                                            child:
                                                _buildClassDistributionCard(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Clean Meniu create-user card ────────────────────────────────────────────
  Widget _buildCleanCreateUserCard() {
    const Color green = Color(0xFF3A7A40);
    const Color darkGreen = Color(0xFF0A6B1C);

    InputDecoration fieldDeco(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF374151), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FFF5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF7AAF5B), width: 2),
      ),
    );

    Widget fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
          letterSpacing: 0.8,
        ),
      ),
    );

    Widget dropdownBox({
      required List<DropdownMenuItem<String>> items,
      required String? value,
      required ValueChanged<String?> onChanged,
      String hint = '',
    }) => Container(
      width: double.infinity,
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFF5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF374151),
          ),
          hint: Text(
            hint,
            style: const TextStyle(color: Color(0xFF374151), fontSize: 14),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );

    return _buildCard(
      title: 'Creează Utilizator Nou',
      primaryGreen: green,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Fields row ──────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldLabel('NUME COMPLET'),
                    TextField(
                      controller: fullNameC,
                      decoration: fieldDeco('Introduceți numele...'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fieldLabel('ROL UTILIZATOR'),
                    dropdownBox(
                      value: role,
                      items: const [
                        DropdownMenuItem(value: 'student', child: Text('Elev')),
                        DropdownMenuItem(
                          value: 'teacher',
                          child: Text('Diriginte'),
                        ),
                        DropdownMenuItem(
                          value: 'parent',
                          child: Text('Părinte'),
                        ),
                        DropdownMenuItem(value: 'gate', child: Text('Turnichet')),
                      ],
                      onChanged: (v) => setState(() {
                        role = v ?? 'student';
                        if (role != 'student' && role != 'teacher') {
                          selectedCreateUserClassId = '';
                        }
                      }),
                    ),
                  ],
                ),
              ),
              // Class (only for student / teacher)
              if (role == 'student' || role == 'teacher') ...[
                const SizedBox(width: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classes')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snap) {
                      final classOptions = snap.hasData
                          ? snap.data!.docs.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return {
                                'id': doc.id,
                                'name': (data['name'] ?? doc.id).toString(),
                              };
                            }).toList()
                          : <Map<String, String>>[];
                      final hasSelected = classOptions.any(
                        (o) => o['id'] == selectedCreateUserClassId,
                      );
                      if (!hasSelected &&
                          selectedCreateUserClassId.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            setState(() => selectedCreateUserClassId = '');
                          }
                        });
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          fieldLabel('CLASĂ'),
                          dropdownBox(
                            value: hasSelected
                                ? selectedCreateUserClassId
                                : null,
                            hint: 'Selectează...',
                            items: classOptions
                                .map(
                                  (o) => DropdownMenuItem<String>(
                                    value: o['id'],
                                    child: Text(o['name']!),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(
                              () => selectedCreateUserClassId = v ?? '',
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // ── Buttons row ─────────────────────────────────────────
          Row(
            children: [
              const Spacer(),
              // Creează Cont Utilizator
              ElevatedButton.icon(
                onPressed: _isActionBusy('create-user-meniu')
                    ? null
                    : () {
                        _runGuarded('create-user-meniu', () async {
                          final full = fullNameC.text.trim();
                          if (full.isEmpty) {
                            _showInfoMessage('Completează numele complet.');
                            return;
                          }
                          if ((role == 'student' || role == 'teacher') &&
                              selectedCreateUserClassId.trim().isEmpty) {
                            _showInfoMessage(
                              'Selectează o clasă pentru elev/profesor.',
                            );
                            return;
                          }

                          final base = _baseFromFullName(full);
                          final uname = '$base${_randDigits(3)}';
                          final pass = _randPassword(10);

                          try {
                            await api.createUser(
                              username: uname.toLowerCase(),
                              password: pass,
                              role: role,
                              fullName: full,
                              classId: (role == 'student' || role == 'teacher')
                                  ? selectedCreateUserClassId
                                  : null,
                            );

                            String? csvPath;
                            try {
                              csvPath = await _appendCreatedUserToCsv(
                                username: uname.toLowerCase(),
                                password: pass,
                                fullName: full,
                                role: role,
                                classId:
                                    (role == 'student' || role == 'teacher')
                                    ? selectedCreateUserClassId
                                    : null,
                              );
                              _logSuccess('CSV actualizat: $csvPath');
                            } catch (csvErr) {
                              _logFailure(
                                'Utilizatorul a fost creat, dar CSV-ul nu a putut fi salvat: $csvErr',
                              );
                            }

                            _logSuccess('Utilizator creat: $uname');
                            if (!mounted) return;
                            setState(() {
                              fullNameC.clear();
                              selectedCreateUserClassId = '';
                            });
                            _showInfoMessage(
                              csvPath == null
                                  ? 'Utilizator creat: $uname. CSV-ul nu a fost actualizat.'
                                  : 'Utilizator creat: $uname. CSV actualizat.',
                            );
                          } catch (e) {
                            final msg = _friendlyCreateUserError(
                              e,
                              role,
                              selectedCreateUserClassId,
                            );
                            _logFailure(msg);
                            _showInfoMessage(msg);
                          }
                        });
                      },
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text('Creează Cont Utilizator'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: darkGreen.withValues(alpha: 0.45),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 22,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required Color primaryGreen,
    required Widget child,
    bool hasBorder = false,
  }) {
    const Color darkGreen = Color(0xFF5A9641);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasBorder ? const Color(0xFFD1D5DB) : const Color(0xFFE5E7EB),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.06),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ColoredBox(
              color: const Color(0xFFF3F7F3),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A6B1C),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(color: Color(0xFFE5E7EB), height: 1, thickness: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF5A8040)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.30)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.green.withValues(alpha: 0.30)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7AAF5B), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color primaryGreen,
    required VoidCallback? onPressed,
    bool fullWidth = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        elevation: 0,
        shadowColor: Colors.transparent,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        disabledBackgroundColor: primaryGreen.withValues(alpha: 0.45),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
        minimumSize: fullWidth ? const Size.fromHeight(52) : const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildEmbeddedPage(String label) {
    switch (label) {
      case 'Clase':
        return const AdminClassesPage(embedded: true);
      case 'Elevi':
        return const AdminStudentsPage(key: ValueKey('students-page-v2'));
      case 'Părinți':
        return const AdminParentsPage();
      case 'Diriginți':
        return const AdminTeachersPage();
      case 'Turnichete':
        return const AdminTurnstilesPage(embedded: true);
      case 'Vacanțe':
        return const admin_vacante.AdminClassesPage(embedded: true);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatsRow() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, classesSnap) {
            final users = usersSnap.data?.docs ?? [];
            final totalElevi = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'student',
                )
                .length;
            final totalDiriginti = users
                .where(
                  (d) =>
                      (d.data() as Map<String, dynamic>)['role'] == 'teacher',
                )
                .length;
            final totalClase = classesSnap.data?.docs.length ?? 0;
            final totalTurnichete = users
                .where(
                  (d) => (d.data() as Map<String, dynamic>)['role'] == 'gate',
                )
                .length;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Row(
                children: [
                  _statCard(
                    icon: Icons.school_rounded,
                    label: 'Total Elevi',
                    value: usersSnap.hasData ? '$totalElevi' : '...',
                  ),
                  const SizedBox(width: 20),
                  _statCard(
                    icon: Icons.badge_rounded,
                    label: 'Total Diriginți',
                    value: usersSnap.hasData ? '$totalDiriginti' : '...',
                  ),
                  const SizedBox(width: 20),
                  _statCard(
                    icon: Icons.door_front_door_rounded,
                    label: 'Turnichete',
                    value: usersSnap.hasData ? '$totalTurnichete' : '...',
                  ),
                  const SizedBox(width: 20),
                  _statCard(
                    icon: Icons.table_chart_rounded,
                    label: 'Total Clase',
                    value: classesSnap.hasData ? '$totalClase' : '...',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<_ClassDistributionItem> _buildClassDistributionItems(
    List<QueryDocumentSnapshot<Object?>> users,
    List<QueryDocumentSnapshot<Object?>> classes,
  ) {
    final Map<String, int> countsByClassId = {};
    for (final userDoc in users) {
      final data = userDoc.data() as Map<String, dynamic>;
      if (data['role'] != 'student') continue;
      final classId = (data['classId'] ?? '').toString().trim();
      if (classId.isEmpty) continue;
      countsByClassId[classId] = (countsByClassId[classId] ?? 0) + 1;
    }

    final List<_ClassDistributionItem> items = classes.map((classDoc) {
      final data = classDoc.data() as Map<String, dynamic>;
      final label = (data['name'] ?? classDoc.id).toString();
      return _ClassDistributionItem(
        label: label,
        count: countsByClassId[classDoc.id] ?? 0,
      );
    }).toList();

    items.sort((a, b) {
      final ai = _classSortIndex(a.label);
      final bi = _classSortIndex(b.label);
      if (ai != bi) return ai.compareTo(bi);
      return a.label.compareTo(b.label);
    });
    return items;
  }

  int _classSortIndex(String rawLabel) {
    final label = rawLabel.toUpperCase().replaceAll('CLASA', '').trim();
    final romanMatch = RegExp(r'(XII|XI|IX|X|VIII|VII|VI|V)').firstMatch(label);
    final roman = romanMatch?.group(0) ?? '';
    switch (roman) {
      case 'V':
        return 5;
      case 'VI':
        return 6;
      case 'VII':
        return 7;
      case 'VIII':
        return 8;
      case 'IX':
        return 9;
      case 'X':
        return 10;
      case 'XI':
        return 11;
      case 'XII':
        return 12;
      default:
        return 99;
    }
  }

  Widget _buildClassDistributionCard() {
    const int perPage = 5;
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, usersSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('classes').snapshots(),
          builder: (context, classesSnap) {
            final users = usersSnap.data?.docs ?? <QueryDocumentSnapshot>[];
            final classes = classesSnap.data?.docs ?? <QueryDocumentSnapshot>[];
            final allItems = _buildClassDistributionItems(users, classes);

            // Sort descending by count
            allItems.sort((a, b) => b.count.compareTo(a.count));

            int maxCount = 1;
            for (final item in allItems) {
              if (item.count > maxCount) maxCount = item.count;
            }

            final totalPages = (allItems.length / perPage).ceil();
            if (_classDistPage >= totalPages && totalPages > 0) {
              _classDistPage = totalPages - 1;
            }
            final start = _classDistPage * perPage;
            final pageItems = allItems.skip(start).take(perPage).toList();

            return Container(
              padding: const EdgeInsets.fromLTRB(30, 12, 30, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F3),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Distribuție pe Clase',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A2E1A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!usersSnap.hasData || !classesSnap.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Se încarcă...',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else if (allItems.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Nu există clase.',
                        style: TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 12,
                        ),
                      ),
                    )
                  else ...[
                    ...pageItems.map((item) {
                      final progress = maxCount == 0
                          ? 0.0
                          : item.count / maxCount;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 13),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF2F3C2F),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${item.count} ELEVI',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2F3C2F),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 7),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 8,
                                value: progress,
                                backgroundColor: const Color(0xFFD9DDD6),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF0A6B1C),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    if (totalPages > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _classDistPageBtn(
                              icon: Icons.chevron_left,
                              onTap: _classDistPage > 0
                                  ? () => setState(() => _classDistPage--)
                                  : null,
                            ),
                            ..._buildClassDistPageButtons(totalPages),
                            _classDistPageBtn(
                              icon: Icons.chevron_right,
                              onTap: _classDistPage < totalPages - 1
                                  ? () => setState(() => _classDistPage++)
                                  : null,
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _classDistPageBtn({required IconData icon, VoidCallback? onTap}) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Icon(
          icon,
          size: 18,
          color: enabled ? const Color(0xFF374151) : const Color(0xFFD1D5DB),
        ),
      ),
    );
  }

  List<Widget> _buildClassDistPageButtons(int totalPages) {
    final List<Widget> buttons = [];
    for (int i = 0; i < totalPages; i++) {
      if (totalPages > 5 &&
          i > 1 &&
          i < totalPages - 1 &&
          (i - _classDistPage).abs() > 1) {
        if (buttons.isNotEmpty && buttons.last is! Text) {
          buttons.add(
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                '...',
                style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
              ),
            ),
          );
        }
        continue;
      }
      final selected = i == _classDistPage;
      buttons.add(
        GestureDetector(
          onTap: () => setState(() => _classDistPage = i),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2D2D2D)
                    : const Color(0xFFD1D5DB),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${i + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      );
    }
    return buttons;
  }

  Future<void> _sendDashboardGlobalMessage() async {
    final message = _globalMsgController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scrie un mesaj înainte de trimitere.')),
      );
      return;
    }
    if (!_msgToStudents && !_msgToParents && !_msgToTeachers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selectează cel puțin un destinatar.')),
      );
      return;
    }
    if (_sendingGlobalMsg) return;
    setState(() => _sendingGlobalMsg = true);

    try {
      final now = Timestamp.now();
      final senderUid = (AppSession.uid ?? '').trim();
      final senderName = (AppSession.fullName ?? 'Secretariat').trim();
      final broadcastId = '${now.millisecondsSinceEpoch}_$senderUid';
      final batch = FirebaseFirestore.instance.batch();

      for (final role in [
        if (_msgToStudents) 'student',
        if (_msgToParents) 'parent',
        if (_msgToTeachers) 'teacher',
      ]) {
        final ref = FirebaseFirestore.instance
            .collection('secretariatMessages')
            .doc('${broadcastId}_$role');
        batch.set(ref, {
          'recipientRole': role,
          'recipientUid': '',
          'studentUid': '',
          'studentUsername': '',
          'studentName': '',
          'classId': '',
          'recipientName': '',
          'recipientUsername': '',
          'message': message,
          'title': 'Mesaj Secretariat',
          'createdAt': now,
          'senderUid': senderUid,
          'senderName': senderName,
          'broadcastId': broadcastId,
          'audienceLabel': role == 'student'
              ? 'Toți elevii'
              : role == 'parent'
              ? 'Toți părinții'
              : 'Toți diriginții',
          'messageType': 'secretariatGlobal',
          'source': 'secretariat',
        });
      }
      await batch.commit();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mesaj global trimis cu succes.')),
      );
      _globalMsgController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare la trimitere: $e')));
    } finally {
      if (mounted) setState(() => _sendingGlobalMsg = false);
    }
  }

  Widget _buildGlobalMessagingCard() {
    return _buildCard(
      title: 'Mesagerie Globală',
      primaryGreen: const Color(0xFF3A7A40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'MESAJ',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _globalMsgController,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Scrie mesajul ce va apărea în inbox...',
              hintStyle: const TextStyle(
                color: Color(0xFF374151),
                fontSize: 14,
              ),
              filled: true,
              fillColor: const Color(0xFFF8FFF5),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF7AAF5B),
                  width: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'DESTINATARI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _msgChip(
                  'Elevi',
                  Icons.school_outlined,
                  _msgToStudents,
                  (v) {
                    setState(() => _msgToStudents = v ?? false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _msgChip(
                  'Părinți',
                  Icons.family_restroom_outlined,
                  _msgToParents,
                  (v) {
                    setState(() => _msgToParents = v ?? false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _msgChip(
                  'Diriginți',
                  Icons.person_outline_rounded,
                  _msgToTeachers,
                  (v) {
                    setState(() => _msgToTeachers = v ?? false);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _sendingGlobalMsg
                    ? null
                    : _sendDashboardGlobalMessage,
                icon: _sendingGlobalMsg
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Trimite Mesaj'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A6B1C),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF0A6B1C),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 48,
                    vertical: 18,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
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

  Widget _msgChip(
    String label,
    IconData icon,
    bool selected,
    ValueChanged<bool?> onChanged,
  ) {
    final Color bg = selected
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFF8FFF5);
    final Color border = selected
        ? const Color(0xFF7AAF5B)
        : const Color(0xFFD1D5DB);
    final Color textColor = selected
        ? const Color(0xFF0A6B1C)
        : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: () => onChanged(!selected),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.check_circle,
                size: 16,
                color: Color(0xFF0A6B1C),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bubble(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7F3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF3A7A40)),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A2E1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final bool selected = label == activeSidebarLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.04),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: selected
                  ? Colors.white.withValues(alpha: 0.17)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.65),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.80),
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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

  Widget _buildGlobalSecurityControls() {
    return StreamBuilder<SecurityFlags>(
      stream: SecurityFlagsService.watch(),
      initialData: SecurityFlags.defaults,
      builder: (context, snapshot) {
        final flags = snapshot.data ?? SecurityFlags.defaults;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FFF1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFCDE8B0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Setări globale securitate',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF3A5C24),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'ON/OFF pentru onboarding și 2FA la nivelul întregii aplicații.',
                style: TextStyle(color: Color(0xFF5A8040), fontSize: 12),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Onboarding global'),
                        Text(
                          flags.onboardingEnabled ? 'Pornit' : 'Oprit',
                          style: TextStyle(
                            fontSize: 12,
                            color: flags.onboardingEnabled
                                ? const Color(0xFF2F5F2B)
                                : const Color(0xFF7C3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    activeTrackColor: const Color(0xFF5A9641),
                    value: flags.onboardingEnabled,
                    onChanged: _isActionBusy('toggle-onboarding-global')
                        ? null
                        : (value) {
                            _runGuarded('toggle-onboarding-global', () async {
                              try {
                                await SecurityFlagsService.setOnboardingEnabled(
                                  value,
                                );
                                _logSuccess(
                                  'Onboarding global ${value ? 'pornit' : 'oprit'}.',
                                );
                                _showInfoMessage(
                                  'Onboarding global ${value ? 'pornit' : 'oprit'}.',
                                );
                              } catch (_) {
                                final message = _friendlyError(
                                  'toggle-onboarding-global',
                                );
                                _logFailure(message);
                                _showInfoMessage(message);
                              }
                            });
                          },
                  ),
                ],
              ),
              const Divider(height: 8, color: Color(0xFFD9EDBB)),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2FA global'),
                        Text(
                          flags.twoFactorEnabled ? 'Pornit' : 'Oprit',
                          style: TextStyle(
                            fontSize: 12,
                            color: flags.twoFactorEnabled
                                ? const Color(0xFF2F5F2B)
                                : const Color(0xFF7C3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    activeTrackColor: const Color(0xFF5A9641),
                    value: flags.twoFactorEnabled,
                    onChanged: _isActionBusy('toggle-2fa-global')
                        ? null
                        : (value) {
                            _runGuarded('toggle-2fa-global', () async {
                              try {
                                await SecurityFlagsService.setTwoFactorEnabled(
                                  value,
                                );
                                _logSuccess(
                                  '2FA global ${value ? 'pornit' : 'oprit'}.',
                                );
                                _showInfoMessage(
                                  '2FA global ${value ? 'pornit' : 'oprit'}.',
                                );
                              } catch (_) {
                                final message = _friendlyError(
                                  'toggle-2fa-global',
                                );
                                _logFailure(message);
                                _showInfoMessage(message);
                              }
                            });
                          },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClassDistributionItem {
  final String label;
  final int count;

  const _ClassDistributionItem({required this.label, required this.count});
}
