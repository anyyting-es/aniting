import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_chat_panel.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_chapters_strip.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_episode_header.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_synopsis_section.dart';

/// Scrollable YouTube-style content column rendered below the desktop player:
/// episode header, synopsis, chapters and comments. Playback source/audio/subtitle
/// selectors live on the page header line instead.
class PlayerWatchContent extends ConsumerWidget {
  final int? mediaId;
  final String animeTitle;
  final int? episodeNumber;
  final String? episodeTitle;
  final AnimeDetails? animeDetails;
  final AniZipData? aniZipData;

  final List<PlayerChapter> chapters;
  final PlayerChapter? activeChapter;
  final ValueChanged<Duration> onSeekToChapter;
  final Widget? headerTrailing;
  final ValueListenable<Duration>? positionNotifier;
  final Future<Uint8List?> Function()? captureFrame;

  const PlayerWatchContent({
    super.key,
    this.mediaId,
    required this.animeTitle,
    this.episodeNumber,
    this.episodeTitle,
    this.animeDetails,
    this.aniZipData,
    this.chapters = const [],
    this.activeChapter,
    required this.onSeekToChapter,
    this.headerTrailing,
    this.positionNotifier,
    this.captureFrame,
  });

  String _resolveSynopsis() {
    final episodes = animeDetails?.episodes ?? const <AnimeEpisode>[];
    final currentEpNum = episodeNumber ?? 1;
    final aniZip = aniZipData ?? animeDetails?.aniZipData;
    final currentAniZipEp = aniZip?.getEpisode(currentEpNum);

    final episodeSynopsis = currentAniZipEp?.synopsis ??
        (episodes.isNotEmpty
            ? episodes
                .cast<AnimeEpisode?>()
                .firstWhere(
                  (e) => e?.episodeNumber == currentEpNum,
                  orElse: () => null,
                )
                ?.description
            : null);

    if (episodeSynopsis != null && episodeSynopsis.trim().isNotEmpty) {
      return episodeSynopsis.trim();
    }
    return PlayerEpisodeHeader.cleanDescription(animeDetails?.description);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    final synopsis = _resolveSynopsis();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: PlayerEpisodeHeader(
                animeTitle: animeTitle,
                episodeNumber: episodeNumber,
                episodeTitle: episodeTitle,
                animeDetails: animeDetails,
                aniZipData: aniZipData,
              ),
            ),
            if (headerTrailing != null) ...[
              const SizedBox(width: 12),
              headerTrailing!,
            ],
          ],
        ),
        if (synopsis.isNotEmpty) ...[
          const SizedBox(height: 24),
          PlayerSynopsisSection(synopsis: synopsis),
        ],
        if (chapters.isNotEmpty) ...[
          const SizedBox(height: 28),
          PlayerChaptersStrip(
            chapters: chapters,
            activeChapter: activeChapter,
            onSeekToChapter: onSeekToChapter,
          ),
        ],
        const SizedBox(height: 36),
        Row(
          children: [
            Icon(AppIcons.chatBubble(iconPack), size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              l10n.comments,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PlayerChatPanel(
          mediaId: mediaId,
          episodeNumber: episodeNumber,
          embedded: true,
          positionNotifier: positionNotifier,
          captureFrame: captureFrame,
        ),
      ],
    );
  }
}
