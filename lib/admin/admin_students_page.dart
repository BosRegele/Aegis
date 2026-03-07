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
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Admin: Toti elevii")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchC,
              decoration: const InputDecoration(
                labelText: "Search (username / nume / clasa)",
              ),
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'student')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(
                    child: SelectableText("Eroare:\n${snap.error}"),
                  );
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

                final docs = [...snap.data!.docs];

                // sort local by fullName
                docs.sort((a, b) {
                  final an = ((a.data() as Map)['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final bn = ((b.data() as Map)['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return an.compareTo(bn);
                });

                // filter local
                final filtered = docs.where((d) {
                  if (q.isEmpty) return true;
                  final data = d.data() as Map<String, dynamic>;
                  final username = d.id.toLowerCase();
                  final fullName = (data['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final classId = (data['classId'] ?? '')
                      .toString()
                      .toLowerCase();
                  return username.contains(q) ||
                      fullName.contains(q) ||
                      classId.contains(q);
                }).toList();

                if (filtered.isEmpty)
                  return const Center(child: Text("Nu exista rezultate"));

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final data = d.data() as Map<String, dynamic>;
                    final username = d.id;
                    final fullName = (data['fullName'] ?? username).toString();
                    final classId = (data['classId'] ?? '').toString();
                    final status = (data['status'] ?? 'active').toString();

                    return ListTile(
                      title: Text(fullName),
                      subtitle: Text(
                        "user: $username | clasa: $classId | $status",
                      ),
                      onTap: () => _openStudentDialog(
                        context,
                        username: username,
                        fullName: fullName,
                        classId: classId,
                        status: status,
                      ),
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
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(fullName),
        content: SelectableText(
          "username: $username\nclassId: $classId\nstatus: $status",
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
                  content: Text("Stergi elevul: $username ?"),
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
