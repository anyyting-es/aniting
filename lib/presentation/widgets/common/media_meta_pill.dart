import 'package:flutter/material.dart';

/// Small translucent pill drawn over cover art to show quick facts
/// (episode/chapter count, year) without adding height to the card.
class MediaMetaPill extends StatelessWidget {
  final String text;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color backgroundColor;
  final Color textColor;

  const MediaMetaPill({
    super.key,
    required this.text,
    this.fontSize = 9.5,
    this.padding = const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
    this.borderRadius = const BorderRadius.all(Radius.circular(5)),
    this.backgroundColor = const Color(0xB8000000),
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}
