import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/session.dart';
import 'admin_api.dart';
import 'admin_classes_page.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final AdminApi _api = AdminApi();
  final Random _rng = Random.secure();
  final TextEditingController _quickCreateFullNameC = TextEditingController();
  bool _sidebarNavigationBusy = false;
  bool _quickCreateBusy = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _usersSub;
  List<_AccountSearchRecord> _accountSearchRecords = const [];
  String _quickCreateRole = 'student';
  String _quickCreateClassId = '';
  String _quickCreateUsername = '';
  String _quickCreatePassword = '';

  @override
  void initState() {
    super.initState();
    _usersSub = FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .listen((snapshot) {
          final next = snapshot.docs
              .map((doc) {
                final data = doc.data();
                final fullName = (data['fullName'] ?? '').toString().trim();
                final username = (data['username'] ?? doc.id).toString().trim();
                final role = (data['role'] ?? '').toString().trim();
                final classId = (data['classId'] ?? '').toString().trim();
                final createdAt = _asDateTime(
                  data['createdAt'] ??
                      data['created_on'] ??
                      data['createdOn'] ??
                      data['timestamp'],
                );

                return _AccountSearchRecord(
                  userId: doc.id,
                  fullName: fullName,
                  username: username,
                  role: role,
                  classId: classId,
                  createdAt: createdAt,
                );
              })
              .toList()
            ..sort((a, b) {
              final byName = a.fullName.toLowerCase().compareTo(
                b.fullName.toLowerCase(),
              );
              if (byName != 0) return byName;
              return a.username.toLowerCase().compareTo(
                b.username.toLowerCase(),
              );
            });

          if (!mounted) return;
          setState(() => _accountSearchRecords = next);
        });
  }

  @override
  void dispose() {
    _usersSub?.cancel();
    _quickCreateFullNameC.dispose();
    super.dispose();
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

  String _normalizeName(String value) {
    return value.trim().toLowerCase();
  }

  String _baseFromFullName(String fullName) {
    final normalized = _normalizeName(fullName);
    if (normalized.isEmpty) return 'user';

    final parts = normalized
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'user';

    final first = parts.first;
    final last = parts.length > 1 ? parts.last : '';
    final rawBase = last.isEmpty ? first : '${first[0]}$last';
    return rawBase.replaceAll(RegExp(r'[^a-z0-9]'), '');
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

  String _roleLabel(String role) {
    switch (role) {
      case 'student':
        return 'elev';
      case 'teacher':
        return 'diriginte';
      case 'parent':
        return 'parinte';
      case 'gate':
        return 'turnichet';
      default:
        return role;
    }
  }

  bool _roleNeedsClass(String role) {
    return role == 'student' || role == 'teacher';
  }

  void _generateQuickCreateCredentials() {
    final fullName = _quickCreateFullNameC.text.trim();
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completeaza mai intai numele complet.'),
        ),
      );
      return;
    }

    final base = _baseFromFullName(fullName);
    setState(() {
      _quickCreateUsername = '$base${_randDigits(3)}';
      _quickCreatePassword = _randPassword(10);
    });
  }

  Future<void> _copyQuickCreateCredentials() async {
    if (_quickCreateUsername.isEmpty || _quickCreatePassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Genereaza mai intai datele contului.'),
        ),
      );
      return;
    }

    await _copyCredentials(
      username: _quickCreateUsername,
      password: _quickCreatePassword,
    );
  }

  Future<void> _submitQuickCreateForm() async {
    final fullName = _quickCreateFullNameC.text.trim();
    final role = _quickCreateRole;
    final needsClass = _roleNeedsClass(role);

    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completeaza numele complet al utilizatorului.'),
        ),
      );
      return;
    }

    if (needsClass && _quickCreateClassId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecteaza clasa pentru ${_roleLabel(role)}.'),
        ),
      );
      return;
    }

    var username = _quickCreateUsername;
    var password = _quickCreatePassword;
    if (username.isEmpty || password.isEmpty) {
      final base = _baseFromFullName(fullName);
      username = '$base${_randDigits(3)}';
      password = _randPassword(10);
      setState(() {
        _quickCreateUsername = username;
        _quickCreatePassword = password;
      });
    }

    setState(() => _quickCreateBusy = true);
    try {
      await _api.createUser(
        username: username,
        password: password,
        fullName: fullName,
        role: role,
        classId: needsClass ? _quickCreateClassId : null,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cont ${_roleLabel(role)} creat cu succes.')),
      );
      setState(() {
        _quickCreateFullNameC.clear();
        _quickCreateClassId = '';
        _quickCreateUsername = '';
        _quickCreatePassword = '';
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Eroare la creare cont: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _quickCreateBusy = false);
      }
    }
  }

  Widget _buildQuickCreateSection() {
    const roleOptions = <Map<String, String>>[
      {'value': 'student', 'label': 'Elev'},
      {'value': 'teacher', 'label': 'Diriginte'},
      {'value': 'parent', 'label': 'Parinte'},
      {'value': 'gate', 'label': 'Turnichet'},
    ];

    final needsClass = _roleNeedsClass(_quickCreateRole);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5E0D1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E9DE)),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  color: Color(0xFF136A29),
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Creeaza Utilizator Nou',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF213524),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final fieldChildren = [
                      _QuickCreateField(
                        label: 'Nume complet',
                        child: TextField(
                          controller: _quickCreateFullNameC,
                          decoration: const InputDecoration(
                            hintText: 'Introduceti numele...',
                            filled: true,
                            fillColor: Color(0xFFF3F7EE),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE7D7)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE7D7)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _QuickCreateField(
                        label: 'Rol utilizator',
                        child: DropdownButtonFormField<String>(
                          value: _quickCreateRole,
                          items: roleOptions
                              .map(
                                (option) => DropdownMenuItem<String>(
                                  value: option['value'],
                                  child: Text(option['label']!),
                                ),
                              )
                              .toList(),
                          onChanged: _quickCreateBusy
                              ? null
                              : (value) {
                                  if (value == null) return;
                                  setState(() {
                                    _quickCreateRole = value;
                                    if (!_roleNeedsClass(value)) {
                                      _quickCreateClassId = '';
                                    }
                                  });
                                },
                          decoration: const InputDecoration(
                            filled: true,
                            fillColor: Color(0xFFF3F7EE),
                            border: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE7D7)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Color(0xFFDDE7D7)),
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _QuickCreateField(
                        label: 'Clasa',
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection('classes')
                              .orderBy('name')
                              .snapshots(),
                          builder: (context, snapshot) {
                            final docs = snapshot.data?.docs ?? const [];
                            final hasCurrent = docs.any(
                              (doc) => doc.id == _quickCreateClassId,
                            );

                            return DropdownButtonFormField<String>(
                              value: needsClass && hasCurrent
                                  ? _quickCreateClassId
                                  : null,
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
                              onChanged: !needsClass || _quickCreateBusy
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _quickCreateClassId = value ?? '';
                                      });
                                    },
                              disabledHint: Text(
                                needsClass
                                    ? 'Selecteaza...'
                                    : 'Nu este necesara',
                              ),
                              decoration: const InputDecoration(
                                filled: true,
                                fillColor: Color(0xFFF3F7EE),
                                border: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE7D7)),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: Color(0xFFDDE7D7)),
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(10),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (var index = 0; index < fieldChildren.length; index++) ...[
                            fieldChildren[index],
                            if (index != fieldChildren.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: fieldChildren[0]),
                        const SizedBox(width: 14),
                        Expanded(child: fieldChildren[1]),
                        const SizedBox(width: 14),
                        Expanded(child: fieldChildren[2]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final actionButtons = [
                      OutlinedButton.icon(
                        onPressed:
                            _quickCreateBusy ? null : _generateQuickCreateCredentials,
                        icon: const Icon(Icons.auto_fix_high_rounded),
                        label: const Text('Genereaza Date'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF136A29),
                          side: const BorderSide(color: Color(0xFFD5E0D1)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed:
                            _quickCreateBusy ? null : _copyQuickCreateCredentials,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copiaza Date'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF136A29),
                          side: const BorderSide(color: Color(0xFFD5E0D1)),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ];

                    if (compact) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: actionButtons,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed:
                                  _quickCreateBusy ? null : _submitQuickCreateForm,
                              icon: _quickCreateBusy
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.person_add_alt_1_rounded),
                              label: Text(
                                _quickCreateBusy
                                    ? 'Se creeaza...'
                                    : 'Creeaza Cont Utilizator',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF136A29),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    return Row(
                      children: [
                        ...actionButtons,
                        const Spacer(),
                        FilledButton.icon(
                          onPressed:
                              _quickCreateBusy ? null : _submitQuickCreateForm,
                          icon: _quickCreateBusy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            _quickCreateBusy
                                ? 'Se creeaza...'
                                : 'Creeaza Cont Utilizator',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF136A29),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (_quickCreateUsername.isNotEmpty ||
                    _quickCreatePassword.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6EA),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFD5E0D1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date generate',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF406247),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          'ID utilizator: $_quickCreateUsername\nParola: $_quickCreatePassword',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF213524),
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  DateTime? _asDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      // Accept both unix seconds and milliseconds.
      final ms = value < 1000000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDateTimeValue(DateTime? value) {
    if (value == null) return '-';
    final dd = value.day.toString().padLeft(2, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final yyyy = value.year.toString();
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$dd.$mm.$yyyy $hh:$min';
  }

  String _roleTitle(String role) {
    switch (role.toLowerCase()) {
      case 'student':
        return 'Elev';
      case 'teacher':
        return 'Diriginte';
      case 'parent':
        return 'Parinte';
      case 'admin':
        return 'Admin';
      case 'gate':
        return 'Turnichet';
      default:
        return role.isEmpty ? '-' : role;
    }
  }

  Future<void> _showAccountDetailsDialog(_AccountSearchRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Detalii inregistrare cont'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Nume', record.displayName),
              _detailRow('ID utilizator', record.username),
              _detailRow('UID', record.userId),
              _detailRow('Rol', _roleTitle(record.role)),
              _detailRow(
                'Clasa',
                record.classId.isEmpty ? '-' : record.classId,
              ),
              _detailRow(
                'Data inregistrarii',
                _formatDateTimeValue(record.createdAt),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Inchide'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF2B3C2E),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Color(0xFF2B3C2E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String rawType) {
    final type = rawType.trim().toLowerCase();
    if (type == 'entry') {
      return _buildTinyBadge(
        label: 'INTRAT',
        background: const Color(0xFFD7F5E0),
        foreground: const Color(0xFF17784D),
      );
    }
    if (type == 'exit') {
      return _buildTinyBadge(
        label: 'IESIT',
        background: const Color(0xFFFBE0E0),
        foreground: const Color(0xFFA13737),
      );
    }
    return _buildTinyBadge(
      label: 'SCANARE',
      background: const Color(0xFFE8EEF5),
      foreground: const Color(0xFF3E556D),
    );
  }

  Widget _buildTinyBadge({
    required String label,
    required Color background,
    required Color foreground,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  int _extractClassNumber(String classId) {
    final match = RegExp(r'^(\d+)').firstMatch(classId.trim().toUpperCase());
    if (match == null) return -1;
    return int.tryParse(match.group(1) ?? '') ?? -1;
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.fullName?.trim().isNotEmpty == true)
        ? AppSession.fullName!.trim()
        : ((AppSession.username?.trim().isNotEmpty == true)
              ? AppSession.username!.trim()
              : 'Admin Secretariat');

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
              onStudentsTap: () => _openSidebarPage(const AdminStudentsPage()),
              onTeachersTap: () => _openSidebarPage(const AdminTeachersPage()),
              onTurnstilesTap: () =>
                  _openSidebarPage(const AdminTurnstilesPage()),
              onClassesTap: () => _openSidebarPage(const AdminClassesPage()),
              onVacanteTap: () =>
                  _openSidebarPage(const admin_vacante.AdminClassesPage()),
              onParentsTap: () => _openSidebarPage(const AdminParentsPage()),
              onLogoutTap: _showLogoutDialog,
            ),
            Expanded(
              child: Container(
                color: const Color(0xFFF0F3EC),
                child: Column(
                  children: [
                    _TopBar(
                      displayName: displayName,
                      records: _accountSearchRecords,
                      onRecordSelected: _showAccountDetailsDialog,
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, usersSnap) {
                    final users = usersSnap.data?.docs ?? const [];
                    final studentCount = users
                        .where(
                          (doc) =>
                              (doc.data() as Map<String, dynamic>? ??
                                  {})['role'] ==
                              'student',
                        )
                        .length;
                    final teacherCount = users
                        .where(
                          (doc) =>
                              (doc.data() as Map<String, dynamic>? ??
                                  {})['role'] ==
                              'teacher',
                        )
                        .length;
                    final activeTurnstiles = users.where((doc) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      final role = (data['role'] ?? '').toString();
                      final status = (data['status'] ?? '')
                          .toString()
                          .toLowerCase();
                      return role == 'gate' && status == 'active';
                    }).length;

                    final classDistribution = <int, int>{};
                    for (final doc in users) {
                      final data = doc.data() as Map<String, dynamic>? ?? {};
                      if ((data['role'] ?? '').toString() != 'student')
                        continue;
                      final classId = (data['classId'] ?? '').toString();
                      if (classId.isEmpty) continue;
                      final classNumber = _extractClassNumber(classId);
                      if (classNumber <= 0) continue;
                      classDistribution[classNumber] =
                          (classDistribution[classNumber] ?? 0) + 1;
                    }
                    final sortedClassEntries =
                        classDistribution.entries.toList()
                          ..sort((a, b) => a.key.compareTo(b.key));

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('leaveRequests')
                          .snapshots(),
                      builder: (context, leavesSnap) {
                        final leaveCount = leavesSnap.data?.docs.length ?? 0;

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('classes')
                              .snapshots(),
                          builder: (context, classesSnap) {
                            final classCount = classesSnap.data?.docs.length ?? 0;

                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 14,
                                    runSpacing: 14,
                                    children: [
                                      _MetricCard(
                                        title: 'Total Elevi',
                                        value: studentCount.toString(),
                                        subtitle: 'la momentul curent',
                                        icon: Icons.school_rounded,
                                      ),
                                      _MetricCard(
                                        title: 'Numar Diriginti',
                                        value: teacherCount.toString(),
                                        subtitle: 'conturi profesor',
                                        icon: Icons.groups_2_rounded,
                                      ),
                                      _MetricCard(
                                        title: 'Turnicheti Activi',
                                        value: activeTurnstiles.toString(),
                                        subtitle: 'status activ',
                                        icon: Icons.door_front_door_rounded,
                                      ),
                                      _MetricCard(
                                        title: 'Cereri Invoire',
                                        value: leaveCount.toString(),
                                        subtitle: 'total inregistrate',
                                        icon: Icons.description_rounded,
                                      ),
                                      _MetricCard(
                                        title: 'Numar Clase',
                                        value: classCount.toString(),
                                        subtitle: 'clase configurate',
                                        icon: Icons.table_chart_rounded,
                                      ),
                                    ],
                                  ),
                              const SizedBox(height: 24),
                              const Text(
                                'Creare Rapida Conturi',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF213524),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildQuickCreateSection(),
                              const SizedBox(height: 24),
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: _PanelCard(
                                        title: 'Acces Recent',
                                        child: StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance
                                            .collection('accessEvents')
                                            .orderBy(
                                              'timestamp',
                                              descending: true,
                                            )
                                            .limit(20)
                                            .snapshots(),
                                        builder: (context, accessSnap) {
                                          if (accessSnap.hasError) {
                                            return const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Text(
                                                'Nu s-au putut incarca evenimentele de acces.',
                                              ),
                                            );
                                          }
                                          if (!accessSnap.hasData) {
                                            return const Padding(
                                              padding: EdgeInsets.all(22),
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            );
                                          }
                                          final docs = accessSnap.data!.docs;
                                          if (docs.isEmpty) {
                                            return const Padding(
                                              padding: EdgeInsets.all(12),
                                              child: Text(
                                                'Nu exista scanari inregistrate.',
                                              ),
                                            );
                                          }

                                          return SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            child: DataTable(
                                              headingTextStyle: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF48604A),
                                              ),
                                              dataTextStyle: const TextStyle(
                                                color: Color(0xFF2D3930),
                                              ),
                                              columns: const [
                                                DataColumn(
                                                  label: Text('Nume elev'),
                                                ),
                                                DataColumn(label: Text('Ora')),
                                                DataColumn(
                                                  label: Text('Locatie'),
                                                ),
                                                DataColumn(
                                                  label: Text('Status'),
                                                ),
                                              ],
                                              rows: docs.map((doc) {
                                                final data =
                                                    doc.data()
                                                        as Map<
                                                          String,
                                                          dynamic
                                                        >? ??
                                                    {};
                                                final fullName =
                                                    (data['fullName'] ??
                                                            data['userId'] ??
                                                            '-')
                                                        .toString();
                                                final timestamp =
                                                    data['timestamp']
                                                        as Timestamp?;
                                                final location =
                                                    (data['location'] ??
                                                            data['gate'] ??
                                                            '-')
                                                        .toString();
                                                final type =
                                                    (data['type'] ??
                                                            data['scanType'] ??
                                                            '')
                                                        .toString();
                                                return DataRow(
                                                  cells: [
                                                    DataCell(Text(fullName)),
                                                    DataCell(
                                                      Text(
                                                        _formatDateTime(
                                                          timestamp,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(Text(location)),
                                                    DataCell(_statusChip(type)),
                                                  ],
                                                );
                                              }).toList(),
                                            ),
                                          );
                                        },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      flex: 2,
                                      child: _PanelCard(
                                        title: 'Distributie pe Clase',
                                        expandChild: true,
                                        child: sortedClassEntries.isEmpty
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: Text(
                                                  'Nu exista elevi asignati claselor.',
                                                ),
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceEvenly,
                                                children: sortedClassEntries.map((
                                                  entry,
                                                ) {
                                                  final number = entry.key;
                                                  final count = entry.value;
                                                  final maxValue =
                                                      sortedClassEntries.fold<int>(
                                                        1,
                                                        (prev, e) => max(
                                                          prev,
                                                          e.value,
                                                        ),
                                                      );
                                                  final factor = count / maxValue;
                                                  return Row(
                                                    children: [
                                                      SizedBox(
                                                        width: 90,
                                                        child: Text(
                                                          'CLASA A $number-a',
                                                          style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 12,
                                                            color: Color(
                                                              0xFF37513B,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Stack(
                                                          children: [
                                                            Container(
                                                              height: 8,
                                                              decoration: BoxDecoration(
                                                                color: const Color(
                                                                  0xFFE2EBDD,
                                                                ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                  999,
                                                                ),
                                                              ),
                                                            ),
                                                            FractionallySizedBox(
                                                              widthFactor: factor,
                                                              child: Container(
                                                                height: 8,
                                                                decoration: BoxDecoration(
                                                                  color: const Color(
                                                                    0xFF1F7A3A,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                    999,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Text(
                                                        '$count ELEVI',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 12,
                                                          color: Color(
                                                            0xFF37513B,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                }).toList(),
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                                ],
                              ),
                            );
                          },
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

class _Sidebar extends StatelessWidget {
  final String displayName;
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onTeachersTap;
  final VoidCallback onTurnstilesTap;
  final VoidCallback onClassesTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParentsTap;
  final VoidCallback onLogoutTap;

  const _Sidebar({
    required this.displayName,
    required this.onMenuTap,
    required this.onStudentsTap,
    required this.onTeachersTap,
    required this.onTurnstilesTap,
    required this.onClassesTap,
    required this.onVacanteTap,
    required this.onParentsTap,
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
            icon: Icons.dashboard_rounded,
            selected: true,
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
            onTap: onTeachersTap,
          ),
          _SidebarTile(
            label: 'Parinti',
            icon: Icons.family_restroom_rounded,
            onTap: onParentsTap,
          ),
          _SidebarTile(
            label: 'Clase',
            icon: Icons.table_chart_rounded,
            onTap: onClassesTap,
          ),
          _SidebarTile(
            label: 'Vacante',
            icon: Icons.event_available_rounded,
            onTap: onVacanteTap,
          ),
          _SidebarTile(
            label: 'Turnicheti',
            icon: Icons.door_front_door_rounded,
            onTap: onTurnstilesTap,
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
  final String displayName;
  final List<_AccountSearchRecord> records;
  final ValueChanged<_AccountSearchRecord> onRecordSelected;

  const _TopBar({
    required this.displayName,
    required this.records,
    required this.onRecordSelected,
  });

  static String _normalize(String value) {
    return value.toLowerCase().trim();
  }

  static bool _isOrderedMatch(String query, String source) {
    if (query.isEmpty) return true;
    var qi = 0;
    for (var i = 0; i < source.length && qi < query.length; i++) {
      if (source[i] == query[qi]) qi++;
    }
    return qi == query.length;
  }

  static int _score(String query, _AccountSearchRecord item) {
    final name = _normalize(item.fullName);
    final user = _normalize(item.username);
    if (name.startsWith(query) || user.startsWith(query)) return 0;
    if (name.contains(query) || user.contains(query)) return 1;
    return 2;
  }

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
            'Panou de Control',
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
                child: RawAutocomplete<_AccountSearchRecord>(
                  displayStringForOption: (option) => option.displayName,
                  optionsBuilder: (value) {
                    final query = _normalize(value.text);
                    if (query.isEmpty) {
                      return const Iterable<_AccountSearchRecord>.empty();
                    }

                    final filtered = records.where((item) {
                      final name = _normalize(item.fullName);
                      final username = _normalize(item.username);
                      return _isOrderedMatch(query, name) ||
                          _isOrderedMatch(query, username);
                    }).toList()
                      ..sort((a, b) {
                        final byScore = _score(query, a).compareTo(
                          _score(query, b),
                        );
                        if (byScore != 0) return byScore;
                        return a.displayName.toLowerCase().compareTo(
                          b.displayName.toLowerCase(),
                        );
                      });

                    return filtered.take(8);
                  },
                  onSelected: onRecordSelected,
                  fieldViewBuilder: (
                    context,
                    textController,
                    focusNode,
                    onFieldSubmitted,
                  ) {
                    return Container(
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
                              controller: textController,
                              focusNode: focusNode,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isCollapsed: true,
                                hintText: 'Cauta inregistrari...',
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
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    final items = options.toList(growable: false);
                    return Align(
                      alignment: Alignment.topCenter,
                      child: Material(
                        color: Colors.transparent,
                        child: Container(
                          margin: const EdgeInsets.only(top: 6),
                          constraints: const BoxConstraints(
                            maxWidth: 560,
                            maxHeight: 280,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDBE7D9)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            shrinkWrap: true,
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE9EFE8),
                            ),
                            itemBuilder: (context, index) {
                              final item = items[index];
                              final subtitle = item.classId.isEmpty
                                  ? '${item.username} • ${item.role}'
                                  : '${item.username} • ${item.role} • ${item.classId}';
                              return InkWell(
                                onTap: () => onSelected(item),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    9,
                                    12,
                                    9,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF1E2E22),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Color(0xFF58725C),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const AdminNotificationBell(),
        ],
      ),
    );
  }
}

class _AccountSearchRecord {
  final String userId;
  final String fullName;
  final String username;
  final String role;
  final String classId;
  final DateTime? createdAt;

  const _AccountSearchRecord({
    required this.userId,
    required this.fullName,
    required this.username,
    required this.role,
    required this.classId,
    required this.createdAt,
  });

  String get displayName => fullName.isEmpty ? username : fullName;
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 246,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCEDCCB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCECDD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1B6A2E), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF2F6B3E),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF26352A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 36,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A2D1F),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickCreateField extends StatelessWidget {
  final String label;
  final Widget child;

  const _QuickCreateField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: Color(0xFF566955),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool expandChild;

  const _PanelCard({
    required this.title,
    required this.child,
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD5E0D1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF213625),
            ),
          ),
          const SizedBox(height: 8),
          if (expandChild) Expanded(child: child) else child,
        ],
      ),
    );
  }
}
