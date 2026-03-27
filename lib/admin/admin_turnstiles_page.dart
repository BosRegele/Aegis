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
    // Culorile tematice
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color darkGreen = Color(0xFF5A9641);
    const Color lightBg = Color(0xFFF8FFF5);
    const Color borderColor = Color(0xFFCDE8B0);

    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Acces refuzat (doar pentru admin)")),
      );
    }

    return Scaffold(
      backgroundColor: lightBg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryGreen, darkGreen],
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
              .where('role', isEqualTo: 'gate')
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;
            return Row(
              children: [
                const Text(
                  "Turnichete",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$count",
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            );
          },
        ),
      ),
      body: Column(
        children: [
          /// BARA DE CĂUTARE
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                hintText: "Caută turnichet (nume / id)...",
                prefixIcon: const Icon(Icons.search, color: primaryGreen),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: primaryGreen, width: 2),
                ),
              ),
              onChanged: (v) => setState(() => q = v.trim().toLowerCase()),
            ),
          ),

          const Divider(height: 1, color: borderColor),

          /// LISTA DE TURNICHETE
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'gate')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Center(child: Text("Eroare: ${snap.error}"));
                if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: primaryGreen));

                final docs = snap.data!.docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['fullName'] ?? '').toString().toLowerCase();
                  final uid = d.id.toLowerCase();
                  return name.contains(q) || uid.contains(q);
                }).toList();

                if (docs.isEmpty) return const Center(child: Text("Nu s-au găsit turnichete."));

                return ListView.builder(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final uid = docs[index].id;
                    final username = data['username'] ?? uid; // Fallback pe ID dacă lipsește user
                    final fullName = data['fullName'] ?? username;
                    final status = data['status'] ?? 'active';

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: primaryGreen.withOpacity(0.1),
                          child: const Icon(Icons.door_sliding, color: primaryGreen),
                        ),
                        title: Text(fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        // --- MODIFICARE AICI: Afișăm Username-ul, nu ID-ul ---
                        subtitle: Text("user: $username | Status: $status"),
                        trailing: const Icon(Icons.chevron_right, color: borderColor),
                        onTap: () => _openGateDialog(context, uid, username, fullName, status),
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

  /// NOUUL DIALOG STILIZAT (POP-UP CU BANDA VERDE)
  void _openGateDialog(BuildContext context, String uid, String username, String fullName, String status) {
    // Definirea culorilor locale pentru a fi sigur de consistență
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color darkGreen = Color(0xFF5A9641);

    showDialog(
      context: context,
      builder: (context) {
        bool isBusy = false;
        return StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Container(
              // Lățime fixă pentru monitoare mari
              constraints: const BoxConstraints(maxWidth: 450),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Se adaptează pe înălțime
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- HEADER CU BANDA VERDE ȘI SCRIS ÎNGROȘAT ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryGreen, darkGreen],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800, // Scris îngroșat
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
                          _buildDetailRow("Username utilizator", username),
                          _buildDetailRow("Device ID (UID)", uid),
                          _buildDetailRow(
                              "Status poartă",
                              status == 'disabled'
                                  ? "🔴 Dezactivată"
                                  : "🟢 Activă (Enabled)"),
                        ],
                      ),
                    ),
                  ),

                  // --- BUTOANE DE ACȚIUNE ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Buton Activează/Dezactivează (Verde/Portocaliu)
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'disabled'
                                      ? Colors.green
                                      : Colors.orangeAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        setDialogState(() => isBusy = true);
                                        await store.setDisabled(
                                            username, status != 'disabled');
                                        if (mounted) Navigator.pop(context);
                                      },
                                child: Text(
                                    status == 'disabled'
                                        ? "Activează"
                                        : "Dezactivează",
                                    style:
                                        const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // --- MODIFICARE: Buton Șterge mare, roșu ---
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935), // Roșu
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: isBusy
                                    ? null
                                    : () async {
                                        final ok =
                                            await _showConfirmDelete(context, username);
                                        if (ok == true) {
                                          setDialogState(() => isBusy = true);
                                          try {
                                            await store.deleteUser(username);
                                            if (mounted) Navigator.pop(context);
                                          } catch (_) {
                                            setDialogState(() => isBusy = false);
                                          }
                                        }
                                      },
                                child: isBusy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2, color: Colors.white))
                                    : const Text("Șterge poarta",
                                        style: TextStyle(
                                            fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Buton Close
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.withOpacity(0.1),
                              foregroundColor: const Color(0xFF2E3B4E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Închide",
                                style: TextStyle(fontWeight: FontWeight.w700)),
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

  // Widget helper pentru afișarea detaliilor în dialog
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5F6771),
                  fontSize: 13)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E3B4E),
                  fontSize: 15)),
        ],
      ),
    );
  }

  // Dialog de confirmare ștergere
  Future<bool?> _showConfirmDelete(BuildContext context, String name) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ștergere turnichet"),
        content: Text("Ești sigur că vrei să elimini poarta $name?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Anulează")),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Da, Șterge poarta",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}