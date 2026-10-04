import 'dart:async';
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/explore_carousel_config.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart' show optimizeTmdbImageUrl;
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class ExploreCarouselItem {
  final int mediaId;
  final String title;
  final String? bannerImage;
  final String? coverImage;
  final String? horizontalBackground;
  final String? verticalBackground;
  final String? logoImage;
  final String? format;
  final double? score;
  final int? year;
  final List<String> genres;
  final VoidCallback onTap;

  const ExploreCarouselItem({
    required this.mediaId,
    required this.title,
    this.bannerImage,
    this.coverImage,
    this.horizontalBackground,
    this.verticalBackground,
    this.logoImage,
    this.format,
    this.score,
    this.year,
    this.genres = const [],
    required this.onTap,
  });

  factory ExploreCarouselItem.fromFeatured(
    ExploreFeaturedItem item,
    BuildContext context,
  ) {
    return ExploreCarouselItem(
      mediaId: item.mediaId,
      title: item.title,
      horizontalBackground: item.horizontalBackground,
      verticalBackground: item.verticalBackground,
      logoImage: item.logo,
      format: item.format,
      score: item.score,
      year: item.year,
      genres: item.genres,
      onTap: () {
        AnimeDetailScreen.navigate(
          context,
          mediaId: item.mediaId,
        );
      },
    );
  }

  factory ExploreCarouselItem.fromAnime(
    AnimeEntry anime,
    BuildContext context,
    TitleLanguage titleLang,
  ) {
    int? year = anime.year;
    if (year == null && anime.airDate != null && anime.airDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(anime.airDate!);
      year = parsed?.year ?? int.tryParse(anime.airDate!.split('-').first);
    }

    return ExploreCarouselItem(
      mediaId: anime.mediaId,
      title: anime.displayTitle(titleLang),
      bannerImage: anime.bannerImage,
      coverImage: anime.coverImage,
      format: anime.format,
      score: anime.score,
      year: year,
      genres: anime.genres,
      onTap: () {
        AnimeDetailScreen.navigate(
          context,
          mediaId: anime.mediaId,
          initialEntry: anime,
        );
      },
    );
  }

  factory ExploreCarouselItem.fromManga(
    MangaEntry manga,
    BuildContext context,
    TitleLanguage titleLang,
  ) {
    return ExploreCarouselItem(
      mediaId: manga.mediaId,
      title: manga.displayTitle(titleLang),
      bannerImage: manga.bannerImage,
      coverImage: manga.coverImage,
      format: manga.format,
      score: manga.score,
      year: manga.year,
      genres: manga.genres,
      onTap: () {
        MangaDetailScreen.navigate(
          context,
          mediaId: manga.mediaId,
          initialEntry: manga,
        );
      },
    );
  }
}

class ExploreHeroCarousel extends ConsumerStatefulWidget {
  final List<ExploreCarouselItem> items;
  final double? height;

  const ExploreHeroCarousel({
    super.key,
    required this.items,
    this.height,
  });

  @override
  ConsumerState<ExploreHeroCarousel> createState() => _ExploreHeroCarouselState();
}

class _ExploreHeroCarouselState extends ConsumerState<ExploreHeroCarousel> {
  static const int _kVirtualBase = 10000;
  late final PageController _pageController;
  late int _currentPage;
  Timer? _autoPlayTimer;
  bool _isInteracting = false;

