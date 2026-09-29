import 'package:flutter/material.dart';

/// Custom vertical bar thumb shape matching Material 3 expressive design.
class VerticalBarThumbShape extends SliderComponentShape {
  final double width;
  final double height;
  final double radius;

  const VerticalBarThumbShape({
    this.width = 4.0,
    this.height = 32.0,
    this.radius = 2.0,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? Colors.deepPurple
      ..style = PaintingStyle.fill;

    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }
}

/// Custom expressive track shape with asymmetric rounded corners and gap around thumb,
/// without any end dot indicator.
class M3ExpressiveTrackShape extends SliderTrackShape {
  final double trackHeight;
  final double gap;
  final double outerRadius;
  final double innerRadius;

  const M3ExpressiveTrackShape({
    this.trackHeight = 24.0,
    this.gap = 4.0,
    this.outerRadius = 12.0,
    this.innerRadius = 2.5,
  });

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    const double horizontalPadding = 4.0;
    final double trackLeft = offset.dx + horizontalPadding;
    final double trackTop =
        offset.dy + (parentBox.size.height - trackHeight) / 2;
    final double trackWidth = parentBox.size.width - (horizontalPadding * 2);
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
    double additionalActiveTrackHeight = 0,
  }) {
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final Canvas canvas = context.canvas;
    final double halfThumbWidth =
        (sliderTheme.thumbShape?.getPreferredSize(isEnabled, isDiscrete).width ?? 4.0) / 2;

    // 1. Barra activa (Izquierda)
    final double activeRight = thumbCenter.dx - halfThumbWidth - gap;
    if (activeRight > trackRect.left) {
      final Rect activeRect = Rect.fromLTRB(
        trackRect.left,
        trackRect.top,
        activeRight,
        trackRect.bottom,
      );
      final activePaint = Paint()
        ..color = sliderTheme.activeTrackColor ?? Colors.deepPurple
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          activeRect,
          topLeft: Radius.circular(outerRadius),
          bottomLeft: Radius.circular(outerRadius),
          topRight: Radius.circular(innerRadius),
          bottomRight: Radius.circular(innerRadius),
        ),
        activePaint,
      );
    }

    // 2. Barra inactiva (Derecha)
    final double inactiveLeft = thumbCenter.dx + halfThumbWidth + gap;
    if (inactiveLeft < trackRect.right) {
      final Rect inactiveRect = Rect.fromLTRB(
        inactiveLeft,
        trackRect.top,
        trackRect.right,
        trackRect.bottom,
      );
      final inactivePaint = Paint()
        ..color = sliderTheme.inactiveTrackColor ?? Colors.deepPurple.shade100
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          inactiveRect,
          topLeft: Radius.circular(innerRadius),
          bottomLeft: Radius.circular(innerRadius),
          topRight: Radius.circular(outerRadius),
          bottomRight: Radius.circular(outerRadius),
        ),
        inactivePaint,
      );
    }
  }
}

/// Vertical interactive or display slider matching Material 3 Expressive design.
class M3ExpressiveVerticalSlider extends StatelessWidget {
  final double value; // 0.0 to 1.0
  final double height;
  final double trackWidth;
  final double thumbWidth;
  final double thumbHeight;
  final double gap;
  final double? outerRadius;
  final double innerRadius;
  final Color activeColor;
  final Color inactiveColor;
  final ValueChanged<double>? onChanged;
  final VoidCallback? onChangeStart;
  final VoidCallback? onChangeEnd;
  final bool showStopDot;
  final Color? stopDotColor;
  final bool showThumb;

  const M3ExpressiveVerticalSlider({
    super.key,
    required this.value,
    this.height = 180.0,
    this.trackWidth = 28.0,
    this.thumbWidth = 38.0,
    this.thumbHeight = 4.0,
    this.gap = 4.0,
    this.outerRadius,
    this.innerRadius = 2.5,
    required this.activeColor,
    required this.inactiveColor,
    this.onChanged,
    this.onChangeStart,
    this.onChangeEnd,
    this.showStopDot = false,
    this.stopDotColor,
    this.showThumb = true,
  });

  void _handleDrag(Offset localPosition, double totalHeight) {
    if (totalHeight <= 0 || onChanged == null) return;
    // In vertical: 0.0 is at the bottom, 1.0 is at the top
    final double normalized = 1.0 - (localPosition.dy / totalHeight);
    onChanged!(normalized.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final double resolvedOuterRadius = outerRadius ?? (trackWidth / 2);
    final double maxW =
        showThumb && thumbWidth > trackWidth ? thumbWidth : trackWidth;

    final customPaint = SizedBox(
      width: maxW,
      height: height,
      child: CustomPaint(
        size: Size(maxW, height),
        painter: _M3VerticalSliderPainter(
          value: value.clamp(0.0, 1.0),
          trackWidth: trackWidth,
          thumbWidth: thumbWidth,
          thumbHeight: thumbHeight,
          gap: gap,
          outerRadius: resolvedOuterRadius,
          innerRadius: innerRadius,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
          showStopDot: showStopDot,
          stopDotColor: stopDotColor,
          showThumb: showThumb,
        ),
      ),
    );

    if (onChanged == null) {
      return customPaint;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => onChangeStart?.call(),
      onVerticalDragDown: (details) {
        onChangeStart?.call();
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _handleDrag(details.localPosition, box.size.height);
        }
      },
      onVerticalDragUpdate: (details) {
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _handleDrag(details.localPosition, box.size.height);
        }
      },
      onVerticalDragEnd: (_) => onChangeEnd?.call(),
      onVerticalDragCancel: () => onChangeEnd?.call(),
      onTapDown: (details) {
        onChangeStart?.call();
        final box = context.findRenderObject() as RenderBox?;
        if (box != null) {
          _handleDrag(details.localPosition, box.size.height);
        }
      },
      onTapUp: (_) => onChangeEnd?.call(),
      onTapCancel: () => onChangeEnd?.call(),
      child: customPaint,
    );
  }
}

