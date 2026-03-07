import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

class MeniuScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const MeniuScreen({super.key, this.onNavigateTab, this.onOpenOrar});

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    return Scaffold(
      backgroundColor: const Color(0xFFD8DDD8),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 110,
              color: const Color(0xFF7AAF5B),
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      bottom: 8,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.shield_rounded,
                      size: 72,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                decoration: const BoxDecoration(
                  color: Color(0xFFD8DDD8),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        'Bun venit, $displayName!',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2E3B4E),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: 'Acces\nQR',
                            icon: Icons.qr_code_2_rounded,
                            colors: const [
                              Color(0xFF4B78D2),
                              Color(0xFF304EAF),
                            ],
                            onTap: () {
                              if (onNavigateTab != null) {
                                onNavigateTab!(1);
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TeodorScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MenuTile(
                            label: 'Orar',
                            icon: Icons.calendar_month_rounded,
                            colors: const [
                              Color(0xFFF0B15A),
                              Color(0xFFE47E2D),
                            ],
                            onTap: () {
                              if (onOpenOrar != null) {
                                onOpenOrar!();
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const OrarScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _MenuTile(
                            label: 'Cereri\nInvoire',
                            icon: Icons.article_rounded,
                            colors: const [
                              Color(0xFF17B5A8),
                              Color(0xFF0C8D80),
                            ],
                            onTap: () {
                              if (onNavigateTab != null) {
                                onNavigateTab!(2);
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const CereriScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MenuTile(
                            label: 'Mesaje',
                            icon: Icons.chat_bubble_rounded,
                            colors: const [
                              Color(0xFF9C84E0),
                              Color(0xFF6E46C2),
                            ],
                            onTap: () {
                              if (onNavigateTab != null) {
                                onNavigateTab!(3);
                                return;
                              }

                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const InboxScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _AccessInfoCard(
                      statusText: 'in afara incintei',
                      hasActivePermission: false,
                      lastScanText: '08:30 - Turnichet principal',
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.label,
    required this.icon,
    required this.colors,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 104,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, color: Colors.white, size: 44),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessInfoCard extends StatelessWidget {
  final String statusText;
  final bool hasActivePermission;
  final String lastScanText;

  const _AccessInfoCard({
    required this.statusText,
    required this.hasActivePermission,
    required this.lastScanText,
  });

  @override
  Widget build(BuildContext context) {
    final permissionText = hasActivePermission ? 'Da' : 'Nu';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD0D6D4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 24, color: Color(0xFF2E343B)),
              children: [
                const TextSpan(text: 'Status: '),
                TextSpan(
                  text: statusText,
                  style: const TextStyle(
                    color: Color(0xFFC4463D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Ultima scanare: $lastScanText',
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF48515A),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 24, color: Color(0xFF2E343B)),
              children: [
                const TextSpan(text: 'Permisiune activa: '),
                TextSpan(
                  text: permissionText,
                  style: TextStyle(
                    color: hasActivePermission
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC4463D),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
