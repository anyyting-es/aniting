import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopHeader extends ConsumerStatefulWidget {
  final String seasonYearStr;
  final String title;
  final String? subtitle;
  final List<String> genres;
  final String description;
  final String? format;
  final String? status;
  final String? userStatus;
  final int? progress;
  final num? score;
  final String? studio;
  final int? totalEpisodes;
  final int? duration;
  final String? dateSeasonStr;
  final VoidCallback? onEditStatus;

  const DesktopHeader({
    super.key,
    this.seasonYearStr = '',
    required this.title,
    this.subtitle,
    required this.genres,
    required this.description,
    this.format,
    this.status,
    this.userStatus,
    this.progress,
    this.score,
    this.studio,
    this.totalEpisodes,
    this.duration,
    this.dateSeasonStr,
    this.onEditStatus,
  });

  @override
  ConsumerState<DesktopHeader> createState() => _DesktopHeaderState();
}

class _DesktopHeaderState extends ConsumerState<DesktopHeader> {
  bool _isSynopsisExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.70) : theme.colorScheme.onSurfaceVariant;
    final metaColor = isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface;
    final descColor = isDark ? Colors.white.withValues(alpha: 0.75) : theme.colorScheme.onSurfaceVariant;
    final textShadows = isDark
        ? const [
            Shadow(color: Colors.black87, blurRadius: 8, offset: Offset(0, 1)),
          ]
        : null;

    final effectiveDateSeason = (widget.dateSeasonStr != null && widget.dateSeasonStr!.isNotEmpty)
        ? widget.dateSeasonStr!
        : widget.seasonYearStr;

    // Status to display: user status (Watching, Completed, etc.) or release status (Releasing, Finished)
    final displayStatusRaw = widget.userStatus ?? widget.status;
    final displayStatus = displayStatusRaw != null && displayStatusRaw.isNotEmpty
        ? ((displayStatusRaw.toUpperCase() == 'WATCHING' || displayStatusRaw.toUpperCase() == 'CURRENT')
            ? l10n.statusWatching
            : l10n.formatStatus(displayStatusRaw))
        : null;

    final scoreDisplay = widget.score != null && widget.score! > 0
        ? (widget.score! > 10 ? '${widget.score!.round()}%' : widget.score!.toStringAsFixed(1))
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── 1. Main Anime Title (32px Bold) ───
        Text(
          widget.title,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
            height: 1.15,
            color: titleColor,
            shadows: textShadows,
          ),
        ),

        // ─── 2. Subtitle / Alternate Title (16px Medium) ───
        if (widget.subtitle != null && widget.subtitle!.isNotEmpty && widget.subtitle != widget.title) ...[
          const SizedBox(height: 6),
          Text(
            widget.subtitle!,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.2,
              height: 1.25,
              color: subtitleColor,
              shadows: textShadows,
            ),
          ),
        ],

        const SizedBox(height: 14),

        // ─── 3. Metadata Row 1: [Progress / Total Eps] [Status Pill] | [Date - Season] ───
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Format (e.g. TV, MOVIE, OVA)
            if (widget.format != null && widget.format!.isNotEmpty)
              Text(
                widget.format!.toUpperCase() == 'TV' ? 'TV' : l10n.formatFormat(widget.format),
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: metaColor,
                  shadows: textShadows,
                ),
              ),

            // Episodes / Progress Info (e.g. 4/12 or 12 Eps)
            if (widget.progress != null && widget.progress! > 0 && widget.totalEpisodes != null && widget.totalEpisodes! > 0)
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${widget.progress}',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w900,
                        color: metaColor,
                        shadows: textShadows,
                      ),
                    ),
                    TextSpan(
                      text: '/${widget.totalEpisodes}',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: metaColor.withValues(alpha: 0.75),
                        shadows: textShadows,
                      ),
                    ),
                  ],
                ),
              )
            else if (widget.totalEpisodes != null && widget.totalEpisodes! > 0)
              Text(
                '${widget.totalEpisodes} ${l10n.episodesCountSuffix}',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: metaColor,
                  shadows: textShadows,
                ),
              ),

            // Status Pill (with subtle edit pencil icon, no neon glow)
            if (displayStatus != null)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onEditStatus,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.black.withValues(alpha: 0.10),
                        width: 0.8,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size: 13.5,
                          color: metaColor.withValues(alpha: 0.85),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          displayStatus,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: metaColor,
                            shadows: textShadows,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Vertical divider bar '|'
            if (effectiveDateSeason.isNotEmpty)
              Text(
                '|',
                style: TextStyle(
                  color: isDark ? Colors.white30 : Colors.black26,
                  fontSize: 15,
                  fontWeight: FontWeight.w300,
                ),
              ),

            // Date & Season with Calendar Icon
            if (effectiveDateSeason.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14.5,
                    color: metaColor.withValues(alpha: 0.8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    effectiveDateSeason,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: metaColor,
                      shadows: textShadows,
                    ),
                  ),
                ],
              ),
          ],
        ),

        const SizedBox(height: 10),

        // ─── 4. Metadata Row 2: [♡ Score] [Studio] [Genre 1] [Genre 2] ───
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 14,
          runSpacing: 6,
          children: [
            // Score with Clean Heart Outline (Neutral typography, no yellow background/text)
            if (scoreDisplay != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_border_rounded,
                    size: 16,
                    color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    scoreDisplay,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      shadows: textShadows,
                    ),
                  ),
                ],
              ),

            // Studio in Bold
            if (widget.studio != null && widget.studio!.isNotEmpty)
              Text(
                widget.studio!,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  shadows: textShadows,
                ),
              ),

            // Genres as Clean Plain Text with spacing (No boxes, no borders, no cyan)
            if (widget.genres.isNotEmpty)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: widget.genres.map((g) {
                  return Text(
                    g,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: descColor,
                      shadows: textShadows,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── 5. Expandable Synopsis (Constrained Width for Comfortable Reading) ───
        if (widget.description.isNotEmpty) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
                child: Text(
                  widget.description,
                  maxLines: _isSynopsisExpanded ? 99 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: descColor,
                    shadows: textShadows,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}
