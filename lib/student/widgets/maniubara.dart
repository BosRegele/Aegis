import 'package:flutter/material.dart';

class FixedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FixedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF7AAF5B),
      unselectedItemColor: const Color(0xFF5F6771),
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
      onTap: onTap,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_rounded),
          label: 'Acasa',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.qr_code_2_rounded),
          label: 'Acces',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_rounded),
          label: 'Profil',
        ),
      ],
    );
  }
}
