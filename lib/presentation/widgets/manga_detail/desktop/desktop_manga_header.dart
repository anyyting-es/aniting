import 'package:flutter/material.dart';

class DesktopMangaHeader extends StatefulWidget {
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
  State<DesktopMangaHeader> createState() => _DesktopMangaHeaderState();
}

class _DesktopMangaHeaderState extends State<DesktopMangaHeader> {
  bool _isSynopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tags = <Widget>[];

    if (widget.format != null && widget.format!.isNotEmpty) {
      tags.add(_buildMetaBadge(
        theme,
        widget.format!.replaceAll('_', ' '),
        color: theme.colorScheme.primary,
        bgColor: theme.colorScheme.primaryContainer,
      ));
    }
    if (widget.status != null && widget.status!.isNotEmpty) {
      tags.add(_buildMetaBadge(
        theme,
        widget.status == 'RELEASING' ? 'En emisión' : (widget.status == 'FINISHED' ? 'Finalizado' : widget.status!),
        color: theme.colorScheme.secondary,
        bgColor: theme.colorScheme.secondaryContainer,
      ));
    }
    if (widget.year != null) {
      tags.add(_buildMetaBadge(
        theme,
        '${widget.year}',
        color: theme.colorScheme.onSurfaceVariant,
        bgColor: theme.colorScheme.surfaceContainerHighest,
      ));
    }
    if (widget.score != null && widget.score! > 0) {
      tags.add(_buildMetaBadge(
        theme,
        '★ ${widget.score!.toStringAsFixed(1)}',
        color: const Color(0xFFFFB800),
        bgColor: const Color(0xFFFFB800).withValues(alpha: 0.15),
      ));
    }
    if (widget.totalChapters != null && widget.totalChapters! > 0) {
      tags.add(_buildMetaBadge(
        theme,
        '${widget.totalChapters} Caps',
        color: theme.colorScheme.onSurfaceVariant,
        bgColor: theme.colorScheme.surfaceContainerHighest,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metadata badges row
        if (tags.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: tags,
          ),
          const SizedBox(height: 10),
        ] else if (widget.subtitleStr != null && widget.subtitleStr!.isNotEmpty) ...[
          Text(
            widget.subtitleStr!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
        ],

        // Main Title
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
            height: 1.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // System-Colored Genre Pills
        if (widget.genres.isNotEmpty) ...[
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: widget.genres.map((g) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  g,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
        ],

        // Synopsis (Expandable with AnimatedSize)
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
                    fontSize: 13.5,
                    height: 1.5,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildMetaBadge(
    ThemeData theme,
    String label, {
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
