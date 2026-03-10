import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'admin_store.dart';
import 'package:cloud_functions/cloud_functions.dart';

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key});

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  final store = AdminStore();

  String? selectedClassId;
  Map<String, dynamic>? selectedClassData;

  // pentru dialog change teacher
  final teacherUserC = TextEditingController();

  final _teacherSearchC = TextEditingController();

  // pentru căutare clase
  final _classSearchC = TextEditingController();
  String _classQuery = "";

  @override
  void dispose() {
    teacherUserC.dispose();
    _teacherSearchC.dispose();
    _classSearchC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color.fromARGB(255, 94, 184, 78);
    const Color lightGreen = Color(0xFFF0F4E8);
    const Color darkGreen = Color.fromARGB(255, 94, 202, 54);

    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Admin · Clase & Elevi",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
      ),
      body: Row(
        children: [
          // LEFT: classes sidebar
          Container(
            width: 280,
            color: darkGreen,
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _classSearchC,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Caută clasă...",
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _classQuery = value.toLowerCase().trim();
                      });
                    },
                  ),
                ),
                // Classes list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('classes')
                        .orderBy('name')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: SelectableText("Eroare clase:\n${snap.error}"),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = snap.data!.docs;
                      if (docs.isEmpty) {
                        return const Center(child: Text("Nu exista clase"));
                      }

                      // Filter classes based on search query
                      final filteredDocs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final name = (data['name'] ?? doc.id)
                            .toString()
                            .toLowerCase();
                        final teacherU = (data['teacherUsername'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(_classQuery) ||
                            teacherU.contains(_classQuery);
                      }).toList();

                      return ListView.builder(
                        itemCount: filteredDocs.length,
                        itemBuilder: (_, i) {
                          final d = filteredDocs[i];
                          final data = (d.data() as Map<String, dynamic>);
                          final name = (data['name'] ?? d.id).toString();
                          final teacherU = (data['teacherUsername'] ?? '')
                              .toString()
                              .trim()
                              .toLowerCase();
                          final isSelected = selectedClassId == d.id;

                          return Column(
                            children: [
                              Container(
                                color: isSelected
                                    ? Colors.white.withOpacity(0.15)
                                    : null,
                                child: ListTile(
                                  title: Text(
                                    name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    teacherU.isEmpty
                                        ? "Diriginte: (nepus)"
                                        : "Diriginte: $teacherU",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                  onTap: () {
                                    if (selectedClassId == d.id) return;
                                    setState(() {
                                      selectedClassId = d.id;
                                      selectedClassData = data;
                                    });
                                  },
                                ),
                              ),
                              Divider(
                                height: 1,
                                color: Colors.white.withOpacity(0.2),
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

          const VerticalDivider(width: 1),

          // RIGHT: selected class details + students
          Expanded(
            child: selectedClassId == null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: primaryGreen.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.school,
                            size: 50,
                            color: primaryGreen.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Selecteazà o clasă din stânga",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Alege o clasă din lista din stânga pentru\na vedea elevii.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF777777),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TeacherHeader(
                        classId: selectedClassId!,
                        classData: selectedClassData,
                        onChangeTeacher: _openChangeTeacherDialog,
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: _StudentsList(
                          classId: selectedClassId!,
                          store: store,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
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
      "username": username,
      "password": password,
      "role": role,
      "classId": classId,
      "fullName": fullName,
    });
  }

  Future<void> _openChangeTeacherDialog(
    String classId,
    String currentTeacherUsername,
  ) async {
    teacherUserC.text = currentTeacherUsername;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text("Change teacher for $classId"),
        content: TextField(
          controller: teacherUserC,
          decoration: const InputDecoration(
            labelText: "teacher username (gol = scoate dirigintele)",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final newTeacher = teacherUserC.text.trim().toLowerCase();

                await store.changeClassTeacher(
                  classId: classId,
                  teacherUsername: newTeacher,
                );

                if (mounted) {
                  setState(() {
                    if (selectedClassId == classId &&
                        selectedClassData != null) {
                      final updated = {...selectedClassData!};

                      if (newTeacher.isEmpty) {
                        updated.remove(
                          "teacherUsername",
                        ); // ca în DB (FieldValue.delete)
                      } else {
                        updated["teacherUsername"] = newTeacher;
                      }

                      selectedClassData = updated;
                    }
                  });

                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Eroare: $e")));
                }
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  final String classId;
  final Map<String, dynamic>? classData;
  final Future<void> Function(String classId, String currentTeacherUsername)
  onChangeTeacher;

  const _TeacherHeader({
    required this.classId,
    required this.classData,
    required this.onChangeTeacher,
  });

  @override
  Widget build(BuildContext context) {
    final teacherUsername = (classData?['teacherUsername'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // ✅ schedule fields din documentul clasei
    final noExitStart = (classData?['noExitStart'] ?? '').toString().trim();
    final noExitEnd = (classData?['noExitEnd'] ?? '').toString().trim();

    final scheduleText = (noExitStart.isNotEmpty && noExitEnd.isNotEmpty)
        ? "Nu poti iesi: $noExitStart - $noExitEnd (L-V)"
        : "Nu poti iesi: (nesetat)";

    // ✅ dacă nu există diriginte -> NU StreamBuilder
    if (teacherUsername.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Diriginte: (nepus)",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(scheduleText, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // dacă există diriginte -> citim numele din users/{username}
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUsername)
          .snapshots(),
      builder: (context, snap) {
        String teacherName = "(nepus)";
        if (snap.hasData && snap.data!.exists) {
          final u = snap.data!.data() as Map<String, dynamic>;
          teacherName = (u['fullName'] ?? teacherUsername).toString();
        } else {
          teacherName = teacherUsername; // fallback
        }

        return Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Clasa: $classId  |  Diriginte: ${teacherName.trim().isEmpty ? '(nepus)' : teacherName}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(scheduleText, style: const TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StudentsList extends StatelessWidget {
  final String classId;
  final AdminStore store;

  const _StudentsList({required this.classId, required this.store});

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color.fromARGB(255, 94, 184, 78);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: SelectableText("Eroare elevi:\n${snap.error}"));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
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

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final uid = d.id;
            final username = (data['username'] ?? '').toString();
            final fullName = (data['fullName'] ?? username).toString();
            final status = (data['status'] ?? 'active').toString();

            return Column(
              children: [
                ListTile(
                  title: Text(fullName),
                  subtitle: Text(
                    "username: $username | uid: $uid | status: $status",
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: "Delete user",
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFE53935),
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Delete user?"),
                              content: Text("Stergi user: $username ?"),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text("Delete"),
                                ),
                              ],
                            ),
                          );

                          if (ok == true) {
                            try {
                              await store.deleteUser(username);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Eroare: $e")),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: primaryGreen.withOpacity(0.3)),
              ],
            );
          },
        );
      },
    );
  }
}
