import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class ParentInboxPage extends StatelessWidget {
  const ParentInboxPage({super.key});

  Future<List<String>> _loadChildrenUids() async {
    final parentUid = AppSession.uid;
    if (parentUid == null || parentUid.isEmpty) {
      throw Exception('Părinte neautentificat.');
    }

    final parentDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .get();
    if (!parentDoc.exists) {
      throw Exception('Profilul părintelui nu a fost găsit.');
    }

    final data = parentDoc.data() ?? <String, dynamic>{};
    return List<String>.from(data['children'] ?? const <String>[]);
  }

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
        child: FutureBuilder<List<String>>(
          future: _loadChildrenUids(),
          builder: (context, childrenSnapshot) {
            if (childrenSnapshot.hasError) {
              return Center(child: Text('Eroare: ${childrenSnapshot.error}'));
            }
            if (!childrenSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final childrenUids = childrenSnapshot.data!;
            if (childrenUids.isEmpty) {
              return const Center(
                child: Text(
                  'Nu ai elevi asociați pe acest cont.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              );
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('leaveRequests')
                  .where('studentUid', whereIn: childrenUids)
                  .orderBy('reviewedAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Eroare: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = (data['status'] ?? 'pending').toString();
                  return status == 'approved' || status == 'rejected';
                }).toList();

                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nu există mesaje în inbox.',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final studentName =
                        data['studentName'] ?? 'Elev necunoscut';
                    final classId = data['classId'] ?? '-';
                    final reviewer = data['reviewedByName'] ?? 'Necunoscut';
                    final time = data['timeText'] ?? '-';
                    final status = data['status'] ?? 'pending';

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
                          approved ? 'Cerere acceptată' : 'Cerere respinsă',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 0),
                            Text('Elev: $studentName'),
                            Text('Clasa: $classId'),
                            Text('De la: $reviewer'),
                            Text('Ora: $time'),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
