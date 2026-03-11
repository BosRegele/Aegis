import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/StudentInterface/widgets/maniubara.dart';
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
    _currentIndex = idx < 0 ? 0 : (idx > 4 ? 4 : idx);
  }

  void _setTab(int index) {
    if (_currentIndex == index) {
      return;
    }

    setState(() {
      _currentIndex = index;
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
