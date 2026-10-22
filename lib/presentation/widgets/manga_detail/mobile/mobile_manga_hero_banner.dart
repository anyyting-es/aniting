import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Parallax hero banner for Manga Mobile Layout with 0 FPS CPU consumption at idle.
/// Operates passively from the scroll controller offset without any ticking animation loops.
class MobileMangaHeroBanner extends StatelessWidget {
  final ScrollController scrollController;
  final String? bannerUrl;
  final bool shouldBlur;

  const MobileMangaHeroBanner({
    super.key,
    required this.scrollController,
    required this.bannerUrl,
    required this.shouldBlur,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Positioned(
      top: -16,
      left: 0,
      right: 0,
      height: 345,
      child: Container(
        color: theme.scaffoldBackgroundColor,
        child: ClipRect(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: scrollController,
              builder: (context, _) {
                final scrollOffset = scrollController.hasClients
                    ? scrollController.offset.clamp(0.0, double.infinity)
                    : 0.0;
                final parallaxTranslateY =
                    scrollOffset > 0 ? -scrollOffset * 0.35 : 0.0;
                final scrollDarkening = (scrollOffset / 200.0).clamp(0.0, 1.0);

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // Parallax Banner Image (strictly clipped to bounds to avoid blur bleed)
                    Transform.translate(
                      offset: Offset(0, parallaxTranslateY),
                      child: bannerUrl != null
                          ? (shouldBlur
                              ? ClipRect(
                                  child: ImageFiltered(
                                    imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                                    child: Transform.scale(
                                      scale: 1.25,
                                      child: CachedNetworkImage(
                                        imageUrl: bannerUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        memCacheWidth: 1080,
                                        errorWidget: (_, _, _) =>
                                            Container(color: theme.colorScheme.surfaceContainer),
                                      ),
                                    ),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: bannerUrl!,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  memCacheWidth: 1080,
                                  errorWidget: (_, _, _) =>
                                      Container(color: theme.colorScheme.surfaceContainer),
                                ))
                          : Container(color: theme.colorScheme.surfaceContainer),
                    ),

                    // Stationary Multi-Stop Cinematic Gradient into Theme Background
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.black.withValues(alpha: 0.15),
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.black.withValues(alpha: 0.85),
                                  theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
                                  theme.scaffoldBackgroundColor,
                                ]
                              : [
                                  Colors.black.withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.white.withValues(alpha: 0.50),
                                  Colors.white.withValues(alpha: 0.88),
                                  theme.scaffoldBackgroundColor.withValues(alpha: 0.96),
                                  theme.scaffoldBackgroundColor,
                                ],
                          stops: const [0.0, 0.20, 0.45, 0.70, 0.90, 1.0],
                        ),
                      ),
                    ),

                    // Scroll-driven darkening: seamlessly transitions into active theme background
                    Container(
                      color: theme.scaffoldBackgroundColor.withValues(alpha: scrollDarkening),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
