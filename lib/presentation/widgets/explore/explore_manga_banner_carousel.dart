import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'explore_carousel_models.dart';

/// Banner-proportioned horizontal carousel specifically tailored for Manga.
class ExploreMangaBannerCarousel extends ConsumerStatefulWidget {
  final List<ExploreCarouselItem> items;
  final double? height;

  const ExploreMangaBannerCarousel({
    super.key,
    required this.items,
    this.height,
  });

  @override
  ConsumerState<ExploreMangaBannerCarousel> createState() =>
      _ExploreMangaBannerCarouselState();
}

class _ExploreMangaBannerCarouselState
    extends ConsumerState<ExploreMangaBannerCarousel> {
  late final PageController _pageController;
  int _currentIndex = 0;
  Timer? _autoScrollTimer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    if (widget.items.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _isHovered || widget.items.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % widget.items.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _onHover(bool hovering) {
    if (_isHovered != hovering) {
      setState(() => _isHovered = hovering);
      if (!hovering) {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 720;
    final isLarge = screenWidth >= 1200;

    final bannerHeight = widget.height ?? (isLarge ? 210.0 : (isDesktop ? 190.0 : 155.0));
    final horizontalPadding = isDesktop ? 24.0 : 16.0;

    final colors = context.themeColors;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: SizedBox(
          height: bannerHeight,
          width: double.infinity,
          child: Stack(
            children: [
              // 1. Banner PageView
              PageView.builder(
                controller: _pageController,
                itemCount: widget.items.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                },
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return _buildBannerCard(
                    context: context,
                    item: item,
                    isDesktop: isDesktop,
                    colors: colors,
                    iconPack: iconPack,
                    l10n: l10n,
                  );
                },
              ),

              // 2. Pagination Indicator Dots
              if (widget.items.length > 1)
                Positioned(
                  right: 18,
                  bottom: 12,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(widget.items.length, (index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          _pageController.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          width: isSelected ? 18 : 6,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.accent
                                : Colors.white.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBannerCard({
    required BuildContext context,
    required ExploreCarouselItem item,
    required bool isDesktop,
    required AppThemeColors colors,
    required dynamic iconPack,
    required dynamic l10n,
  }) {
    final bgUrl = item.backdropUrl ?? item.posterUrl ?? '';
    final coverUrl = item.posterUrl ?? '';

    return GestureDetector(
      onTap: () => _navigateToManga(context, item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.border.withValues(alpha: 0.4),
              width: 0.8,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── Blurred Banner Background ───
              if (bgUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: bgUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  memCacheWidth: isDesktop ? 1200 : 600,
                  placeholder: (_, _) => const SizedBox.shrink(),
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
                ),

              // Dark Contrast Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.92),
                        Colors.black.withValues(alpha: 0.78),
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── Content Row (Cover Art + Info) ───
              Padding(
                padding: EdgeInsets.all(isDesktop ? 14 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 3:4 Manga Poster Thumbnail
                    if (coverUrl.isNotEmpty)
                      AspectRatio(
                        aspectRatio: 2.7 / 4.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: coverUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            placeholder: (_, _) => const ColoredBox(
                              color: Colors.black26,
                            ),
                            errorWidget: (_, _, _) => const ColoredBox(
                              color: Colors.black26,
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(width: 14),

                    // Metadata & Actions
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Badges Row (MANGA, Score, Year)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildPill(
                                text: item.format ?? 'MANGA',
                                bgColor: colors.accent.withValues(alpha: 0.25),
                                textColor: colors.accent,
                                isBold: true,
                              ),
                              if (item.score != null && item.score! > 0)
                                _buildPill(
                                  text: '★ ${item.score!.toStringAsFixed(1)}',
                                  bgColor: const Color(0xFFE5A00D)
                                      .withValues(alpha: 0.25),
                                  textColor: const Color(0xFFFFC107),
                                  isBold: true,
                                ),
                              if (item.year != null)
                                _buildPill(
                                  text: '${item.year}',
                                  bgColor: Colors.white.withValues(alpha: 0.12),
                                  textColor: Colors.white.withValues(alpha: 0.85),
                                ),
                              for (final genre in item.genres.take(2))
                                _buildPill(
                                  text: genre,
                                  bgColor: Colors.white.withValues(alpha: 0.08),
                                  textColor: Colors.white.withValues(alpha: 0.75),
                                ),
                            ],
                          ),

                          const SizedBox(height: 6),

                          // Manga Title
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: isDesktop ? 17 : 14.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),

                          // Short Synopsis
                          if (item.description != null &&
                              item.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _cleanDescription(item.description!),
                              maxLines: isDesktop ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isDesktop ? 12 : 11,
                                height: 1.3,
                                color: Colors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],

                          const SizedBox(height: 8),

                          // Action Button
                          M3EButton.icon(
                            style: M3EButtonStyle.filled,
                            size: M3EButtonSize.xs,
                            icon: Icon(AppIcons.manga(iconPack), size: 14),
                            label: Text(
                              l10n.details,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                            onPressed: () => _navigateToManga(context, item),
                          ),
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

  Widget _buildPill({
    required String text,
    required Color bgColor,
    required Color textColor,
    bool isBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
          color: textColor,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _cleanDescription(String desc) {
    return desc
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void _navigateToManga(BuildContext context, ExploreCarouselItem item) {
    if (item.mangaEntry != null) {
      MangaDetailScreen.navigate(
        context,
        mediaId: item.mediaId,
        initialEntry: item.mangaEntry,
      );
    }
  }
}
