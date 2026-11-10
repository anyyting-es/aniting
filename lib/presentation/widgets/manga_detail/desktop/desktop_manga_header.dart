import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/i18n_provider.dart';

class DesktopMangaHeader extends ConsumerStatefulWidget {
  final String title;
  final String? subtitleStr;
  final int progress;
  final int? totalChapters;
  final String? userStatus;
  final String? releaseStatus;
  final String? startDateStr;
  final double? score;
  final List<String> genres;
  final String description;
  final String? format;
  final VoidCallback onOpenEditModal;

  const DesktopMangaHeader({
    super.key,
    required this.title,
    this.subtitleStr,
    this.progress = 0,
    this.totalChapters,
    this.userStatus,
    this.releaseStatus,
    this.startDateStr,
    this.score,
    this.genres = const [],
    this.description = '',
    this.format,
    required this.onOpenEditModal,
  });

  @override
  ConsumerState<DesktopMangaHeader> createState() => _DesktopMangaHeaderState();
}

class _DesktopMangaHeaderState extends ConsumerState<DesktopMangaHeader> {
  bool _isSynopsisExpanded = false;

  String _formatUserStatus(String? status, AppTranslations l10n) {
    if (status == null || status.isEmpty) return l10n.reading;
    switch (status.toUpperCase()) {
      case 'CURRENT':
      case 'READING':
        return l10n.reading;
      case 'PLANNING':
        return l10n.statusPlanning;
      case 'COMPLETED':
        return l10n.statusCompleted;
      case 'PAUSED':
        return l10n.statusPaused;
      case 'DROPPED':
        return l10n.statusDropped;
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    final progressTotalStr =
        '${widget.progress}/${widget.totalChapters != null && widget.totalChapters! > 0 ? widget.totalChapters : '-'}';
    final userStatusLabel = _formatUserStatus(widget.userStatus, l10n);
    final releaseStatusLabel = widget.releaseStatus != null && widget.releaseStatus!.isNotEmpty
        ? l10n.formatStatus(widget.releaseStatus)
        : null;

    final pillBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6);
    final pillBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.45);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Main Title (32px Bold) ──
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.15,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),

        // ── 2. Romaji / Native Subtitle ──
        if (widget.subtitleStr != null && widget.subtitleStr!.isNotEmpty) ...[
          Text(
            widget.subtitleStr!,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 8),

        // ── 3. Badges Row: [Progress] [✎ UserStatus] [📅 StartDate] [🌐 ReleaseStatus] ──
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Progress / Total e.g. "72/-"
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                progressTotalStr,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),

            // User Status with Edit pencil [ ✎ Reading ]
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onOpenEditModal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: pillBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_outlined,
                        size: 13,
                        color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        userStatusLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Start Date pill [ 📅 Aug 2024 ]
            if (widget.startDateStr != null && widget.startDateStr!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: pillBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.startDateStr!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),

            // Releasing Status pill [ 🌐 Releasing ]
            if (releaseStatusLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFB8A1FF).withValues(alpha: isDark ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFB8A1FF).withValues(alpha: 0.4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      size: 13,
                      color: Color(0xFFB8A1FF),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      releaseStatusLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB8A1FF),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // ── 4. Score & Genres Row (♡ 7.6  Comedy  Romance) ──
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            if (widget.score != null && widget.score! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 14,
                    color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.score!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            for (final genre in widget.genres)
              Text(
                genre,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        // ── 5. Expandable Synopsis ──
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
                    color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.88),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── 6. Format tag (e.g. MANGA) ──
        if (widget.format != null && widget.format!.isNotEmpty)
          Text(
            widget.format!.toUpperCase().replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
  }
}
