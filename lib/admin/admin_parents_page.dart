import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'services/admin_store.dart';

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
              .where('role', isEqualTo: 'parent')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Părinți",
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
                hintText: "Caută după utilizator sau nume...",
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

          /// PARENTS LIST
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'parent')
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
                  final fullName = (data['fullName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final username = (data['username'] ?? d.id)
                      .toString()
                      .toLowerCase();
                  return fullName.contains(q) || username.contains(q);
                }).toList();

                if (filtered.isEmpty)
                  return const Center(child: Text("Nu există rezultate"));

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final data = d.data() as Map<String, dynamic>;
                    final username = (data['username'] ?? d.id).toString();
                    final fullName = (data['fullName'] ?? username).toString();
                    final status = (data['status'] ?? 'active').toString();
                    final onboarded =
                        data['onboardingComplete'] as bool? ?? false;

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
                          child: const Icon(
                            Icons.family_restroom,
                            color: primaryGreen,
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text("user: $username"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: onboarded
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: onboarded
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFFF9800),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    onboarded
                                        ? Icons.how_to_reg
                                        : Icons.hourglass_top,
                                    size: 13,
                                    color: onboarded
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF9800),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'OB',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: onboarded
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFF9800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                        onTap: () => _openParentDialog(
                          context,
                          username: username,
                          fullName: fullName,
                          status: status,
                          childrenIds: List<String>.from(
                            data['children'] ?? [],
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
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$label: ",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F6771),
              fontSize: 14,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E3B4E),
                fontSize: 14,
              ),
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
    required List<String> childrenIds,
  }) async {
    await showDialog(
      context: context,
      builder: (_) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER ---
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7AAF5B), Color(0xFF5A9641)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  // --- CONTENT ---
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow("Username", username),
                          _buildDetailRow(
                            "Status",
                            status == 'disabled' ? 'Dezactivat' : 'Activ',
                          ),

                          if (childrenIds.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE6EBEE)),
                            const SizedBox(height: 8),
                            const Text(
                              'Copii:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5F6771),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<List<DocumentSnapshot>>(
                              future: Future.wait(
                                childrenIds.map(
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
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );

                                final docs = csnap.data!;
                                if (docs.isEmpty)
                                  return const Text(
                                    'Niciun copil înregistrat.',
                                  );

                                return Column(
                                  children: docs.map((ds) {
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
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FFF5),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFCDE8B0),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.person,
                                            size: 20,
                                            color: Color(0xFF7AAF5B),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  cname,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2E3B4E),
                                                  ),
                                                ),
                                                Text(
                                                  'user: $cun',
                                                  style: const TextStyle(
                                                    color: Colors.black54,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // --- ACTIONS ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Buton Enable/Disable (Albastru/Gri)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'disabled'
                                      ? const Color(0xFF4CAF50)
                                      : const Color.fromARGB(
                                          154,
                                          109,
                                          103,
                                          100,
                                        ),
                                  foregroundColor: const Color.fromARGB(
                                    255,
                                    0,
                                    0,
                                    0,
                                  ),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final disable = status != 'disabled';
                                        setDialogState(() => busy = true);
                                        await store.setDisabled(
                                          username,
                                          disable,
                                        );
                                        if (mounted) Navigator.pop(context);
                                      },
                                child: Text(
                                  status == 'disabled'
                                      ? "Activează"
                                      : "Dezactivează",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Buton Delete (Roșu)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("Ștergere"),
                                            content: Text(
                                              "Ștergi definitiv părintele: $username?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text("Anulează"),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text("Șterge"),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;
                                        setDialogState(() => busy = true);
                                        try {
                                          await store.deleteUser(username);
                                          if (mounted) Navigator.pop(context);
                                        } catch (_) {
                                          setDialogState(() => busy = false);
                                        }
                                      },
                                child: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Șterge",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.withValues(
                                alpha: 0.15,
                              ),
                              foregroundColor: const Color(0xFF2E3B4E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Închide",
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
