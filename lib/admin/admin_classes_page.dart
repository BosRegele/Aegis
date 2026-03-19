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
    const Color primaryGreen = Color(0xFF7AAF5B);

    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7AAF5B), Color(0xFF5A9641)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Clase & Elevi",
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Row(
        children: [
          // LEFT: classes sidebar
          Container(
            width: 280,
            color: const Color(0xFF5C8B42),
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
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.60),
                      ),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.10),
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

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (selectedClassId == d.id) return;
                                  setState(() {
                                    selectedClassId = d.id;
                                    selectedClassData = data;
                                  });
                                },
                                borderRadius: BorderRadius.circular(18),
                                hoverColor: Colors.white.withValues(
                                  alpha: 0.05,
                                ),
                                splashColor: Colors.white.withValues(
                                  alpha: 0.04,
                                ),
                                highlightColor: Colors.white.withValues(
                                  alpha: 0.03,
                                ),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF9AC972)
                                          : Colors.white.withValues(
                                              alpha: 0.07,
                                            ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? const Color(0xFF40632D)
                                              : Colors.white,
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                      teacherU.isEmpty
                                          ? Text(
                                              'Diriginte: (nepus)',
                                              style: TextStyle(
                                                color: isSelected
                                                    ? const Color(0xFF355126)
                                                    : Colors.white.withValues(
                                                        alpha: 0.70,
                                                      ),
                                                fontSize: 11,
                                              ),
                                            )
                                          : StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('users')
                                                  .where(
                                                    'username',
                                                    isEqualTo: teacherU,
                                                  )
                                                  .limit(1)
                                                  .snapshots(),
                                              builder: (context, snap) {
                                                String displayName = teacherU;
                                                if (snap.hasData &&
                                                    snap
                                                        .data!
                                                        .docs
                                                        .isNotEmpty) {
                                                  final u =
                                                      snap.data!.docs.first
                                                              .data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  final fn =
                                                      (u['fullName'] ?? '')
                                                          .toString()
                                                          .trim();
                                                  if (fn.isNotEmpty)
                                                    displayName = fn;
                                                }
                                                return Text(
                                                  'Diriginte: $displayName',
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF355126,
                                                          )
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.70,
                                                              ),
                                                    fontSize: 11,
                                                  ),
                                                );
                                              },
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
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
                            color: primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Icon(
                            Icons.school,
                            size: 50,
                            color: primaryGreen.withValues(alpha: 0.50),
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
                        updated.remove("teacherUsername");
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

    // noExit schedule removed from header display

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
                ],
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: teacherUsername)
          .limit(1)
          .snapshots(),
      builder: (context, snap) {
        String teacherName = teacherUsername;
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final u = snap.data!.docs.first.data() as Map<String, dynamic>;
          final fn = (u['fullName'] ?? '').toString().trim();
          if (fn.isNotEmpty) teacherName = fn;
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
                      "Clasa: $classId  |  Diriginte: ${teacherName.trim().isEmpty ? '(nepus)' : teacherName} | $teacherUsername",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
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
            final username = (data['username'] ?? '').toString();
            final fullName = (data['fullName'] ?? username).toString();
            final inSchool = data['inSchool'] as bool? ?? false;

            return Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFCDE8B0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                title: Text(fullName),
                subtitle: Text("username: $username"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: inSchool
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: inSchool
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFF44336),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            inSchool ? Icons.location_on : Icons.location_off,
                            color: inSchool
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF44336),
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            inSchool ? 'In scoala' : 'Afara',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: inSchool
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
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
                                onPressed: () => Navigator.pop(context, false),
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
            );
          },
        );
      },
    );
  }
}
