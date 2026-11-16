import 'dart:math';

import 'package:material_ui/material_ui.dart';

class GlazeSwatch extends StatelessWidget {
  const GlazeSwatch({
    super.key,
    required this.color,
    required this.label,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
  });

  final Color color;
  final String label;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: borderRadius),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: CustomPaint(
            painter: _GlazePainter(color),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _GlazePainter extends CustomPainter {
  _GlazePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final light = Color.lerp(color, const Color(0xFFFFFFFF), 0.14)!;
    final dark = Color.lerp(color, const Color(0xFF000000), 0.2)!;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [light, color, dark],
        ).createShader(rect),
    );
    final speck = Paint()
      ..color = (color.computeLuminance() > 0.55 ? const Color(0xFF241816) : const Color(0xFFF6F1EA))
          .withValues(alpha: 0.16);
    final random = Random(color.toARGB32());
    final count = 18 + (size.shortestSide / 12).round();
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width, random.nextDouble() * size.height),
        random.nextDouble() * 1.5 + 0.4,
        speck,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GlazePainter oldDelegate) => oldDelegate.color != color;
}
