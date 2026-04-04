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
  bool _profilePressed = false;
  String? _inboxHighlightId;

  @override
  void initState() {
    super.initState();
    final idx = widget.initialIndex;
    final maxIndex = 3; // 4 children: 0, 1, 2, 3
    _currentIndex = idx < 0 ? 0 : (idx > maxIndex ? maxIndex : idx);
  }

  void _openInboxWithHighlight(String docId) {
    setState(() {
      _currentIndex = 3;
      _inboxHighlightId = docId;
    });
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
              MeniuScreen(
                onNavigateTab: _setTab,
                onNavigateToActiveLeave: _openInboxWithHighlight,
              ),
              OrarScreen(onBackToHome: () => _setTab(0)),
              CereriScreen(onNavigateTab: _setTab),
              InboxScreen(
                onNavigateTab: _setTab,
                highlightDocId: _inboxHighlightId,
                onHighlightConsumed: () =>
                    setState(() => _inboxHighlightId = null),
              ),
            ],
          ),
          if (_currentIndex == 0)
            Positioned(
              top: topPadding - 2,
              right: 14,
              child: GestureDetector(
                onTapDown: (_) => setState(() => _profilePressed = true),
                onTapUp: (_) {
                  setState(() => _profilePressed = false);
                  _setTab(1);
                },
                onTapCancel: () => setState(() => _profilePressed = false),
                child: AnimatedScale(
                  scale: _profilePressed ? 0.78 : 1.0,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
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
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