class _M3VerticalSliderPainter extends CustomPainter {
  final double value;
  final double trackWidth;
  final double thumbWidth;
  final double thumbHeight;
  final double gap;
  final double outerRadius;
  final double innerRadius;
  final Color activeColor;
  final Color inactiveColor;
  final bool showStopDot;
  final Color? stopDotColor;
  final bool showThumb;

  _M3VerticalSliderPainter({
    required this.value,
    required this.trackWidth,
    required this.thumbWidth,
    required this.thumbHeight,
    required this.gap,
    required this.outerRadius,
    required this.innerRadius,
    required this.activeColor,
    required this.inactiveColor,
    this.showStopDot = false,
    this.stopDotColor,
    this.showThumb = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double trackLeft = centerX - (trackWidth / 2);
    final double trackRight = centerX + (trackWidth / 2);

    // Position Y of thumb (0.0 is at bottom, 1.0 is at top)
    final double thumbCenterY = size.height * (1.0 - value);

    if (!showThumb) {
      final trackRect = Rect.fromLTWH(trackLeft, 0, trackWidth, size.height);
      final trackRRect =
          RRect.fromRectAndRadius(trackRect, Radius.circular(outerRadius));

      // 1. Inactive background capsule
      final inactivePaint = Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(trackRRect, inactivePaint);

      // 2. Active track clipped to capsule
      if (value > 0) {
        canvas.save();
        canvas.clipRRect(trackRRect);
        final activePaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
        final activeRect = Rect.fromLTRB(
          trackLeft,
          thumbCenterY,
          trackRight,
          size.height,
        );
        canvas.drawRect(activeRect, activePaint);
        canvas.restore();
      }

      if (showStopDot) {
        final dotPaint = Paint()
          ..color = stopDotColor ?? inactiveColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(centerX, 8), 2.0, dotPaint);
      }
      return;
    }

    final double halfThumbHeight = thumbHeight / 2;

    // 1. Inactive track (upper portion)
    final double inactiveBottom = thumbCenterY - halfThumbHeight - gap;
    if (inactiveBottom > 0) {
      final inactiveRect = Rect.fromLTRB(
        trackLeft,
        0,
        trackRight,
        inactiveBottom,
      );
      final inactivePaint = Paint()
        ..color = inactiveColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          inactiveRect,
          topLeft: Radius.circular(outerRadius),
          topRight: Radius.circular(outerRadius),
          bottomLeft: Radius.circular(innerRadius),
          bottomRight: Radius.circular(innerRadius),
        ),
        inactivePaint,
      );

      if (showStopDot) {
        final dotPaint = Paint()
          ..color = stopDotColor ?? inactiveColor.withValues(alpha: 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(centerX, 8), 2.0, dotPaint);
      }
    }

    // 2. Active track (lower portion)
    final double activeTop = thumbCenterY + halfThumbHeight + gap;
    if (activeTop < size.height) {
      final activeRect = Rect.fromLTRB(
        trackLeft,
        activeTop,
        trackRight,
        size.height,
      );
      final activePaint = Paint()
        ..color = activeColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndCorners(
          activeRect,
          topLeft: Radius.circular(innerRadius),
          topRight: Radius.circular(innerRadius),
          bottomLeft: Radius.circular(outerRadius),
          bottomRight: Radius.circular(outerRadius),
        ),
        activePaint,
      );
    }

    // 3. Thumb indicator horizontal bar
    final thumbRect = Rect.fromCenter(
      center: Offset(centerX, thumbCenterY),
      width: thumbWidth,
      height: thumbHeight,
    );
    final thumbPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, Radius.circular(thumbHeight / 2)),
      thumbPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _M3VerticalSliderPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.trackWidth != trackWidth ||
        oldDelegate.thumbWidth != thumbWidth ||
        oldDelegate.thumbHeight != thumbHeight ||
        oldDelegate.outerRadius != outerRadius ||
        oldDelegate.innerRadius != innerRadius ||
        oldDelegate.gap != gap ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.showStopDot != showStopDot ||
        oldDelegate.stopDotColor != stopDotColor ||
        oldDelegate.showThumb != showThumb;
  }
}

