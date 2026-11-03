import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

import 'explore_carousel_models.dart';

/// Visually impressive hero carousel for Anime & Shows on the Explore page.
class ExploreHeroCarousel extends ConsumerStatefulWidget {
  final List<ExploreCarouselItem> items;
  final double? height;
  final double contentLeftInset;

  const ExploreHeroCarousel({
    super.key,
    required this.items,
    this.height,
    this.contentLeftInset = 0,
  });

  @override
  ConsumerState<ExploreHeroCarousel> createState() =>
      _ExploreHeroCarouselState();
}

class _ExploreHeroCarouselState extends ConsumerState<ExploreHeroCarousel> {
  int _currentIndex = 0;
  Timer? _autoScrollTimer;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _autoScrollTimer?.cancel();
    if (widget.items.length <= 1) return;
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (!mounted || _isHovered || widget.items.isEmpty) return;
      final nextIndex = (_currentIndex + 1) % widget.items.length;
      _setCurrentIndex(nextIndex);
    });
  }

  void _setCurrentIndex(int index) {
    if (!mounted || widget.items.isEmpty) return;
    setState(() => _currentIndex = index % widget.items.length);
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

    final carouselHeight =
        widget.height ?? (isLarge ? 820.0 : (isDesktop ? 680.0 : 480.0));

    final theme = Theme.of(context);
    final colors = context.themeColors;
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    return MouseRegion(
      onEnter: (_) => _onHover(true),
      onExit: (_) => _onHover(false),
      child: SizedBox(
        height: carouselHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 150 || widget.items.length < 2) return;
                final nextIndex = velocity < 0
                    ? (_currentIndex + 1) % widget.items.length
                    : (_currentIndex - 1 + widget.items.length) %
                          widget.items.length;
                _setCurrentIndex(nextIndex);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 700),
                reverseDuration: const Duration(milliseconds: 500),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [...previousChildren, ?currentChild],
                  );
                },
                transitionBuilder: (child, animation) {
                  final scale = Tween<double>(begin: 1.025, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: scale, child: child),
                  );
                },
                child: _buildHeroSlide(
                  key: ValueKey(_currentIndex),
                  context: context,
                  item: widget.items[_currentIndex],
                  isDesktop: isDesktop,
                  colors: colors,
                  isDark: isDark,
                  iconPack: iconPack,
                  l10n: l10n,
                ),
              ),
            ),

            // Pagination Indicator Pills
            if (widget.items.length > 1)
              Positioned(
                right: isDesktop ? 32 : 16,
                bottom: isDesktop ? 22 : 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.items.length, (index) {
                    final isSelected = index == _currentIndex;
                    return GestureDetector(
                      onTap: () {
                        _setCurrentIndex(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isSelected ? 22 : 7,
                        height: 5,
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
    );
  }

  Widget _buildHeroSlide({
    Key? key,
    required BuildContext context,
    required ExploreCarouselItem item,
    required bool isDesktop,
    required AppThemeColors colors,
    required bool isDark,
    required dynamic iconPack,
    required dynamic l10n,
  }) {
    final bgUrl = item.backdropUrl ?? item.posterUrl ?? '';
    // Consumes colors.background from AppThemeColors (context.themeColors).
    // In OLED mode this is pure black (0xFF000000), and in any theme it always matches
    // the exact background color of the scaffold and canvas!
    final groundColor = colors.background;

    return GestureDetector(
      key: key,
      onTap: () => _navigateToDetails(context, item),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ─── Backdrop Image ───
          if (bgUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: bgUrl,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              memCacheWidth: isDesktop ? 1920 : 960,
              placeholder: (_, _) => const ColoredBox(color: Colors.black12),
              errorWidget: (_, _, _) =>
                  const ColoredBox(color: Color(0xFF14141A)),
            )
          else
            const ColoredBox(color: Color(0xFF14141A)),

          // ─── Sombra "U sin palito derecho" (Palito izquierdo + Piso integrado) ───
          // 1. Palito Izquierdo (Sombra vertical desde el borde izquierdo hacia la derecha)
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: isDesktop ? 700 : 360,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    stops: const [0.0, 0.30, 0.65, 1.0],
                    colors: [
                      groundColor.withValues(alpha: isDark ? 0.96 : 0.90),
                      groundColor.withValues(alpha: isDark ? 0.80 : 0.70),
                      groundColor.withValues(alpha: isDark ? 0.35 : 0.25),
                      Colors.transparent, // Lado derecho 100% nítido y libre
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Piso / Difuminado Abajo: Anclado estrictamente al piso (bottom: 0)
          // para que el fondo del carrusel se fusione de forma 100% limpia con la pantalla inferior,
          // alcanzando 100% de solidez en la base e integrando los dots sobre el suelo oscuro.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: isDesktop ? 340 : 240,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.30, 0.65, 1.0],
                    colors: [
                      Colors.transparent,
                      groundColor.withValues(alpha: 0.30),
                      groundColor.withValues(alpha: 0.75),
                      groundColor.withValues(alpha: 1.0), // 100% sólido pegado al piso
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ─── Foreground Info & Metadata ───
          Positioned(
            left: (isDesktop ? 32 : 18) + widget.contentLeftInset,
            right: isDesktop ? 180 : 36,
            bottom: isDesktop ? 24 : 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo or Big Title
                if (item.logoUrl != null && item.logoUrl!.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: isDesktop ? 140 : 90,
                      maxWidth: isDesktop ? 500 : 300,
                    ),
                    child: _buildLogoWidget(item.logoUrl!, item.title),
                  )
                else
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isDesktop ? 26 : 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.4,
                    ),
                  ),

                const SizedBox(height: 10),

                // Badges Row (Format, Year, Score, Genres)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Format pill
                    if (item.format != null && item.format!.isNotEmpty)
                      _buildPill(
                        text: item.format!,
                        bgColor: Colors.white.withValues(alpha: 0.2),
                        textColor: Colors.white,
                      ),

                    // Year
                    if (item.year != null)
                      _buildPill(
                        text: '${item.year}',
                        bgColor: Colors.white.withValues(alpha: 0.12),
                        textColor: Colors.white.withValues(alpha: 0.9),
                      ),

                    // Score ⭐
                    if (item.score != null && item.score! > 0)
                      _buildPill(
                        text: '★ ${item.score!.toStringAsFixed(1)}',
                        bgColor: const Color(0xFFE5A00D)
                            .withValues(alpha: 0.25),
                        textColor: const Color(0xFFFFC107),
                        isBold: true,
                      ),

                    // Top 2 Genres
                    for (final genre in item.genres.take(2))
                      _buildPill(
                        text: genre,
                        bgColor: Colors.black.withValues(alpha: 0.35),
                        textColor: Colors.white.withValues(alpha: 0.8),
                      ),
                  ],
                ),

                // Description preview
                if (item.description != null &&
                    item.description!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 520 : 320,
                    ),
                    child: Text(
                      _cleanDescription(item.description!),
                      maxLines: isDesktop ? 2 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: isDesktop ? 13 : 11.5,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Action Button: "Ver detalles"
                M3EButton.icon(
                  style: M3EButtonStyle.filled,
                  size: isDesktop ? M3EButtonSize.sm : M3EButtonSize.xs,
                  icon: Icon(AppIcons.info(iconPack), size: 15),
                  label: Text(
                    l10n.details,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onPressed: () => _navigateToDetails(context, item),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoWidget(String logoUrl, String fallbackTitle) {
    final isSvg = logoUrl.toLowerCase().endsWith('.svg');
    if (isSvg) {
      return SvgPicture.network(
        logoUrl,
        fit: BoxFit.contain,
        alignment: Alignment.bottomLeft,
        placeholderBuilder: (_) => const SizedBox.shrink(),
      );
    }
    return CachedNetworkImage(
      imageUrl: logoUrl,
      fit: BoxFit.contain,
      alignment: Alignment.bottomLeft,
      memCacheHeight: 180,
      placeholder: (_, _) => const SizedBox.shrink(),
      errorWidget: (_, _, _) => Text(
        fallbackTitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: Colors.white,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.5,
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

  void _navigateToDetails(BuildContext context, ExploreCarouselItem item) {
    if (item.animeEntry != null) {
      AnimeDetailScreen.navigate(
        context,
        mediaId: item.mediaId,
        initialEntry: item.animeEntry,
      );
    }
  }
}
