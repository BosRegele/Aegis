import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/core/session.dart';
import 'package:firster/student/meniu.dart';
import 'package:firster/student/orar.dart';
import 'package:firster/student/cereri.dart';
import 'package:firster/student/inbox.dart';
import 'package:flutter/material.dart';

class AppShell extends StatefulWidget {
  final int initialIndex;

  const AppShell({super.key, this.initialIndex = 0});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    final maxIndex = 3; // 4 children: 0, 1, 2, 3
    _currentIndex = idx < 0 ? 0 : (idx > maxIndex ? maxIndex : idx);
  }

  void _setTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    // Marcare ca văzut când se selectează tab-ul inbox (index 3)
    if (index == 3) {
      final uid = AppSession.uid;
      if (uid != null && uid.isNotEmpty) {
        FirebaseFirestore.instance.collection('users').doc(uid).set({
          'inboxLastOpenedAt': FieldValue.serverTimestamp(),
          'unreadCount': 0,
        }, SetOptions(merge: true));
      }
    }

    setState(() {
      final maxIndex = 3; // 4 children: 0, 1, 2, 3
      _currentIndex = (index < 0) ? 0 : (index > maxIndex ? maxIndex : index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: [
              MeniuScreen(onNavigateTab: _setTab),
              OrarScreen(onBackToHome: () => _setTab(0)),
              CereriScreen(onNavigateTab: _setTab),
              InboxScreen(onNavigateTab: _setTab),
            ],
          ),
          Positioned(
            top: topPadding - 2,
            right: 14,
            child: GestureDetector(
              onTap: () => _setTab(1),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0x337DE38D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0x6DC7F4CE),
                    width: 1,
                  ),
                ),
                child: const Icon(Icons.person, color: Colors.white, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
