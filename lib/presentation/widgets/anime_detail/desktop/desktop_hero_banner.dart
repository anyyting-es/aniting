import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/banner_blur_provider.dart';

class DesktopHeroBanner extends ConsumerWidget {
  final String? bannerUrl;
  final bool isBlurredCover;
  final ValueListenable<double>? scrollProgressListenable;
  final double scrollProgress;
  final Color scaffoldBackgroundColor;
  final bool isFullPage;

  const DesktopHeroBanner({
    super.key,
    required this.bannerUrl,
    required this.isBlurredCover,
    this.scrollProgressListenable,
    this.scrollProgress = 0.0,
    required this.scaffoldBackgroundColor,
    this.isFullPage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (bannerUrl == null) return const SizedBox.shrink();

    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = isBlurredCover || isBlurSetting;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bannerContent = ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. Static Backdrop Layer (Cached in GPU layer, NEVER repainted on scroll) ───
          RepaintBoundary(
            child: _DesktopHeroStaticBackdrop(
              bannerUrl: bannerUrl!,
              shouldBlur: shouldBlur,
              isFullPage: isFullPage,
              isDark: isDark,
              scaffoldBackgroundColor: scaffoldBackgroundColor,
            ),
          ),

          // ─── 2. Scroll-driven Darkening Layer (Only this simple fill repaints during scroll) ───
          if (scrollProgressListenable != null)
            ValueListenableBuilder<double>(
              valueListenable: scrollProgressListenable!,
              builder: (context, progress, _) {
                final alpha = isFullPage
                    ? (progress * 0.78).clamp(0.0, 0.85)
                    : progress.clamp(0.0, 1.0);
                if (alpha <= 0.001) return const SizedBox.shrink();
                return Container(
                  color: scaffoldBackgroundColor.withValues(alpha: alpha),
                );
              },
            )
          else if (scrollProgress > 0)
            Container(
              color: scaffoldBackgroundColor.withValues(
                alpha: isFullPage
                    ? (scrollProgress * 0.78).clamp(0.0, 0.85)
                    : scrollProgress.clamp(0.0, 1.0),
              ),
            ),
        ],
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

/// Fully isolated, static backdrop widget.
/// Decodes and renders the banner image, blur filter, and static linear gradients once.
class _DesktopHeroStaticBackdrop extends StatelessWidget {
  final String bannerUrl;
  final bool shouldBlur;
  final bool isFullPage;
  final bool isDark;
  final Color scaffoldBackgroundColor;

  const _DesktopHeroStaticBackdrop({
    required this.bannerUrl,
    required this.shouldBlur,
    required this.isFullPage,
    required this.isDark,
    required this.scaffoldBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
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
                        imageUrl: bannerUrl,
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
                  imageUrl: bannerUrl,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),
        ),

        if (isFullPage) ...[
          // Full-page: Left-to-right gradient using pure black/scaffold background for contrast on the left,
          // leaving the right side 100% bright and alive without color shifts or blue flashing!
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  scaffoldBackgroundColor.withValues(alpha: isDark ? 0.96 : 0.92),
                  scaffoldBackgroundColor.withValues(alpha: isDark ? 0.82 : 0.75),
                  scaffoldBackgroundColor.withValues(alpha: isDark ? 0.35 : 0.30),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.30, 0.55, 0.85],
              ),
            ),
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
        ],
      ],
    );
  }
}
