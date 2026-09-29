import 'package:flutter/material.dart';

enum InvertedCornerPlacement {
  topRight,
  bottomRight,
}

class InvertedCornerPainter extends CustomPainter {
  final Color color;
  final InvertedCornerPlacement placement;
  final double radius;

  InvertedCornerPainter({
    required this.color,
    required this.placement,
    this.radius = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    if (placement == InvertedCornerPlacement.topRight) {
      // Paints a concave curve at the bottom-right of the upper area
      // Canvas size: radius x radius
      // The curve cuts inwards toward bottom-right
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
      path.arcToPoint(
        Offset(0, size.height),
        radius: Radius.circular(radius),
        clockwise: false,
      );
      path.close();
    } else {
      // Paints a concave curve at the top-right of the lower area
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.arcToPoint(
        Offset(0, 0),
        radius: Radius.circular(radius),
        clockwise: true,
      );
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant InvertedCornerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.placement != placement ||
        oldDelegate.radius != radius;
  }
}
