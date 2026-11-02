import 'package:flutter/material.dart';

/// Thin, self-contained indeterminate progress line for the calendar header.
class CalendarLoadingLine extends StatefulWidget {
  const CalendarLoadingLine({super.key});

  @override
  State<CalendarLoadingLine> createState() => _CalendarLoadingLineState();
}

class _CalendarLoadingLineState extends State<CalendarLoadingLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lineColor = isDark ? Colors.white : theme.colorScheme.primary;

    return SizedBox(
      height: 2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final barWidth = width * 0.3;

          return AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final left = (width + barWidth) * _controller.value - barWidth;
              return Stack(
                children: [
                  Container(
                    height: 2,
                    color: lineColor.withValues(alpha: 0.05),
                  ),
                  Positioned(
                    left: left,
                    width: barWidth,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            lineColor.withValues(alpha: 0),
                            lineColor.withValues(alpha: 0.4),
                            lineColor.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
