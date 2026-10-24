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
  final Color? dominantColor;
  final bool isFullPage;

  const DesktopHeroBanner({
    super.key,
    required this.bannerUrl,
    required this.isBlurredCover,
    required this.scrollProgress,
    required this.scaffoldBackgroundColor,
    this.dominantColor,
    this.isFullPage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bannerUrl == null) return const SizedBox.shrink();

    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = isBlurredCover || isBlurSetting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bannerContent = RepaintBoundary(
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image with Blur Fallback – instantaneous zero-drift presentation
            SizedBox.expand(
              child: shouldBlur
                  ? ClipRect(
                      child: ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                        child: Transform.scale(
                          scale: 1.25,
                          child: CachedNetworkImage(
                            imageUrl: bannerUrl!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.2),
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            errorWidget: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: bannerUrl!,
                      fit: BoxFit.cover,
                      alignment: const Alignment(0, -0.2),
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
            ),

            if (isFullPage) ...[
              // Full-page: Left-to-right gradient using dominant color for contrast on the left,
              // leaving the right side 100% bright and alive!
              Builder(
                builder: (context) {
                  final darkShadowColor = dominantColor != null
                      ? Color.alphaBlend(dominantColor!.withValues(alpha: isDark ? 0.40 : 0.25), scaffoldBackgroundColor)
                      : scaffoldBackgroundColor;

                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          darkShadowColor.withValues(alpha: isDark ? 0.95 : 0.92),
                          darkShadowColor.withValues(alpha: isDark ? 0.80 : 0.75),
                          darkShadowColor.withValues(alpha: isDark ? 0.35 : 0.30),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.30, 0.55, 0.85],
                      ),
                    ),
                  );
                },
              ),

              // Full-page: Vertical gradient at top for status/back bar and at bottom to ground the content
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scaffoldBackgroundColor.withValues(alpha: isDark ? 0.45 : 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      scaffoldBackgroundColor.withValues(alpha: isDark ? 0.50 : 0.60),
                      scaffoldBackgroundColor.withValues(alpha: isDark ? 0.85 : 0.92),
                    ],
                    stops: const [0.0, 0.12, 0.60, 0.88, 1.0],
                  ),
                ),
              ),

              // Full-page: Subtle scroll-driven darkening
              if (scrollProgress > 0)
                Container(
                  color: scaffoldBackgroundColor.withValues(alpha: (scrollProgress * 0.25)),
                ),
            ] else ...[
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
          ],
        ),
      ),
    );

    if (isFullPage) {
      return Positioned.fill(child: bannerContent);
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 640,
      child: bannerContent,
    );
  }
}
