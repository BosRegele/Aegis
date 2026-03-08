import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
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
  final classIdC = TextEditingController();

  String role = "student";

  // orar
  final scheduleClassC = TextEditingController();
  final noExitStartC = TextEditingController(text: "07:30");
  final noExitEndC = TextEditingController(text: "12:30");

  // actions
  final targetUserC = TextEditingController();
  final moveClassC = TextEditingController();

  // class
  final newClassC = TextEditingController();

  String log = "";
  final _rng = Random.secure();

  void _log(String s) => setState(() => log = "$s\n$log");

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
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
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Copiat in clipboard ✅")));
  }

  void _generateCreds() {
    final full = fullNameC.text.trim();
    final base = _baseFromFullName(full);
    final uname = "${base}${_randDigits(3)}";
    final pass = _randPassword(10);

    setState(() {
      usernameC.text = uname;
      passwordC.text = pass;
    });

    _log("GENERATED: $uname / $pass");
  }

  @override
  void dispose() {
    fullNameC.dispose();
    usernameC.dispose();
    passwordC.dispose();
    classIdC.dispose();
    scheduleClassC.dispose();
    noExitStartC.dispose();
    noExitEndC.dispose();
    targetUserC.dispose();
    moveClassC.dispose();
    newClassC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B5E20),
        elevation: 12,
        shadowColor: const Color(0xFF1B5E20).withOpacity(0.4),
        title: const Text(
          "Secretariat",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: Container(
        color: Colors.grey[50],
        child: isMobile
            ? _buildMobileLayout()
            : _buildDesktopLayout(),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildManagementSection(),
          const SizedBox(height: 20),
          _buildCreateUserCard(),
          const SizedBox(height: 16),
          _buildResetDisableMoveCard(),
          const SizedBox(height: 16),
          _buildCreateClassCard(),
          const SizedBox(height: 16),
          _buildScheduleCard(),
          const SizedBox(height: 20),
          _buildLogCard(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // Sidebar
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            image: DecorationImage(
              image: AssetImage('assets/sidebar_texture.png'),
              fit: BoxFit.cover,
              opacity: 0.15,
            ),
          ),
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildManagementSection(),
              // ...existing code...
            ],
          ),
        ),
        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _buildCreateUserCard(),
                      const SizedBox(height: 16),
                      _buildResetDisableMoveCard(),
                      const SizedBox(height: 16),
                      _buildLogCard(),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      _buildCreateClassCard(),
                      const SizedBox(height: 16),
                      _buildScheduleCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManagementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            "MANAGEMENT",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E7D32),
              letterSpacing: 1,
            ),
          ),
        ),
        _buildManagemtButton(
          "Clase și Elevi",
          "📋",
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminClassesPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildManagemtButton(
          "Toți Elevii",
          "👥",
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminStudentsPage()),
            );
          },
        ),
        const SizedBox(height: 12),
        _buildManagemtButton(
          "Toți Profesorii",
          "👨‍🏫",
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminTeachersPage()),
            );
          },
        ),
      ],
    );
  }

  Widget _buildManagemtButton(String label, String icon, VoidCallback onPressed) {
    return Material(
      color: Colors.grey[50],
      borderRadius: BorderRadius.circular(8),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          side: const BorderSide(color: Colors.black, width: 1),
          backgroundColor: Colors.grey[50],
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          elevation: 0,
        ),
        child: Row(
          children: [
<<<<<<< HEAD
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w500,
=======
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminClassesPage()),
                );
              },
              child: const Text("Vezi clase + elevi"),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminStudentsPage(),
                          ),
                        );
                      },
                      child: const Text("Toti elevii"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminTeachersPage(),
                          ),
                        );
                      },
                      child: const Text("Toti profesorii"),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminAdminsPage(),
                          ),
                        );
                      },
                      child: const Text("Toti administratorii"),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminTurnstilesPage(),
                          ),
                        );
                      },
                      child: const Text("Turnichete"),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Text("1) Create user"),
            TextField(
              controller: fullNameC,
              decoration: const InputDecoration(labelText: "Full name"),
            ),
            TextField(
              controller: usernameC,
              decoration: const InputDecoration(labelText: "Username"),
            ),
            TextField(
              controller: passwordC,
              decoration: const InputDecoration(labelText: "Password"),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _generateCreds,
                  child: const Text("Generate user + pass"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    _copy(
                      "username: ${usernameC.text}\npassword: ${passwordC.text}",
                    );
                  },
                  child: const Text("Copy creds"),
                ),
              ],
            ),
            DropdownButton<String>(
              value: role,
              items: const [
                DropdownMenuItem(value: "student", child: Text("student")),
                DropdownMenuItem(value: "teacher", child: Text("teacher")),
                DropdownMenuItem(value: "admin", child: Text("admin")),
                DropdownMenuItem(value: "gate", child: Text("gate")),
              ],
              onChanged: (v) => setState(() => role = v ?? "student"),
            ),
            if (role == "student" || role == "teacher")
              TextField(
                controller: classIdC,
                decoration: const InputDecoration(
                  labelText: "ClassId (ex: 10A)",
>>>>>>> 89acbf800162dadcc44ea54211649b84759478b1
                ),
              ),
            ),
