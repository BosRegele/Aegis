import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
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
  bool _showOrar = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _setTab(int index) {
    if (_currentIndex == index && !_showOrar) {
      return;
    }

    setState(() {
      _showOrar = false;
      _currentIndex = index;
    });
  }

  void _openOrar() {
    if (_showOrar) {
      return;
    }

    setState(() {
      _showOrar = true;
      _currentIndex = 0;
    });
  }

  void _closeOrar() {
    if (!_showOrar) {
      return;
    }

    setState(() {
      _showOrar = false;
      _currentIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showOrar
          ? OrarScreen(onBackToHome: _closeOrar)
          : IndexedStack(
              index: _currentIndex,
              children: [
                MeniuScreen(onNavigateTab: _setTab, onOpenOrar: _openOrar),
                TeodorScreen(onNavigateTab: _setTab),
                CereriScreen(onNavigateTab: _setTab),
                InboxScreen(onNavigateTab: _setTab),
              ],
            ),
      bottomNavigationBar: FixedBottomNav(
        currentIndex: _currentIndex,
        onTap: _setTab,
      ),
    );
  }
}
