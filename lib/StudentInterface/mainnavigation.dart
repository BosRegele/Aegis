import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/session.dart';
import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MeniuScreen(onNavigateTab: _setTab),
          OrarScreen(onBackToHome: () => _setTab(0)),
          CereriScreen(onNavigateTab: _setTab),
          InboxScreen(onNavigateTab: _setTab),
        ],
      ),
    );
  }
}
