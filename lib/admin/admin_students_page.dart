import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'admin_store.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final store = AdminStore();
  final searchC = TextEditingController();
  String q = "";

  @override
  void dispose() {
    searchC.dispose();
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
        title: const Text(
          "Admin · All Students",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                hintText: "Search by username, full name or class...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            ),
          ),

          const Divider(height: 1),

          /// STUDENTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: SelectableText("Eroare:\n${snap.error}"),
                  );
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

                final filtered = docs.where((d) {
                  if (q.isEmpty) return true;

                  final data = d.data() as Map<String, dynamic>;
                  final uid = d.id;
                  final username = (data['username'] ?? uid).toString();
                  final fullName = (data['fullName'] ?? username).toString();
                  final classId = (data['classId'] ?? '')
                      .toString()
                      .toLowerCase();

                  return username.contains(q) ||
                      fullName.contains(q) ||
                      classId.contains(q);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text("Nu există rezultate"));
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final data = d.data() as Map<String, dynamic>;

                    final uid = d.id;
                    final username = (data['username'] ?? uid).toString();
                    final fullName = (data['fullName'] ?? username).toString();
                    final classId = (data['classId'] ?? '').toString();
                    final status = (data['status'] ?? 'active').toString();

                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.2),
                            child: const Icon(Icons.person),
                          ),
                          title: Text(
                            fullName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "user: $username | clasă: $classId | $status",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openStudentDialog(
                            context,
                            username: username,
                            fullName: fullName,
                            classId: classId,
                            status: status,
                            parentIds: List<String>.from(data['parents'] ?? []),
                          ),
                        ),
                        Divider(height: 1, color: darkGreen.withOpacity(0.3)),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStudentDialog(
    BuildContext context, {
    required String username,
    required String fullName,
    required String classId,
    required String status,
    required List<String> parentIds,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(fullName),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                "username: $username\nclassId: $classId\nstatus: $status",
              ),
              if (parentIds.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Părinți:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<DocumentSnapshot>>(
                  future: Future.wait(
                    parentIds.map(
                      (id) => FirebaseFirestore.instance
                          .collection('users')
                          .doc(id)
                          .get(),
                    ),
                  ),
                  builder: (context, psnap) {
                    if (psnap.hasError) return const SizedBox.shrink();
                    if (!psnap.hasData) {
                      return const CircularProgressIndicator();
                    }
                    final docs = psnap.data!;
                    if (docs.isEmpty) return const Text('Niciun părinte');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...docs.map((ds) {
                          final md = ds.data() as Map<String, dynamic>? ?? {};
                          final pname =
                              (md['fullName'] ?? md['username'] ?? ds.id)
                                  .toString();
                          final pun = (md['username'] ?? ds.id).toString();
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Expanded(child: Text(pname)),
                                Text(
                                  'user: $pun',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
          TextButton(
            onPressed: () async {
              await store.setDisabled(username, status != 'disabled');
              if (mounted) Navigator.pop(context);
            },
            child: Text(status == 'disabled' ? "Enable" : "Disable"),
          ),
          TextButton(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete user?"),
                  content: Text("Ștergi elevul: $username ?"),
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
                await store.deleteUser(username);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
