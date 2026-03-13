import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../session.dart';
import 'orardir.dart';
import 'cereriasteptare.dart';
import 'statuselevi.dart';
import 'mesajedir.dart';

class TeacherDashboardPage extends StatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  State<TeacherDashboardPage> createState() => _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends State<TeacherDashboardPage> {
  @override
  Widget build(BuildContext context) {
    final teacherUid = AppSession.uid;
    if (teacherUid == null || teacherUid.isEmpty) {
      return const Scaffold(body: Center(child: Text("No session")));
    }

    final teacherDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid);

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        title: const Text(
          "Pagina Diriginte",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: teacherDoc.get(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text("Eroare: ${snap.error}"));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snap.data!.exists) {
            return const Center(child: Text("Teacher not found"));
          }

          final data = snap.data!.data() as Map<String, dynamic>;
          final classId = (data["classId"] ?? "").toString().trim();

          if (classId.isEmpty) {
            return Center(
              child: Text(
                "Nu ai clasa asignata.\nCere secretariatului sa-ti seteze classId.",
              ),
            );
          }

          final fullName =
              (data["fullName"] ?? AppSession.username ?? teacherUid)
                  .toString();

          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Bun venit, $fullName',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 2.5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _dashboardButton(
                        context,
                        'Cereri in asteptare',
                        const Color(0xFF14A9A0),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CereriAsteptarePage(),
                            ),
                          );
                        },
                      ),
                      _dashboardButton(
                        context,
                        'Mesaje',
                        const Color(0xFF7A56D1),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MesajeDirPage(),
                            ),
                          );
                        },
                      ),
                      _dashboardButton(
                        context,
                        'Orar elevi',
                        const Color(0xFFEA9136),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrarDirPage(),
                            ),
                          );
                        },
                      ),
                      _dashboardButton(
                        context,
                        'Status elevi',
                        const Color.fromRGBO(122, 175, 91, 1),
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StatusEleviPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _dashboardButton(
    BuildContext context,
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    IconData icon;
    if (label.toLowerCase().contains('cereri')) {
      icon = Icons.list_alt;
    } else if (label.toLowerCase().contains('mesaje')) {
      icon = Icons.message;
    } else if (label.toLowerCase().contains('orar')) {
      icon = Icons.calendar_month;
    } else if (label.toLowerCase().contains('status')) {
      icon = Icons.check_circle;
    } else {
      icon = Icons.circle;
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        elevation: 4,
      ),
      onPressed: onPressed,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class SimplePage extends StatelessWidget {
  final String title;

  const SimplePage({required this.title, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text(title, style: const TextStyle(fontSize: 24))),
    );
  }
}
