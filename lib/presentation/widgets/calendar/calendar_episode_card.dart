import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/show_preview_data.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/show_quick_view_detector.dart';

class CalendarEpisodeCard extends StatefulWidget {
  final AiringScheduleItem schedule;
  final TitleLanguage titleLang;
  final String? titleHeroTag;

  const CalendarEpisodeCard({
    super.key,
    required this.schedule,
    required this.titleLang,
    this.titleHeroTag,
  });

  @override
  State<CalendarEpisodeCard> createState() => _CalendarEpisodeCardState();
}

class _CalendarEpisodeCardState extends State<CalendarEpisodeCard> {
  bool _isHovered = false;

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return 'TBA';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final anime = widget.schedule.media;

    final rawTitle = anime.displayTitle(widget.titleLang);
    final title = (rawTitle.isNotEmpty && rawTitle != 'Sin título' && rawTitle != 'No title')
        ? rawTitle
        : (anime.title.isNotEmpty && anime.title != 'Sin título' && anime.title != 'No title'
            ? anime.title
            : (anime.romajiTitle?.trim().isNotEmpty == true
                ? anime.romajiTitle!.trim()
                : (anime.englishTitle?.trim().isNotEmpty == true
                    ? anime.englishTitle!.trim()
                    : (anime.nativeTitle?.trim().isNotEmpty == true
                        ? anime.nativeTitle!.trim()
                        : 'Ep. ${widget.schedule.episode}'))));

    final isOled = isDark && theme.scaffoldBackgroundColor == Colors.black;
    final timeStr = _formatTime(widget.schedule.airingAt);
    final placeholderColor = isOled
        ? const Color(0xFF101014)
        : (isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHighest);

    final heroTag = 'cal_ep_${widget.schedule.id}_${anime.mediaId}';

    return ShowQuickViewDetector(
      heroTag: heroTag,
      dataBuilder: () => ShowPreviewData.fromAnime(
        anime,
        widget.titleLang,
      ),
      onOpenDetails: () {
        AnimeDetailScreen.navigate(
          context,
          mediaId: anime.mediaId,
          initialEntry: anime,
        );
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            AnimeDetailScreen.navigate(
              context,
              mediaId: anime.mediaId,
              initialEntry: anime,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            padding: const EdgeInsets.fromLTRB(9, 7, 10, 7),
            decoration: BoxDecoration(
              color: _isHovered
                  ? (isOled
                      ? const Color(0xFF141418)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.055)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? (isOled
                        ? const Color(0xFF262632)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)))
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Time gutter
                SizedBox(
                  width: 38,
                  child: Text(
                    timeStr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _isHovered
                          ? (isDark ? Colors.white : theme.colorScheme.onSurface)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.72)
                              : theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 7),

                // Artwork with Hero
                Hero(
                  tag: heroTag,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: anime.coverImage != null
                          ? CachedNetworkImage(
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              imageUrl: anime.coverImage!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) =>
                                  Container(color: placeholderColor),
                            )
                          : Container(color: placeholderColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Title + episode
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.titleHeroTag != null)
                        Hero(
                          tag: widget.titleHeroTag!,
                          flightShuttleBuilder: (flightContext, animation, flightDirection, fromHeroContext, toHeroContext) {
                            return Material(
                              type: MaterialType.transparency,
                              child: toHeroContext.widget,
                            );
                          },
                          child: Material(
                            type: MaterialType.transparency,
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                                letterSpacing: -0.1,
                                color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        )
                      else
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            letterSpacing: -0.1,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      const SizedBox(height: 3.5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isOled
                              ? const Color(0xFF16161D)
                              : (isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)),
                          borderRadius: BorderRadius.circular(6),
                          border: isOled
                              ? Border.all(color: const Color(0xFF24242E), width: 0.8)
                              : null,
                        ),
                        child: Text(
                          'Ep. ${widget.schedule.episode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.85)
                                : theme.colorScheme.onSurface,
                          ),
                        ),
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
