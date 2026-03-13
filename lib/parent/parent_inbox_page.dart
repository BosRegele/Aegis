import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ParentInboxPage extends StatelessWidget {
  const ParentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF7AAF5B);
    const Color bgGrey = Color(0xFFE7EDF0);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text("Inbox"),
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('leaveRequests')
              .where('status', whereIn: ['approved', 'rejected'])
              .orderBy('reviewedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text("Eroare: ${snapshot.error}"));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  "Nu există mesaje în inbox.",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return ListView.separated(
              itemCount: docs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final data = docs[index].data() as Map<String, dynamic>;

                final studentName = data['studentName'] ?? "Elev necunoscut";
                final classId = data['classId'] ?? "-";
                final reviewer = data['reviewedByName'] ?? "Necunoscut";
                final time = data['timeText'] ?? "-";
                final status = data['status'] ?? "pending";

                final bool approved = status == 'approved';

                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    visualDensity: VisualDensity.compact,
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    leading: Icon(
                      approved ? Icons.check_circle : Icons.cancel,
                      color: approved ? Colors.green : Colors.red,
                      size: 32,
                    ),
                    title: Text(
                      approved ? "Cerere acceptată" : "Cerere respinsă",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 0),
                        Text("Elev: $studentName"),
                        Text("Clasa: $classId"),
                        Text("De la: $reviewer"),
                        Text("Ora: $time"),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
