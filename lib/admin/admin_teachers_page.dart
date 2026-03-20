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
        title: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'teacher')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Profesori",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          /// SEARCH BAR
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                hintText: "Caută după utilizator, nume sau clasă...",
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7AAF5B)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.green.withValues(alpha: 0.30),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Colors.green.withValues(alpha: 0.30),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: Color(0xFF7AAF5B),
                    width: 2,
                  ),
                ),
              ),
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFCDE8B0)),

          /// TEACHERS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'teacher')
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
                  final username = (data['username'] ?? uid)
                      .toString()
                      .toLowerCase();
                  final fullName = (data['fullName'] ?? username)
                      .toString()
                      .toLowerCase();
                  final classId = (data['classId'] ?? '')
                      .toString()
                      .toLowerCase();

                  return fullName.contains(q) ||
                      username.contains(q) ||
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
                        leading: CircleAvatar(
                          backgroundColor: primaryGreen.withValues(alpha: 0.20),
                          child: const Icon(Icons.person_outline),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text("user: $username | clasă: $classId"),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTeacherDialog(
                          context,
                          username: username,
                          fullName: fullName,
                          classId: classId,
                          status: status,
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
      builder: (_) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(fullName),
            content: SelectableText(
              "username: $username\nclassId (clasa reprezentată): $classId\nstatus: ${status == 'disabled' ? 'disabled' : 'enabled'}",
            ),
            actions: [
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final disable = status != 'disabled';
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Confirmare"),
                            content: Text(
                              disable
                                  ? "Dezactivezi profesorul: $username ?"
                                  : "Activezi profesorul: $username ?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Confirm"),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        setDialogState(() => busy = true);
                        await store.setDisabled(username, disable);
                        if (mounted) Navigator.pop(context);
                      },
                child: Text(status == 'disabled' ? "Enable" : "Disable"),
              ),
              TextButton(
                onPressed: busy
                    ? null
                    : () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Delete user?"),
                            content: Text("Ștergi profesorul: $username ?"),
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
                        if (ok != true) return;
                        setDialogState(() => busy = true);
                        try {
                          await store.deleteUser(username);
                          if (!mounted) return;
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Utilizator șters cu succes.'),
                            ),
                          );
                        } catch (_) {
                          setDialogState(() => busy = false);
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Utilizatorul nu a putut fi șters.',
                              ),
                            ),
                          );
                        }
                      },
                child: busy
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text("Delete"),
              ),
            ],
          ),
        );
      },
    );
  }
}
