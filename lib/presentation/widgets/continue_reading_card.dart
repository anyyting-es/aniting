import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class ContinueReadingCard extends ConsumerStatefulWidget {
  final MangaEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetails;
  final double? width;
  final double? height;

  const ContinueReadingCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onOpenDetails,
    this.width,
    this.height,
  });

  @override
  ConsumerState<ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends ConsumerState<ContinueReadingCard> {
  late final FocusNode _focusNode = FocusNode();
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerTap() {
    widget.onTap();
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

    final nextChapter = widget.entry.progress + 1;
    final mangaTitle = widget.entry.displayTitle(titleLang);
    final imageUrl = widget.entry.coverImage ?? widget.entry.bannerImage;

    final totalCaps = widget.entry.totalChapters;
    final hasTotal = totalCaps != null && totalCaps > 0;
    final double? progressFraction = hasTotal
        ? (widget.entry.progress / totalCaps).clamp(0.0, 1.0)
        : null;

    final String chapterSubtitle = hasTotal
        ? '${l10n.chapter} $nextChapter - $totalCaps'
        : '${l10n.chapter} $nextChapter';

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = (widget.width != null && widget.width! < 155) || screenWidth < 720;
    final dynamicColor = parseHexColor(widget.entry.coverColor) ?? colors.accent;

    Widget buildCard(BuildContext context) {
      return RepaintBoundary(
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
              onLongPress: widget.onOpenDetails,
              onSecondaryTap: widget.onOpenDetails,
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

                      // Foreground Content
                      Padding(
                        padding: const EdgeInsets.all(6),
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
                                  child: imageUrl != null
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          memCacheWidth: isCompact ? 300 : 350,
                                          memCacheHeight: isCompact ? 440 : 520,
                                          fadeInDuration: const Duration(milliseconds: 150),
                                          fadeOutDuration: const Duration(milliseconds: 100),
                                          placeholder: (context, url) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: theme.colorScheme.surfaceContainerHighest,
                                            child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.outline, size: isCompact ? 28 : 36),
                                          ),
                                        )
                                      : Container(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          child: Icon(Icons.menu_book_rounded, color: theme.colorScheme.outline, size: isCompact ? 28 : 36),
                                        ),
                                ),
                              ),
                            ),

                            SizedBox(height: isCompact ? 6 : 8),

                            // 2. Title only: enlarged and clean
                            Text(
                              mangaTitle,
                              maxLines: 1,
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
                            const SizedBox(height: 2),
                            Text(
                              chapterSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: isCompact ? 10.5 : 11.5,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (progressFraction != null) ...[
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: LinearProgressIndicator(
                                  value: progressFraction,
                                  minHeight: 3.0,
                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(dynamicColor),
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
      );
    }

    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: buildCard(context),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, maxHeight: 380),
      child: buildCard(context),
    );
  }
}
