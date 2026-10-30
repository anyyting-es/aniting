import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_episodes_rail.dart';

/// Presents the episode list in a modal sheet. Used by the desktop watch page
/// when the window is too narrow to host the side rail, reusing the same
/// [PlayerEpisodesRail] so the look and behaviour stay identical.
class PlayerEpisodesSheet extends StatelessWidget {
  final String animeTitle;
  final int? mediaId;
  final List<AnimeEpisode> episodes;
  final AniZipData? aniZipData;
  final int? currentEpisodeNumber;
  final bool isMovie;
  final ValueChanged<int> onSelectEpisode;

  const PlayerEpisodesSheet({
    super.key,
    required this.animeTitle,
    this.mediaId,
    required this.episodes,
    this.aniZipData,
    this.currentEpisodeNumber,
    this.isMovie = false,
    required this.onSelectEpisode,
  });

  static Future<void> show({
    required BuildContext context,
    required String animeTitle,
    int? mediaId,
    required List<AnimeEpisode> episodes,
    AniZipData? aniZipData,
    int? currentEpisodeNumber,
    bool isMovie = false,
    required ValueChanged<int> onSelectEpisode,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (ctx) => PlayerEpisodesSheet(
        animeTitle: animeTitle,
        mediaId: mediaId,
        episodes: episodes,
        aniZipData: aniZipData,
        currentEpisodeNumber: currentEpisodeNumber,
        isMovie: isMovie,
        onSelectEpisode: (n) {
          Navigator.of(ctx).pop();
          onSelectEpisode(n);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.of(context).size.height * 0.7;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
              child: PlayerEpisodesRail(
                animeTitle: animeTitle,
                mediaId: mediaId,
                episodes: episodes,
                aniZipData: aniZipData,
                currentEpisodeNumber: currentEpisodeNumber,
                isMovie: isMovie,
                onSelectEpisode: onSelectEpisode,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
