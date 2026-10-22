import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/show_scores_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

class MangaCard extends ConsumerStatefulWidget {
  final MangaEntry entry;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Object? heroTag;

  const MangaCard({
    super.key,
    required this.entry,
    this.onTap,
    this.width,
    this.height,
    this.heroTag,
  });

  @override
  ConsumerState<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends ConsumerState<MangaCard> {
  late final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      MangaDetailScreen.navigate(
        context,
        mediaId: widget.entry.mediaId,
        initialEntry: widget.entry,
        heroTag: widget.heroTag,
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
    final l10n = ref.watch(translationsProvider);
    final showScores = ref.watch(showScoresProvider);
    final displayTitle = widget.entry.displayTitle(titleLang);

    Widget buildCard(BuildContext context, BoxConstraints constraints) {
      final cardWidth = widget.width ?? constraints.maxWidth;
      final isCompact = cardWidth < 155;
      final dynamicColor = parseHexColor(widget.entry.coverColor) ?? colors.accent;

      return RepaintBoundary(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
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
              child: ValueListenableBuilder<AppInputMode>(
                valueListenable: AppFocusCoordinator.inputMode,
                builder: (context, mode, _) {
                  final isDpad = mode == AppInputMode.dpad;
                  final isActive = (mode == AppInputMode.mouse && _isHovered) || (isDpad && _isFocused);

                  return Stack(
                    children: [
                      // Ambient color background with inside-out expansion animation (No borders)
                      Positioned.fill(
                        child: AnimatedScale(
                          scale: isActive ? 1.0 : 0.85,
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
                                scale: isActive ? 1.015 : 1.0,
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      isCompact ? (colors.borderRadius * 0.8).clamp(0.0, 16.0) : colors.borderRadius,
                                    ),
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
                                          child: _buildCoverImage(theme, isCompact),
                                        )
                                      else
                                        _buildCoverImage(theme, isCompact),

                                      // Downloaded badge
                                      if (widget.entry.isDownloaded)
                                        Positioned(
                                          top: isCompact ? 5 : 6,
                                          left: isCompact ? 5 : 6,
                                          child: Container(
                                            padding: isCompact
                                                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                                : const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: theme.colorScheme.primary.withValues(alpha: 0.92),
                                              borderRadius: BorderRadius.circular(isCompact ? 4 : 5),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.35),
                                                  blurRadius: 3,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.download_done_rounded,
                                                  size: isCompact ? 10 : 12,
                                                  color: theme.colorScheme.onPrimary,
                                                ),
                                                if (widget.entry.downloadedChaptersCount > 0) ...[
                                                  const SizedBox(width: 2.5),
                                                  Text(
                                                    '${widget.entry.downloadedChaptersCount}',
                                                    style: TextStyle(
                                                      color: theme.colorScheme.onPrimary,
                                                      fontSize: isCompact ? 8.5 : 9.5,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),

                                      // Subtle Chapter Progress pill
                                      if (widget.entry.progress > 0)
                                        Positioned(
                                          top: isCompact ? 5 : 6,
                                          right: isCompact ? 5 : 6,
                                          child: Container(
                                            padding: isCompact
                                                ? const EdgeInsets.symmetric(horizontal: 4, vertical: 2)
                                                : const EdgeInsets.symmetric(horizontal: 5, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(isCompact ? 4 : 5),
                                            ),
                                            child: Text(
                                              'Ch. ${widget.entry.progress}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: isCompact ? 8.5 : 9.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        )
                                      else if (showScores && widget.entry.score != null && widget.entry.score! > 0)
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
                            if (widget.entry.year != null || widget.entry.status.isNotEmpty) ...[
                              SizedBox(height: isCompact ? 2.0 : 3.0),
                              Text(
                                [
                                  if (widget.entry.year != null) '${widget.entry.year}',
                                  widget.entry.status.isNotEmpty
                                      ? l10n.formatStatus(widget.entry.status)
                                      : l10n.manga,
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: isCompact ? 10.5 : 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.1,
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

  Widget _buildCoverImage(ThemeData theme, bool isCompact) {
    if (widget.entry.localCoverPath != null && File(widget.entry.localCoverPath!).existsSync()) {
      return Image.file(
        File(widget.entry.localCoverPath!),
        cacheWidth: 440,
        cacheHeight: 640,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.outline,
            size: isCompact ? 28 : 36,
          ),
        ),
      );
    }

    if (widget.entry.coverImage != null) {
      return CachedNetworkImage(
        imageUrl: widget.entry.coverImage!,
        fit: BoxFit.cover,
        memCacheWidth: isCompact ? 280 : 420,
        memCacheHeight: isCompact ? 400 : 600,
        maxWidthDiskCache: 500,
        maxHeightDiskCache: 750,
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (context, url) => ColoredBox(
          color: theme.colorScheme.surfaceContainerHighest,
        ),
        errorWidget: (context, url, error) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.outline,
            size: isCompact ? 28 : 36,
          ),
        ),
      );
    }

    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.menu_book_rounded,
        color: theme.colorScheme.outline,
        size: isCompact ? 28 : 36,
      ),
    );
  }
}
