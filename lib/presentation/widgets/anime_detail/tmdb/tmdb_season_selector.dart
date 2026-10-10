import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbSeasonSelector extends ConsumerWidget {
  final List<TmdbSeason> seasons;
  final int selectedSeasonNumber;
  final ValueChanged<int> onSeasonSelected;
  final bool isMovie;

  const TmdbSeasonSelector({
    super.key,
    required this.seasons,
    required this.selectedSeasonNumber,
    required this.onSeasonSelected,
    this.isMovie = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    if (isMovie) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: theme.colorScheme.primary.withValues(alpha: 0.12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_rounded, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.movieDetails,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
      );
    }

    if (seasons.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter seasons: sort by seasonNumber (0 = specials at the end if desired, or in order)
    final sortedSeasons = List<TmdbSeason>.from(seasons);
    sortedSeasons.sort((a, b) {
      // Put season 0 (specials) at the end
      if (a.seasonNumber == 0) return 1;
      if (b.seasonNumber == 0) return -1;
      return a.seasonNumber.compareTo(b.seasonNumber);
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: sortedSeasons.map((season) {
          final isSelected = season.seasonNumber == selectedSeasonNumber;
          final title = season.seasonNumber == 0
              ? l10n.specials
              : (season.name.isNotEmpty
                  ? season.name
                  : '${l10n.season} ${season.seasonNumber}');

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSeasonSelected(season.seasonNumber),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: isSelected
                        ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.25 : 0.15)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04)),
                    border: Border.all(
                      color: isSelected
                          ? theme.colorScheme.primary.withValues(alpha: 0.8)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06)),
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : theme.colorScheme.primary)
                              : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                      if (season.episodeCount > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(5),
                            color: isSelected
                                ? theme.colorScheme.primary.withValues(alpha: 0.3)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.06)),
                          ),
                          child: Text(
                            '${season.episodeCount}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