  @override
  void initState() {
    super.initState();
    final isInfinite = widget.items.length > 1;
    _currentPage = isInfinite
        ? (_kVirtualBase - (_kVirtualBase % widget.items.length))
        : 0;
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 1.0,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(ExploreHeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.items.length != oldWidget.items.length) {
      final isInfinite = widget.items.length > 1;
      _currentPage = isInfinite
          ? (_kVirtualBase - (_kVirtualBase % widget.items.length))
          : 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_currentPage);
      }
      _startAutoPlay();
    }
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.items.length <= 1 || _isInTest) return;

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 7), (_) {
      if (!mounted || _isInteracting || !_pageController.hasClients || !TickerMode.of(context)) return;
      // Seamlessly advance forward without fast backward rewinding
      final nextPage = _currentPage + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _pauseAutoPlay() {
    _isInteracting = true;
    _autoPlayTimer?.cancel();
  }

  void _resumeAutoPlay() {
    _isInteracting = false;
    _startAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    // Generous, expansive cinematic height:
    // On Desktop: ~70% of screen height (clamped between 620.0 and 760.0) + topPadding
    // On Mobile: ~58% of screen height (clamped between 470.0 and 580.0) + topPadding
    final defaultHeight = (isDesktop
        ? (screenHeight * 0.70).clamp(620.0, 760.0) + topPadding
        : (screenHeight * 0.58).clamp(470.0, 580.0) + topPadding).roundToDouble();
    final carouselHeight = widget.height ?? defaultHeight;
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return SizedBox(
      height: carouselHeight,
      width: double.infinity,
      child: ColoredBox(
        color: theme.scaffoldBackgroundColor,
        child: ClipRect(
          child: MouseRegion(
            onEnter: (_) => _pauseAutoPlay(),
            onExit: (_) => _resumeAutoPlay(),
            child: Listener(
              onPointerDown: (_) => _pauseAutoPlay(),
              onPointerUp: (_) => _resumeAutoPlay(),
              onPointerCancel: (_) => _resumeAutoPlay(),
              child: Stack(
                children: [
                  // 1. Edge-to-edge In-Place Crossfade Dissolve (No page-slide motion, infinite forward loop)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      return PageView.builder(
                        controller: _pageController,
                        itemCount: widget.items.length > 1 ? null : widget.items.length,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemBuilder: (context, index) {
                          final itemIndex = (index % widget.items.length + widget.items.length) % widget.items.length;
                          final item = widget.items[itemIndex];
                          return AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double page = _currentPage.toDouble();
                              if (_pageController.hasClients && _pageController.position.haveDimensions) {
                                page = _pageController.page ?? _currentPage.toDouble();
                              }

                              final double pageOffset = page - index;
                              if (pageOffset.abs() >= 1.0) {
                                return const SizedBox.shrink();
                              }
                              final double absOffset = pageOffset.abs().clamp(0.0, 1.0);
                              final double opacity = (1.0 - absOffset).clamp(0.0, 1.0);
                              if (opacity <= 0.005) {
                                return const SizedBox.shrink();
                              }
                              final double smoothOpacity = Curves.easeInOut.transform(opacity);

                              // Counteract PageView's horizontal translation completely:
                              // PageView positions child at (index - page) * width.
                              // By translating by + (page - index) * width, the net position is strictly 0.0.
                              // The content dissolves strictly in-place without page-sliding motion.
                              final double counterOffset = pageOffset * width;

                              return IgnorePointer(
                                ignoring: absOffset > 0.5,
                                child: Opacity(
                                  opacity: smoothOpacity,
                                  child: Transform.translate(
                                    offset: Offset(counterOffset, 0),
                                    child: child,
                                  ),
                                ),
                              );
                            },
                            child: RepaintBoundary(
                              child: _HeroBannerSlide(
                                key: ValueKey('hero_slide_${item.mediaId}_$index'),
                                item: item,
                                theme: theme,
                                l10n: l10n,
                                isDesktop: isDesktop,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // 2. Persistent Static Viewport Bottom Blend
                  // Fixed to the carousel viewport (outside the PageView and never faded by slide Opacity).
                  // Permanently anchors the bottom of the carousel to theme.scaffoldBackgroundColor,
                  // guaranteeing zero gap, zero separation from the section below, and preventing any
                  // backdrop artwork colors from bleeding at the seam during in-place dissolve.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: isDesktop ? 68.0 : 44.0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.35, 0.70, 0.90, 1.0],
                            colors: [
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.22),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.65),
                              theme.scaffoldBackgroundColor.withValues(alpha: 0.95),
                              theme.scaffoldBackgroundColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 2b. Subpixel Seam Bridge
                  // Eliminates any fractional floating-point rasterization seams on Windows high-DPI scaling.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: 2.5,
                    child: IgnorePointer(
                      child: ColoredBox(color: theme.scaffoldBackgroundColor),
                    ),
                  ),

                  // 3. Desktop Navigation Arrows (Prev / Next)
                  if (isDesktop && widget.items.length > 1) ...[
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.chevron_left_rounded, size: 28, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeOutCubic,
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.chevron_right_rounded, size: 28, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // 4. Indicator Dots near bottom
                  if (widget.items.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: _buildIndicatorRow(theme),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicatorRow(ThemeData theme) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    final activeIndex = (_currentPage % widget.items.length + widget.items.length) % widget.items.length;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.items.length,
        (index) {
          final isSelected = index == activeIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: isSelected ? 20.0 : 5.0,
            height: 4.5,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        },
      ),
    );
  }
}

class _HeroBannerSlide extends StatelessWidget {
  final ExploreCarouselItem item;
  final ThemeData theme;
  final AppTranslations l10n;
  final bool isDesktop;

  const _HeroBannerSlide({
    super.key,
    required this.item,
    required this.theme,
    required this.l10n,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = theme.scaffoldBackgroundColor;
    final topPadding = MediaQuery.of(context).padding.top;

    final String rawImageUrl;
    if (isDesktop) {
      rawImageUrl = item.horizontalBackground ??
          item.bannerImage ??
          item.verticalBackground ??
          item.coverImage ??
          '';
    } else {
      rawImageUrl = item.verticalBackground ??
          item.horizontalBackground ??
          item.bannerImage ??
          item.coverImage ??
          '';
    }
    final imageUrl = optimizeTmdbImageUrl(rawImageUrl, isDesktop: isDesktop, isLogo: false);

    final scoreVal = item.score != null
        ? (item.score! > 10 ? (item.score! / 10).toStringAsFixed(1) : item.score!.toStringAsFixed(1))
        : null;

    final hasLogo = item.logoImage != null && item.logoImage!.isNotEmpty;
    // Generous bottom shadow height (smooth cubic feather into page background)
    final bottomShadowHeight = isDesktop ? 320.0 : 230.0;

    return ClipRect(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Static Banner Background Image (Zero continuous repaint, 0% idle GPU)
              // Aligned towards the upper portion (-0.42 desktop / -0.15 mobile) to fully reveal character heads & composition
              if (imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  alignment: Alignment(0.0, isDesktop ? -0.42 : -0.15),
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  memCacheWidth: isDesktop ? 1920 : 1080,
                  maxWidthDiskCache: isDesktop ? 1920 : 1080,
                  placeholder: (context, url) => Container(
                    color: Colors.black26,
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        color: Colors.white24,
                        size: 32,
                      ),
                    ),
                  ),
                ),

              // 2. Subtle Top Status Bar Scrim (low-profile protection for status bar icons only)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + 42,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2b. Desktop Horizontal Vignette Scrim (Left-to-Right contrast protection for logo & text, preserving art vibrance)
              if (isDesktop)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          stops: const [0.0, 0.30, 0.65, 1.0],
                          colors: [
                            Colors.black.withValues(alpha: 0.65),
                            Colors.black.withValues(alpha: 0.30),
                            Colors.black.withValues(alpha: 0.05),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // 3. Compact Eased Bottom Shadow (Ultra-smooth cubic feather, zero harsh cuts or solid block look)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: bottomShadowHeight,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.22, 0.45, 0.68, 0.85, 0.94, 1.0],
                        colors: [
                          bgColor.withValues(alpha: 0.0),
                          bgColor.withValues(alpha: 0.04),
                          bgColor.withValues(alpha: 0.16),
                          bgColor.withValues(alpha: 0.46),
                          bgColor.withValues(alpha: 0.82),
                          bgColor,
                          bgColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Clean Bottom Metadata & Action Pills
            Positioned(
              left: isDesktop ? 36 : 16,
              right: isDesktop ? 36 : 16,
              bottom: isDesktop ? 34 : 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: isDesktop ? 12 : 8),
                    child: SizedBox(
                      height: isDesktop ? 120 : 65,
                      child: Align(
                        alignment: Alignment.bottomLeft,
                        child: hasLogo
                            ? CachedNetworkImage(
                                imageUrl: optimizeTmdbImageUrl(item.logoImage!, isDesktop: isDesktop, isLogo: true),
                                fit: BoxFit.contain,
                                alignment: Alignment.bottomLeft,
                                fadeInDuration: Duration.zero,
                                memCacheHeight: isDesktop ? 240 : 140,
                                maxHeightDiskCache: isDesktop ? 240 : 140,
                                placeholder: (context, url) => const SizedBox.shrink(),
                                errorWidget: (context, url, error) => _buildTitleText(item.title, isDesktop),
                              )
                            : _buildTitleText(item.title, isDesktop),
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (item.year != null) ...[
                          Text(
                            '${item.year}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                            ),
                          ),
                          _buildBullet(),
                        ],
                        if (item.format != null && item.format!.isNotEmpty) ...[
                          Text(
                            item.format!.replaceAll('_', ' '),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                            ),
                          ),
                          if (scoreVal != null || item.genres.isNotEmpty)
                            _buildBullet(),
                        ],
                        if (scoreVal != null) ...[
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 14,
                                color: Colors.amber,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                scoreVal,
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)],
                                ),
                              ),
                            ],
                          ),
                          if (item.genres.isNotEmpty)
                            _buildBullet(),
                        ],
                        if (item.genres.isNotEmpty) ...[
                          Text(
                            item.genres.take(2).join(' • '),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: isDesktop ? 12 : 8),

                  // Action Pill Button (Ver detalles)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.icon(
                        onPressed: item.onTap,
                        icon: const Icon(Icons.info_outline_rounded, size: 16),
                        label: Text(
                          l10n.details,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isDesktop ? 13 : 12,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.symmetric(
                            horizontal: isDesktop ? 18 : 14,
                            vertical: isDesktop ? 10 : 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildBullet() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        '•',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTitleText(String title, bool isDesktop) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: isDesktop ? 24 : 19,
        letterSpacing: -0.3,
        height: 1.15,
        shadows: const [
          Shadow(
            offset: Offset(0, 1),
            blurRadius: 4,
            color: Colors.black87,
          ),
        ],
      ),
    );
  }
}
