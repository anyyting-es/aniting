import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopHeader extends ConsumerStatefulWidget {
  final String? clearlogoUrl;
  final bool isTmdb;
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
    this.clearlogoUrl,
    this.isTmdb = false,
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

    // Duration formatting (e.g. 2h 25m or 24m or 12 Episodes)
    final String? durationStr;
    if (widget.duration != null && widget.duration! > 0) {
      final hours = widget.duration! ~/ 60;
      final mins = widget.duration! % 60;
      durationStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    } else if (widget.totalEpisodes != null && widget.totalEpisodes! > 0) {
      durationStr = '${widget.totalEpisodes} ${l10n.episodes}';
    } else {
      durationStr = null;
    }

    // Score format: e.g. "7.9" or "84%"
    final scoreDisplay = widget.score != null && widget.score! > 0
        ? (widget.score! > 10 ? '${widget.score!.round()}%' : widget.score!.toStringAsFixed(1))
        : null;

    final hasClearLogo = widget.clearlogoUrl != null && widget.clearlogoUrl!.isNotEmpty;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ─── 1. Clear Logo (If no logo, show nothing) ───
          if (hasClearLogo) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 180,
                maxWidth: 580,
              ),
              child: CachedNetworkImage(
                imageUrl: widget.clearlogoUrl!,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
                fadeInDuration: Duration.zero,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 14),
          ],

        // ─── 2. Metadata Row: Year • Duration • [Rating / Status Pill] • [IMDb / Score Badge] ───
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            // Year
            if (effectiveDateSeason.isNotEmpty)
              Text(
                effectiveDateSeason,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: metaColor,
                  shadows: textShadows,
                ),
              ),

            // Duration (e.g. 2h 25m or 12 Episodes)
            if (durationStr != null)
              Text(
                durationStr,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: metaColor,
                  shadows: textShadows,
                ),
              ),

            // Format Pill (e.g. [TV], [MOVIE])
            if (widget.format != null && widget.format!.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.format!.toUpperCase() == 'TV' ? 'TV' : l10n.formatFormat(widget.format),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

            // Status Pill (e.g. [Watching], [Finished], [PG-13])
            if (displayStatus != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1,
                  ),
                ),
                child: Text(
                  displayStatus,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),

            // Score Badge (e.g. Yellow [IMDb 7.9] or [TMDB 7.9] or [★ 8.4])
            if (scoreDisplay != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5C518),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isTmdb ? 'TMDB ' : (scoreDisplay.contains('%') ? '' : '★ '),
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    Text(
                      scoreDisplay,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),

        // ─── 3. Studio & Genres Row (bullet separated) ───
        if ((widget.studio != null && widget.studio!.isNotEmpty) || widget.genres.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              if (widget.studio != null && widget.studio!.isNotEmpty) ...[
                Text(
                  widget.studio!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.90),
                    shadows: textShadows,
                  ),
                ),
                if (widget.genres.isNotEmpty)
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
              ],
              for (int i = 0; i < widget.genres.length; i++) ...[
                if (i > 0)
                  Text(
                    '•',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.50),
                    ),
                  ),
                Text(
                  widget.genres[i],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.75),
                    shadows: textShadows,
                  ),
                ),
              ],
            ],
          ),
        ],

        // ─── 4. Expandable Synopsis ───
        if (widget.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.description,
                  maxLines: _isSynopsisExpanded ? null : 3,
                  overflow: _isSynopsisExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.45,
                    color: descColor,
                    shadows: textShadows,
                  ),
                ),
                if (widget.description.length > 160) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _isSynopsisExpanded ? '${l10n.synopsisLess} ▲' : '${l10n.synopsisMore} ▼',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
  }
}

