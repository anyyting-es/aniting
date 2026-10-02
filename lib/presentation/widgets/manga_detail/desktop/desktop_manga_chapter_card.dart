import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class DesktopMangaChapterCard extends ConsumerStatefulWidget {
  final MangaChapter chapter;
  final bool isRead;
  final bool isDownloaded;
  final bool isDownloading;
  final bool canDownload;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const DesktopMangaChapterCard({
    super.key,
    required this.chapter,
    required this.isRead,
    required this.isDownloaded,
    required this.isDownloading,
    required this.canDownload,
    required this.onTap,
    required this.onDownload,
  });

  @override
  ConsumerState<DesktopMangaChapterCard> createState() => _DesktopMangaChapterCardState();
}

class _DesktopMangaChapterCardState extends ConsumerState<DesktopMangaChapterCard> {
  bool _isHovered = false;

  String _formatChapterLabel(MangaChapter c, AppTranslations l10n) {
    if (c.chapter.isNotEmpty) {
      final parsed = double.tryParse(c.chapter);
      if (parsed != null && parsed == parsed.roundToDouble()) {
        return l10n.chapterAbbr('${parsed.toInt()}');
      }
      return l10n.chapterAbbr(c.chapter);
    }
    return l10n.chapterAbbr('${c.index + 1}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final cardOpacity = widget.isRead ? (_isHovered ? 0.85 : 0.45) : 1.0;
    final chapterLabel = _formatChapterLabel(widget.chapter, l10n);

    final hasTitle = widget.chapter.title.isNotEmpty &&
        widget.chapter.title.toLowerCase() != chapterLabel.toLowerCase() &&
        widget.chapter.title != widget.chapter.chapter;

    final baseBg = isDark
        ? Colors.white.withValues(alpha: 0.03)
        : theme.colorScheme.surfaceContainerLow;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest;

    final baseBorder = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.22);
    final hoverBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _isHovered ? hoverBg : baseBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered ? hoverBorder : baseBorder,
              ),
            ),
            child: Row(
              children: [
                // Minimal Chapter Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isRead
                        ? (isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest)
                        : theme.colorScheme.primary.withValues(alpha: isDark ? 0.14 : 0.10),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: widget.isRead
                          ? (isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3))
                          : theme.colorScheme.primary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    chapterLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isRead
                          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                          : theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Title & Scanlator on single line
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          hasTitle
                              ? widget.chapter.title
                              : '${l10n.chapter} ${widget.chapter.chapter.isNotEmpty ? widget.chapter.chapter : (widget.chapter.index + 1)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: widget.isRead
                                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (widget.chapter.scanlator != null &&
                          widget.chapter.scanlator!.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.chapter.scanlator!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Read indicator
                if (widget.isRead) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      l10n.readBadge,
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Download icon / indicator
                if (widget.isDownloading)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    ),
                  )
                else if (widget.isDownloaded)
                  Icon(
                    Icons.download_done_rounded,
                    color: theme.colorScheme.primary,
                    size: 18,
                  )
                else if (widget.canDownload)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 17),
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: _isHovered ? 0.9 : 0.5),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: l10n.downloadChapterAction,
                    onPressed: widget.onDownload,
                  ),

                // Subtle chevron on hover
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.primary,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
