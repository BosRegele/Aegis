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

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final api = AdminApi();
  final store = AdminStore();
  String activeSidebarLabel = "Clase";

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

  void _log(String s) => setState(() => log = "$s\n$log");

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
    const Color primaryGreen = Color.fromARGB(255, 94, 184, 78);

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
    const Color primaryGreen = Color.fromARGB(255, 94, 184, 78);
    const Color lightGreen = Color(0xFFF0F4E8);
    const Color darkGreen = Color.fromARGB(255, 94, 184, 78);

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(),
      ),
      body: Column(
        children: [
          // Top Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: const Color.fromARGB(255, 252, 252, 252),
                  width: 1,
                ),
              ),
            ),
            height: 70,
            child: Row(
              children: [
                // Green section with Secretariat
                Container(
                  width: 280,
                  color: darkGreen,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Secretariat",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                // White section extending to the right
                Expanded(child: Container(color: Colors.white)),
              ],
            ),
          ),
          // Main Content
          Expanded(
            child: Row(
              children: [
                // SIDEBAR
                Container(
                  width: 280,
                  height: double.infinity,
                  color: darkGreen,
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Management Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          "ADMINISTRARE",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            _buildSidebarItem(
                              icon: Icons.table_chart,
                              label: "Clase",
                              onTap: () async {
                                setState(() => activeSidebarLabel = "Clase");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminClassesPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.people,
                              label: "Elevi",
                              onTap: () async {
                                setState(() => activeSidebarLabel = "Elevi");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminStudentsPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.family_restroom,
                              label: "Parinti",
                              onTap: () async {
                                setState(() => activeSidebarLabel = "Parinti");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminParentsPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.person,
                              label: "Profesori",
                              onTap: () async {
                                setState(
                                  () => activeSidebarLabel = "Profesori",
                                );
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminTeachersPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.admin_panel_settings,
                              label: "Administratori",
                              onTap: () async {
                                setState(
                                  () => activeSidebarLabel = "Administratori",
                                );
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminAdminsPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.door_front_door,
                              label: "Turnichete",
                              onTap: () async {
                                setState(
                                  () => activeSidebarLabel = "Turnichete",
                                );
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminTurnstilesPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                            _buildSidebarItem(
                              icon: Icons.schedule,
                              label: "Orare",
                              onTap: () async {
                                setState(() => activeSidebarLabel = "Orare");
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminSchedulesPage(),
                                  ),
                                );
                                setState(() => activeSidebarLabel = "");
                              },
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Logout Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: GestureDetector(
                          onTap: _showLogoutDialog,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Colors.red.withOpacity(0.2),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  "Deconectare",
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
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
                // MAIN CONTENT
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey[200]!,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: role,
                                              isExpanded: true,
                                              items: const [
                                                DropdownMenuItem(
                                                  value: "student",
                                                  child: Text("elev"),
                                                ),
                                                DropdownMenuItem(
                                                  value: "teacher",
                                                  child: Text("profesor"),
                                                ),
                                                DropdownMenuItem(
                                                  value: "admin",
                                                  child: Text("administrator"),
                                                ),
                                                DropdownMenuItem(
                                                  value: "parent",
                                                  child: Text("părinte"),
                                                ),
                                                DropdownMenuItem(
                                                  value: "gate",
                                                  child: Text("poartă"),
                                                ),
                                              ],
                                              onChanged: (v) => setState(
                                                () => role = v ?? "student",
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (role == "student" ||
                                            role == "teacher") ...[
                                          const SizedBox(height: 12),
                                          StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('classes')
                                                .orderBy('name')
                                                .snapshots(),
                                            builder: (context, snap) {
                                              if (snap.hasError) {
                                                return Text(
                                                  "Eroare clase: ${snap.error}",
                                                  style: const TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                );
                                              }
                                              if (!snap.hasData) {
                                                return const CircularProgressIndicator();
                                              }

                                              final docs = snap.data!.docs;
                                              final classOptions = docs.map((
                                                doc,
                                              ) {
                                                final data =
                                                    doc.data()
                                                        as Map<String, dynamic>;
                                                return {
                                                  'id': doc.id,
                                                  'name':
                                                      (data['name'] ?? doc.id)
                                                          .toString(),
                                                };
                                              }).toList();

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
                                                    (option) => option['name']!,
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
                                                        focusNode: focusNode,
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
                                                          fillColor:
                                                              Colors.grey[50],
                                                        ),
                                                      );
                                                    },
                                                optionsViewBuilder: (context, onSelected, options) {
                                                  return Align(
                                                    alignment:
                                                        Alignment.topLeft,
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
                                                              maxHeight: 200,
                                                            ),
                                                        child: ListView.builder(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          shrinkWrap: true,
                                                          itemCount:
                                                              options.length,
                                                          itemBuilder:
                                                              (context, index) {
                                                                final option =
                                                                    options
                                                                        .elementAt(
                                                                          index,
                                                                        );
                                                                return ListTile(
                                                                  title: Text(
                                                                    option['name']!,
                                                                  ),
                                                                  onTap: () =>
                                                                      onSelected(
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
                                          DropdownMenuItem(
                                            value: "parent",
                                            child: Text("parent"),
                                          ),
                                        ],
                                        const SizedBox(height: 16),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildButton(
                                                label: "Generează",
                                                primaryGreen: primaryGreen,
                                                onPressed: _generateCreds,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildButton(
                                                label: "Copiază",
                                                primaryGreen: primaryGreen,
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
                                          onPressed: () async {
                                            final uname = usernameC.text.trim();
                                            final pass = passwordC.text;
                                            final full = fullNameC.text.trim();

                                            // Basic client-side validation to avoid cloud failures
                                            if (full.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Completează numele complet',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            if (uname.isEmpty) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Completează username',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            if (uname.contains(RegExp(r'\s'))) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Username nu poate conține spații',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }
                                            if (pass.length < 6) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Parola trebuie să aibă cel puțin 6 caractere',
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            try {
                                              final u = FirebaseAuth
                                                  .instance
                                                  .currentUser;
                                              _log(
                                                "AUTH user = ${u?.uid} | email=${u?.email}",
                                              );

                                              // cloud function
                                              final res = await api.createUser(
                                                username: uname.toLowerCase(),
                                                password: pass,
                                                role: role,
                                                fullName: full,
                                                classId:
                                                    role == "student" ||
                                                        role == "teacher"
                                                    ? selectedCreateUserClassId
                                                    : null,
                                              );

                                              _log(
                                                "API CREATE OK: $uname | uid=${res['uid']}",
                                              );

                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "User creat: $uname",
                                                  ),
                                                  backgroundColor: Colors.green,
                                                  duration: const Duration(
                                                    seconds: 2,
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              _log("CREATE ERROR: $e");
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Eroare creare user: $e',
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
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
                                                    color: Colors.grey[200]!,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<int>(
                                                    value: selectedNumber,
                                                    isExpanded: true,
                                                    items:
                                                        List.generate(
                                                          13,
                                                          (i) => i,
                                                        ).map((num) {
                                                          return DropdownMenuItem(
                                                            value: num,
                                                            child: Text(
                                                              num.toString(),
                                                            ),
                                                          );
                                                        }).toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedNumber =
                                                          v ?? 9,
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
                                                    color: Colors.grey[200]!,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value: selectedLetter,
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
                                                            value: letter,
                                                            child: Text(letter),
                                                          );
                                                        }).toList(),
                                                    onChanged: (v) => setState(
                                                      () => selectedLetter =
                                                          v ?? "A",
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
                                                label: "Creeaza/Actualizeaza",
                                                primaryGreen: primaryGreen,
                                                onPressed: () async {
                                                  final classId =
                                                      "$selectedNumber$selectedLetter";
                                                  try {
                                                    await api
                                                        .createClass(
                                                          name: classId,
                                                        )
                                                        .then(
                                                          (_) => _log(
                                                            "CLASS OK: $classId",
                                                          ),
                                                        );
                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          "Clasă creată: $classId",
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                        duration:
                                                            const Duration(
                                                              seconds: 2,
                                                            ),
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    _log("CLASS ERROR: $e");
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () async {
                                                  final classId =
                                                      "$selectedNumber$selectedLetter";
                                                  try {
                                                    await api
                                                        .deleteClassCascade(
                                                          classId: classId,
                                                        );
                                                    _log(
                                                      "DELETE CLASS OK: $classId",
                                                    );
                                                  } catch (e) {
                                                    _log(
                                                      "DELETE CLASS ERROR: $e",
                                                    );
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.red[600],
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          6,
                                                        ),
                                                  ),
                                                ),
                                                child: const Text(
                                                  "Sterge",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
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
                                          stream: FirebaseFirestore.instance
                                              .collection('users')
                                              .where(
                                                'role',
                                                isEqualTo: 'student',
                                              )
                                              .snapshots(),
                                          builder: (context, snap) {
                                            if (snap.hasError) {
                                              return Text(
                                                'Eroare: ${snap.error}',
                                              );
                                            }
                                            if (!snap.hasData) {
                                              return const CircularProgressIndicator();
                                            }

                                            final opts = snap.data!.docs.map((
                                              d,
                                            ) {
                                              final data =
                                                  d.data()
                                                      as Map<String, dynamic>;
                                              final name =
                                                  (data['fullName'] ??
                                                          data['username'] ??
                                                          d.id)
                                                      .toString();
                                              return {'id': d.id, 'name': name};
                                            }).toList();

                                            opts.sort(
                                              (a, b) => a['name']!
                                                  .toLowerCase()
                                                  .compareTo(
                                                    b['name']!.toLowerCase(),
                                                  ),
                                            );

                                            return Autocomplete<
                                              Map<String, String>
                                            >(
                                              optionsBuilder: (txt) {
                                                if (txt.text.isEmpty) {
                                                  return opts;
                                                }
                                                return opts.where(
                                                  (o) => o['name']!
                                                      .toLowerCase()
                                                      .contains(
                                                        txt.text.toLowerCase(),
                                                      ),
                                                );
                                              },
                                              displayStringForOption: (o) =>
                                                  o['name']!,
                                              onSelected: (o) => setState(
                                                () => selectedAssignStudent = o,
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
                                                      focusNode: focusNode,
                                                      decoration:
                                                          const InputDecoration(
                                                            hintText:
                                                                'Type student name...',
                                                          ),
                                                    );
                                                  },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        if (selectedAssignStudent != null) ...[
                                          const Text("Parintii actuali:"),
                                          const SizedBox(height: 8),
                                          StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(
                                                  selectedAssignStudent!['id'],
                                                )
                                                .snapshots(),
                                            builder: (context, snap) {
                                              if (snap.hasError) {
                                                return Text(
                                                  'Eroare: ${snap.error}',
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
                                              final parents = List<String>.from(
                                                data['parents'] ?? [],
                                              );

                                              if (parents.isEmpty) {
                                                return const Text(
                                                  'Niciun părinte asignat',
                                                );
                                              }

                                              return Column(
                                                children: parents.map((puid) {
                                                  return FutureBuilder<
                                                    DocumentSnapshot
                                                  >(
                                                    future: FirebaseFirestore
                                                        .instance
                                                        .collection('users')
                                                        .doc(puid)
                                                        .get(),
                                                    builder: (context, psnap) {
                                                      if (!psnap.hasData) {
                                                        return const SizedBox.shrink();
                                                      }
                                                      final pdata =
                                                          psnap.data!.data()
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
                                                        title: Text(pname),
                                                        subtitle: Text(
                                                          'uid: $puid',
                                                        ),
                                                        trailing: IconButton(
                                                          icon: const Icon(
                                                            Icons.remove_circle,
                                                            color: Colors.red,
                                                          ),
                                                          onPressed: () async {
                                                            final confirm = await showDialog<bool>(
                                                              context: context,
                                                              builder: (_) => AlertDialog(
                                                                title:
                                                                    const Text(
                                                                      'Confirm',
                                                                    ),
                                                                content: Text(
                                                                  'Sunteți sigur că vreți să scoateți părintele $pname din elevul ${selectedAssignStudent!['name']}?',
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          context,
                                                                          false,
                                                                        ),
                                                                    child:
                                                                        const Text(
                                                                          'Nu',
                                                                        ),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed: () =>
                                                                        Navigator.pop(
                                                                          context,
                                                                          true,
                                                                        ),
                                                                    child:
                                                                        const Text(
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
                                                              final stuRef =
                                                                  FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                        'users',
                                                                      )
                                                                      .doc(
                                                                        selectedAssignStudent!['id'],
                                                                      );
                                                              final parRef =
                                                                  FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                        'users',
                                                                      )
                                                                      .doc(
                                                                        puid,
                                                                      );
                                                              await stuRef.update({
                                                                'parents':
                                                                    FieldValue.arrayRemove(
                                                                      [puid],
                                                                    ),
                                                              });
                                                              await parRef.update({
                                                                'children':
                                                                    FieldValue.arrayRemove([
                                                                      selectedAssignStudent!['id'],
                                                                    ]),
                                                              });
                                                              if (mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Părinte scos cu succes',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            } catch (e) {
                                                              if (mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      'Eroare: $e',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            }
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
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .where(
                                                  'role',
                                                  isEqualTo: 'parent',
                                                )
                                                .snapshots(),
                                            builder: (context, psnap) {
                                              if (psnap.hasError) {
                                                return Text(
                                                  'Eroare: ${psnap.error}',
                                                );
                                              }
                                              if (!psnap.hasData) {
                                                return const CircularProgressIndicator();
                                              }
                                              final popts = psnap.data!.docs.map((
                                                d,
                                              ) {
                                                final data =
                                                    d.data()
                                                        as Map<String, dynamic>;
                                                final name =
                                                    (data['fullName'] ??
                                                            data['username'] ??
                                                            d.id)
                                                        .toString();
                                                return {
                                                  'id': d.id,
                                                  'name': name,
                                                };
                                              }).toList();

                                              popts.sort(
                                                (a, b) => a['name']!
                                                    .toLowerCase()
                                                    .compareTo(
                                                      b['name']!.toLowerCase(),
                                                    ),
                                              );

                                              return Autocomplete<
                                                Map<String, String>
                                              >(
                                                optionsBuilder: (txt) {
                                                  if (txt.text.isEmpty) {
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
                                                displayStringForOption: (o) =>
                                                    o['name']!,
                                                onSelected: (o) => setState(
                                                  () =>
                                                      selectedAssignParent = o,
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
                                                        controller: ctrl,
                                                        focusNode: focusNode,
                                                        decoration:
                                                            const InputDecoration(
                                                              hintText:
                                                                  'Type parent name...',
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
                                                          null
                                                      ? null
                                                      : () async {
                                                          final sp =
                                                              selectedAssignStudent!['id'];
                                                          final pp =
                                                              selectedAssignParent!['id'];
                                                          try {
                                                            final stuRef =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'users',
                                                                    )
                                                                    .doc(sp);
                                                            final stuSnap =
                                                                await stuRef
                                                                    .get();
                                                            final stuData =
                                                                stuSnap
                                                                    .data() ??
                                                                {};
                                                            final parents =
                                                                List<
                                                                  String
                                                                >.from(
                                                                  stuData['parents'] ??
                                                                      [],
                                                                );
                                                            if (parents
                                                                .contains(pp)) {
                                                              if (mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Părinte deja asignat',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                              return;
                                                            }
                                                            if (parents
                                                                    .length >=
                                                                2) {
                                                              if (mounted) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Elevul are deja 2 parinti assign',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                              return;
                                                            }
                                                            final parRef =
                                                                FirebaseFirestore
                                                                    .instance
                                                                    .collection(
                                                                      'users',
                                                                    )
                                                                    .doc(pp);
                                                            await stuRef.update({
                                                              'parents':
                                                                  FieldValue.arrayUnion(
                                                                    [pp],
                                                                  ),
                                                            });
                                                            await parRef.update({
                                                              'children':
                                                                  FieldValue.arrayUnion(
                                                                    [sp],
                                                                  ),
                                                            });
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                const SnackBar(
                                                                  content: Text(
                                                                    'Părinte asignat cu succes',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          } catch (e) {
                                                            if (mounted) {
                                                              ScaffoldMessenger.of(
                                                                context,
                                                              ).showSnackBar(
                                                                SnackBar(
                                                                  content: Text(
                                                                    'Eroare: $e',
                                                                  ),
                                                                ),
                                                              );
                                                            }
                                                          }
                                                        },
                                                  child: const Text(
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
                                        borderRadius: BorderRadius.circular(6),
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
                                    title: "Resetează / Dezactivează cont",
                                    primaryGreen: primaryGreen,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildTextField(
                                          controller: targetUserC,
                                          label: "Nume utilizator țintă",
                                        ),
                                        const SizedBox(height: 16),
                                        _buildButton(
                                          label: "Resetare Parolă",
                                          primaryGreen: primaryGreen,
                                          onPressed: () async {
                                            try {
                                              final res = await api
                                                  .resetPassword(
                                                    username: targetUserC.text,
                                                  );
                                              final newPass = res['password'];
                                              _log(
                                                "RESET OK: newPass=$newPass",
                                              );
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    "Parola noua: $newPass",
                                                  ),
                                                ),
                                              );
                                            } catch (e) {
                                              _log("RESET ERROR: $e");
                                            }
                                          },
                                          fullWidth: true,
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: _buildButton(
                                                label: "Dezactiveaza",
                                                primaryGreen: primaryGreen,
                                                onPressed: () async {
                                                  try {
                                                    await api.setDisabled(
                                                      username:
                                                          targetUserC.text,
                                                      disabled: true,
                                                    );
                                                    _log("DISABLE OK");
                                                  } catch (e) {
                                                    _log("DISABLE ERROR: $e");
                                                  }
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: _buildButton(
                                                label: "Activeaza",
                                                primaryGreen: primaryGreen,
                                                onPressed: () async {
                                                  try {
                                                    await api.setDisabled(
                                                      username:
                                                          targetUserC.text,
                                                      disabled: false,
                                                    );
                                                    _log("ENABLE OK");
                                                  } catch (e) {
                                                    _log("ENABLE ERROR: $e");
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('classes')
                                              .orderBy('name')
                                              .snapshots(),
                                          builder: (context, snap) {
                                            if (snap.hasError) {
                                              return Text(
                                                "Eroare clase: ${snap.error}",
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              );
                                            }
                                            if (!snap.hasData) {
                                              return const CircularProgressIndicator();
                                            }

                                            final docs = snap.data!.docs;
                                            final classOptions = docs.map((
                                              doc,
                                            ) {
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              return {
                                                'id': doc.id,
                                                'name': (data['name'] ?? doc.id)
                                                    .toString(),
                                              };
                                            }).toList();

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
                                                  (option) => option['name']!,
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
                                                      focusNode: focusNode,
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
                                                        fillColor:
                                                            Colors.grey[50],
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
                                                          Alignment.topLeft,
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
                                                                maxHeight: 200,
                                                              ),
                                                          child: ListView.builder(
                                                            padding:
                                                                EdgeInsets.zero,
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                options.length,
                                                            itemBuilder: (context, index) {
                                                              final option =
                                                                  options
                                                                      .elementAt(
                                                                        index,
                                                                      );
                                                              return ListTile(
                                                                title: Text(
                                                                  option['name']!,
                                                                ),
                                                                onTap: () =>
                                                                    onSelected(
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
                                          onPressed: () async {
                                            try {
                                              await api.moveStudentClass(
                                                username: targetUserC.text,
                                                newClassId: selectedMoveClassId,
                                              );
                                              _log("MOVE OK");
                                            } catch (e) {
                                              _log("MOVE ERROR: $e");
                                            }
                                          },
                                          fullWidth: true,
                                        ),
                                        const SizedBox(height: 12),
                                        // delete user button
                                        _buildButton(
                                          label: "Sterge utilizator",
                                          primaryGreen: Colors.red[600]!,
                                          onPressed: () async {
                                            final uname = targetUserC.text
                                                .trim()
                                                .toLowerCase();
                                            if (uname.isEmpty) {
                                              _log(
                                                "DELETE ERROR: username gol",
                                              );
                                              return;
                                            }
                                            try {
                                              // try cloud function first
                                              await api.deleteUser(
                                                username: uname,
                                              );
                                              _log("API DELETE OK: $uname");
                                            } catch (e) {
                                              _log("API DELETE ERROR: $e");
                                            }
                                            try {
                                              await store.deleteUser(uname);
                                              _log("STORE DELETE OK: $uname");
                                            } catch (e) {
                                              _log("STORE DELETE ERROR: $e");
                                            }
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
                                          stream: FirebaseFirestore.instance
                                              .collection('classes')
                                              .orderBy('name')
                                              .snapshots(),
                                          builder: (context, snap) {
                                            if (snap.hasError) {
                                              return Text(
                                                "Eroare clase: ${snap.error}",
                                                style: const TextStyle(
                                                  color: Colors.red,
                                                ),
                                              );
                                            }
                                            if (!snap.hasData) {
                                              return const CircularProgressIndicator();
                                            }

                                            final docs = snap.data!.docs;
                                            final classOptions = docs.map((
                                              doc,
                                            ) {
                                              final data =
                                                  doc.data()
                                                      as Map<String, dynamic>;
                                              return {
                                                'id': doc.id,
                                                'name': (data['name'] ?? doc.id)
                                                    .toString(),
                                              };
                                            }).toList();

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
                                                  (option) => option['name']!,
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
                                                      focusNode: focusNode,
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
                                                        fillColor:
                                                            Colors.grey[50],
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
                                                          Alignment.topLeft,
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
                                                                maxHeight: 200,
                                                              ),
                                                          child: ListView.builder(
                                                            padding:
                                                                EdgeInsets.zero,
                                                            shrinkWrap: true,
                                                            itemCount:
                                                                options.length,
                                                            itemBuilder: (context, index) {
                                                              final option =
                                                                  options
                                                                      .elementAt(
                                                                        index,
                                                                      );
                                                              return ListTile(
                                                                title: Text(
                                                                  option['name']!,
                                                                ),
                                                                onTap: () =>
                                                                    onSelected(
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
                                              selectedDays[day] ?? false;
                                          final times =
                                              dayTimes[day] ??
                                              {
                                                'start': const TimeOfDay(
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
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? primaryGreen
                                                            .withOpacity(0.1)
                                                      : Colors.grey[100],
                                                  border: Border.all(
                                                    color: isSelected
                                                        ? primaryGreen
                                                        : Colors.grey[200]!,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            day,
                                                            style: TextStyle(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color: isSelected
                                                                  ? primaryGreen
                                                                  : Colors
                                                                        .grey[600],
                                                            ),
                                                          ),
                                                        ),
                                                        Checkbox(
                                                          value: isSelected,
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
                                                                    color: Colors
                                                                        .grey[600],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () async {
                                                                    final time = await showTimePicker(
                                                                      context:
                                                                          context,
                                                                      initialTime:
                                                                          times['start']!,
                                                                    );
                                                                    if (time !=
                                                                        null) {
                                                                      setState(() {
                                                                        dayTimes[day]!['start'] =
                                                                            time;
                                                                      });
                                                                    }
                                                                  },
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          8,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      border: Border.all(
                                                                        color:
                                                                            primaryGreen,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            4,
                                                                          ),
                                                                    ),
                                                                    child: Text(
                                                                      _formatTimeOfDay(
                                                                        times['start']!,
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color:
                                                                            primaryGreen,
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
                                                                    color: Colors
                                                                        .grey[600],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                GestureDetector(
                                                                  onTap: () async {
                                                                    final time = await showTimePicker(
                                                                      context:
                                                                          context,
                                                                      initialTime:
                                                                          times['end']!,
                                                                    );
                                                                    if (time !=
                                                                        null) {
                                                                      setState(() {
                                                                        dayTimes[day]!['end'] =
                                                                            time;
                                                                      });
                                                                    }
                                                                  },
                                                                  child: Container(
                                                                    padding:
                                                                        const EdgeInsets.all(
                                                                          8,
                                                                        ),
                                                                    decoration: BoxDecoration(
                                                                      border: Border.all(
                                                                        color:
                                                                            primaryGreen,
                                                                      ),
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                            4,
                                                                          ),
                                                                    ),
                                                                    child: Text(
                                                                      _formatTimeOfDay(
                                                                        times['end']!,
                                                                      ),
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            14,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color:
                                                                            primaryGreen,
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
                                          onPressed: () async {
                                            if (selectedScheduleClassId
                                                .isEmpty) {
                                              _log(
                                                "ORAR ERROR: Select class first",
                                              );
                                              return;
                                            }
                                            final selectedDaysList =
                                                selectedDays.entries
                                                    .where((e) => e.value)
                                                    .map((e) => e.key)
                                                    .toList();
                                            if (selectedDaysList.isEmpty) {
                                              _log(
                                                "ORAR ERROR: Select at least one day",
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
                                                <int, Map<String, String>>{};
                                            for (final day
                                                in selectedDaysList) {
                                              final dayNum = dayMapping[day]!;
                                              final times = dayTimes[day]!;
                                              schedulePerDay[dayNum] = {
                                                'start': _formatTimeOfDay(
                                                  times['start']!,
                                                ),
                                                'end': _formatTimeOfDay(
                                                  times['end']!,
                                                ),
                                              };
                                            }
                                            _log(
                                              "DEBUG: Sending schedule per day: $schedulePerDay",
                                            );
                                            try {
                                              await api
                                                  .setClassSchedulePerDay(
                                                    classId:
                                                        selectedScheduleClassId,
                                                    schedulePerDay:
                                                        schedulePerDay,
                                                  )
                                                  .then(
                                                    (_) => _log(
                                                      "SCHEDULE OK: $selectedScheduleClassId for days ${selectedDaysList.join(', ')}",
                                                    ),
                                                  );
                                            } catch (e) {
                                              _log("SCHEDULE ERROR: $e");
                                            }
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
              ],
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
    const Color darkGreen = Color(0xFF2D5A3D);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: hasBorder ? Border.all(color: darkGreen, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
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
        labelStyle: TextStyle(color: Colors.grey[600]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required Color primaryGreen,
    required VoidCallback onPressed,
    bool fullWidth = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        minimumSize: fullWidth ? const Size.fromHeight(48) : const Size(0, 0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: selected ? Colors.white : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? Color.fromARGB(255, 94, 202, 54)
                  : Colors.white.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Color.fromARGB(255, 94, 202, 54)
                    : Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
