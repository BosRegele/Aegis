import 'package:flutter/material.dart';

const parentGreen = Color(0xFF0C6D1C);
const parentPageBg = Color(0xFFF7F8EC);
const parentCardBg = Colors.white;
const parentMutedGreen = Color(0xFFDDE5D8);
const parentText = Color(0xFF151A14);
const parentSubtle = Color(0xFF4A5746);

class ParentPatternHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final double height;

  const ParentPatternHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: parentGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(44),
          bottomRight: Radius.circular(44),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x220A5A18),
            blurRadius: 26,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(44),
          bottomRight: Radius.circular(44),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -34,
              top: -26,
              child: _SoftCircle(
                size: 124,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              left: 200,
              top: 102,
              child: _SoftCircle(
                size: 82,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
            Positioned.fill(child: CustomPaint(painter: _HeaderDotsPainter())),
            SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.7,
                        ),
                      ),
                    ),
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

class ParentDottedBackground extends StatelessWidget {
  final Widget child;

  const ParentDottedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: parentPageBg,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _BodyDotsPainter(),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _SoftCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _HeaderDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.10);
    const spacing = 32.0;
    const radius = 1.7;

    for (double y = 18; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BodyDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFC7D6C0).withValues(alpha: 0.55);
    const spacing = 32.0;
    const radius = 1.8;

    for (double y = 14; y < size.height; y += spacing) {
      for (double x = 16; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}