<<<<<<< HEAD
=======

            const Divider(),
            const Text("2) Reset / Disable / Move"),
            TextField(
              controller: targetUserC,
              decoration: const InputDecoration(labelText: "Target username"),
            ),
            Row(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    try {
                      final res = await api.resetPassword(
                        username: targetUserC.text,
                      );
                      final newPass = res['password'];
                      _log("RESET OK: newPass=$newPass");
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Parola noua: $newPass")),
                      );
                    } catch (e) {
                      _log("RESET ERROR: $e");
                    }
                  },
                  child: const Text("Reset password"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
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
                  child: const Text("Disable"),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
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
                  child: const Text("Enable"),
                ),
              ],
            ),
            TextField(
              controller: moveClassC,
              decoration: const InputDecoration(labelText: "Move to classId"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.moveStudentClass(
                    username: targetUserC.text,
                    newClassId: moveClassC.text,
                  );
                  _log("MOVE OK");
                } catch (e) {
                  _log("MOVE ERROR: $e");
                }
              },
              child: const Text("Move student"),
            ),

            const Divider(),
            const Text("3) Create class"),
            TextField(
              controller: newClassC,
              decoration: const InputDecoration(labelText: "ClassId (ex: 10A)"),
            ),

            const Divider(),
            const Text("4) Orare (luni–vineri)"),
            TextField(
              controller: scheduleClassC,
              decoration: const InputDecoration(labelText: "ClassId (ex: 10A)"),
            ),
            TextField(
              controller: noExitStartC,
              decoration: const InputDecoration(
                labelText: "Nu iesi de la (HH:mm)",
              ),
            ),
            TextField(
              controller: noExitEndC,
              decoration: const InputDecoration(
                labelText: "Nu iesi pana la (HH:mm)",
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.setClassNoExitSchedule(
                    classId: scheduleClassC.text,
                    startHHmm: noExitStartC.text,
                    endHHmm: noExitEndC.text,
                  );
                  _log(
                    "ORAR OK: ${scheduleClassC.text} ${noExitStartC.text}-${noExitEndC.text}",
                  );
                } catch (e) {
                  _log("ORAR ERROR: $e");
                }
              },
              child: const Text("Salveaza orarul"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.createClass(name: newClassC.text);
                  _log("CLASS OK: ${newClassC.text}");
                } catch (e) {
                  _log("CLASS ERROR: $e");
                }
              },
              child: const Text("Create/Update class"),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await api.deleteClassCascade(classId: newClassC.text);
                  _log("DELETE CLASS OK: ${newClassC.text}");
                } catch (e) {
                  _log("DELETE CLASS ERROR: $e");
                }
              },
              child: const Text("Delete class (cu elevi + profesor)"),
            ),

            const Divider(),
            const Text("LOG"),
            SelectableText(log.isEmpty ? "(empty)" : log),
