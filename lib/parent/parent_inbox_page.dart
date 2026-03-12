import 'package:flutter/material.dart';

class ParentInboxPage extends StatelessWidget {
  const ParentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color bgGrey = Color(0xFFE7EDF0);

    return Scaffold(
      backgroundColor: bgGrey,
      appBar: AppBar(
        title: const Text("Inbox"),
        backgroundColor: const Color(0xFF7AAF5B),
        foregroundColor: Colors.white,
      ),
      body: Container(
        color: bgGrey,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "Inbox Gol",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Nu aveți mesaje noi momentan.",
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7AAF5B),
                foregroundColor: Colors.white,
              ),
              child: const Text("Actualizează"),
            )
          ],
        ),
      ),
      ),
    );
  }
}
