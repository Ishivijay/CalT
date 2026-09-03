import 'dart:math' as math;

import 'package:flutter/material.dart';

/// CalT's brand mark, drawn to the same geometry as the launcher icon
/// (see `tools/icon/generate_icon.dart`): a calorie ring opened into a
/// "C" — monogram and progress ring in one shape — with a bolt inside.
///
/// The ring keeps its fixed coral-to-amber brand gradient rather than
/// following the user's accent colour, so the mark in the app bar and
/// the icon on the home screen stay recognisably the same thing. Only
/// the bolt adapts, so it stays legible on either theme's surface.
class CaltLogoMark extends StatelessWidget {
  const CaltLogoMark({super.key});

  static const ringStart = Color(0xFFC7401F);
  static const ringEnd = Color(0xFFEEA13C);

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _CaltLogoPainter(bolt: Theme.of(context).colorScheme.onSurface),
  );
}

class _CaltLogoPainter extends CustomPainter {
  const _CaltLogoPainter({required this.bolt});

  final Color bolt;

  // Gap at the upper right, leaning the same way as the bolt.
  static const _arcStart = -14 * math.pi / 180;
  static const _sweep = 298 * math.pi / 180;

  // Proportions of the shortest side, matched to the icon generator.
  static const _radiusRatio = 0.330;
  static const _strokeRatio = 0.084;
  static const _boltRatio = 0.322;

  static const _boltPath = <Offset>[
    Offset(0.19, -0.60),
    Offset(-0.35, 0.05),
    Offset(-0.05, 0.05),
    Offset(-0.19, 0.60),
    Offset(0.35, -0.05),
    Offset(0.05, -0.05),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = side * _radiusRatio;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      _arcStart,
      _sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = side * _strokeRatio
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: 0,
          endAngle: _sweep,
          colors: [CaltLogoMark.ringStart, CaltLogoMark.ringEnd],
          transform: GradientRotation(_arcStart),
        ).createShader(rect),
    );

    final scale = side * _boltRatio;
    final path = Path();
    for (var i = 0; i < _boltPath.length; i++) {
      final point = center + _boltPath[i] * scale;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = bolt);
  }

  @override
  bool shouldRepaint(_CaltLogoPainter oldDelegate) => oldDelegate.bolt != bolt;
}
