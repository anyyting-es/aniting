import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/core/utils/synopsis_utils.dart';
import 'package:aniting/data/models/anime_entry.dart';

/// Compact preview shown from the catalog results on right click.
/// The cover travels from the card to this panel with a Hero animation.
class AnimePreviewPopup extends ConsumerWidget {
  final AnimeEntry entry;
  final Object heroTag;
  final VoidCallback onOpenDetails;

  const AnimePreviewPopup({
    super.key,
    required this.entry,
    required this.heroTag,
    required this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final title = entry.displayTitle(titleLang);
    final rating = entry.score == null
        ? null
        : (entry.score! > 10 ? entry.score! / 10 : entry.score!);
    final seasonYear = _seasonYear(l10n);
    final genres = entry.genres.take(8).toList();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Material(
            color: theme.colorScheme.surface,
            elevation: 24,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 470;
                      final cover = _cover(context, compact);
                      final info = _info(
                        context,
                        l10n: l10n,
                        title: title,
                        rating: rating,
                        seasonYear: seasonYear,
                        genres: genres,
                      );

                      if (compact) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: cover),
                            const SizedBox(height: 16),
                            info,
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          cover,
                          const SizedBox(width: 20),
                          Expanded(child: info),
                        ],
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: l10n.close,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cover(BuildContext context, bool compact) {
    final theme = Theme.of(context);
    return SizedBox(
      width: compact ? 130 : 178,
      child: AspectRatio(
        aspectRatio: 0.72,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Hero(
            tag: heroTag,
            child: entry.coverImage != null
                ? CachedNetworkImage(
                    imageUrl: entry.coverImage!,
                    fit: BoxFit.cover,
                    memCacheWidth: 480,
                    memCacheHeight: 720,
                    placeholder: (_, _) =>
                        ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                    errorWidget: (_, _, _) => ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_rounded,
                        color: theme.colorScheme.outline,
                        size: 32,
                      ),
                    ),
                  )
                : ColoredBox(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.movie_rounded,
                      color: theme.colorScheme.outline,
                      size: 32,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _info(
    BuildContext context, {
    required AppTranslations l10n,
    required String title,
    required double? rating,
    required String? seasonYear,
    required List<String> genres,
  }) {
    final theme = Theme.of(context);
    final episodes = entry.totalEpisodes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 24),
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (rating != null) _ratingChip(theme, rating),
            if (seasonYear != null) _metaChip(theme, seasonYear),
            if (episodes != null && episodes > 0)
              _metaChip(theme, '$episodes EP'),
            if (entry.format != null && entry.format!.isNotEmpty)
              _metaChip(theme, entry.format!),
          ],
        ),
        if (genres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final genre in genres) _genreChip(theme, genre),
            ],
          ),
        ],
        if (cleanSynopsis(entry.description).isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            cleanSynopsis(entry.description),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            M3EButton.icon(
              onPressed: onOpenDetails,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(l10n.details),
              style: M3EButtonStyle.filled,
              size: M3EButtonSize.sm,
            ),
            M3EButton(
              onPressed: () => Navigator.of(context).pop(),
              label: Text(l10n.close),
              style: M3EButtonStyle.text,
              size: M3EButtonSize.sm,
            ),
          ],
        ),
      ],
    );
  }

  Widget _ratingChip(ThemeData theme, double rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 14,
            color: theme.colorScheme.onPrimary,
          ),
          const SizedBox(width: 3),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(ThemeData theme, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: theme.colorScheme.onSurfaceVariant,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _genreChip(ThemeData theme, String genre) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        genre,
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String? _seasonYear(AppTranslations l10n) {
    final year = entry.year;
    final season = entry.season?.toUpperCase();
    String? seasonLabel;
    switch (season) {
      case 'WINTER':
        seasonLabel = l10n.seasonWinter;
        break;
      case 'SPRING':
        seasonLabel = l10n.seasonSpring;
        break;
      case 'SUMMER':
        seasonLabel = l10n.seasonSummer;
        break;
      case 'FALL':
        seasonLabel = l10n.seasonFall;
        break;
    }
    if (seasonLabel != null && year != null) return '$seasonLabel $year';
    if (year != null && year > 0) return '$year';
    return null;
  }
}
