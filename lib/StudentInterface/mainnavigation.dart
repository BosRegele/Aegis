import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firster/session.dart';
import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/StudentInterface/widgets/maniubara.dart';
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
    final maxIndex = 4; // 5 children: 0, 1, 2, 3, 4
    _currentIndex = idx < 0 ? 0 : (idx > maxIndex ? maxIndex : idx);
  }

  void _setTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    // Marcare ca văzut când se selectează tab-ul inbox (index 4)
    if (index == 4) {
      final uid = AppSession.uid;
      print('[Inbox] _markAsRead() called from tab, uid: $uid');
      if (uid != null && uid.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              'inboxLastOpenedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .then((_) {
              print('[Inbox] _markAsRead() Firestore update OK (tab)');
            })
            .catchError((e) {
              print('[Inbox] _markAsRead() Firestore error (tab): $e');
            });
      } else {
        print('[Inbox] _markAsRead() aborted: uid null/gol (tab)');
      }
    }

    setState(() {
      final maxIndex = 4; // 5 children: 0, 1, 2, 3, 4
      _currentIndex = (index < 0) ? 0 : (index > maxIndex ? maxIndex : index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomNavIndex = _currentIndex <= 2 ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MeniuScreen(onNavigateTab: _setTab, onOpenOrar: () => _setTab(2)),
          TeodorScreen(onNavigateTab: _setTab),
          OrarScreen(onBackToHome: () => _setTab(0)),
          CereriScreen(onNavigateTab: _setTab),
          InboxScreen(onNavigateTab: _setTab),
        ],
      ),
      bottomNavigationBar: FixedBottomNav(
        currentIndex: bottomNavIndex,
        onTap: _setTab,
      ),
    );
  }
}
