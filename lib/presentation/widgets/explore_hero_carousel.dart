import 'dart:async';
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

class ExploreCarouselItem {
  final int mediaId;
  final String title;
  final String? bannerImage;
  final String? coverImage;
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
    this.format,
    this.score,
    this.year,
    this.genres = const [],
    required this.onTap,
  });

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
      if (!mounted || _isInteracting || !_pageController.hasClients) return;
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
    final topPadding = MediaQuery.of(context).padding.top;
    // Slimmer, cinematic height (260dp on mobile, 340dp on desktop + topPadding)
    final carouselHeight = widget.height ?? ((isDesktop ? 340.0 : 260.0) + topPadding);
    final theme = Theme.of(context);

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
                              final double absOffset = pageOffset.abs().clamp(0.0, 1.0);
                              final double opacity = (1.0 - absOffset).clamp(0.0, 1.0);
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
                                isDesktop: isDesktop,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // 2. Indicator Dots near bottom
                  if (widget.items.length > 1)
                    Positioned(
                      bottom: 8,
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
            width: isSelected ? 18.0 : 5.0,
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

class _HeroBannerSlide extends StatefulWidget {
  final ExploreCarouselItem item;
  final ThemeData theme;
  final bool isDesktop;

  const _HeroBannerSlide({
    super.key,
    required this.item,
    required this.theme,
    required this.isDesktop,
  });

  @override
  State<_HeroBannerSlide> createState() => _HeroBannerSlideState();
}

class _HeroBannerSlideState extends State<_HeroBannerSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _panController;
  late final Animation<double> _panAnimation;

  @override
  void initState() {
    super.initState();
    // Ultra-slow, peaceful ambient pan animation (28 seconds duration)
    _panController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 28),
    );

    // Subtle ambient pan range (-0.20 to 0.20 on mobile, -0.08 to 0.08 on desktop)
    final panRange = widget.isDesktop ? 0.08 : 0.20;
    _panAnimation = Tween<double>(
      begin: -panRange,
      end: panRange,
    ).animate(CurvedAnimation(
      parent: _panController,
      curve: Curves.easeInOutSine,
    ));

    if (!_isInTest) {
      _panController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _panController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isDesktop = widget.isDesktop;
    final bgColor = widget.theme.scaffoldBackgroundColor;
    final topPadding = MediaQuery.of(context).padding.top;

    final imageUrl = (item.bannerImage != null && item.bannerImage!.isNotEmpty)
        ? item.bannerImage!
        : (item.coverImage ?? '');

    final scoreVal = item.score != null
        ? (item.score! > 10 ? (item.score! / 10).toStringAsFixed(1) : item.score!.toStringAsFixed(1))
        : null;

    // Compact, non-intrusive bottom shadow height (only covers metadata area, not the whole banner)
    final bottomShadowHeight = isDesktop ? 140.0 : 115.0;

    return ClipRect(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Banner Background Image with Slow Ambient Pan (Ken Burns)
              if (imageUrl.isNotEmpty)
                AnimatedBuilder(
                  animation: _panAnimation,
                  builder: (context, child) {
                    return CachedNetworkImage(
                      imageUrl: imageUrl,
                      alignment: Alignment(_panAnimation.value, 0.0),
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 250),
                      memCacheWidth: 1080,
                      maxWidthDiskCache: 1400,
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
                    );
                  },
                ),

              // 2. Subtle Top Status Bar Scrim (low-profile protection for status bar icons only)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + 36,
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
                        stops: const [0.0, 0.22, 0.45, 0.68, 0.86, 1.0],
                        colors: [
                          bgColor.withValues(alpha: 0.0),
                          bgColor.withValues(alpha: 0.06),
                          bgColor.withValues(alpha: 0.22),
                          bgColor.withValues(alpha: 0.52),
                          bgColor.withValues(alpha: 0.85),
                          bgColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // 4. Clean Bottom Metadata (ON TOP OF GRADIENTS! FULLY VISIBLE!)
            Positioned(
              left: 16,
              right: 16,
              bottom: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
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
                  ),
                  const SizedBox(height: 6),
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
}
