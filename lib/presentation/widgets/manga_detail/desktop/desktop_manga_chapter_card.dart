import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/i18n_provider.dart';
import 'package:aniting/data/models/manga_entry.dart';

class DesktopMangaChapterCard extends ConsumerStatefulWidget {
  final MangaChapter chapter;
  final bool isRead;
  final bool isDownloaded;
  final bool isDownloading;
  final bool canDownload;
  final VoidCallback onTap;
  final VoidCallback onDownload;
  final bool isSelected;
  final VoidCallback? onToggleSelect;

  const DesktopMangaChapterCard({
    super.key,
    required this.chapter,
    required this.isRead,
    required this.isDownloaded,
    required this.isDownloading,
    required this.canDownload,
    required this.onTap,
    required this.onDownload,
    this.isSelected = false,
    this.onToggleSelect,
  });

  @override
  ConsumerState<DesktopMangaChapterCard> createState() => _DesktopMangaChapterCardState();
}

class _DesktopMangaChapterCardState extends ConsumerState<DesktopMangaChapterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    final cardOpacity = widget.isRead ? (_isHovered ? 0.9 : 0.5) : 1.0;

    final hasCustomTitle = widget.chapter.title.isNotEmpty &&
        widget.chapter.title.toLowerCase() != widget.chapter.chapter.toLowerCase();
    final displayName = hasCustomTitle
        ? widget.chapter.title
        : '${l10n.chapter} ${widget.chapter.chapter.isNotEmpty ? widget.chapter.chapter : (widget.chapter.index + 1)}';

    final chapterNumberStr = widget.chapter.chapter.isNotEmpty
        ? widget.chapter.chapter
        : '${widget.chapter.index + 1}';

    final scanlatorStr = (widget.chapter.scanlator != null && widget.chapter.scanlator!.isNotEmpty)
        ? widget.chapter.scanlator!
        : '-';

    final rowBg = widget.isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
        : (_isHovered
            ? (isDark ? Colors.white.withValues(alpha: 0.04) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5))
            : Colors.transparent);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          onTap: widget.isSelected && widget.onToggleSelect != null
              ? widget.onToggleSelect
              : widget.onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: rowBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                // 1. Radio / Circle Selection Checkbox
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: widget.onToggleSelect,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isSelected ? theme.colorScheme.primary : Colors.transparent,
                          border: Border.all(
                            color: widget.isSelected
                                ? theme.colorScheme.primary
                                : (isDark ? Colors.white.withValues(alpha: 0.25) : theme.colorScheme.outlineVariant),
                            width: 1.6,
                          ),
                        ),
                        child: widget.isSelected
                            ? const Icon(Icons.check, size: 12, color: Colors.white)
                            : null,
                      ),
                    ),
                  ),
                ),

                // 2. Name Column (Flexible)
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _isHovered
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white : theme.colorScheme.onSurface),
                    ),
                  ),
                ),

                // 3. Scanlator Column (Width ~170)
                SizedBox(
                  width: 170,
                  child: Text(
                    scanlatorStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // 4. Number Column (Width ~65)
                SizedBox(
                  width: 65,
                  child: Text(
                    chapterNumberStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),

                // 5. Actions (Download & Read)
                SizedBox(
                  width: 72,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Download action
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
                          icon: const Icon(Icons.download_rounded, size: 18),
                          color: isDark
                              ? (_isHovered ? Colors.white70 : Colors.white38)
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          tooltip: l10n.downloadChapterAction,
                          onPressed: widget.onDownload,
                        ),

                      const SizedBox(width: 4),

                      // Read action icon
                      IconButton(
                        icon: const Icon(Icons.menu_book_rounded, size: 18),
                        color: isDark
                            ? (_isHovered ? Colors.white : Colors.white38)
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        tooltip: l10n.startReading,
                        onPressed: widget.onTap,
                      ),
                    ],
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
