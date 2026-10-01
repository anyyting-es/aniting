import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

class MangaCard extends ConsumerStatefulWidget {
  final MangaEntry entry;
  final VoidCallback? onTap;
  final double? width;
  final double? height;

  const MangaCard({
    super.key,
    required this.entry,
    this.onTap,
    this.width,
    this.height,
  });

  @override
  ConsumerState<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends ConsumerState<MangaCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  void _triggerTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      MangaDetailScreen.navigate(
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
    final l10n = ref.watch(translationsProvider);
    final displayTitle = widget.entry.displayTitle(titleLang);

    Widget buildCard(BuildContext context, BoxConstraints constraints) {
      final cardWidth = widget.width ?? constraints.maxWidth;
      final isCompact = cardWidth < 155;

      return RepaintBoundary(
        child: Focus(
          onFocusChange: (val) => setState(() => _isFocused = val),
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
                  // 1. Poster Art Container (whole box expands on hover)
                  AspectRatio(
                    aspectRatio: 0.72,
                    child: AnimatedScale(
                      scale: _isHovered ? 1.025 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(isCompact ? (colors.borderRadius * 0.8).clamp(0.0, 16.0) : colors.borderRadius),
                          color: colors.surface,
                          border: Border.all(
                            color: _isFocused
                                ? Colors.white
                                : (_isHovered
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : colors.border.withValues(alpha: 0.5)),
                            width: _isFocused ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isHovered ? 0.30 : 0.15),
                              blurRadius: _isHovered ? 8 : 4,
                              offset: Offset(0, _isHovered ? 3 : 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.entry.localCoverPath != null &&
                                    // TODO: Synchronous file I/O in build method. Needs model change to fix properly.
                                    File(widget.entry.localCoverPath!).existsSync()
                                ? Image.file(
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
                                  )
                                : (widget.entry.coverImage != null
                                    ? CachedNetworkImage(
                                        imageUrl: widget.entry.coverImage!,
                                        fit: BoxFit.cover,
                                        memCacheWidth: isCompact ? 350 : 440,
                                        memCacheHeight: isCompact ? 500 : 640,
                                        maxWidthDiskCache: 600,
                                        maxHeightDiskCache: 850,
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
                                      )
                                    : Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: Icon(
                                          Icons.menu_book_rounded,
                                          color: theme.colorScheme.outline,
                                          size: isCompact ? 28 : 36,
                                        ),
                                      )),

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

                          // Subtle Chapter / Volume Progress pill
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
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isCompact ? 5 : 7),
                  // 2. Title & Metadata
                  Container(
                    height: isCompact ? 30.0 : 34.0,
                    alignment: Alignment.topLeft,
                    child: Text(
                      displayTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: (_isActive || _isHovered)
                            ? theme.colorScheme.primary
                            : (theme.brightness == Brightness.dark
                                ? colors.textPrimary
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
                      if (widget.entry.year != null) '${widget.entry.year}',
                      widget.entry.status.isNotEmpty ? l10n.formatStatus(widget.entry.status) : l10n.manga,
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
