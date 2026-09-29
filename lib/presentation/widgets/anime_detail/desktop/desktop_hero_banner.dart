import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DesktopHeroBanner extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (bannerUrl == null) return const SizedBox.shrink();

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: 480,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner Image with Blur Fallback & Scroll-Driven Dissolve
          Opacity(
            opacity: (1.0 - scrollProgress * 0.95).clamp(0.0, 1.0),
            child: isBlurredCover
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                    child: Transform.scale(
                      scale: 1.25,
                      child: CachedNetworkImage(
                        imageUrl: bannerUrl!,
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.2),
                        errorWidget: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: bannerUrl!,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
          ),

          // Ambient darkening overlay in theme tone
          Container(
            color: scaffoldBackgroundColor.withValues(alpha: 0.22),
          ),

          // Non-linear bottom gradient for deep cinematic contrast into theme background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  scaffoldBackgroundColor.withValues(alpha: 0.35),
                  scaffoldBackgroundColor.withValues(alpha: 0.70),
                  scaffoldBackgroundColor.withValues(alpha: 0.92),
                  scaffoldBackgroundColor,
                ],
                stops: const [0.0, 0.35, 0.65, 0.88, 1.0],
              ),
            ),
          ),

          // Scroll-driven darkening: Turns completely into the active theme background
          Container(
            color: scaffoldBackgroundColor.withValues(alpha: scrollProgress),
          ),
        ],
      ),
    );
  }
}
