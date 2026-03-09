import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'admin_store.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
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
      appBar: AppBar(title: const Text("Admin: Toti profesorii")),
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
                  .where('role', isEqualTo: 'teacher')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError)
                  return Center(
                    child: SelectableText("Eroare:\n${snap.error}"),
                  );
                if (!snap.hasData)
                  return const Center(child: CircularProgressIndicator());

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

                if (filtered.isEmpty)
                  return const Center(child: Text("Nu exista rezultate"));

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

                    return ListTile(
                      title: Text(fullName),
                      subtitle: Text(
                        "user: $username | clasa: $classId | $status",
                      ),
                      onTap: () => _openTeacherDialog(
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

  Future<void> _openTeacherDialog(
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
          "username: $username\nclassId (clasa reprezentata): $classId\nstatus: $status",
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
                  content: Text("Stergi profesorul: $username ?"),
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
