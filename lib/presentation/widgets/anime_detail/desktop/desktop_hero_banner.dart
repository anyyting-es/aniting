import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/banner_blur_provider.dart';

class DesktopHeroBanner extends ConsumerWidget {
  final String? bannerUrl;
  final bool isBlurredCover;
  final double scrollProgress;
  final Color scaffoldBackgroundColor;

  const DesktopHeroBanner({
    super.key,
    required this.bannerUrl,
    required this.isBlurredCover,
    required this.scrollProgress,
    required this.scaffoldBackgroundColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bannerUrl == null) return const SizedBox.shrink();

    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = isBlurredCover || isBlurSetting;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 640,
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
          children: [
            // Banner Image with Blur Fallback (scroll darkening handled by overlay below)
            shouldBlur
                ? ClipRect(
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Transform.scale(
                        scale: 1.25,
                        child: CachedNetworkImage(
                          imageUrl: bannerUrl!,
                          fit: BoxFit.cover,
                          alignment: const Alignment(0, -0.2),
                          fadeInDuration: const Duration(milliseconds: 250),
                          fadeOutDuration: const Duration(milliseconds: 150),
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: bannerUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    fadeInDuration: const Duration(milliseconds: 250),
                    fadeOutDuration: const Duration(milliseconds: 150),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),

            // Ambient darkening overlay in theme tone (translucent for vivid fanart)
            Container(
              color: scaffoldBackgroundColor.withValues(alpha: 0.18),
            ),

            // Left-to-right gradient: deeper opacity on left for text readability, clear on right
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    scaffoldBackgroundColor.withValues(alpha: 0.88),
                    scaffoldBackgroundColor.withValues(alpha: 0.60),
                    scaffoldBackgroundColor.withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.32, 0.65, 1.0],
                ),
              ),
            ),

            // Non-linear bottom gradient for deep cinematic contrast into theme background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    scaffoldBackgroundColor.withValues(alpha: 0.20),
                    scaffoldBackgroundColor.withValues(alpha: 0.55),
                    scaffoldBackgroundColor.withValues(alpha: 0.88),
                    scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.40, 0.65, 0.82, 0.94, 1.0],
                ),
              ),
            ),

            // Scroll-driven darkening: Turns completely into the active theme background
            Container(
              color: scaffoldBackgroundColor.withValues(alpha: scrollProgress),
            ),
          ],
        ),
      ),
    ),
  );
  }
}
