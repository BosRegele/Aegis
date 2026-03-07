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
          icon: Icon(Icons.calendar_month_rounded),
          label: 'Acces',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.article_rounded),
          label: 'Cereri',
        ),
        BottomNavigationBarItem(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.person_rounded),
              Positioned(
                right: -8,
                top: -5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF7AAF5B),
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    '2',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          label: 'Inbox',
        ),
      ],
    );
  }
}
