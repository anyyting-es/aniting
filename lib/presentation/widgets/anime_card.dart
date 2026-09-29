import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/preferences/show_scores_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

class AnimeCard extends ConsumerStatefulWidget {
  final AnimeEntry entry;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const AnimeCard({
    super.key,
    required this.entry,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  ConsumerState<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends ConsumerState<AnimeCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  int? get _year {
    if (widget.entry.year != null) return widget.entry.year;
    final airDate = widget.entry.airDate;
    if (airDate != null && airDate.isNotEmpty) {
      final parsed = DateTime.tryParse(airDate);
      if (parsed != null) return parsed.year;
      return int.tryParse(airDate.split('-').first);
    }
    return null;
  }

  void _triggerTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      AnimeDetailScreen.navigate(
        context,
        mediaId: widget.entry.mediaId,
        initialEntry: widget.entry,
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _triggerTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final titleLang = ref.watch(titleLanguageProvider);
    final showScores = ref.watch(showScoresProvider);
    final displayTitle = widget.entry.displayTitle(titleLang);
    final year = _year;

    Widget buildCard(BuildContext context, BoxConstraints constraints) {
      final cardWidth = widget.width ?? constraints.maxWidth;
      final isCompact = cardWidth < 155;

      return RepaintBoundary(
        child: Focus(
          onFocusChange: (focused) => setState(() => _isFocused = focused),
          onKeyEvent: _handleKeyEvent,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _triggerTap,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Poster Art Container
                  AspectRatio(
                    aspectRatio: 0.72,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(isCompact ? (colors.borderRadius * 0.8).clamp(0.0, 16.0) : colors.borderRadius),
                        color: colors.surface,
                        border: Border.all(
                          color: _isActive ? Colors.white : colors.border.withValues(alpha: 0.5),
                          width: _isActive ? 2.0 : 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          widget.entry.coverImage != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.entry.coverImage!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: isCompact ? 350 : 440,
                                  memCacheHeight: isCompact ? 500 : 640,
                                  maxWidthDiskCache: 600,
                                  maxHeightDiskCache: 850,
                                  placeholder: (context, url) => ColoredBox(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(
                                      Icons.movie_rounded,
                                      color: theme.colorScheme.outline,
                                      size: isCompact ? 28 : 36,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.movie_rounded,
                                    color: theme.colorScheme.outline,
                                    size: isCompact ? 28 : 36,
                                  ),
                                ),

                        // Subtle Top-right Score pill
                        if (showScores && widget.entry.score != null && widget.entry.score! > 0)
                          Positioned(
                            top: isCompact ? 5 : 6,
                            right: isCompact ? 5 : 6,
                            child: Container(
                              padding: isCompact
                                  ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                  : const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(isCompact ? 4 : 5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, color: Colors.amber, size: isCompact ? 10 : 11),
                                  const SizedBox(width: 2),
                                  Text(
                                    widget.entry.score! > 10
                                        ? (widget.entry.score! / 10).toStringAsFixed(1)
                                        : widget.entry.score!.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: isCompact ? 8.5 : 9.5,
                                      fontWeight: FontWeight.bold,
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

                SizedBox(height: isCompact ? 5 : 7),

                // 2. Info OUTSIDE the card
                Container(
                  height: isCompact ? 30.0 : 34.0,
                  alignment: Alignment.topLeft,
                  child: Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _isHovered
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.dark
                              ? theme.colorScheme.onSurface
                              : const Color(0xFF111418)),
                      fontSize: isCompact ? 11.5 : 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      fontFamilyFallback: kJapaneseFontFallbacks,
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 2.0 : 3.0),
                Text(
                  [
                    if (year != null) '$year',
                    if (widget.entry.format != null && widget.entry.format!.isNotEmpty)
                      widget.entry.format!
                    else if (year == null)
                      'Anime',
                  ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: isCompact ? 10.0 : 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    }

    if (widget.width != null) {
      return SizedBox(
        width: widget.width,
        child: LayoutBuilder(
          builder: (context, constraints) => buildCard(context, constraints),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) => buildCard(context, constraints),
    );
  }
}
