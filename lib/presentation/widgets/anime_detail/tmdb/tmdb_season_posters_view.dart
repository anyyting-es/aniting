import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbSeasonPostersView extends ConsumerWidget {
  final List<TmdbSeason> seasons;
  final int selectedSeasonNumber;
  final ValueChanged<int> onSeasonSelected;
  final String? fallbackCoverUrl;

  const TmdbSeasonPostersView({
    super.key,
    required this.seasons,
    required this.selectedSeasonNumber,
    required this.onSeasonSelected,
    this.fallbackCoverUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (seasons.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    // Sort seasons: season 1, 2, 3... and season 0 (specials) at the end
    final sortedSeasons = List<TmdbSeason>.from(seasons);
    sortedSeasons.sort((a, b) {
      if (a.seasonNumber == 0) return 1;
      if (b.seasonNumber == 0) return -1;
      return a.seasonNumber.compareTo(b.seasonNumber);
    });

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: sortedSeasons.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final season = sortedSeasons[index];
          final isSelected = season.seasonNumber == selectedSeasonNumber;
          final title = season.seasonNumber == 0
              ? l10n.specials
              : (season.name.isNotEmpty
                  ? season.name
                  : '${l10n.season} ${season.seasonNumber}');
          final posterUrl = season.posterUrl ?? fallbackCoverUrl;

          return _TmdbSeasonPosterCard(
            season: season,
            title: title,
            posterUrl: posterUrl,
            isSelected: isSelected,
            isDark: isDark,
            theme: theme,
            onTap: () => onSeasonSelected(season.seasonNumber),
          );
        },
      ),
    );
  }
}

class _TmdbSeasonPosterCard extends StatefulWidget {
  final TmdbSeason season;
  final String title;
  final String? posterUrl;
  final bool isSelected;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _TmdbSeasonPosterCard({
    required this.season,
    required this.title,
    required this.posterUrl,
    required this.isSelected,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  @override
  State<_TmdbSeasonPosterCard> createState() => _TmdbSeasonPosterCardState();
}

class _TmdbSeasonPosterCardState extends State<_TmdbSeasonPosterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster Container (2:3 Aspect Ratio)
              Expanded(
                child: AnimatedScale(
                  scale: _isHovered ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isSelected
                            ? widget.theme.colorScheme.primary
                            : (_isHovered
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08)),
                        width: widget.isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isSelected
                              ? widget.theme.colorScheme.primary.withValues(alpha: 0.28)
                              : Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.20),
                          blurRadius: widget.isSelected ? 10 : (_isHovered ? 8 : 4),
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (widget.posterUrl != null && widget.posterUrl!.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: widget.posterUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 240,
                            memCacheHeight: 360,
                            placeholder: (_, _) => Container(
                              color: widget.theme.colorScheme.surfaceContainerHighest,
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: widget.theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.movie_rounded, size: 28),
                            ),
                          )
                        else
                          Container(
                            color: widget.theme.colorScheme.surfaceContainerHighest,
                            child: const Icon(Icons.movie_rounded, size: 28),
                          ),

                        // Bottom gradient on card
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.70),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Episode Count Badge (bottom right)
                        if (widget.season.episodeCount > 0)
                          Positioned(
                            bottom: 5,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${widget.season.episodeCount} eps',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 7),

              // Season Name Label
              Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                  color: widget.isSelected
                      ? widget.theme.colorScheme.primary
                      : (widget.isDark ? Colors.white : widget.theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
