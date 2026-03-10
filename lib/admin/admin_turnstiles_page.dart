import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'admin_store.dart';

class AdminTurnstilesPage extends StatefulWidget {
  const AdminTurnstilesPage({super.key});

  @override
  State<AdminTurnstilesPage> createState() => _AdminTurnstilesPageState();
}

class _AdminTurnstilesPageState extends State<AdminTurnstilesPage> {
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
          "Admin · Toate turnichetele",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
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
                hintText: "Caută turnichet (username / nume / uid)",
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

          /// TURNSTILES LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'gate')
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
                  final uid = d.id.toLowerCase();
                  final username = (data['username'] ?? '')
                      .toString()
                      .toLowerCase();
                  final fullName = (data['fullName'] ?? '')
                      .toString()
                      .toLowerCase();

                  return uid.contains(q) ||
                      username.contains(q) ||
                      fullName.contains(q);
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
                    final username = (data['username'] ?? '').toString();
                    final fullName = (data['fullName'] ?? username).toString();
                    final status = (data['status'] ?? 'active').toString();

                    return Column(
                      children: [
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: primaryGreen.withOpacity(0.2),
                            child: const Icon(Icons.door_front_door),
                          ),
                          title: Text(
                            fullName,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            "username: $username | uid: $uid | $status",
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openGateDialog(
                            context,
                            uid: uid,
                            username: username,
                            fullName: fullName,
                            status: status,
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: darkGreen.withOpacity(0.3),
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
    );
  }

  Future<void> _openGateDialog(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String status,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(fullName),
        content: SelectableText(
          "username: $username\nuid: $uid\nstatus: $status\nrole: gate",
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
                  content: Text("Ștergi turnichetul: $username ?"),
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