import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';

class TeacherDashboardPage extends StatelessWidget {
  const TeacherDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final teacherUsername =
        AppSession.username; // presupun că ai așa în session
    if (teacherUsername == null) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUsername);

    return Scaffold(
      appBar: AppBar(title: const Text("Diriginte")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: teacherDoc.snapshots(),
        builder: (context, snap) {
          if (snap.hasError)
            return Center(child: Text("Eroare: ${snap.error}"));
          if (!snap.hasData)
            return const Center(child: CircularProgressIndicator());
          if (!snap.data!.exists)
            return const Center(child: Text("Teacher not found"));

          final data = snap.data!.data() as Map<String, dynamic>;
          final fullName = (data["fullName"] ?? teacherUsername).toString();
          final classId = (data["classId"] ?? "").toString().trim();

          if (classId.isEmpty) {
            return Center(
              child: Text(
                "Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.",
              ),
            );
          }

          final studentsQuery = FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'student')
              .where('classId', isEqualTo: classId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  "$fullName\nClasa: $classId",
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: studentsQuery.snapshots(),
                  builder: (context, s2) {
                    if (s2.hasError)
                      return Center(child: Text("Eroare elevi: ${s2.error}"));
                    if (!s2.hasData)
                      return const Center(child: CircularProgressIndicator());

                    final docs = s2.data!.docs;
                    if (docs.isEmpty)
                      return const Center(
                        child: Text("Nu exista elevi in clasa asta"),
                      );

                    // sort local
                    final list = docs.toList()
                      ..sort((a, b) {
                        final an = ((a.data() as Map)['fullName'] ?? '')
                            .toString();
                        final bn = ((b.data() as Map)['fullName'] ?? '')
                            .toString();
                        return an.compareTo(bn);
                      });

                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final d = list[i];
                        final sd = d.data() as Map<String, dynamic>;
                        final u = d.id;
                        final n = (sd["fullName"] ?? u).toString();
                        final status = (sd["status"] ?? "active").toString();

                        return ListTile(
                          title: Text(n),
                          subtitle: Text("user: $u | $status"),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
