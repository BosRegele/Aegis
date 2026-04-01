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
                    Container(
                      padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF4F9F3),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: _colHeader('NUME PĂRINTE')),
                          Expanded(
                            flex: 3,
                            child: Center(child: _colHeader('ELEVI ATRIBUIȚI')),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(child: _colHeader('EMAIL')),
                          ),
                          Expanded(
                            flex: 1,
                            child: Center(child: _colHeader('SETĂRI')),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: Color(0xFFE8F5E0)),
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
                            padding: const EdgeInsets.fromLTRB(40, 16, 40, 24),
                            itemCount: docs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final d = docs[i];
                              final data = d.data() as Map<String, dynamic>;
                              final uid = d.id;
                              final username = (data['username'] ?? uid)
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
                                  vertical: 12,
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
                                                color: Color(0xFF1A1A1A),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: Color(0xFF111111),
                                                  ),
                                                ),
                                                Text(
                                                  'Username: $username',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF7A9070),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: childrenIds.isEmpty
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFF5F5F5),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: const Text(
                                                  'NEATRIBUIT',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF9E9E9E),
                                                  ),
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
                                                  if (!csnap.hasData) {
                                                    return const SizedBox
                                                        .shrink();
                                                  }
                                                  return Wrap(
                                                    spacing: 4,
                                                    runSpacing: 4,
                                                    children: csnap.data!
                                                        .map((ds) {
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
                                                                const EdgeInsets
                                                                    .symmetric(
                                                                  horizontal: 10,
                                                                  vertical: 5,
                                                                ),
                                                            decoration:
                                                                BoxDecoration(
                                                                  color: const Color(
                                                                    0xFFDCEEDC,
                                                                  ),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                            20,
                                                                          ),
                                                                ),
                                                            child: Text(
                                                              name,
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700,
                                                                    color: Color(
                                                                      0xFF2E7D32,
                                                                    ),
                                                                  ),
                                                            ),
                                                          );
                                                        })
                                                        .toList(),
                                                  );
                                                },
                                              ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        (email != null && email.isNotEmpty)
                                            ? email
                                            : '-',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF2E4A2E),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.settings_outlined,
                                            color: Color(0xFF757575),
                                            size: 22,
                                          ),
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
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF006B3D),
        letterSpacing: 1.2,
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
      Color(0xFFA5D6A7),
      Color(0xFFCE93D8),
      Color(0xFF80DEEA),
      Color(0xFFFFCC80),
      Color(0xFF90A4AE),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F6771),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3B4E),
              fontSize: 15,
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
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow("Username", username),
                          _buildDetailRow(
                            "Status cont",
                            status == 'disabled' ? 'Dezactivat' : 'Activ',
                          ),
                          if (childrenIds.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE6EBEE)),
                            const SizedBox(height: 8),
                            const Text(
                              'Copii atribuiți:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5F6771),
                                fontSize: 13,
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
                                if (!csnap.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                }
                                return Column(
                                  children: csnap.data!.map((ds) {
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
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'disabled'
                                      ? const Color(0xFF4CAF50)
                                      : Colors.orangeAccent,
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
                                        final disable = status != 'disabled';
                                        final nav = Navigator.of(context);
                                        setDialogState(() => busy = true);
                                        await store.setDisabled(
                                          username,
                                          disable,
                                        );
                                        if (!mounted) return;
                                        nav.pop();
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
                                        final nav = Navigator.of(context);
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
                                          if (!mounted) return;
                                          nav.pop();
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
                                alpha: 0.1,
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
