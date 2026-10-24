import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/preferences/wallpaper_preferences_provider.dart';

class AppWallpaperBackground extends StatelessWidget {
  final AppWallpaperState wallpaper;

  const AppWallpaperBackground({
    super.key,
    required this.wallpaper,
  });

  @override
  Widget build(BuildContext context) {
    if (!wallpaper.hasValidWallpaper) {
      return const SizedBox.shrink();
    }

    final file = File(wallpaper.filePath!);
    final blur = wallpaper.blur;
    final opacity = wallpaper.opacity;

    Widget imageWidget = Image.file(
      file,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      alignment: Alignment.center,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
    );

    if (blur > 0.1) {
      imageWidget = ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: imageWidget,
      );
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final colorScheme = theme.colorScheme;
    final baseColor = isDark
        ? const Color(0xFF0C0C0F)
        : colorScheme.surface;

    Widget renderedImage = Opacity(
      opacity: opacity.clamp(0.05, 1.0),
      child: ClipRect(
        child: imageWidget,
      ),
    );

    if (!isDark) {
      // In light mode, apply a soft tonal wash of the light surface so text and cards stay expressive and readable
      renderedImage = Stack(
        fit: StackFit.expand,
        children: [
          renderedImage,
          ColoredBox(
            color: colorScheme.surface.withValues(
              alpha: (1.0 - (opacity * 0.7)).clamp(0.10, 0.60),
            ),
          ),
        ],
      );
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: ColoredBox(
          color: baseColor,
          child: renderedImage,
        ),
      ),
    );
  }
}
