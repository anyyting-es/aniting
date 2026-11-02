import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/preferences/show_scores_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/common/media_meta_pill.dart';

class AnimeCard extends ConsumerStatefulWidget {
  final AnimeEntry entry;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final double? width;
  final double? height;
  final Object? heroTag;
  final bool showMetadata;
  final bool animateEntry;

  const AnimeCard({
    super.key,
    required this.entry,
    this.onTap,
    this.onSecondaryTap,
    this.width,
    this.height,
    this.heroTag,
    this.showMetadata = false,
    this.animateEntry = true,
  });

  @override
  ConsumerState<AnimeCard> createState() => _AnimeCardState();
}

class _AnimeCardState extends ConsumerState<AnimeCard> {
  late final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;
  bool _entryAnimationDone = false;

  @override
  void initState() {
    super.initState();
    _entryAnimationDone = !widget.animateEntry;
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      AnimeDetailScreen.navigate(
        context,
        mediaId: widget.entry.mediaId,
        initialEntry: widget.entry,
        heroTag: widget.heroTag,
      );
    }
  }

  String? get _episodeText {
    final episodes = widget.entry.totalEpisodes;
    if (episodes == null || episodes <= 0) return null;
    return '$episodes EP';
  }

  String? _seasonYearText(AppTranslations l10n) {
    final year = widget.entry.year;
    final season = widget.entry.season?.toUpperCase();
    String? seasonLabel;
    switch (season) {
      case 'WINTER':
        seasonLabel = l10n.seasonWinter;
        break;
      case 'SPRING':
        seasonLabel = l10n.seasonSpring;
        break;
      case 'SUMMER':
        seasonLabel = l10n.seasonSummer;
        break;
      case 'FALL':
        seasonLabel = l10n.seasonFall;
        break;
    }
    if (seasonLabel != null && year != null) return '$seasonLabel $year';
    if (year != null && year > 0) return '$year';
    return null;
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
    final l10n = ref.watch(translationsProvider);
    final displayTitle = widget.entry.displayTitle(titleLang);

    Widget buildCard(BuildContext context, BoxConstraints constraints) {
      final cardWidth = widget.width ?? constraints.maxWidth;
      final isCompact = cardWidth < 155;
      final dynamicColor = parseHexColor(widget.entry.coverColor) ?? colors.accent;
      final episodeText = widget.showMetadata ? _episodeText : null;
      final seasonYear = widget.showMetadata ? _seasonYearText(l10n) : null;
      final showRating =
          (showScores || widget.showMetadata) &&
          widget.entry.score != null &&
          widget.entry.score! > 0;

      return RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: widget.animateEntry
              ? const Duration(milliseconds: 220)
              : Duration.zero,
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (!mounted || _entryAnimationDone) return;
            setState(() => _entryAnimationDone = true);
          },
          builder: (context, animValue, child) {
            if (animValue >= 0.999) return child!;
            return Transform.scale(
              scale: 0.94 + (0.06 * animValue),
              alignment: Alignment.center,
              child: Opacity(
                opacity: animValue,
                child: child,
              ),
            );
          },
          child: Focus(
            focusNode: _focusNode,
            onFocusChange: (focused) {
              if (focused) {
                AppFocusCoordinator.onNodeFocused(_focusNode);
              }
              setState(() => _isFocused = focused);
            },
            onKeyEvent: _handleKeyEvent,
            child: MouseRegion(
              onEnter: (_) {
                AppFocusCoordinator.switchToMouse(_focusNode);
              setState(() => _isHovered = true);
            },
            onExit: (_) {
              if (AppFocusCoordinator.lastHoveredNode == _focusNode) {
                AppFocusCoordinator.lastHoveredNode = null;
              }
              setState(() => _isHovered = false);
            },
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _triggerTap,
              onSecondaryTap: widget.onSecondaryTap,
              child: ValueListenableBuilder<AppInputMode>(
                valueListenable: AppFocusCoordinator.inputMode,
                builder: (context, mode, _) {
                  final isDpad = mode == AppInputMode.dpad;
                  final isActive = _entryAnimationDone &&
                      ((mode == AppInputMode.mouse && _isHovered) ||
                          (isDpad && _isFocused));

                  return Stack(
                    children: [
                      // Ambient color background with inside-out expansion animation (No borders)
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: 1.0,
                          duration: const Duration(milliseconds: 220),
                          curve: isActive ? Curves.easeOutCubic : Curves.easeInCubic,
                          alignment: Alignment.center,
                          child: AnimatedOpacity(
                            opacity: isActive ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                color: dynamicColor.withValues(
                                  alpha: theme.brightness == Brightness.dark ? 0.16 : 0.10,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Card Foreground Content
                      Padding(
                        padding: EdgeInsets.all(isCompact ? 2.5 : 4.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. Poster Art Container (whole box expands on hover)
                            AspectRatio(
                              aspectRatio: 0.72,
                              child: AnimatedScale(
                                // Keep bitmap content unscaled on hover: scaling
                                // images on Windows (fractional DPI) resamples
                                // them every frame and produces a random
                                // shimmer. The glow behind provides the
                                // expansion cue instead.
                                scale: 1.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(isCompact ? (colors.borderRadius * 0.8).clamp(0.0, 16.0) : colors.borderRadius),
                                color: colors.surface,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: _isHovered ? 0.32 : 0.15),
                                    blurRadius: _isHovered ? 10 : 4,
                                    offset: Offset(0, _isHovered ? 3 : 2),
                                  ),
                                ],
                              ),
                              clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (widget.heroTag != null)
                              Hero(
                                tag: widget.heroTag!,
                                flightShuttleBuilder: (
                                  flightContext,
                                  animation,
                                  flightDirection,
                                  fromHeroContext,
                                  toHeroContext,
                                ) {
                                  final curved = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeInOutCubicEmphasized,
                                  );
                                  return FadeTransition(
                                    opacity: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
                                    child: toHeroContext.widget,
                                  );
                                },
                                child: widget.entry.coverImage != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.entry.coverImage!,
                                        fit: BoxFit.cover,
                                        filterQuality: FilterQuality.medium,
                                        memCacheWidth: isCompact ? 280 : 420,
                                        memCacheHeight: isCompact ? 400 : 600,
                                        maxWidthDiskCache: 500,
                                        maxHeightDiskCache: 750,
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
                              )
                            else
                              widget.entry.coverImage != null
                                  ? CachedNetworkImage(
                                      imageUrl: widget.entry.coverImage!,
                                      fit: BoxFit.cover,
                                      filterQuality: FilterQuality.medium,
                                      memCacheWidth: isCompact ? 280 : 420,
                                      memCacheHeight: isCompact ? 400 : 600,
                                      maxWidthDiskCache: 500,
                                      maxHeightDiskCache: 750,
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

                        // Rating ribbon (top-right, 1–10 scale)
                        if (showRating)
                          Positioned(
                            top: widget.showMetadata ? 0 : (isCompact ? 5 : 6),
                            right: widget.showMetadata ? 0 : (isCompact ? 5 : 6),
                            child: Container(
                              padding: widget.showMetadata
                                  ? EdgeInsets.fromLTRB(
                                      isCompact ? 7 : 8,
                                      isCompact ? 3 : 4,
                                      isCompact ? 7 : 8,
                                      isCompact ? 3 : 4,
                                    )
                                  : (isCompact
                                      ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                      : const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5)),
                              decoration: BoxDecoration(
                                color: widget.showMetadata
                                    ? theme.colorScheme.primary
                                    : Colors.black.withValues(alpha: 0.78),
                                borderRadius: widget.showMetadata
                                    ? const BorderRadius.only(
                                        bottomLeft: Radius.circular(10),
                                      )
                                    : BorderRadius.circular(isCompact ? 4 : 5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.showMetadata
                                        ? Icons.star_outline_rounded
                                        : Icons.star_rounded,
                                    color: widget.showMetadata
                                        ? theme.colorScheme.onPrimary
                                        : Colors.amber,
                                    size: widget.showMetadata
                                        ? (isCompact ? 12 : 14)
                                        : (isCompact ? 10 : 11),
                                  ),
                                  const SizedBox(width: 2.5),
                                  Text(
                                    widget.entry.score! > 10
                                        ? (widget.entry.score! / 10).toStringAsFixed(1)
                                        : widget.entry.score!.toStringAsFixed(1),
                                    style: TextStyle(
                                      color: widget.showMetadata
                                          ? theme.colorScheme.onPrimary
                                          : Colors.white,
                                      fontSize: widget.showMetadata
                                          ? (isCompact ? 10 : 11.5)
                                          : (isCompact ? 8.5 : 9.5),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                        // Episode count, attached to the bottom-left corner
                        if (episodeText != null)
                          Positioned(
                            left: 0,
                            bottom: 0,
                            child: MediaMetaPill(
                              text: episodeText,
                              fontSize: isCompact ? 9.5 : 10.5,
                              padding: EdgeInsets.symmetric(
                                horizontal: isCompact ? 6 : 7,
                                vertical: isCompact ? 3 : 3.5,
                              ),
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(10),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

                  SizedBox(height: isCompact ? 6 : 8),

                  // 2. Title only: enlarged and clean
                  Text(
                    displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.onSurface
                          : const Color(0xFF111418),
                      fontSize: isCompact ? 13.0 : 14.5,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      fontFamilyFallback: kJapaneseFontFallbacks,
                    ),
                  ),

                  // 3. Season + year
                  if (seasonYear != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      seasonYear,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: isCompact ? 11.0 : 12.0,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    ),
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
