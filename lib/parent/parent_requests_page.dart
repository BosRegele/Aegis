import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class ParentRequestsPage extends StatefulWidget {
  const ParentRequestsPage({super.key});

  @override
  State<ParentRequestsPage> createState() => _ParentRequestsPageState();
}

class _ParentRequestsPageState extends State<ParentRequestsPage> {
  Future<void> _handleRequest(String docId, bool approved) async {
    final parentName = AppSession.username ?? "Parinte";
    try {
      await FirebaseFirestore.instance.collection('leaveRequests').doc(docId).update({
        'status': approved ? 'approved' : 'rejected',
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedByUid': AppSession.uid,
        'reviewedByName': parentName,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approved ? 'Cerere aprobată!' : 'Cerere respinsă.'),
        backgroundColor: approved ? Colors.green : Colors.red,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color bgGrey = Color(0xFFE7EDF0);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text("Cereri de învoire"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: bgGrey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leaveRequests')
                    .where('status', isEqualTo: 'pending')
                    .orderBy('requestedAt', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('Eroare: ${snapshot.error}'));
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text("Nu există cereri noi.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                    );
                  }

                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final studentName = data['studentName'] ?? 'Elev necunoscut';
                      final date = data['dateText'] ?? '-';
                      final message = data['message'] ?? '';

                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(studentName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text("Data: $date"),
                              Text("Motiv: $message", style: const TextStyle(fontStyle: FontStyle.italic)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () => _handleRequest(doc.id, false),
                                    child: const Text("Respinge", style: TextStyle(color: Colors.red)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _handleRequest(doc.id, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                                    child: const Text("Aprobă"),
                                  ),
                                ],
                              )
                            ],
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
      ),
      ),
    );
  }
}
