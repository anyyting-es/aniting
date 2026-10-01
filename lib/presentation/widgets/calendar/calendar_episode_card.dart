import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

class CalendarEpisodeCard extends StatefulWidget {
  final AiringScheduleItem schedule;
  final TitleLanguage titleLang;

  const CalendarEpisodeCard({
    super.key,
    required this.schedule,
    required this.titleLang,
  });

  @override
  State<CalendarEpisodeCard> createState() => _CalendarEpisodeCardState();
}

class _CalendarEpisodeCardState extends State<CalendarEpisodeCard> {
  bool _isHovered = false;

  String _formatTime(int timestamp) {
    if (timestamp <= 0) return 'Time TBA';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    return DateFormat('HH:mm').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final anime = widget.schedule.media;
    final title = anime.displayTitle(widget.titleLang);
    final timeStr = _formatTime(widget.schedule.airingAt);

    return MouseRegion(
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
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: _isHovered
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Airing Time - clear, bold & readable
              Row(
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Thumbnail and Title Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square Thumbnail with larger comfortable scale
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: anime.coverImage != null
                          ? CachedNetworkImage(
                              memCacheWidth: 160,
                              memCacheHeight: 160,
                              imageUrl: anime.coverImage!,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
                                color: isDark
                                    ? const Color(0xFF1E2228)
                                    : theme.colorScheme.surfaceContainerHighest,
                              ),
                            )
                          : Container(
                              color: isDark
                                  ? const Color(0xFF1E2228)
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title and Episode
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ep. ${widget.schedule.episode}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
