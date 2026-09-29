import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class DesktopMangaChapterCard extends StatefulWidget {
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
  State<DesktopMangaChapterCard> createState() => _DesktopMangaChapterCardState();
}

class _DesktopMangaChapterCardState extends State<DesktopMangaChapterCard> {
  bool _isHovered = false;

  String _formatChapterLabel(MangaChapter c) {
    if (c.chapter.isNotEmpty) {
      final parsed = double.tryParse(c.chapter);
      if (parsed != null && parsed == parsed.roundToDouble()) {
        return 'Cap. ${parsed.toInt()}';
      }
      return 'Cap. ${c.chapter}';
    }
    return 'Cap. ${c.index + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardOpacity = widget.isRead ? (_isHovered ? 0.85 : 0.45) : 1.0;
    final chapterLabel = _formatChapterLabel(widget.chapter);

    final hasTitle = widget.chapter.title.isNotEmpty &&
        widget.chapter.title.toLowerCase() != chapterLabel.toLowerCase() &&
        widget.chapter.title != widget.chapter.chapter;

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
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFF14171B).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Row(
              children: [
                // Minimal Chapter Number Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: widget.isRead
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFF00C7FF).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: widget.isRead
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFF00C7FF).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    chapterLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: widget.isRead
                          ? Colors.white60
                          : const Color(0xFF00C7FF),
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
                              : 'Capítulo ${widget.chapter.chapter.isNotEmpty ? widget.chapter.chapter : (widget.chapter.index + 1)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: widget.isRead ? Colors.white70 : Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.38),
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
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LEÍDO',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Download icon / indicator
                if (widget.isDownloading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C7FF)),
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
                    color: Colors.white.withValues(alpha: _isHovered ? 0.85 : 0.35),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Descargar',
                    onPressed: widget.onDownload,
                  ),

                // Subtle chevron on hover
                AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 120),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF00C7FF),
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
