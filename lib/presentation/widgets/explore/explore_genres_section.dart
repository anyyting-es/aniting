import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/theme/custom_route_transitions.dart';
import 'package:aniting/presentation/screens/genre_detail_screen.dart';
import 'package:aniting/presentation/screens/genres_screen.dart';

/// "Géneros" row for the Explore hub.
///
/// Every genre is a wide tile with its artwork as background and the **genre
/// name on top of the card**, so the row reads as a browse-by-genre entry point
/// without opening the genres screen first. The "ver más" action still leads to
/// the full [GenresScreen] grid.
class ExploreGenresSection extends ConsumerWidget {
  final bool isDesktop;
  final bool isTv;

  const ExploreGenresSection({
    super.key,
    required this.isDesktop,
    required this.isTv,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final compact = isTv;

    final tileWidth = compact ? 300.0 : (isDesktop ? 340.0 : 250.0);
    final tileHeight = tileWidth * 0.56;
    final spacing = isDesktop ? 16.0 : 12.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.genresTitle,
                style:
                    (compact
                            ? theme.textTheme.titleSmall
                            : theme.textTheme.titleMedium)
                        ?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    SlideRightToLeftPageRoute(child: const GenresScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  child: Text(
                    l10n.seeMore,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: tileHeight + 8,
          child: ListView.separated(
            clipBehavior: Clip.hardEdge,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            scrollDirection: Axis.horizontal,
            cacheExtent: 320,
            itemCount: kAppGenres.length,
            separatorBuilder: (context, index) => SizedBox(width: spacing),
            itemBuilder: (context, index) {
              final genre = kAppGenres[index];
              return _GenreTile(
                genre: genre,
                label: isSpanish ? genre.nameEs : genre.nameEn,
                width: tileWidth,
                height: tileHeight,
              );
            },
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _GenreTile extends StatefulWidget {
  final GenreItem genre;
  final String label;
  final double width;
  final double height;

  const _GenreTile({
    required this.genre,
    required this.label,
    required this.width,
    required this.height,
  });

  @override
  State<_GenreTile> createState() => _GenreTileState();
}

class _GenreTileState extends State<_GenreTile> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  void _open() {
    Navigator.push(
      context,
      SlideRightToLeftPageRoute(
        child: GenreDetailScreen(
          genre: widget.genre.key,
          displayGenreName: widget.label,
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _open();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return RepaintBoundary(
      child: Focus(
        onFocusChange: (focused) => setState(() => _isFocused = focused),
        onKeyEvent: _handleKey,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: Stack(
                children: [
                  // Same hover cue as the rest of the app (AnimeCard): an
                  // accent halo that fades in behind the artwork instead of a
                  // scale/zoom, which would resample the bitmap every frame.
                  Positioned.fill(
                    child: AnimatedOpacity(
                      opacity: _isActive ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(
                            alpha: isDark ? 0.16 : 0.10,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: colors.surfaceContainerHigh,
                          border: Border.all(
                            color: colors.outlineVariant.withValues(
                              alpha: 0.25,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: _isActive ? 0.34 : 0.2,
                              ),
                              blurRadius: _isActive ? 12 : 6,
                              offset: Offset(0, _isActive ? 5 : 3),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            CachedNetworkImage(
                              imageUrl: widget.genre.imageUrl,
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.medium,
                              memCacheWidth: (widget.width * 2).round(),
                              fadeInDuration: const Duration(
                                milliseconds: 200,
                              ),
                              placeholder: (context, _) =>
                                  const SizedBox.expand(),
                              errorWidget: (context, _, _) => ColoredBox(
                                color: colors.surfaceContainerHighest,
                              ),
                            ),

                            // Keeps the title readable on any artwork without
                            // dulling the whole image: strong at the top, gone
                            // by mid-card.
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  stops: [0.0, 0.55, 1.0],
                                  colors: [
                                    Color(0xCC000000),
                                    Color(0x22000000),
                                    Color(0x66000000),
                                  ],
                                ),
                              ),
                            ),

                            // Genre name on top of the card.
                            Align(
                              alignment: Alignment.topLeft,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  12,
                                  14,
                                  0,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.genre.icon,
                                      size: 17,
                                      color: Colors.white.withValues(
                                        alpha: 0.95,
                                      ),
                                      shadows: const [
                                        Shadow(
                                          blurRadius: 6,
                                          color: Colors.black87,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        widget.label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontSize: widget.width >= 300
                                                  ? 17
                                                  : 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              letterSpacing: 0.1,
                                              shadows: const [
                                                Shadow(
                                                  blurRadius: 8,
                                                  color: Colors.black87,
                                                ),
                                              ],
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
