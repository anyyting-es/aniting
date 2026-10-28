import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/episode_item.dart';
import 'package:seanime_app/presentation/widgets/episodes/episode_card.dart';

/// Right-side "Up next" episodes rail for the desktop player. Episodes only,
/// borderless and loosely spaced so it never feels boxed against the edges.
class PlayerEpisodesRail extends ConsumerWidget {
  final String animeTitle;
  final int? mediaId;
  final List<AnimeEpisode> episodes;
  final AniZipData? aniZipData;
  final int? currentEpisodeNumber;
  final bool isMovie;
  final ValueChanged<int> onSelectEpisode;

  const PlayerEpisodesRail({
    super.key,
    required this.animeTitle,
    this.mediaId,
    required this.episodes,
    this.aniZipData,
    this.currentEpisodeNumber,
    this.isMovie = false,
    required this.onSelectEpisode,
  });

  EpisodeItem _toItem(AnimeEpisode ep) {
    final aniZip = aniZipData;
    return EpisodeItem.fromAniZip(
      ep.episodeNumber,
      aniZip?.getEpisode(ep.episodeNumber),
      fallbackTitle: ep.title,
      fallbackImage: ep.image,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
          child: Row(
            children: [
              Icon(AppIcons.tv(iconPack), size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.episodes} (${episodes.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: (isMovie || episodes.isEmpty)
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isMovie ? animeTitle : l10n.noEpisodesFound,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 24),
                  itemCount: episodes.length,
                  itemBuilder: (context, index) {
                    final ep = episodes[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: EpisodeCard(
                        mediaId: mediaId,
                        episode: _toItem(ep),
                        fallbackImageUrl: ep.image,
                        isGridView: false,
                        listThumbnailWidth: 176,
                        isActive: ep.episodeNumber == currentEpisodeNumber,
                        onTap: () => onSelectEpisode(ep.episodeNumber),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
