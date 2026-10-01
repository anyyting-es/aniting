import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class ContinueReadingCard extends ConsumerStatefulWidget {
  final MangaEntry entry;
  final VoidCallback onTap;
  final double? width;
  final double? height;

  const ContinueReadingCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.width,
    this.height,
  });

  @override
  ConsumerState<ContinueReadingCard> createState() => _ContinueReadingCardState();
}

class _ContinueReadingCardState extends ConsumerState<ContinueReadingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

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

    final card = RepaintBoundary(
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
              children: [
                Expanded(
                  child: AnimatedScale(
                    scale: _isHovered ? 1.02 : 1.0,
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
                SizedBox(height: isCompact ? 5 : 7),
                Text(
                  mangaTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 11.5 : 12.5,
                    fontWeight: FontWeight.w700,
                    color: (_isActive || _isHovered)
                        ? theme.colorScheme.primary
                        : (theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface
                            : const Color(0xFF111418)),
                    fontFamilyFallback: kJapaneseFontFallbacks,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  chapterSubtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isCompact ? 10.0 : 11.0,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (progressFraction != null) ...[
                  SizedBox(height: isCompact ? 4 : 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progressFraction,
                      minHeight: isCompact ? 2.5 : 3.0,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: card,
      );
    }

    return card;
  }
}
