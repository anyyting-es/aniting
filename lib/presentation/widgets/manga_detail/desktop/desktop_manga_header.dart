import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/i18n_provider.dart';

class DesktopMangaHeader extends ConsumerStatefulWidget {
  final String? subtitleStr;
  final String title;
  final List<String> genres;
  final String description;
  final String? format;
  final String? status;
  final int? year;
  final double? score;
  final int? totalChapters;
  final int? totalVolumes;

  const DesktopMangaHeader({
    super.key,
    this.subtitleStr,
    required this.title,
    required this.genres,
    required this.description,
    this.format,
    this.status,
    this.year,
    this.score,
    this.totalChapters,
    this.totalVolumes,
  });

  @override
  ConsumerState<DesktopMangaHeader> createState() => _DesktopMangaHeaderState();
}

class _DesktopMangaHeaderState extends ConsumerState<DesktopMangaHeader> {
  bool _isSynopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    final metaItems = <Widget>[];
    if (widget.year != null) {
      metaItems.add(
        Text(
          '${widget.year}',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
            letterSpacing: 0.3,
          ),
        ),
      );
    }
    if (widget.status != null && widget.status!.isNotEmpty) {
      if (metaItems.isNotEmpty) {
        metaItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '•',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white30 : theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        );
      }
      final statusLabel = l10n.formatStatus(widget.status);
      metaItems.add(
        Text(
          statusLabel,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: widget.status == 'RELEASING'
                ? (isDark ? const Color(0xFF68D391) : Colors.green.shade700)
                : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Main Title on Top (Bigger & Cinematic) ──
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),

        // ── 2. Floating Metadata Row (Year • Status) ──
        if (metaItems.isNotEmpty) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: metaItems,
          ),
          const SizedBox(height: 8),
        ],

        // ── 3. Floating Genres (No Heavy Backgrounds) ──
        if (widget.genres.isNotEmpty) ...[
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              for (int i = 0; i < widget.genres.length; i++) ...[
                if (i > 0)
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white24 : theme.colorScheme.outlineVariant,
                    ),
                  ),
                Text(
                  widget.genres[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
        ],

        // ── 4. Synopsis (Expandable) ──
        if (widget.description.isNotEmpty) ...[
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topLeft,
                child: Text(
                  widget.description,
                  maxLines: _isSynopsisExpanded ? 99 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}
