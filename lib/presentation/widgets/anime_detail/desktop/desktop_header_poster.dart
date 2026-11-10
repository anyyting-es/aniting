import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Vertical poster shown at the top of the desktop detail header, floating
/// just below the back button and horizontally centered with the clear logo.
class DesktopHeaderPoster extends StatelessWidget {
  final String url;
  final double width;
  final double height;

  const DesktopHeaderPoster({
    super.key,
    required this.url,
    this.width = 300,
    this.height = 450,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(16);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 38,
            spreadRadius: 2,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CachedNetworkImage(
          imageUrl: url,
          width: width,
          height: height,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 220),
          placeholder: (_, _) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
          errorWidget: (_, _, _) => Container(
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
      ),
    );
  }
}
