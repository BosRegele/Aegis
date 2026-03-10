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
    _currentIndex = idx < 0 ? 0 : (idx > 2 ? 2 : idx);
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
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          MeniuScreen(onNavigateTab: _setTab, onOpenOrar: () => _setTab(2)),
          TeodorScreen(onNavigateTab: _setTab),
          OrarScreen(onBackToHome: () => _setTab(0)),
        ],
      ),
      bottomNavigationBar: FixedBottomNav(
        currentIndex: _currentIndex,
        onTap: _setTab,
      ),
    );
  }
}
