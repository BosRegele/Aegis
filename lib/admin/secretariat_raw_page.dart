import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_api.dart';
import 'admin_store.dart';
import 'admin_classes_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_admins_page.dart';
import 'admin_parents_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_schedules_page.dart';
import '../session.dart';

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final api = AdminApi();
  final store = AdminStore();
  String activeSidebarLabel = "";
  bool _sidebarNavigationBusy = false;

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
      case 'save-schedule':
        return 'Orarul nu a putut fi salvat.';
      case 'assign-parent':
        return 'Părintele nu a putut fi atribuit elevului.';
      case 'remove-parent':
        return 'Părintele nu a putut fi eliminat din elev.';
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
    ).showSnackBar(const SnackBar(content: Text("Copiat in clipboard ✅")));
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _openSidebarPage(Widget page) async {
    if (_sidebarNavigationBusy || !mounted) return;
    _sidebarNavigationBusy = true;
    try {
      await Navigator.of(context).push(
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

  void _generateCreds() {
    final full = fullNameC.text.trim();
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
    const Color primaryGreen = Color(0xFF5A9641);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          "Deconectare",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        content: const Text(
          "Esti sigur ca vrei sa fii deconectat?",
          style: TextStyle(fontSize: 16, color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Nu",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text(
              "Da",
              style: TextStyle(
                color: primaryGreen,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color surfaceColor = Color(0xFFF8FFF5);
    final displayName = (AppSession.fullName?.trim().isNotEmpty == true)
        ? AppSession.fullName!.trim()
        : ((AppSession.username?.trim().isNotEmpty == true)
              ? AppSession.username!.trim()
              : "Secretariat");

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF7AAF5B), Color(0xFF5A9641)],
              ),
            ),
          ),
          Positioned(
            top: -140,
            right: -100,
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.14),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -220,
            left: -130,
            child: Container(
              width: 420,
              height: 420,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.10),
                    Colors.black.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 304,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF5C8B42), Color(0xFF40632D)],
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 40,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.20,
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const Icon(
                                            Icons.shield_rounded,
                                            color: Colors.white,
                                            size: 42,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: const [
                                            Text(
                                              "Secretariat",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    "ADMINISTRARE",
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.60,
                                      ),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(26),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    children: [
                                      _buildSidebarItem(
                                        icon: Icons.table_chart,
                                        label: "Clase",
                                        onTap: () => _openSidebarPage(
                                          const AdminClassesPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.people,
                                        label: "Elevi",
                                        onTap: () => _openSidebarPage(
                                          const AdminStudentsPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.family_restroom,
                                        label: "Parinti",
                                        onTap: () => _openSidebarPage(
                                          const AdminParentsPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.person,
                                        label: "Profesori",
                                        onTap: () => _openSidebarPage(
                                          const AdminTeachersPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.admin_panel_settings,
                                        label: "Administratori",
                                        onTap: () => _openSidebarPage(
                                          const AdminAdminsPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.door_front_door,
                                        label: "Turnichete",
                                        onTap: () => _openSidebarPage(
                                          const AdminTurnstilesPage(),
                                        ),
                                      ),
                                      _buildSidebarItem(
                                        icon: Icons.schedule,
                                        label: "Orare",
                                        onTap: () => _openSidebarPage(
                                          const AdminSchedulesPage(),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Tooltip(
                            message: "Deconectare",
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _showLogoutDialog,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                child: Icon(
                                  Icons.logout_rounded,
                                  color: Colors.white.withValues(alpha: 0.82),
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.97),
                            surfaceColor.withValues(alpha: 0.95),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(36),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 32,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(26),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1320),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(28),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF7AAF5B),
                                        Color(0xFF5A9641),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.30,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.20,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(0, 16),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Bun venit, $displayName",
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(height: 10),
                                                const Text(
                                                  "Cele trei valori pe care Colegiul Național de Informatică Tudor Vianu le Încurajează",
                                                  style: TextStyle(
                                                    color: Color(0xFFE5FFF0),
                                                    fontSize: 14,
                                                    height: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 18),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: 0.14,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: Colors.white.withValues(
                                                  alpha: 0.18,
                                                ),
                                              ),
                                            ),
                                            child: const Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  "Misiune",
                                                  style: TextStyle(
                                                    color: Color(0xFFC7F1D8),
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2,
                                                  ),
                                                ),
                                                SizedBox(height: 6),
                                                Text(
                                                  "Tudor Vianu",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        children: const [
                                          _HeaderBadge(
                                            icon: Icons.groups_outlined,
                                            label: "Spiritul de echipă",
                                          ),
                                          _HeaderBadge(
                                            icon: Icons.emoji_events_outlined,
                                            label: "Performanță",
                                          ),
                                          _HeaderBadge(
                                            icon: Icons.military_tech_outlined,
                                            label: "Competiție",
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Left Column
                                    Expanded(
                                      child: Column(
                                        children: [
                                          // Create User Card
                                          _buildCard(
                                            title: "Crează Utilizator",
                                            primaryGreen: primaryGreen,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildTextField(
                                                  controller: fullNameC,
                                                  label: "Nume complet",
                                                ),
                                                const SizedBox(height: 12),
                                                _buildTextField(
                                                  controller: usernameC,
                                                  label: "Utilizator",
                                                ),
                                                const SizedBox(height: 12),
                                                _buildTextField(
                                                  controller: passwordC,
                                                  label: "Parolă",
                                                ),
                                                const SizedBox(height: 12),
                                                Container(
                                                  width: double.infinity,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                      color: Colors.grey[200]!,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: DropdownButtonHideUnderline(
                                                    child:
                                                        DropdownButton<String>(
                                                          value: role,
                                                          isExpanded: true,
                                                          items: const [
                                                            DropdownMenuItem(
                                                              value: "student",
                                                              child: Text(
                                                                "elev",
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "teacher",
                                                              child: Text(
                                                                "profesor",
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "admin",
                                                              child: Text(
                                                                "administrator",
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "parent",
                                                              child: Text(
                                                                "părinte",
                                                              ),
                                                            ),
                                                            DropdownMenuItem(
                                                              value: "gate",
                                                              child: Text(
                                                                "poartă",
                                                              ),
                                                            ),
                                                          ],
                                                          onChanged: (v) =>
                                                              setState(
                                                                () => role =
                                                                    v ??
                                                                    "student",
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                                if (role == "student" ||
                                                    role == "teacher") ...[
                                                  const SizedBox(height: 12),
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore
                                                        .instance
                                                        .collection('classes')
                                                        .orderBy('name')
                                                        .snapshots(),
                                                    builder: (context, snap) {
                                                      if (snap.hasError) {
                                                        return Text(
                                                          "Clasele nu au putut fi încărcate.",
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                        );
                                                      }
                                                      if (!snap.hasData) {
                                                        return const CircularProgressIndicator();
                                                      }

                                                      final docs =
                                                          snap.data!.docs;
                                                      final classOptions = docs.map(
                                                        (doc) {
                                                          final data =
                                                              doc.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >;
                                                          return {
                                                            'id': doc.id,
                                                            'name':
                                                                (data['name'] ??
                                                                        doc.id)
                                                                    .toString(),
                                                          };
                                                        },
                                                      ).toList();

                                                      return Autocomplete<
                                                        Map<String, String>
                                                      >(
                                                        initialValue: TextEditingValue(
                                                          text: classOptions
                                                              .where(
                                                                (option) =>
                                                                    option['id'] ==
                                                                    selectedCreateUserClassId,
                                                              )
                                                              .map(
                                                                (option) =>
                                                                    option['name']!,
                                                              )
                                                              .firstWhere(
                                                                (_) => false,
                                                                orElse: () =>
                                                                    '',
                                                              ),
                                                        ),
                                                        optionsBuilder:
                                                            (
                                                              TextEditingValue
                                                              textEditingValue,
                                                            ) {
                                                              if (textEditingValue
                                                                  .text
                                                                  .isEmpty) {
                                                                return classOptions;
                                                              }
                                                              return classOptions
                                                                  .where(
                                                                    (
                                                                      option,
                                                                    ) => option['name']!
                                                                        .toLowerCase()
                                                                        .contains(
                                                                          textEditingValue
                                                                              .text
                                                                              .toLowerCase(),
                                                                        ),
                                                                  )
                                                                  .toList();
                                                            },
                                                        displayStringForOption:
                                                            (option) =>
                                                                option['name']!,
                                                        fieldViewBuilder:
                                                            (
                                                              context,
                                                              textEditingController,
                                                              focusNode,
                                                              onFieldSubmitted,
                                                            ) {
                                                              return TextFormField(
                                                                controller:
                                                                    textEditingController,
                                                                focusNode:
                                                                    focusNode,
                                                                decoration: InputDecoration(
                                                                  labelText:
                                                                      "Selecteaza clasa",
                                                                  hintText:
                                                                      "Scrie pentru a cauta clase...",
                                                                  border: OutlineInputBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
                                                                        ),
                                                                  ),
                                                                  filled: true,
                                                                  fillColor: Colors
                                                                      .grey[50],
                                                                ),
                                                              );
                                                            },
                                                        optionsViewBuilder:
                                                            (
                                                              context,
                                                              onSelected,
                                                              options,
                                                            ) {
                                                              return Align(
                                                                alignment:
                                                                    Alignment
                                                                        .topLeft,
                                                                child: Material(
                                                                  elevation:
                                                                      4.0,
                                                                  child: Container(
                                                                    width:
                                                                        MediaQuery.of(
                                                                          context,
                                                                        ).size.width *
                                                                        0.3,
                                                                    constraints:
                                                                        const BoxConstraints(
                                                                          maxHeight:
                                                                              200,
                                                                        ),
                                                                    child: ListView.builder(
                                                                      padding:
                                                                          EdgeInsets
                                                                              .zero,
                                                                      shrinkWrap:
                                                                          true,
                                                                      itemCount:
                                                                          options
                                                                              .length,
                                                                      itemBuilder:
                                                                          (
                                                                            context,
                                                                            index,
                                                                          ) {
                                                                            final option = options.elementAt(
                                                                              index,
                                                                            );
                                                                            return ListTile(
                                                                              title: Text(
                                                                                option['name']!,
                                                                              ),
                                                                              onTap: () => onSelected(
                                                                                option,
                                                                              ),
                                                                            );
                                                                          },
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                        onSelected: (option) {
                                                          setState(() {
                                                            selectedCreateUserClassId =
                                                                option['id']!;
                                                          });
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ],
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: "Generează",
                                                        primaryGreen:
                                                            primaryGreen,
                                                        onPressed:
                                                            _generateCreds,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: "Copiază",
                                                        primaryGreen:
                                                            primaryGreen,
                                                        onPressed: () {
                                                          _copy(
                                                            "username: ${usernameC.text}\npassword: ${passwordC.text}",
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                // create user button
                                                _buildButton(
                                                  label: "Crează utilizator",
                                                  primaryGreen: primaryGreen,
                                                  fullWidth: true,
                                                  onPressed:
                                                      _isActionBusy(
                                                        'create-user',
                                                      )
                                                      ? null
                                                      : () {
                                                          _runGuarded('create-user', () async {
                                                            final uname =
                                                                usernameC.text
                                                                    .trim();
                                                            final pass =
                                                                passwordC.text;
                                                            final full =
                                                                fullNameC.text
                                                                    .trim();

                                                            // Basic client-side validation to avoid cloud failures
                                                            if (full.isEmpty) {
                                                              _logFailure(
                                                                'Completează numele complet.',
                                                              );
                                                              _showInfoMessage(
                                                                'Completează numele complet.',
                                                              );
                                                              return;
                                                            }
                                                            if (uname.isEmpty) {
                                                              _logFailure(
                                                                'Completează username-ul.',
                                                              );
                                                              _showInfoMessage(
                                                                'Completează username-ul.',
                                                              );
                                                              return;
                                                            }
                                                            if (uname.contains(
                                                              RegExp(r'\s'),
                                                            )) {
                                                              _logFailure(
                                                                'Username-ul nu poate conține spații.',
                                                              );
                                                              _showInfoMessage(
                                                                'Username-ul nu poate conține spații.',
                                                              );
                                                              return;
                                                            }
                                                            if (pass.length <
                                                                6) {
                                                              _logFailure(
                                                                'Parola trebuie să aibă cel puțin 6 caractere.',
                                                              );
                                                              _showInfoMessage(
                                                                'Parola trebuie să aibă cel puțin 6 caractere.',
                                                              );
                                                              return;
                                                            }
                                                            if ((role ==
                                                                        'teacher' ||
                                                                    role ==
                                                                        'student') &&
                                                                selectedCreateUserClassId
                                                                    .trim()
                                                                    .isEmpty) {
                                                              _logFailure(
                                                                'Selectează o clasă pentru elev/profesor.',
                                                              );
                                                              _showInfoMessage(
                                                                'Selectează o clasă pentru elev/profesor.',
                                                              );
                                                              return;
                                                            }

                                                            try {
                                                              // cloud function
                                                              await api.createUser(
                                                                username: uname
                                                                    .toLowerCase(),
                                                                password: pass,
                                                                role: role,
                                                                fullName: full,
                                                                classId:
                                                                    role ==
                                                                            "student" ||
                                                                        role ==
                                                                            "teacher"
                                                                    ? selectedCreateUserClassId
                                                                    : null,
                                                              );

                                                              _logSuccess(
                                                                'Utilizator creat: $uname',
                                                              );

                                                              if (!mounted)
                                                                return;
                                                              _showInfoMessage(
                                                                "Utilizator creat: $uname",
                                                              );
                                                            } catch (e) {
                                                              final message =
                                                                  _friendlyCreateUserError(
                                                                    e,
                                                                    role,
                                                                    selectedCreateUserClassId,
                                                                  );
                                                              _logFailure(
                                                                message,
                                                              );
                                                              _showInfoMessage(
                                                                message,
                                                              );
                                                            }
                                                          });
                                                        },
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          // Create Class Card
                                          _buildCard(
                                            title: "Creeaza Clasa",
                                            primaryGreen: primaryGreen,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey[200]!,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: DropdownButtonHideUnderline(
                                                          child: DropdownButton<int>(
                                                            value:
                                                                selectedNumber,
                                                            isExpanded: true,
                                                            items:
                                                                List.generate(
                                                                  12,
                                                                  (i) => i + 1,
                                                                ).map((num) {
                                                                  return DropdownMenuItem(
                                                                    value: num,
                                                                    child: Text(
                                                                      num.toString(),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                            onChanged: (v) =>
                                                                setState(
                                                                  () =>
                                                                      selectedNumber =
                                                                          v ??
                                                                          9,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          border: Border.all(
                                                            color: Colors
                                                                .grey[200]!,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: DropdownButtonHideUnderline(
                                                          child: DropdownButton<String>(
                                                            value:
                                                                selectedLetter,
                                                            isExpanded: true,
                                                            items:
                                                                List.generate(
                                                                  26,
                                                                  (i) =>
                                                                      String.fromCharCode(
                                                                        65 + i,
                                                                      ),
                                                                ).map((letter) {
                                                                  return DropdownMenuItem(
                                                                    value:
                                                                        letter,
                                                                    child: Text(
                                                                      letter,
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                            onChanged: (v) =>
                                                                setState(
                                                                  () =>
                                                                      selectedLetter =
                                                                          v ??
                                                                          "A",
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildButton(
                                                        label:
                                                            "Creeaza/Actualizeaza",
                                                        primaryGreen:
                                                            primaryGreen,
                                                        onPressed:
                                                            _isActionBusy(
                                                              'create-class',
                                                            )
                                                            ? null
                                                            : () {
                                                                _runGuarded(
                                                                  'create-class',
                                                                  () async {
                                                                    final classId =
                                                                        "$selectedNumber$selectedLetter";
                                                                    final existingClass = await FirebaseFirestore
                                                                        .instance
                                                                        .collection(
                                                                          'classes',
                                                                        )
                                                                        .doc(
                                                                          classId,
                                                                        )
                                                                        .get();
                                                                    if (existingClass
                                                                        .exists) {
                                                                      final message =
                                                                          'Clasa $classId există deja.';
                                                                      _logFailure(
                                                                        message,
                                                                      );
                                                                      _showInfoMessage(
                                                                        message,
                                                                      );
                                                                      return;
                                                                    }
                                                                    try {
                                                                      await api.createClass(
                                                                        name:
                                                                            classId,
                                                                      );
                                                                      _logSuccess(
                                                                        'Clasă creată: $classId',
                                                                      );
                                                                      if (!mounted) {
                                                                        return;
                                                                      }
                                                                      _showInfoMessage(
                                                                        "Clasă creată: $classId",
                                                                      );
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      final message =
                                                                          _friendlyCreateClassError(
                                                                            e,
                                                                            classId,
                                                                          );
                                                                      _logFailure(
                                                                        message,
                                                                      );
                                                                      _showInfoMessage(
                                                                        message,
                                                                      );
                                                                    }
                                                                  },
                                                                );
                                                              },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: "Sterge",
                                                        primaryGreen:
                                                            Colors.red.shade600,
                                                        onPressed:
                                                            _isActionBusy(
                                                              'delete-class',
                                                            )
                                                            ? null
                                                            : () {
                                                                _runGuarded(
                                                                  'delete-class',
                                                                  () async {
                                                                    final shouldProceed = await _confirmMajorAction(
                                                                      title:
                                                                          'Confirmare',
                                                                      message:
                                                                          'Esti sigur ca vrei sa stergi clasa selectata?',
                                                                    );
                                                                    if (!shouldProceed) {
                                                                      return;
                                                                    }

                                                                    final classId =
                                                                        "$selectedNumber$selectedLetter";
                                                                    try {
                                                                      await api.deleteClassCascade(
                                                                        classId:
                                                                            classId,
                                                                      );
                                                                      _logSuccess(
                                                                        'Clasă ștearsă: $classId',
                                                                      );
                                                                      _showInfoMessage(
                                                                        'Clasa a fost ștearsă.',
                                                                      );
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      final message =
                                                                          _friendlyError(
                                                                            'delete-class',
                                                                          );
                                                                      _logFailure(
                                                                        message,
                                                                      );
                                                                      _showInfoMessage(
                                                                        message,
                                                                      );
                                                                    }
                                                                  },
                                                                );
                                                              },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          // Assign Parents Card
                                          _buildCard(
                                            title: "Atribuie Parinti",
                                            primaryGreen: primaryGreen,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text("Selecteaza elev:"),
                                                const SizedBox(height: 8),
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .where(
                                                        'role',
                                                        isEqualTo: 'student',
                                                      )
                                                      .snapshots(),
                                                  builder: (context, ssnap) {
                                                    if (ssnap.hasError) {
                                                      return Text(
                                                        'Lista elevilor nu a putut fi încărcată.',
                                                      );
                                                    }
                                                    if (!ssnap.hasData) {
                                                      return const CircularProgressIndicator();
                                                    }

                                                    final studentOptions = ssnap
                                                        .data!
                                                        .docs
                                                        .map((d) {
                                                          final data =
                                                              d.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >;
                                                          final name =
                                                              (data['fullName'] ??
                                                                      data['username'] ??
                                                                      d.id)
                                                                  .toString();
                                                          return {
                                                            'id': d.id,
                                                            'name': name,
                                                          };
                                                        })
                                                        .toList();

                                                    studentOptions.sort(
                                                      (a, b) => a['name']!
                                                          .toLowerCase()
                                                          .compareTo(
                                                            b['name']!
                                                                .toLowerCase(),
                                                          ),
                                                    );

                                                    return Autocomplete<
                                                      Map<String, String>
                                                    >(
                                                      optionsBuilder: (txt) {
                                                        if (txt.text.isEmpty) {
                                                          return studentOptions;
                                                        }
                                                        return studentOptions.where(
                                                          (o) => o['name']!
                                                              .toLowerCase()
                                                              .contains(
                                                                txt.text
                                                                    .toLowerCase(),
                                                              ),
                                                        );
                                                      },
                                                      displayStringForOption:
                                                          (o) => o['name']!,
                                                      onSelected: (o) => setState(
                                                        () {
                                                          selectedAssignStudent =
                                                              o;
                                                          selectedAssignParent =
                                                              null;
                                                        },
                                                      ),
                                                      fieldViewBuilder:
                                                          (
                                                            context,
                                                            ctrl,
                                                            focusNode,
                                                            onSubmit,
                                                          ) {
                                                            ctrl.text =
                                                                selectedAssignStudent?['name'] ??
                                                                '';
                                                            return TextField(
                                                              controller: ctrl,
                                                              focusNode:
                                                                  focusNode,
                                                              decoration:
                                                                  const InputDecoration(
                                                                    hintText:
                                                                        'Numele studentului...',
                                                                  ),
                                                            );
                                                          },
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                if (selectedAssignStudent !=
                                                    null) ...[
                                                  const Text(
                                                    "Parintii actuali:",
                                                  ),
                                                  const SizedBox(height: 8),
                                                  StreamBuilder<
                                                    DocumentSnapshot
                                                  >(
                                                    stream: FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(
                                                          selectedAssignStudent!['id'],
                                                        )
                                                        .snapshots(),
                                                    builder: (context, snap) {
                                                      if (snap.hasError) {
                                                        return Text(
                                                          'Datele elevului nu au putut fi încărcate.',
                                                        );
                                                      }
                                                      if (!snap.hasData) {
                                                        return const CircularProgressIndicator();
                                                      }
                                                      final data =
                                                          snap.data!.data()
                                                              as Map<
                                                                String,
                                                                dynamic
                                                              >? ??
                                                          {};
                                                      final parents =
                                                          List<String>.from(
                                                            data['parents'] ??
                                                                [],
                                                          );

                                                      if (parents.isEmpty) {
                                                        return const Text(
                                                          'Niciun părinte asignat',
                                                        );
                                                      }

                                                      return Column(
                                                        children: parents.map((
                                                          puid,
                                                        ) {
                                                          return FutureBuilder<
                                                            DocumentSnapshot
                                                          >(
                                                            future:
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'users',
                                                                    )
                                                                    .doc(puid)
                                                                    .get(),
                                                            builder: (context, psnap) {
                                                              if (!psnap
                                                                  .hasData) {
                                                                return const SizedBox.shrink();
                                                              }
                                                              final pdata =
                                                                  psnap.data!
                                                                          .data()
                                                                      as Map<
                                                                        String,
                                                                        dynamic
                                                                      >? ??
                                                                  {};
                                                              final pname =
                                                                  (pdata['fullName'] ??
                                                                          pdata['username'] ??
                                                                          psnap
                                                                              .data!
                                                                              .id)
                                                                      .toString();
                                                              return ListTile(
                                                                title: Text(
                                                                  pname,
                                                                ),
                                                                subtitle: Text(
                                                                  'uid: $puid',
                                                                ),
                                                                trailing: IconButton(
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .remove_circle,
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                  onPressed:
                                                                      _isActionBusy(
                                                                        'remove-parent-$puid',
                                                                      )
                                                                      ? null
                                                                      : () {
                                                                          _runGuarded(
                                                                            'remove-parent-$puid',
                                                                            () async {
                                                                              final confirm =
                                                                                  await showDialog<
                                                                                    bool
                                                                                  >(
                                                                                    context: context,
                                                                                    builder:
                                                                                        (
                                                                                          _,
                                                                                        ) => AlertDialog(
                                                                                          title: const Text(
                                                                                            'Confirm',
                                                                                          ),
                                                                                          content: Text(
                                                                                            'Sunteți sigur că vreți să scoateți părintele $pname din elevul ${selectedAssignStudent!['name']}?',
                                                                                          ),
                                                                                          actions: [
                                                                                            TextButton(
                                                                                              onPressed: () => Navigator.pop(
                                                                                                context,
                                                                                                false,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                'Nu',
                                                                                              ),
                                                                                            ),
                                                                                            TextButton(
                                                                                              onPressed: () => Navigator.pop(
                                                                                                context,
                                                                                                true,
                                                                                              ),
                                                                                              child: const Text(
                                                                                                'Da',
                                                                                              ),
                                                                                            ),
                                                                                          ],
                                                                                        ),
                                                                                  );
                                                                              if (confirm !=
                                                                                  true) {
                                                                                return;
                                                                              }
                                                                              try {
                                                                                await api.removeParentFromStudent(
                                                                                  studentUid: selectedAssignStudent!['id']!,
                                                                                  parentUid: puid,
                                                                                );
                                                                                _logSuccess(
                                                                                  'Părinte eliminat din elev cu succes.',
                                                                                );
                                                                                _showInfoMessage(
                                                                                  'Părintele a fost eliminat cu succes.',
                                                                                );
                                                                              } catch (
                                                                                e
                                                                              ) {
                                                                                final message = _friendlyError(
                                                                                  'remove-parent',
                                                                                );
                                                                                _logFailure(
                                                                                  message,
                                                                                );
                                                                                _showInfoMessage(
                                                                                  message,
                                                                                );
                                                                              }
                                                                            },
                                                                          );
                                                                        },
                                                                ),
                                                              );
                                                            },
                                                          );
                                                        }).toList(),
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 12),
                                                  const Text(
                                                    'Select parent to assign:',
                                                  ),
                                                  const SizedBox(height: 8),
                                                  StreamBuilder<QuerySnapshot>(
                                                    stream: FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .where(
                                                          'role',
                                                          isEqualTo: 'parent',
                                                        )
                                                        .snapshots(),
                                                    builder: (context, psnap) {
                                                      if (psnap.hasError) {
                                                        return Text(
                                                          'Lista părinților nu a putut fi încărcată.',
                                                        );
                                                      }
                                                      if (!psnap.hasData) {
                                                        return const CircularProgressIndicator();
                                                      }
                                                      final popts = psnap
                                                          .data!
                                                          .docs
                                                          .map((d) {
                                                            final data =
                                                                d.data()
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >;
                                                            final name =
                                                                (data['fullName'] ??
                                                                        data['username'] ??
                                                                        d.id)
                                                                    .toString();
                                                            return {
                                                              'id': d.id,
                                                              'name': name,
                                                            };
                                                          })
                                                          .toList();

                                                      popts.sort(
                                                        (a, b) => a['name']!
                                                            .toLowerCase()
                                                            .compareTo(
                                                              b['name']!
                                                                  .toLowerCase(),
                                                            ),
                                                      );

                                                      return Autocomplete<
                                                        Map<String, String>
                                                      >(
                                                        optionsBuilder: (txt) {
                                                          if (txt
                                                              .text
                                                              .isEmpty) {
                                                            return popts;
                                                          }
                                                          return popts.where(
                                                            (o) => o['name']!
                                                                .toLowerCase()
                                                                .contains(
                                                                  txt.text
                                                                      .toLowerCase(),
                                                                ),
                                                          );
                                                        },
                                                        displayStringForOption:
                                                            (o) => o['name']!,
                                                        onSelected: (o) => setState(
                                                          () =>
                                                              selectedAssignParent =
                                                                  o,
                                                        ),
                                                        fieldViewBuilder:
                                                            (
                                                              context,
                                                              ctrl,
                                                              focusNode,
                                                              onSubmit,
                                                            ) {
                                                              ctrl.text =
                                                                  selectedAssignParent?['name'] ??
                                                                  '';
                                                              return TextField(
                                                                controller:
                                                                    ctrl,
                                                                focusNode:
                                                                    focusNode,
                                                                decoration:
                                                                    const InputDecoration(
                                                                      hintText:
                                                                          'Numele părintelui...',
                                                                    ),
                                                              );
                                                            },
                                                      );
                                                    },
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: ElevatedButton(
                                                          onPressed:
                                                              selectedAssignParent ==
                                                                      null ||
                                                                  _isActionBusy(
                                                                    'assign-parent',
                                                                  )
                                                              ? null
                                                              : () {
                                                                  _runGuarded(
                                                                    'assign-parent',
                                                                    () async {
                                                                      final sp =
                                                                          selectedAssignStudent!['id'];
                                                                      final pp =
                                                                          selectedAssignParent!['id'];
                                                                      try {
                                                                        final stuRef = FirebaseFirestore
                                                                            .instance
                                                                            .collection(
                                                                              'users',
                                                                            )
                                                                            .doc(
                                                                              sp,
                                                                            );
                                                                        final stuSnap =
                                                                            await stuRef.get();
                                                                        final stuData =
                                                                            stuSnap.data() ??
                                                                            {};
                                                                        final parents =
                                                                            List<
                                                                              String
                                                                            >.from(
                                                                              stuData['parents'] ??
                                                                                  [],
                                                                            );
                                                                        if (parents
                                                                            .contains(
                                                                              pp,
                                                                            )) {
                                                                          _logFailure(
                                                                            'Părintele este deja atribuit acestui elev.',
                                                                          );
                                                                          _showInfoMessage(
                                                                            'Părintele este deja atribuit acestui elev.',
                                                                          );
                                                                          return;
                                                                        }
                                                                        if (parents.length >=
                                                                            2) {
                                                                          _logFailure(
                                                                            'Elevul are deja 2 părinți atribuiți.',
                                                                          );
                                                                          _showInfoMessage(
                                                                            'Elevul are deja 2 părinți atribuiți.',
                                                                          );
                                                                          return;
                                                                        }
                                                                        await api.assignParentToStudent(
                                                                          studentUid:
                                                                              sp!,
                                                                          parentUid:
                                                                              pp!,
                                                                        );
                                                                        _logSuccess(
                                                                          'Părinte atribuit elevului cu succes.',
                                                                        );
                                                                        _showInfoMessage(
                                                                          'Părintele a fost atribuit cu succes.',
                                                                        );
                                                                      } catch (
                                                                        e
                                                                      ) {
                                                                        final message =
                                                                            _friendlyError(
                                                                              'assign-parent',
                                                                            );
                                                                        _logFailure(
                                                                          message,
                                                                        );
                                                                        _showInfoMessage(
                                                                          message,
                                                                        );
                                                                      }
                                                                    },
                                                                  );
                                                                },
                                                          child:
                                                              _isActionBusy(
                                                                'assign-parent',
                                                              )
                                                              ? const SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                                )
                                                              : const Text(
                                                                  'Assign parent',
                                                                ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          // Log Section (moved here)
                                          _buildCard(
                                            title: "Log",
                                            primaryGreen: primaryGreen,
                                            hasBorder: false,
                                            child: Container(
                                              width: double.infinity,
                                              height: 200,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[50],
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.grey[200]!,
                                                ),
                                              ),
                                              padding: const EdgeInsets.all(12),
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  log.isEmpty ? "(empty)" : log,
                                                  style: const TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24),
                                    // Right Column
                                    Expanded(
                                      child: Column(
                                        children: [
                                          // Reset / Disable Card
                                          _buildCard(
                                            title:
                                                "Resetează / Dezactivează cont",
                                            primaryGreen: primaryGreen,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                _buildTextField(
                                                  controller: targetUserC,
                                                  label:
                                                      "Nume utilizator țintă",
                                                ),
                                                const SizedBox(height: 16),
                                                _buildButton(
                                                  label: "Resetare Parolă",
                                                  primaryGreen: primaryGreen,
                                                  onPressed:
                                                      _isActionBusy(
                                                        'reset-password',
                                                      )
                                                      ? null
                                                      : () {
                                                          _runGuarded('reset-password', () async {
                                                            final shouldProceed =
                                                                await _confirmMajorAction(
                                                                  title:
                                                                      'Confirmare',
                                                                  message:
                                                                      'Esti sigur ca vrei sa resetezi parola utilizatorului?',
                                                                );
                                                            if (!shouldProceed) {
                                                              return;
                                                            }
                                                            if (targetUserC.text
                                                                .trim()
                                                                .isEmpty) {
                                                              _showInfoMessage(
                                                                'Completează utilizatorul țintă.',
                                                              );
                                                              return;
                                                            }

                                                            try {
                                                              final res = await api
                                                                  .resetPassword(
                                                                    username:
                                                                        targetUserC
                                                                            .text,
                                                                  );
                                                              final newPass =
                                                                  res['password'];
                                                              _logSuccess(
                                                                'Parola a fost resetată cu succes.',
                                                              );
                                                              if (!mounted)
                                                                return;
                                                              _showInfoMessage(
                                                                "Parola nouă: $newPass",
                                                              );
                                                            } catch (e) {
                                                              final message =
                                                                  _friendlyError(
                                                                    'reset-password',
                                                                  );
                                                              _logFailure(
                                                                message,
                                                              );
                                                              _showInfoMessage(
                                                                message,
                                                              );
                                                            }
                                                          });
                                                        },
                                                  fullWidth: true,
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: "Dezactiveaza",
                                                        primaryGreen:
                                                            primaryGreen,
                                                        onPressed:
                                                            _isActionBusy(
                                                              'disable-user',
                                                            )
                                                            ? null
                                                            : () {
                                                                _runGuarded(
                                                                  'disable-user',
                                                                  () async {
                                                                    final shouldProceed = await _confirmMajorAction(
                                                                      title:
                                                                          'Confirmare',
                                                                      message:
                                                                          'Esti sigur ca vrei sa dezactivezi contul?',
                                                                    );
                                                                    if (!shouldProceed) {
                                                                      return;
                                                                    }
                                                                    if (targetUserC
                                                                        .text
                                                                        .trim()
                                                                        .isEmpty) {
                                                                      _showInfoMessage(
                                                                        'Completează utilizatorul țintă.',
                                                                      );
                                                                      return;
                                                                    }

                                                                    try {
                                                                      final res = await api.setDisabled(
                                                                        username:
                                                                            targetUserC.text,
                                                                        disabled:
                                                                            true,
                                                                      );
                                                                      final changed =
                                                                          res['changed'] ==
                                                                          true;
                                                                      final message =
                                                                          changed
                                                                          ? 'Contul a fost dezactivat.'
                                                                          : 'Contul era deja dezactivat.';
                                                                      _logSuccess(
                                                                        message,
                                                                      );
                                                                      _showInfoMessage(
                                                                        message,
                                                                      );
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      final message =
                                                                          _friendlyError(
                                                                            'disable-user',
                                                                          );
                                                                      _logFailure(
                                                                        message,
                                                                      );
                                                                      _showInfoMessage(
                                                                        message,
                                                                      );
                                                                    }
                                                                  },
                                                                );
                                                              },
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: _buildButton(
                                                        label: "Activeaza",
                                                        primaryGreen:
                                                            primaryGreen,
                                                        onPressed:
                                                            _isActionBusy(
                                                              'enable-user',
                                                            )
                                                            ? null
                                                            : () {
                                                                _runGuarded('enable-user', () async {
                                                                  final shouldProceed =
                                                                      await _confirmMajorAction(
                                                                        title:
                                                                            'Confirmare',
                                                                        message:
                                                                            'Esti sigur ca vrei sa activezi contul?',
                                                                      );
                                                                  if (!shouldProceed) {
                                                                    return;
                                                                  }
                                                                  if (targetUserC
                                                                      .text
                                                                      .trim()
                                                                      .isEmpty) {
                                                                    _showInfoMessage(
                                                                      'Completează utilizatorul țintă.',
                                                                    );
                                                                    return;
                                                                  }

                                                                  try {
                                                                    final res = await api.setDisabled(
                                                                      username:
                                                                          targetUserC
                                                                              .text,
                                                                      disabled:
                                                                          false,
                                                                    );
                                                                    final changed =
                                                                        res['changed'] ==
                                                                        true;
                                                                    final message =
                                                                        changed
                                                                        ? 'Contul a fost activat.'
                                                                        : 'Contul era deja activ.';
                                                                    _logSuccess(
                                                                      message,
                                                                    );
                                                                    _showInfoMessage(
                                                                      message,
                                                                    );
                                                                  } catch (e) {
                                                                    final message =
                                                                        _friendlyError(
                                                                          'enable-user',
                                                                        );
                                                                    _logFailure(
                                                                      message,
                                                                    );
                                                                    _showInfoMessage(
                                                                      message,
                                                                    );
                                                                  }
                                                                });
                                                              },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 16),
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: FirebaseFirestore
                                                      .instance
                                                      .collection('classes')
                                                      .orderBy('name')
                                                      .snapshots(),
                                                  builder: (context, snap) {
                                                    if (snap.hasError) {
                                                      return Text(
                                                        "Clasele nu au putut fi încărcate.",
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                    if (!snap.hasData) {
                                                      return const CircularProgressIndicator();
                                                    }

                                                    final docs =
                                                        snap.data!.docs;
                                                    final classOptions = docs
                                                        .map((doc) {
                                                          final data =
                                                              doc.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >;
                                                          return {
                                                            'id': doc.id,
                                                            'name':
                                                                (data['name'] ??
                                                                        doc.id)
                                                                    .toString(),
                                                          };
                                                        })
                                                        .toList();

                                                    return Autocomplete<
                                                      Map<String, String>
                                                    >(
                                                      initialValue: TextEditingValue(
                                                        text: classOptions
                                                            .where(
                                                              (option) =>
                                                                  option['id'] ==
                                                                  selectedMoveClassId,
                                                            )
                                                            .map(
                                                              (option) =>
                                                                  option['name']!,
                                                            )
                                                            .firstWhere(
                                                              (_) => false,
                                                              orElse: () => '',
                                                            ),
                                                      ),
                                                      optionsBuilder:
                                                          (
                                                            TextEditingValue
                                                            textEditingValue,
                                                          ) {
                                                            if (textEditingValue
                                                                .text
                                                                .isEmpty) {
                                                              return classOptions;
                                                            }
                                                            return classOptions
                                                                .where(
                                                                  (
                                                                    option,
                                                                  ) => option['name']!
                                                                      .toLowerCase()
                                                                      .contains(
                                                                        textEditingValue
                                                                            .text
                                                                            .toLowerCase(),
                                                                      ),
                                                                )
                                                                .toList();
                                                          },
                                                      displayStringForOption:
                                                          (option) =>
                                                              option['name']!,
                                                      fieldViewBuilder:
                                                          (
                                                            context,
                                                            textEditingController,
                                                            focusNode,
                                                            onFieldSubmitted,
                                                          ) {
                                                            return TextFormField(
                                                              controller:
                                                                  textEditingController,
                                                              focusNode:
                                                                  focusNode,
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    "Selecteaza clasa",
                                                                hintText:
                                                                    "Scrie pentru a cauta clase...",
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        6,
                                                                      ),
                                                                ),
                                                                filled: true,
                                                                fillColor: Colors
                                                                    .grey[50],
                                                              ),
                                                            );
                                                          },
                                                      optionsViewBuilder:
                                                          (
                                                            context,
                                                            onSelected,
                                                            options,
                                                          ) {
                                                            return Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topLeft,
                                                              child: Material(
                                                                elevation: 4.0,
                                                                child: Container(
                                                                  width:
                                                                      MediaQuery.of(
                                                                        context,
                                                                      ).size.width *
                                                                      0.3,
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxHeight:
                                                                            200,
                                                                      ),
                                                                  child: ListView.builder(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        options
                                                                            .length,
                                                                    itemBuilder:
                                                                        (
                                                                          context,
                                                                          index,
                                                                        ) {
                                                                          final option = options.elementAt(
                                                                            index,
                                                                          );
                                                                          return ListTile(
                                                                            title: Text(
                                                                              option['name']!,
                                                                            ),
                                                                            onTap: () => onSelected(
                                                                              option,
                                                                            ),
                                                                          );
                                                                        },
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                      onSelected: (option) {
                                                        setState(() {
                                                          selectedMoveClassId =
                                                              option['id']!;
                                                        });
                                                      },
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 12),
                                                _buildButton(
                                                  label: "Mută utilizator",
                                                  primaryGreen: primaryGreen,
                                                  onPressed:
                                                      _isActionBusy('move-user')
                                                      ? null
                                                      : () {
                                                          _runGuarded('move-user', () async {
                                                            if (targetUserC.text
                                                                    .trim()
                                                                    .isEmpty ||
                                                                selectedMoveClassId
                                                                    .trim()
                                                                    .isEmpty) {
                                                              _logFailure(
                                                                'Completează utilizatorul și clasa pentru mutare.',
                                                              );
                                                              _showInfoMessage(
                                                                'Completează utilizatorul și clasa pentru mutare.',
                                                              );
                                                              return;
                                                            }
                                                            try {
                                                              await api.moveStudentClass(
                                                                username:
                                                                    targetUserC
                                                                        .text,
                                                                newClassId:
                                                                    selectedMoveClassId,
                                                              );
                                                              _logSuccess(
                                                                'Utilizator mutat la clasa selectată.',
                                                              );
                                                              _showInfoMessage(
                                                                'Utilizatorul a fost mutat cu succes.',
                                                              );
                                                            } catch (e) {
                                                              final message =
                                                                  _friendlyMoveUserError(
                                                                    e,
                                                                    selectedMoveClassId,
                                                                  );
                                                              _logFailure(
                                                                message,
                                                              );
                                                              _showInfoMessage(
                                                                message,
                                                              );
                                                            }
                                                          });
                                                        },
                                                  fullWidth: true,
                                                ),
                                                const SizedBox(height: 12),
                                                // delete user button
                                                _buildButton(
                                                  label: "Sterge utilizator",
                                                  primaryGreen:
                                                      Colors.red[600]!,
                                                  onPressed:
                                                      _isActionBusy(
                                                        'delete-user',
                                                      )
                                                      ? null
                                                      : () {
                                                          _runGuarded('delete-user', () async {
                                                            final shouldProceed =
                                                                await _confirmMajorAction(
                                                                  title:
                                                                      'Confirmare',
                                                                  message:
                                                                      'Esti sigur ca vrei sa stergi utilizatorul selectat?',
                                                                );
                                                            if (!shouldProceed)
                                                              return;

                                                            final uname =
                                                                targetUserC.text
                                                                    .trim()
                                                                    .toLowerCase();
                                                            if (uname.isEmpty) {
                                                              _logFailure(
                                                                'Completează username-ul utilizatorului de șters.',
                                                              );
                                                              _showInfoMessage(
                                                                'Completează username-ul utilizatorului de șters.',
                                                              );
                                                              return;
                                                            }
                                                            bool deleted =
                                                                false;
                                                            try {
                                                              // try cloud function first
                                                              await api
                                                                  .deleteUser(
                                                                    username:
                                                                        uname,
                                                                  );
                                                              deleted = true;
                                                            } catch (e) {
                                                              // fallback below
                                                            }
                                                            if (!deleted) {
                                                              try {
                                                                await store
                                                                    .deleteUser(
                                                                      uname,
                                                                    );
                                                                deleted = true;
                                                              } catch (e) {
                                                                // handled below
                                                              }
                                                            }

                                                            if (deleted) {
                                                              _logSuccess(
                                                                'Utilizator șters: $uname',
                                                              );
                                                              _showInfoMessage(
                                                                'Utilizatorul a fost șters.',
                                                              );
                                                            } else {
                                                              final message =
                                                                  _friendlyError(
                                                                    'delete-user',
                                                                  );
                                                              _logFailure(
                                                                message,
                                                              );
                                                              _showInfoMessage(
                                                                message,
                                                              );
                                                            }
                                                          });
                                                        },
                                                  fullWidth: true,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 24),
                                          // Orar Clasă Card
                                          _buildCard(
                                            title: "Orar Clasă",
                                            primaryGreen: primaryGreen,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                StreamBuilder<QuerySnapshot>(
                                                  stream: FirebaseFirestore
                                                      .instance
                                                      .collection('classes')
                                                      .orderBy('name')
                                                      .snapshots(),
                                                  builder: (context, snap) {
                                                    if (snap.hasError) {
                                                      return Text(
                                                        "Clasele nu au putut fi încărcate.",
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      );
                                                    }
                                                    if (!snap.hasData) {
                                                      return const CircularProgressIndicator();
                                                    }

                                                    final docs =
                                                        snap.data!.docs;
                                                    final classOptions = docs
                                                        .map((doc) {
                                                          final data =
                                                              doc.data()
                                                                  as Map<
                                                                    String,
                                                                    dynamic
                                                                  >;
                                                          return {
                                                            'id': doc.id,
                                                            'name':
                                                                (data['name'] ??
                                                                        doc.id)
                                                                    .toString(),
                                                          };
                                                        })
                                                        .toList();

                                                    return Autocomplete<
                                                      Map<String, String>
                                                    >(
                                                      initialValue: TextEditingValue(
                                                        text: classOptions
                                                            .where(
                                                              (option) =>
                                                                  option['id'] ==
                                                                  selectedScheduleClassId,
                                                            )
                                                            .map(
                                                              (option) =>
                                                                  option['name']!,
                                                            )
                                                            .firstWhere(
                                                              (_) => false,
                                                              orElse: () => '',
                                                            ),
                                                      ),
                                                      optionsBuilder:
                                                          (
                                                            TextEditingValue
                                                            textEditingValue,
                                                          ) {
                                                            if (textEditingValue
                                                                .text
                                                                .isEmpty) {
                                                              return classOptions;
                                                            }
                                                            return classOptions
                                                                .where(
                                                                  (
                                                                    option,
                                                                  ) => option['name']!
                                                                      .toLowerCase()
                                                                      .contains(
                                                                        textEditingValue
                                                                            .text
                                                                            .toLowerCase(),
                                                                      ),
                                                                )
                                                                .toList();
                                                          },
                                                      displayStringForOption:
                                                          (option) =>
                                                              option['name']!,
                                                      fieldViewBuilder:
                                                          (
                                                            context,
                                                            textEditingController,
                                                            focusNode,
                                                            onFieldSubmitted,
                                                          ) {
                                                            return TextFormField(
                                                              controller:
                                                                  textEditingController,
                                                              focusNode:
                                                                  focusNode,
                                                              decoration: InputDecoration(
                                                                labelText:
                                                                    "Selecteaza clasa",
                                                                hintText:
                                                                    "Scrie pentru a cauta clase...",
                                                                border: OutlineInputBorder(
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        6,
                                                                      ),
                                                                ),
                                                                filled: true,
                                                                fillColor: Colors
                                                                    .grey[50],
                                                              ),
                                                            );
                                                          },
                                                      optionsViewBuilder:
                                                          (
                                                            context,
                                                            onSelected,
                                                            options,
                                                          ) {
                                                            return Align(
                                                              alignment:
                                                                  Alignment
                                                                      .topLeft,
                                                              child: Material(
                                                                elevation: 4.0,
                                                                child: Container(
                                                                  width:
                                                                      MediaQuery.of(
                                                                        context,
                                                                      ).size.width *
                                                                      0.3,
                                                                  constraints:
                                                                      const BoxConstraints(
                                                                        maxHeight:
                                                                            200,
                                                                      ),
                                                                  child: ListView.builder(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    shrinkWrap:
                                                                        true,
                                                                    itemCount:
                                                                        options
                                                                            .length,
                                                                    itemBuilder:
                                                                        (
                                                                          context,
                                                                          index,
                                                                        ) {
                                                                          final option = options.elementAt(
                                                                            index,
                                                                          );
                                                                          return ListTile(
                                                                            title: Text(
                                                                              option['name']!,
                                                                            ),
                                                                            onTap: () => onSelected(
                                                                              option,
                                                                            ),
                                                                          );
                                                                        },
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                      onSelected: (option) {
                                                        setState(() {
                                                          selectedScheduleClassId =
                                                              option['id']!;
                                                        });
                                                      },
                                                    );
                                                  },
                                                ),
                                                const SizedBox(height: 16),
                                                // Zilele săptămânii
                                                Text(
                                                  "Selectează zilele și orele:",
                                                  style: TextStyle(
                                                    color: Colors.grey[700],
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Zilele cu time pickers separate
                                                ...weekDays.map((day) {
                                                  final isSelected =
                                                      selectedDays[day] ??
                                                      false;
                                                  final times =
                                                      dayTimes[day] ??
                                                      {
                                                        'start':
                                                            const TimeOfDay(
                                                              hour: 7,
                                                              minute: 30,
                                                            ),
                                                        'end': const TimeOfDay(
                                                          hour: 13,
                                                          minute: 0,
                                                        ),
                                                      };

                                                  return Column(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              12,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: isSelected
                                                              ? primaryGreen
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    )
                                                              : Colors
                                                                    .grey[100],
                                                          border: Border.all(
                                                            color: isSelected
                                                                ? primaryGreen
                                                                : Colors
                                                                      .grey[200]!,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        child: Column(
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    day,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          16,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color:
                                                                          isSelected
                                                                          ? primaryGreen
                                                                          : Colors.grey[600],
                                                                    ),
                                                                  ),
                                                                ),
                                                                Checkbox(
                                                                  value:
                                                                      isSelected,
                                                                  onChanged: (value) {
                                                                    setState(() {
                                                                      selectedDays[day] =
                                                                          value ??
                                                                          false;
                                                                    });
                                                                  },
                                                                  activeColor:
                                                                      primaryGreen,
                                                                ),
                                                              ],
                                                            ),
                                                            if (isSelected) ...[
                                                              const SizedBox(
                                                                height: 12,
                                                              ),
                                                              Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Ora de inceput:",
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              4,
                                                                        ),
                                                                        GestureDetector(
                                                                          onTap: () async {
                                                                            final time = await showTimePicker(
                                                                              context: context,
                                                                              initialTime: times['start']!,
                                                                            );
                                                                            if (time !=
                                                                                null) {
                                                                              setState(
                                                                                () {
                                                                                  dayTimes[day]!['start'] = time;
                                                                                },
                                                                              );
                                                                            }
                                                                          },
                                                                          child: Container(
                                                                            padding: const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              border: Border.all(
                                                                                color: primaryGreen,
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                4,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              _formatTimeOfDay(
                                                                                times['start']!,
                                                                              ),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w500,
                                                                                color: primaryGreen,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    width: 12,
                                                                  ),
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Text(
                                                                          "Ora de final:",
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                12,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              4,
                                                                        ),
                                                                        GestureDetector(
                                                                          onTap: () async {
                                                                            final time = await showTimePicker(
                                                                              context: context,
                                                                              initialTime: times['end']!,
                                                                            );
                                                                            if (time !=
                                                                                null) {
                                                                              setState(
                                                                                () {
                                                                                  dayTimes[day]!['end'] = time;
                                                                                },
                                                                              );
                                                                            }
                                                                          },
                                                                          child: Container(
                                                                            padding: const EdgeInsets.all(
                                                                              8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              border: Border.all(
                                                                                color: primaryGreen,
                                                                              ),
                                                                              borderRadius: BorderRadius.circular(
                                                                                4,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              _formatTimeOfDay(
                                                                                times['end']!,
                                                                              ),
                                                                              style: TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w500,
                                                                                color: primaryGreen,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                    ],
                                                  );
                                                }),
                                                const SizedBox(height: 16),
                                                _buildButton(
                                                  label: "Save schedule",
                                                  primaryGreen: primaryGreen,
                                                  onPressed:
                                                      _isActionBusy(
                                                        'save-schedule',
                                                      )
                                                      ? null
                                                      : () {
                                                          _runGuarded('save-schedule', () async {
                                                            final shouldProceed =
                                                                await _confirmMajorAction(
                                                                  title:
                                                                      'Confirmare',
                                                                  message:
                                                                      'Esti sigur ca vrei sa salvezi acest orar?',
                                                                );
                                                            if (!shouldProceed) {
                                                              return;
                                                            }

                                                            if (selectedScheduleClassId
                                                                .isEmpty) {
                                                              _logFailure(
                                                                'Selectează mai întâi o clasă pentru orar.',
                                                              );
                                                              _showInfoMessage(
                                                                'Selectează mai întâi o clasă pentru orar.',
                                                              );
                                                              return;
                                                            }
                                                            final selectedDaysList =
                                                                selectedDays
                                                                    .entries
                                                                    .where(
                                                                      (e) => e
                                                                          .value,
                                                                    )
                                                                    .map(
                                                                      (e) =>
                                                                          e.key,
                                                                    )
                                                                    .toList();
                                                            if (selectedDaysList
                                                                .isEmpty) {
                                                              _logFailure(
                                                                'Selectează cel puțin o zi pentru orar.',
                                                              );
                                                              _showInfoMessage(
                                                                'Selectează cel puțin o zi pentru orar.',
                                                              );
                                                              return;
                                                            }
                                                            // Converteste zilele din Romanian la numere
                                                            final dayMapping = {
                                                              'Luni': 1,
                                                              'Marți': 2,
                                                              'Miercuri': 3,
                                                              'Joi': 4,
                                                              'Vineri': 5,
                                                            };
                                                            // Build schedule map: {day_number: {start: "HH:mm", end: "HH:mm"}}
                                                            final schedulePerDay =
                                                                <
                                                                  int,
                                                                  Map<
                                                                    String,
                                                                    String
                                                                  >
                                                                >{};
                                                            for (final day
                                                                in selectedDaysList) {
                                                              final dayNum =
                                                                  dayMapping[day]!;
                                                              final times =
                                                                  dayTimes[day]!;
                                                              schedulePerDay[dayNum] = {
                                                                'start':
                                                                    _formatTimeOfDay(
                                                                      times['start']!,
                                                                    ),
                                                                'end': _formatTimeOfDay(
                                                                  times['end']!,
                                                                ),
                                                              };
                                                            }
                                                            try {
                                                              await api.setClassSchedulePerDay(
                                                                classId:
                                                                    selectedScheduleClassId,
                                                                schedulePerDay:
                                                                    schedulePerDay,
                                                              );
                                                              _logSuccess(
                                                                'Orar salvat pentru clasa $selectedScheduleClassId.',
                                                              );
                                                              _showInfoMessage(
                                                                'Orarul a fost salvat.',
                                                              );
                                                            } catch (e) {
                                                              final message =
                                                                  _friendlyError(
                                                                    'save-schedule',
                                                                  );
                                                              _logFailure(
                                                                message,
                                                              );
                                                              _showInfoMessage(
                                                                message,
                                                              );
                                                            }
                                                          });
                                                        },
                                                  fullWidth: true,
                                                ),
                                              ],
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5FFF0)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: hasBorder ? darkGreen : const Color(0xFFCDE8B0),
          width: hasBorder ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: darkGreen.withValues(alpha: 0.08),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [primaryGreen, const Color(0xFFB3DB8A)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Divider(color: Color(0xFFD9EDBB), height: 22),
          child,
        ],
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
          borderRadius: BorderRadius.circular(20),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          splashColor: Colors.white.withValues(alpha: 0.04),
          highlightColor: Colors.white.withValues(alpha: 0.03),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: selected
                  ? const Color(0xFFECF8DC)
                  : Colors.white.withValues(alpha: 0.02),
              border: Border.all(
                color: selected
                    ? const Color(0xFF9AC972)
                    : Colors.white.withValues(alpha: 0.04),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFB9E7C9)
                        : Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: selected
                        ? const Color(0xFF3A5C24)
                        : const Color(0xFFD8F0E0),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF3A5C24)
                          : Colors.white.withValues(alpha: 0.92),
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
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFFE4FFF0)),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
