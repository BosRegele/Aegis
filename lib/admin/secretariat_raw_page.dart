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
import 'admin_turnstiles_page.dart';

class SecretariatRawPage extends StatefulWidget {
  const SecretariatRawPage({super.key});

  @override
  State<SecretariatRawPage> createState() => _SecretariatRawPageState();
}

class _SecretariatRawPageState extends State<SecretariatRawPage> {
  final api = AdminApi();
  final store = AdminStore();

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

  // actions
  final targetUserC = TextEditingController();
  String selectedMoveClassId = "";

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

  Future<void> _pickStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: noExitStart,
    );
    if (picked != null && picked != noExitStart) {
      setState(() {
        noExitStart = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: noExitEnd,
    );
    if (picked != null && picked != noExitEnd) {
      setState(() {
        noExitEnd = picked;
      });
    }
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
    const Color darkGreen = Color.fromARGB(255, 94, 202, 54);

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        title: const Text(
          "Secretariat",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 220,
            height: double.infinity,
            color: darkGreen,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo/Brand
                  Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: primaryGreen,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.school,
                              color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  // Management Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      "MANAGEMENT",
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
                          label: "Class&Students",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminClassesPage()),
                            );
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.people,
                          label: "All Students",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminStudentsPage()),
                            );
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.person,
                          label: "Teachers",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminTeachersPage()),
                            );
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.admin_panel_settings,
                          label: "Admin",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminAdminsPage()),
                            );
                          },
                        ),
                        _buildSidebarItem(
                          icon: Icons.door_front_door,
                          label: "Turnichete",
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminTurnstilesPage()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                              title: "Create User",
                              primaryGreen: primaryGreen,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                    controller: fullNameC,
                                    label: "Full name",
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: usernameC,
                                    label: "Username",
                                  ),
                                  const SizedBox(height: 12),
                                  _buildTextField(
                                    controller: passwordC,
                                    label: "Password",
                                  ),
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey[300]!),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: role,
                                        isExpanded: true,
                                        items: const [
                                          DropdownMenuItem(
                                              value: "student",
                                              child: Text("student")),
                                          DropdownMenuItem(
                                              value: "teacher",
                                              child: Text("teacher")),
                                          DropdownMenuItem(
                                              value: "admin",
                                              child: Text("admin")),
                                          DropdownMenuItem(
                                              value: "gate",
                                              child: Text("gate")),
                                        ],
                                        onChanged: (v) =>
                                            setState(() => role = v ?? "student"),
                                      ),
                                    ),
                                  ),
                                  if (role == "student" || role == "teacher") ...[
                                    const SizedBox(height: 12),
                                    StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('classes')
                                          .orderBy('name')
                                          .snapshots(),
                                      builder: (context, snap) {
                                        if (snap.hasError) {
                                          return Text("Eroare clase: ${snap.error}",
                                              style: const TextStyle(color: Colors.red));
                                        }
                                        if (!snap.hasData) {
                                          return const CircularProgressIndicator();
                                        }

                                        final docs = snap.data!.docs;
                                        final classOptions = docs.map((doc) {
                                          final data = doc.data() as Map<String, dynamic>;
                                          return {
                                            'id': doc.id,
                                            'name': (data['name'] ?? doc.id).toString(),
                                          };
                                        }).toList();

                                        return Autocomplete<Map<String, String>>(
                                          initialValue: TextEditingValue(
                                            text: classOptions
                                                .where((option) => option['id'] == selectedCreateUserClassId)
                                                .map((option) => option['name']!)
                                                .firstWhere((_) => false, orElse: () => ''),
                                          ),
                                          optionsBuilder: (TextEditingValue textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return classOptions;
                                            }
                                            return classOptions.where((option) =>
                                              option['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase())
                                            ).toList();
                                          },
                                          displayStringForOption: (option) => option['name']!,
                                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                            return TextFormField(
                                              controller: textEditingController,
                                              focusNode: focusNode,
                                              decoration: InputDecoration(
                                                labelText: "Select class",
                                                hintText: "Type to search classes...",
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey[50],
                                              ),
                                            );
                                          },
                                          optionsViewBuilder: (context, onSelected, options) {
                                            return Align(
                                              alignment: Alignment.topLeft,
                                              child: Material(
                                                elevation: 4.0,
                                                child: Container(
                                                  width: MediaQuery.of(context).size.width * 0.3,
                                                  constraints: const BoxConstraints(maxHeight: 200),
                                                  child: ListView.builder(
                                                    padding: EdgeInsets.zero,
                                                    shrinkWrap: true,
                                                    itemCount: options.length,
                                                    itemBuilder: (context, index) {
                                                      final option = options.elementAt(index);
                                                      return ListTile(
                                                        title: Text(option['name']!),
                                                        onTap: () => onSelected(option),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                          onSelected: (option) {
                                            setState(() {
                                              selectedCreateUserClassId = option['id']!;
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
                                          label: "Generate",
                                          primaryGreen: primaryGreen,
                                          onPressed: _generateCreds,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildButton(
                                          label: "Copy",
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
                                    label: "Create user",
                                    primaryGreen: primaryGreen,
                                    fullWidth: true,
                                    onPressed: () async {
                                      try {
                                        final u =
                                            FirebaseAuth.instance.currentUser;
                                        _log("AUTH user = ${u?.uid} | email=${u?.email}");

                                        // cloud function
                                        final res = await api.createUser(
                                          username: usernameC.text,
                                          password: passwordC.text,
                                          role: role,
                                          fullName: fullNameC.text,
                                          classId: role == "student" || role == "teacher"
                                              ? selectedCreateUserClassId
                                              : null,
                                        );
                                        _log(
                                            "API CREATE OK: ${usernameC.text} | uid=${res['uid']}");

                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text("User creat: ${usernameC.text}"),
                                            backgroundColor: Colors.green,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );

                                      } catch (e) {
                                        _log("CREATE ERROR: $e");
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Create Class Card
                            _buildCard(
                              title: "Create Class",
                              primaryGreen: primaryGreen,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<int>(
                                              value: selectedNumber,
                                              isExpanded: true,
                                              items: List.generate(13, (i) => i).map((num) {
                                                return DropdownMenuItem(
                                                    value: num,
                                                    child: Text(num.toString()));
                                              }).toList(),
                                              onChanged: (v) =>
                                                  setState(() => selectedNumber = v ?? 9),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: Colors.grey[300]!),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: selectedLetter,
                                              isExpanded: true,
                                              items: List.generate(26, (i) => String.fromCharCode(65 + i)).map((letter) {
                                                return DropdownMenuItem(
                                                    value: letter,
                                                    child: Text(letter));
                                              }).toList(),
                                              onChanged: (v) =>
                                                  setState(() => selectedLetter = v ?? "A"),
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
                                          label: "Create/Update",
                                          primaryGreen: primaryGreen,
                                          onPressed: () async {
                                            final classId = "$selectedNumber$selectedLetter";
                                            try {
                                              await api
                                                  .createClass(
                                                    name: classId,
                                                  )
                                                  .then((_) =>
                                                      _log(
                                                          "CLASS OK: $classId"));
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text("Clasă creată: $classId"),
                                                  backgroundColor: Colors.green,
                                                  duration: const Duration(seconds: 2),
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
                                            final classId = "$selectedNumber$selectedLetter";
                                            try {
                                              await api.deleteClassCascade(
                                                  classId: classId);
                                              _log(
                                                  "DELETE CLASS OK: $classId");
                                            } catch (e) {
                                              _log("DELETE CLASS ERROR: $e");
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[600],
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                          child: const Text(
                                            "Delete",
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
                              title: "Reset / Disable",
                              primaryGreen: primaryGreen,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTextField(
                                    controller: targetUserC,
                                    label: "Target username",
                                  ),
                                  const SizedBox(height: 16),
                                  _buildButton(
                                    label: "Reset Password",
                                    primaryGreen: primaryGreen,
                                    onPressed: () async {
                                      try {
                                        final res =
                                            await api.resetPassword(
                                              username: targetUserC.text,
                                            );
                                        final newPass = res['password'];
                                        _log("RESET OK: newPass=$newPass");
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text("Parola noua: $newPass"),
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
                                          label: "Disable",
                                          primaryGreen: primaryGreen,
                                          onPressed: () async {
                                            try {
                                              await api.setDisabled(
                                                username: targetUserC.text,
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
                                          label: "Enable",
                                          primaryGreen: primaryGreen,
                                          onPressed: () async {
                                            try {
                                              await api.setDisabled(
                                                username: targetUserC.text,
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
                                        return Text("Eroare clase: ${snap.error}",
                                            style: const TextStyle(color: Colors.red));
                                      }
                                      if (!snap.hasData) {
                                        return const CircularProgressIndicator();
                                      }

                                      final docs = snap.data!.docs;
                                      final classOptions = docs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        return {
                                          'id': doc.id,
                                          'name': (data['name'] ?? doc.id).toString(),
                                        };
                                      }).toList();

                                      return Autocomplete<Map<String, String>>(
                                        initialValue: TextEditingValue(
                                          text: classOptions
                                              .where((option) => option['id'] == selectedMoveClassId)
                                              .map((option) => option['name']!)
                                              .firstWhere((_) => false, orElse: () => ''),
                                        ),
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return classOptions;
                                          }
                                          return classOptions.where((option) =>
                                            option['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase())
                                          ).toList();
                                        },
                                        displayStringForOption: (option) => option['name']!,
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          return TextFormField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            decoration: InputDecoration(
                                              labelText: "Select class",
                                              hintText: "Type to search classes...",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[50],
                                            ),
                                          );
                                        },
                                        optionsViewBuilder: (context, onSelected, options) {
                                          return Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              elevation: 4.0,
                                              child: Container(
                                                width: MediaQuery.of(context).size.width * 0.3,
                                                constraints: const BoxConstraints(maxHeight: 200),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder: (context, index) {
                                                    final option = options.elementAt(index);
                                                    return ListTile(
                                                      title: Text(option['name']!),
                                                      onTap: () => onSelected(option),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        onSelected: (option) {
                                          setState(() {
                                            selectedMoveClassId = option['id']!;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  _buildButton(
                                    label: "Move student",
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
                                    label: "Delete user",
                                    primaryGreen: Colors.red[600]!,
                                    onPressed: () async {
                                      final uname = targetUserC.text.trim().toLowerCase();
                                      if (uname.isEmpty) {
                                        _log("DELETE ERROR: username gol");
                                        return;
                                      }
                                      try {
                                        // try cloud function first
                                        final res = await api.deleteUser(username: uname);
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
                              title: "Class schedule",
                              primaryGreen: primaryGreen,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance
                                        .collection('classes')
                                        .orderBy('name')
                                        .snapshots(),
                                    builder: (context, snap) {
                                      if (snap.hasError) {
                                        return Text("Eroare clase: ${snap.error}",
                                            style: const TextStyle(color: Colors.red));
                                      }
                                      if (!snap.hasData) {
                                        return const CircularProgressIndicator();
                                      }

                                      final docs = snap.data!.docs;
                                      final classOptions = docs.map((doc) {
                                        final data = doc.data() as Map<String, dynamic>;
                                        return {
                                          'id': doc.id,
                                          'name': (data['name'] ?? doc.id).toString(),
                                        };
                                      }).toList();

                                      return Autocomplete<Map<String, String>>(
                                        initialValue: TextEditingValue(
                                          text: classOptions
                                              .where((option) => option['id'] == selectedScheduleClassId)
                                              .map((option) => option['name']!)
                                              .firstWhere((_) => false, orElse: () => ''),
                                        ),
                                        optionsBuilder: (TextEditingValue textEditingValue) {
                                          if (textEditingValue.text.isEmpty) {
                                            return classOptions;
                                          }
                                          return classOptions.where((option) =>
                                            option['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase())
                                          ).toList();
                                        },
                                        displayStringForOption: (option) => option['name']!,
                                        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                          return TextFormField(
                                            controller: textEditingController,
                                            focusNode: focusNode,
                                            decoration: InputDecoration(
                                              labelText: "Select class",
                                              hintText: "Type to search classes...",
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              filled: true,
                                              fillColor: Colors.grey[50],
                                            ),
                                          );
                                        },
                                        optionsViewBuilder: (context, onSelected, options) {
                                          return Align(
                                            alignment: Alignment.topLeft,
                                            child: Material(
                                              elevation: 4.0,
                                              child: Container(
                                                width: MediaQuery.of(context).size.width * 0.3,
                                                constraints: const BoxConstraints(maxHeight: 200),
                                                child: ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  itemCount: options.length,
                                                  itemBuilder: (context, index) {
                                                    final option = options.elementAt(index);
                                                    return ListTile(
                                                      title: Text(option['name']!),
                                                      onTap: () => onSelected(option),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                        onSelected: (option) {
                                          setState(() {
                                            selectedScheduleClassId = option['id']!;
                                          });
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _pickStartTime,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Program start: ${_formatTimeOfDay(noExitStart)}",
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: GestureDetector(
                                          onTap: _pickEndTime,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[50],
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: Colors.grey[300]!),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.access_time, size: 20, color: Colors.grey),
                                                const SizedBox(width: 8),
                                                Text(
                                                  "Program end: ${_formatTimeOfDay(noExitEnd)}",
                                                  style: const TextStyle(fontSize: 16),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _buildButton(
                                    label: "Save schedule",
                                    primaryGreen: primaryGreen,
                                    onPressed: () async {
                                      if (selectedScheduleClassId.isEmpty) {
                                        _log("ORAR ERROR: Select class first");
                                        return;
                                      }
                                      try {
                                        await api
                                            .setClassNoExitSchedule(
                                              classId: selectedScheduleClassId,
                                              startHHmm: _formatTimeOfDay(noExitStart),
                                              endHHmm: _formatTimeOfDay(noExitEnd),
                                            )
                                            .then((_) => _log(
                                                "SCHEDULE OK: $selectedScheduleClassId ${_formatTimeOfDay(noExitStart)}-${_formatTimeOfDay(noExitEnd)}"));
                                      } catch (e) {
                                        _log("SCHEDULE ERROR: $e");
                                      }
                                    },
                                    fullWidth: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Log Section
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
                                  border: Border.all(color: Colors.grey[300]!),
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
                    ],
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
    bool hasBorder = true,
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
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: Color(0xFF4A7C59), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        minimumSize:
            fullWidth ? const Size.fromHeight(48) : const Size(0, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.transparent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: Colors.white.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}