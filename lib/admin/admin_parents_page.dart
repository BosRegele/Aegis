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

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Părinți',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gestionează și monitorizează activitatea părinților, copiii înscriși și detaliile de contact într-o vizualizare centrală.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5A8040)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFCDE8B0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: _colHeader('NUME PĂRINTE')),
                          Expanded(flex: 3, child: _colHeader('ELEVI')),
                          Expanded(flex: 4, child: _colHeader('EMAIL')),
                          Expanded(
                            flex: 1,
                            child: Center(child: _colHeader('SETĂRI')),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFCDE8B0)),
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
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

                          if (docs.isEmpty) {
                            return const Center(
                              child: Text("Nu există părinți"),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                            itemCount: docs.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1,
                              color: Color(0xFFE8F5E0),
                            ),
                            itemBuilder: (_, i) {
                              final d = docs[i];
                              final data = d.data() as Map<String, dynamic>;
                              final username = (data['username'] ?? d.id)
                                  .toString();
                              final fullName = (data['fullName'] ?? username)
                                  .toString();
                              final email = data['email']?.toString();
                              final childrenIds = List<String>.from(
                                data['children'] ?? [],
                              );
                              final status = (data['status'] ?? 'active')
                                  .toString();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: _avatarColor(
                                              fullName,
                                            ),
                                            child: Text(
                                              _initials(fullName),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Flexible(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                    color: Color(0xFF1A2E1A),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Username: $username',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF7AAF5B),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: childrenIds.isEmpty
                                          ? const Text(
                                              '-',
                                              style: TextStyle(
                                                color: Colors.black38,
                                              ),
                                            )
                                          : FutureBuilder<
                                              List<DocumentSnapshot>
                                            >(
                                              future: Future.wait(
                                                childrenIds.map(
                                                  (id) => FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(id)
                                                      .get(),
                                                ),
                                              ),
                                              builder: (context, csnap) {
                                                if (!csnap.hasData)
                                                  return const SizedBox.shrink();
                                                return Wrap(
                                                  spacing: 4,
                                                  runSpacing: 4,
                                                  children: csnap.data!.map((
                                                    ds,
                                                  ) {
                                                    final md =
                                                        ds.data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >? ??
                                                        {};
                                                    final name =
                                                        (md['fullName'] ??
                                                                md['username'] ??
                                                                ds.id)
                                                            .toString();
                                                    return Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 10,
                                                            vertical: 5,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFE8F5E0,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: Color(
                                                            0xFF3A6B2A,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),
                                                );
                                              },
                                            ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        email ?? '-',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF2E3B4E),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.settings,
                                            size: 20,
                                          ),
                                          color: const Color(0xFF9AB88A),
                                          onPressed: () => _openParentDialog(
                                            context,
                                            username: username,
                                            fullName: fullName,
                                            status: status,
                                            childrenIds: childrenIds,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _colHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF9AB88A),
        letterSpacing: 0.8,
      ),
    );
  }

  String _initials(String name) {
    final trimmed = name.trim();
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0 && spaceIdx < trimmed.length - 1) {
      return '${trimmed[0]}${trimmed[spaceIdx + 1]}'.toUpperCase();
    }
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7986CB),
      Color(0xFF4DB6AC),
      Color(0xFFFF8A65),
      Color(0xFFA1887F),
      Color(0xFF4FC3F7),
      Color(0xFFBA68C8),
      Color(0xFF81C784),
      Color(0xFFFFB74D),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  // ── placeholder kept for future use ────────────────────────────────────────
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
