import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

class KilnMark extends StatelessWidget {
  const KilnMark({super.key, this.size = 28, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _KilnMarkPainter(ink)),
    );
  }
}

class _KilnMarkPainter extends CustomPainter {
  _KilnMarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * 0.075
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final arch = Rect.fromLTWH(side * 0.16, side * 0.16, side * 0.68, side * 0.68);
    canvas.drawArc(arch, math.pi, -math.pi, false, stroke);
    final foot = side * 0.16 + side * 0.34;
    canvas.drawLine(Offset(side * 0.16, foot), Offset(side * 0.16, side * 0.84), stroke);
    canvas.drawLine(Offset(side * 0.84, foot), Offset(side * 0.84, side * 0.84), stroke);
    canvas.drawLine(Offset(side * 0.16, side * 0.84), Offset(side * 0.84, side * 0.84), stroke);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(side * 0.5, side * 0.64),
        width: side * 0.08,
        height: side * 0.16,
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _KilnMarkPainter oldDelegate) => oldDelegate.color != color;
}
