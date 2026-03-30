import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'services/admin_store.dart';

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
    const Color primaryGreen = Color(0xFF7AAF5B);

    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: Column(
        children: [
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
                    final inSchool = data['inSchool'] as bool? ?? false;
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
                          child: const Icon(Icons.person),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Row(
                          children: [
                            Expanded(
                              child: Text("user: $username | clasă: $classId"),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: onboarded
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFFFF3E0),
                                borderRadius: BorderRadius.circular(6),
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
                                    size: 11,
                                    color: onboarded
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF9800),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'OB',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: onboarded
                                          ? const Color(0xFF4CAF50)
                                          : const Color(0xFFFF9800),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
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
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                inSchool
                                    ? Icons.location_on
                                    : Icons.location_off,
                                color: inSchool
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFF44336),
                                size: 14,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                inSchool ? 'In scoala' : 'Afara',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: inSchool
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFF44336),
                                ),
                              ),
                            ],
                          ),
                        ),
                        onTap: () => _openStudentDialog(
                          context,
                          username: username,
                          fullName: fullName,
                          classId: classId,
                          inSchool: inSchool,
                          status: status,
                          parentIds: List<String>.from(data['parents'] ?? []),
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

  Future<void> _openStudentDialog(
    BuildContext context, {
    required String username,
    required String fullName,
    required String classId,
    required bool inSchool,
    required String status,
    required List<String> parentIds,
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
                  // --- BANDA VERDE SUS ---
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

                  // --- CONȚINUT / DETALII ---
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow("Username", username),
                          _buildDetailRow("Clasă", classId),
                          _buildDetailRow(
                            "Status",
                            status == 'disabled' ? 'Inactiv' : 'Activ',
                          ),

                          // --- ETICHETĂ LOCAȚIE (STIL PAGINA PRINCIPALĂ) ---
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Row(
                              children: [
                                const Text(
                                  "Locație: ",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF5F6771),
                                    fontSize: 14,
                                  ),
                                ),
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
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        inSchool
                                            ? Icons.location_on
                                            : Icons.location_off,
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
                              ],
                            ),
                          ),

                          if (parentIds.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(color: Color(0xFFE6EBEE)),
                            const SizedBox(height: 8),
                            const Text(
                              'Părinți:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF5F6771),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
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
                                if (psnap.hasError)
                                  return const SizedBox.shrink();
                                if (!psnap.hasData) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  );
                                }
                                final docs = psnap.data!;
                                if (docs.isEmpty) {
                                  return const Text(
                                    'Niciun părinte înregistrat.',
                                  );
                                }
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: docs.map((ds) {
                                    final md =
                                        ds.data() as Map<String, dynamic>? ??
                                        {};
                                    final pname =
                                        (md['fullName'] ??
                                                md['username'] ??
                                                ds.id)
                                            .toString();
                                    final pun = (md['username'] ?? ds.id)
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
                                            Icons.family_restroom,
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
                                                  pname,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF2E3B4E),
                                                  ),
                                                ),
                                                Text(
                                                  'user: $pun',
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

                  // --- BUTOANE DE ACȚIUNE ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
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
                            onPressed: busy
                                ? null
                                : () => Navigator.pop(context),
                            child: const Text(
                              "Închide",
                              style: TextStyle(fontWeight: FontWeight.w700),
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
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                        title: const Text(
                                          "Ștergere utilizator",
                                        ),
                                        content: Text(
                                          "Ești sigur că vrei să ștergi elevul: $fullName?",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Anulează"),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
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
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Utilizator șters cu succes.',
                                          ),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (_) {
                                      setDialogState(() => busy = false);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Utilizatorul nu a putut fi șters.',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                            child: busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
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
