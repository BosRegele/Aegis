import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'admin_store.dart';

class AdminParentsPage extends StatefulWidget {
  const AdminParentsPage({super.key});

  @override
  State<AdminParentsPage> createState() => _AdminParentsPageState();
}

class _AdminParentsPageState extends State<AdminParentsPage> {
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
          "Admin · Parinti",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                hintText: "Search by username or full name...",
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'parent')
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

                  return username.contains(q) || fullName.contains(q);
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
                          subtitle: Text("user: $username | $status"),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openParentDialog(
                            context,
                            username: username,
                            fullName: fullName,
                            status: status,
                          ),
                        ),
                        // show assigned students if any
                        if ((data['children'] ?? []).isNotEmpty)
                          FutureBuilder<List<DocumentSnapshot>>(
                            future: Future.wait(
                              List<String>.from(data['children'] ?? []).map(
                                (id) => FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(id)
                                    .get(),
                              ),
                            ),
                            builder: (context, csnap) {
                              if (csnap.hasError)
                                return const SizedBox.shrink();
                              if (!csnap.hasData)
                                return const SizedBox.shrink();
                              final docs = csnap.data!;
                              if (docs.isEmpty) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  bottom: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Nume copii:'),
                                    const SizedBox(height: 6),
                                    ...docs.map((ds) {
                                      final md =
                                          ds.data() as Map<String, dynamic>? ??
                                          {};
                                      final cname =
                                          (md['fullName'] ??
                                                  md['username'] ??
                                                  ds.id)
                                              .toString();
                                      final cun = (md['username'] ?? ds.id)
                                          .toString();
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 6,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(child: Text(cname)),
                                            Text(
                                              'username: $cun',
                                              style: const TextStyle(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ],
                                ),
                              );
                            },
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

  Future<void> _openParentDialog(
    BuildContext context, {
    required String username,
    required String fullName,
    required String status,
  }) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(fullName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText("username: $username\nstatus: $status"),
            const SizedBox(height: 12),
            // show children in dialog as well
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(username)
                  .get(),
              builder: (context, psnap) {
                // fallback: try to find parent doc by username field if doc id is not username
                return const SizedBox.shrink();
              },
            ),
          ],
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
                  content: Text("Ștergi părintele: $username ?"),
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
