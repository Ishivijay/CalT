import 'package:flutter/material.dart';

class CaltLogoMark extends StatelessWidget {
  const CaltLogoMark({super.key});

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CaltLogoPainter(
      ring: const Color(0xFFFFC966), // mango, matches AppPalette.carbsColor
      bolt: Theme.of(context).colorScheme.primary,
    ),
  );
}

class _CaltLogoPainter extends CustomPainter {
  const _CaltLogoPainter({required this.ring, required this.bolt});
  final Color ring;
  final Color bolt;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = side * .13
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: side * .37),
      -.83,
      4.98,
      false,
      ringPaint,
    );
    final scale = side / 108;
    final path = Path()
      ..moveTo(center.dx + 5 * scale, center.dy - 28 * scale)
      ..lineTo(center.dx - 20 * scale, center.dy + 8 * scale)
      ..lineTo(center.dx - 4 * scale, center.dy + 8 * scale)
      ..lineTo(center.dx - 8 * scale, center.dy + 30 * scale)
      ..lineTo(center.dx + 20 * scale, center.dy - 7 * scale)
      ..lineTo(center.dx + 4 * scale, center.dy - 7 * scale)
      ..close();
    canvas.drawPath(path, Paint()..color = bolt);
  }

  @override
  bool shouldRepaint(_CaltLogoPainter oldDelegate) =>
      oldDelegate.ring != ring || oldDelegate.bolt != bolt;
}
