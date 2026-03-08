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
    return Scaffold(
      appBar: AppBar(title: const Text("Secretariat (raw prototype)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                ),
              ),
            ElevatedButton(
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
                } catch (e) {
                  _log("CREATE ERROR: $e");
                }
              },
              child: const Text("Create user"),
            ),

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
          ],
        ),
      ),
    );
  }
}
