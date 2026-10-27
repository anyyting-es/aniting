import 'dart:async';
import 'dart:io' show Platform;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/desktop_nav_style_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/explore_carousel_config.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/services/custom_anime_assets_service.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart' show optimizeTmdbImageUrl;
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

bool get _isInTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

final animeDetailsFamilyProvider = FutureProvider.family<AnimeDetails?, int>((ref, mediaId) async {
  if (mediaId <= 0) return null;
  return ref.watch(repositoryProvider).getAnimeDetails(mediaId).catchError((_) => null);
});

final carouselAniZipProvider = FutureProvider.family<AniZipData?, int>((ref, mediaId) async {
  if (mediaId <= 0) return null;
  final repo = ref.watch(repositoryProvider);
  final cached = repo.getCachedAniZipData(mediaId);
  if (cached != null) return cached;
  return repo.getAniZipData(mediaId).catchError((_) => null);
});

class ExploreCarouselItem {
  final int mediaId;
  final String title;
  final String? bannerImage;
  final String? coverImage;
  final String? horizontalBackground;
  final String? verticalBackground;
  final String? logoImage;
  final String? description;
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
    this.description,
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
      description: item.description,
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
      description: anime.description,
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
      description: manga.description,
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
  final ScrollController? scrollController;

  const ExploreHeroCarousel({
    super.key,
    required this.items,
    this.height,
    this.scrollController,
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
    final isTv = ref.watch(tvModeProvider);
    final desktopNavStyle = ref.watch(desktopNavStyleProvider);
    final isSidebarMode = isDesktop && desktopNavStyle == DesktopNavStyle.sidebar;
    final isCompactLayout = isTv;
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;
    // Responsive cinematic height:
    // On TV: ~48% clamped [340, 460]
    // On Desktop: ~68% clamped [480, 720]
    // On Mobile: ~56% clamped [420, 560]
    final defaultHeight = (isCompactLayout
            ? (screenHeight * 0.48).clamp(340.0, 460.0) + topPadding
            : (isDesktop
                ? (screenHeight * 0.68).clamp(480.0, 720.0) + topPadding
                : (screenHeight * 0.56).clamp(420.0, 560.0) + topPadding))
        .toDouble();
    final carouselHeight = widget.height ?? defaultHeight;
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    final bgColor = theme.scaffoldBackgroundColor;

    return SizedBox(
      height: carouselHeight,
      width: double.infinity,
      child: ColoredBox(
        color: bgColor,
        child: ClipRect(
          child: MouseRegion(
            onEnter: (_) => _pauseAutoPlay(),
            onExit: (_) => _resumeAutoPlay(),
            child: Listener(
              onPointerDown: (_) => _pauseAutoPlay(),
              onPointerUp: (_) => _resumeAutoPlay(),
              onPointerCancel: (_) => _resumeAutoPlay(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Edge-to-edge Horizontal Sliding Carousel
                  Positioned.fill(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.items.length > 1 ? null : widget.items.length,
                      onPageChanged: (index) {
                        setState(() => _currentPage = index);
                      },
                      itemBuilder: (context, index) {
                        final itemIndex = (index % widget.items.length + widget.items.length) % widget.items.length;
                        final item = widget.items[itemIndex];
                        return RepaintBoundary(
                          child: _HeroBannerSlide(
                            key: ValueKey('hero_slide_v4_${item.mediaId}_$index'),
                            item: item,
                            theme: theme,
                            l10n: l10n,
                            isDesktop: isDesktop,
                            isTv: isCompactLayout,
                            isSidebarMode: isSidebarMode,
                            scrollController: widget.scrollController,
                          ),
                        );
                      },
                    ),
                  ),

                  // 2. Subpixel Seam Guard at absolute bottom edge
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: 2.0,
                    child: IgnorePointer(
                      child: ColoredBox(color: bgColor),
                    ),
                  ),

                  // 3. Indicator Dots near bottom: on desktop aligned neatly to bottom-right; centered on mobile/TV
                  if (widget.items.length > 1)
                    Positioned(
                      bottom: 16,
                      left: isDesktop ? null : 0,
                      right: isDesktop ? 36.0 : 0,
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

class _HeroBannerSlide extends ConsumerWidget {
  final ExploreCarouselItem item;
  final ThemeData theme;
  final AppTranslations l10n;
  final bool isDesktop;
  final bool isTv;
  final bool isSidebarMode;
  final ScrollController? scrollController;

  const _HeroBannerSlide({
    super.key,
    required this.item,
    required this.theme,
    required this.l10n,
    required this.isDesktop,
    this.isTv = false,
    this.isSidebarMode = false,
    this.scrollController,
  });

  String _cleanHtml(String? html) {
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), ' ')
        .replaceAll(RegExp(r'</?i>'), '')
        .replaceAll(RegExp(r'</?b>'), '')
        .replaceAll(RegExp(r'</?p>'), ' ')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&#039;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final topPadding = MediaQuery.of(context).padding.top;
    final iconPack = ref.watch(iconPackProvider);

    // Dynamic AniList + AniZip + CustomAnimeAssets Resolution
    final customAssets = CustomAnimeAssetsService.getAssets(item.mediaId);
    final aniZip = ref.watch(carouselAniZipProvider(item.mediaId)).asData?.value;

    final String rawImageUrl;
    if (isDesktop) {
      rawImageUrl = customAssets?.background ??
          aniZip?.fanartUrl ??
          item.horizontalBackground ??
          aniZip?.bannerUrl ??
          item.bannerImage ??
          item.verticalBackground ??
          item.coverImage ??
          '';
    } else {
      rawImageUrl = customAssets?.poster ??
          aniZip?.fanartUrl ??
          item.verticalBackground ??
          customAssets?.background ??
          item.horizontalBackground ??
          aniZip?.bannerUrl ??
          item.bannerImage ??
          item.coverImage ??
          '';
    }
    final imageUrl = optimizeTmdbImageUrl(rawImageUrl, isDesktop: isDesktop, isLogo: false);

    final resolvedLogoUrl = customAssets?.logo ?? aniZip?.clearlogoUrl ?? item.logoImage;
    final hasLogo = resolvedLogoUrl != null && resolvedLogoUrl.trim().isNotEmpty;

    final scoreVal = item.score != null
        ? (item.score! > 10 ? (item.score! / 10).toStringAsFixed(1) : item.score!.toStringAsFixed(1))
        : null;

    String? rawDesc = item.description;
    if ((rawDesc == null || rawDesc.isEmpty) && isSidebarMode && !_isInTest) {
      final detailsAsync = ref.watch(animeDetailsFamilyProvider(item.mediaId));
      rawDesc = detailsAsync.asData?.value?.description;
    }
    final description = _cleanHtml(rawDesc);
    final metadataRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (item.year != null) ...[
            Text('${item.year}', style: _metadataStyle(isTv)),
            _buildBullet(),
          ],
          if (item.format != null && item.format!.isNotEmpty) ...[
            Text(item.format!.replaceAll('_', ' '), style: _metadataStyle(isTv)),
            if (scoreVal != null || item.genres.isNotEmpty) _buildBullet(),
          ],
          if (scoreVal != null) ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded, size: isTv ? 12 : 14, color: Colors.amber),
                const SizedBox(width: 2),
                Text(
                  scoreVal,
                  style: _metadataStyle(isTv).copyWith(color: Colors.amber, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (item.genres.isNotEmpty) _buildBullet(),
          ],
          if (item.genres.isNotEmpty)
            Text(
              item.genres.take(2).join(' • '),
              style: _metadataStyle(isTv).copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
        ],
      ),
    );

    return ClipRect(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: item.onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Dynamic Banner Background Image with subtle zoom on scroll
              if (imageUrl.isNotEmpty)
                AnimatedBuilder(
                  animation: scrollController ?? const AlwaysStoppedAnimation(0),
                  builder: (context, child) {
                    final scrollOffset = (scrollController != null && scrollController!.hasClients)
                        ? scrollController!.offset
                        : 0.0;
                    // When scrolling down, subtly zoom the banner background (from 1.0 up to 1.15)
                    // When pulling down (overscroll < 0), expand smoothly.
                    final double bgScale;
                    if (scrollOffset < 0) {
                      bgScale = 1.0 + (-scrollOffset / 320.0).clamp(0.0, 0.40);
                    } else {
                      bgScale = 1.0 + (scrollOffset / 1200.0).clamp(0.0, 0.15);
                    }

                    return Transform.scale(
                      scale: bgScale,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: CachedNetworkImage(
                    imageUrl: imageUrl,
                    alignment: Alignment(0.0, isDesktop ? -0.42 : -0.25),
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

              // 2b. Left-to-right contrast protection (guarantees text/logo clarity and seamless sidebar blend)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0.0, 0.32, 0.65, 1.0],
                        colors: [
                          theme.scaffoldBackgroundColor.withValues(alpha: isDesktop ? 0.88 : 0.60),
                          theme.scaffoldBackgroundColor.withValues(alpha: isDesktop ? 0.55 : 0.25),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.12),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2c. Full-height Eased Bottom Blend (Non-linear feather fading 100% into scaffoldBackgroundColor at bottom edge)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.25, 0.50, 0.72, 0.88, 1.0],
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.25),
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.75),
                          theme.scaffoldBackgroundColor,
                          theme.scaffoldBackgroundColor,
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Positioned(
              left: isDesktop ? (isSidebarMode ? (isTv ? 76.0 : 96.0) : 36.0) : 16.0,
              right: isDesktop ? 36.0 : 16.0,
              bottom: isTv ? 44.0 : (isDesktop ? 36.0 : 26.0),
              child: AnimatedBuilder(
                animation: scrollController ?? const AlwaysStoppedAnimation(0),
                builder: (context, child) {
                  final scrollOffset = (scrollController != null && scrollController!.hasClients)
                      ? scrollController!.offset
                      : 0.0;
                  final fgOpacity = (1.0 - (scrollOffset / 300.0)).clamp(0.0, 1.0);
                  final fgTranslateY = scrollOffset > 0 ? -scrollOffset * 0.15 : 0.0;
                  return Opacity(
                    opacity: fgOpacity,
                    child: Transform.translate(
                      offset: Offset(0, fgTranslateY),
                      child: child,
                    ),
                  );
                },
                child: Column(
                crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsets.only(bottom: isTv ? 45 : (isDesktop ? 12 : 6)),
                    child: SizedBox(
                      height: isTv ? 92 : (isDesktop ? (isSidebarMode ? 105 : 120) : 52),
                      child: Align(
                        alignment: isDesktop ? Alignment.bottomLeft : Alignment.bottomCenter,
                        child: hasLogo
                            ? _buildLogoImage(resolvedLogoUrl, isDesktop)
                            : _buildTitleText(item.title, isDesktop),
                      ),
                    ),
                  ),

                  if (isTv) metadataRow,

                  // Description under logo/title in desktop sidebar mode
                  if ((isSidebarMode || isTv) && description.isNotEmpty) ...[
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: (MediaQuery.of(context).size.width * 0.44).clamp(360.0, 520.0),
                      ),
                      child: Text(
                        description,
                        maxLines: isTv ? 4 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontSize: isTv ? 16.0 : 13.5,
                          height: isTv ? 1.25 : 1.45,
                          letterSpacing: -0.1,
                          fontWeight: FontWeight.w400,
                          shadows: const [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 5,
                              color: Colors.black87,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: isTv ? 4 : 14),
                  ],
                  if (!isTv) metadataRow,

                  if (!isTv) SizedBox(height: isDesktop ? 12 : 8),

                  // Refined, balanced Action Button (Ver detalles)
                  if (!isTv) Builder(
                    builder: (context) {
                      final isDark = theme.brightness == Brightness.dark;
                      final btnBgColor = isDark ? Colors.white : theme.colorScheme.onSurface;
                      final btnFgColor = isDark ? const Color(0xFF141414) : theme.colorScheme.surface;

                      return Material(
                        color: btnBgColor,
                        borderRadius: BorderRadius.circular(18),
                        elevation: 1,
                        shadowColor: Colors.black45,
                        child: InkWell(
                          onTap: item.onTap,
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: isDesktop ? 16 : 14,
                              vertical: isDesktop ? 8 : 7,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(AppIcons.info(iconPack), size: isDesktop ? 15 : 14, color: btnFgColor),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.details,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isDesktop ? 12.5 : 12.0,
                                    color: btnFgColor,
                                    letterSpacing: 0.1,
                                    height: 1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    ),
  );
}

  Widget _buildLogoImage(String logoUrl, bool isDesktop) {
    final isSvg = logoUrl.toLowerCase().endsWith('.svg');
    final alignment = isDesktop ? Alignment.bottomLeft : Alignment.bottomCenter;
    final maxDiskHeight = isDesktop ? 260 : 130;

    if (isSvg) {
      return SvgPicture.network(
        logoUrl,
        fit: BoxFit.contain,
        alignment: alignment,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );
    }

    final optimizedUrl = optimizeTmdbImageUrl(logoUrl, isDesktop: isDesktop, isLogo: true);
    return CachedNetworkImage(
      imageUrl: optimizedUrl,
      fit: BoxFit.contain,
      alignment: alignment,
      fadeInDuration: Duration.zero,
      memCacheHeight: maxDiskHeight,
      maxHeightDiskCache: maxDiskHeight,
      placeholder: (context, url) => const SizedBox.shrink(),
      errorWidget: (context, url, error) => _buildTitleText(item.title, isDesktop),
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

  TextStyle _metadataStyle(bool isTv) => TextStyle(
        color: Colors.white,
        fontSize: isTv ? 14.5 : 12,
        fontWeight: FontWeight.w600,
        shadows: const [Shadow(color: Colors.black54, blurRadius: 2)],
      );

  Widget _buildTitleText(String title, bool isDesktop) {
    return Text(
      title,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: isDesktop ? TextAlign.start : TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: isTv ? 38 : (isDesktop ? 24 : 19),
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