>>>>>>> 89acbf800162dadcc44ea54211649b84759478b1
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader(String title) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCreateUserCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF1B5E20).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("1) Creare Utilizator"),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: fullNameC,
                  decoration: InputDecoration(
                    labelText: "Full name",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: usernameC,
                  decoration: InputDecoration(
                    labelText: "Username",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordC,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        label: const Text(
                          "Generate",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: _generateCreds,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.copy, color: Colors.white),
                        label: const Text(
                          "Copy",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        onPressed: () {
                          _copy(
                            "username: ${usernameC.text}\npassword: ${passwordC.text}",
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: role,
                  items: const [
                    DropdownMenuItem(value: "student", child: Text("student")),
                    DropdownMenuItem(value: "teacher", child: Text("teacher")),
                    DropdownMenuItem(value: "admin", child: Text("admin")),
                    DropdownMenuItem(value: "gate", child: Text("gate")),
                  ],
                  onChanged: (v) => setState(() => role = v ?? "student"),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                if (role == "student" || role == "teacher") ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: classIdC,
                    decoration: InputDecoration(
                      labelText: "ClassId (ex: 10A)",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check, color: Colors.white),
                    label: const Text(
                      "Create user",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () async {
                      try {
                        final u = FirebaseAuth.instance.currentUser;
                        _log("AUTH user = ${u?.uid} | email=${u?.email}");

                        final res = await api.createUser(
                          username: usernameC.text,
                          password: passwordC.text,
                          role: role,
                          fullName: fullNameC.text,
                          classId: role == "student" || role == "teacher"
                              ? classIdC.text
                              : null,
                        );

                        _log("CREATE OK: ${usernameC.text} | uid=${res['uid']}");
                        _showSuccessSnackBar("✅ Utilizator creat: ${usernameC.text}");
                      } catch (e) {
                        _log("CREATE ERROR: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Colors.black, width: 1),
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

  Widget _buildResetDisableMoveCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF1B5E20).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("2) Reset / Disable / Move"),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: targetUserC,
                  decoration: InputDecoration(
                    labelText: "Target username",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            final res = await api.resetPassword(
                              uid: targetUserC.text,
                            );
                            final newPass = res['password'];
                            _log("RESET OK: newPass=$newPass");
                            _showSuccessSnackBar("🔄 Parolă resetată pentru: ${targetUserC.text}");
                          } catch (e) {
                            _log("RESET ERROR: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          "Reset Password",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await api.setDisabled(
                              uid: targetUserC.text,
                              disabled: true,
                            );
                            _log("DISABLE OK");
                            _showSuccessSnackBar("🚫 Utilizator dezactivat: ${targetUserC.text}");
                          } catch (e) {
                            _log("DISABLE ERROR: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          "Disable",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await api.setDisabled(
                              uid: targetUserC.text,
                              disabled: false,
                            );
                            _log("ENABLE OK");
                            _showSuccessSnackBar("✅ Utilizator activat: ${targetUserC.text}");
                          } catch (e) {
                            _log("ENABLE ERROR: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          "Enable",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: moveClassC,
                  decoration: InputDecoration(
                    labelText: "Move to classId",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await api.moveStudentClass(
                          uid: targetUserC.text,
                          newClassId: moveClassC.text,
                        );
                        _log("MOVE OK");
                        _showSuccessSnackBar("📦 Elev mutat în clasa: ${moveClassC.text}");
                      } catch (e) {
                        _log("MOVE ERROR: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    child: const Text(
                      "Move student",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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

  Widget _buildCreateClassCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF1B5E20).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("3) Create class"),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: newClassC,
                  decoration: InputDecoration(
                    labelText: "ClassId (ex: 10A)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await store.createClass(classId: newClassC.text);
                            _log("CLASS OK: ${newClassC.text}");
                            _showSuccessSnackBar("🏫 Clasă creată/actualizată: ${newClassC.text}");
                          } catch (e) {
                            _log("CLASS ERROR: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4CAF50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          "Create/Update",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await store.deleteClassCascade(newClassC.text);
                            _log("DELETE CLASS OK: ${newClassC.text}");
                            _showSuccessSnackBar("🗑️ Clasă ștearsă: ${newClassC.text}");
                          } catch (e) {
                            _log("DELETE CLASS ERROR: $e");
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: const BorderSide(color: Colors.black, width: 1),
                        ),
                        child: const Text(
                          "Delete",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildScheduleCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF1B5E20).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("4) Orar (luni–vineri)"),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: scheduleClassC,
                  decoration: InputDecoration(
                    labelText: "ClassId (ex: 10A)",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: noExitStartC,
                        decoration: InputDecoration(
                          labelText: "Nu iesi de la",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: noExitEndC,
                        decoration: InputDecoration(
                          labelText: "Nu iesi pana la",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await store.setClassNoExitSchedule(
                          classId: scheduleClassC.text,
                          startHHmm: noExitStartC.text,
                          endHHmm: noExitEndC.text,
                        );
                        _log(
                          "ORAR OK: ${scheduleClassC.text} ${noExitStartC.text}-${noExitEndC.text}",
                        );
                        _showSuccessSnackBar("📅 Orar salvat pentru clasa: ${scheduleClassC.text}");
                      } catch (e) {
                        _log("ORAR ERROR: $e");
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4CAF50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: const BorderSide(color: Colors.black, width: 1),
                    ),
                    child: const Text(
                      "Salveaza orarul",
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
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

  Widget _buildLogCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      shadowColor: const Color(0xFF1B5E20).withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader("LOG"),
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              constraints: const BoxConstraints(maxHeight: 300),
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
    );
  }
}
