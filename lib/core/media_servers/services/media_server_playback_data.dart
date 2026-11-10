import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/presentation/widgets/player/models/player_direct_episode.dart';
import '../models/media_server_config.dart';
import '../models/media_server_item.dart';
import '../models/media_server_type.dart';
import 'jellyfin_service.dart';
import 'plex_service.dart';

/// Everything the player needs to render a video that comes straight from a
/// Plex / Jellyfin library.
///
/// Media servers are not part of AniList, so their metadata is translated into
/// the same [AnimeDetails] / [AniZipData] shapes the watch page already renders
/// for anime. That keeps the whole player UI (series title, episode heading,
/// synopsis, duration, air date, episode rail) identical across sources.
class MediaServerPlaybackData {
  /// Series title shown in the player header.
  final String title;

  final AnimeDetails details;
  final AniZipData aniZip;

  /// Episodes the player can switch to without resolving anything online.
  final List<PlayerDirectEpisode> episodes;

  /// Items indexed by their server id, used to report progress for whichever
  /// episode is playing when the user leaves.
  final Map<String, MediaServerItem> itemsById;

  const MediaServerPlaybackData({
    required this.title,
    required this.details,
    required this.aniZip,
    required this.episodes,
    required this.itemsById,
  });
}

/// Resolves the metadata and the playable episode list for [item].
///
/// [showEpisodes] is optional: the detail screens already have the list loaded,
/// while continue-watching / library cards let it be fetched here so the player
/// still gets its episode rail.
Future<MediaServerPlaybackData> buildMediaServerPlaybackData({
  required MediaServerItem item,
  required MediaServerConfig server,
  MediaServerItem? show,
  List<MediaServerItem>? showEpisodes,
}) async {
  final isEpisode = item.type == MediaServerItemType.episode;

  List<MediaServerItem> episodes = const [];
  if (isEpisode) {
    final provided = showEpisodes ?? const <MediaServerItem>[];
    episodes = provided.isNotEmpty
        ? prepareMediaServerEpisodes(item, provided)
        : prepareMediaServerEpisodes(
            item,
            await _loadEpisodes(server, item),
          );
  }

  final title = resolveMediaServerShowTitle(item, show, isEpisode);
  final metadata = buildMediaServerPlayerMetadata(
    item: item,
    show: show,
    showTitle: title,
    episodes: episodes,
    isEpisode: isEpisode,
  );

  return MediaServerPlaybackData(
    title: title,
    details: metadata.details,
    aniZip: metadata.aniZip,
    episodes: [
      for (final ep in episodes)
        PlayerDirectEpisode(
          number: ep.episodeNumber ?? 1,
          title: ep.title,
          streamUrl: mediaServerStreamUrl(ep, server),
          sourceId: ep.id,
          startPosition: Duration(milliseconds: ep.playbackPositionMs ?? 0),
        ),
    ],
    itemsById: {
      for (final ep in episodes) ep.id: ep,
      item.id: item,
    },
  );
}

/// Plex exposes the season in `parentTitle` and the series in
/// `grandparentTitle`; Jellyfin puts the series in `parentTitle`. Picking the
/// wrong one showed "Season 1" as the video title.
String resolveMediaServerShowTitle(
  MediaServerItem item,
  MediaServerItem? show,
  bool isEpisode,
) {
  if (!isEpisode) return show?.title ?? item.title;
  final title =
      show?.title ?? item.grandParentTitle ?? item.parentTitle ?? item.title;
  final trimmed = title.trim();
  return trimmed.isEmpty ? item.title : trimmed;
}

/// Builds the AniList-shaped models the watch page renders.
({AnimeDetails details, AniZipData aniZip}) buildMediaServerPlayerMetadata({
  required MediaServerItem item,
  required MediaServerItem? show,
  required String showTitle,
  required List<MediaServerItem> episodes,
  required bool isEpisode,
}) {
  final displayEpisodes = episodes.isEmpty ? [item] : episodes;
  final coverImage = show?.thumbUrl ?? item.thumbUrl;
  final bannerImage = show?.backdropUrl ?? item.backdropUrl;
  final overview = show?.overview ?? item.overview;

  final details = AnimeDetails(
    id: 0,
    title: showTitle,
    coverImage: coverImage,
    bannerImage: bannerImage,
    description: overview,
    totalEpisodes: displayEpisodes.length,
    genres: show?.genres ?? item.genres,
    format: isEpisode ? 'TV' : 'MOVIE',
    score: show?.rating ?? item.rating,
    seasonYear: show?.year ?? item.year,
    studio: show?.studio ?? item.studio,
    episodes: [
      for (final ep in displayEpisodes)
        AnimeEpisode(
          episodeNumber: ep.episodeNumber ?? 1,
          title: ep.title,
          description: ep.overview,
          image: ep.thumbUrl ?? coverImage,
        ),
    ],
  );

  final aniZip = AniZipData(
    titles: {'en': showTitle},
    episodeCount: displayEpisodes.length,
    episodes: [
      for (final ep in displayEpisodes)
        AniZipEpisode(
          episode: '${ep.episodeNumber ?? 1}',
          episodeNumber: ep.episodeNumber ?? 1,
          seasonNumber: ep.seasonNumber,
          titleMap: {if (ep.title.trim().isNotEmpty) 'en': ep.title},
          image: ep.thumbUrl ?? coverImage,
          airDate: ep.airDate,
          runtime: _runtimeMinutes(ep.durationMs),
          overview: ep.overview,
          rating: _ratingLabel(ep.rating),
          isSpecial: false,
        ),
    ],
  );

  return (details: details, aniZip: aniZip);
}

/// Keeps the player rail on one season (episode numbers must stay unique) and
/// guarantees the episode being played is part of the list.
List<MediaServerItem> prepareMediaServerEpisodes(
  MediaServerItem current,
  List<MediaServerItem> all,
) {
  if (all.isEmpty) return [current];

  var pool = all;
  final season = current.seasonNumber;
  if (season != null) {
    final sameSeason = all
        .where((ep) => (ep.seasonNumber ?? season) == season)
        .toList();
    if (sameSeason.isNotEmpty) pool = sameSeason;
  }

  pool = [...pool]
    ..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));

  // Some servers omit the episode index entirely; fall back to sequential
  // numbering so the rail and next/previous still work.
  if (!pool.any((ep) => (ep.episodeNumber ?? 0) > 0)) {
    pool = [
      for (var i = 0; i < pool.length; i++)
        pool[i].copyWith(episodeNumber: i + 1),
    ];
  }

  if (!pool.any((ep) => ep.id == current.id)) {
    pool = [...pool, current]
      ..sort((a, b) => (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));
  }

  return pool;
}

/// Direct-play URL for an item, falling back to the server's file endpoint.
String mediaServerStreamUrl(MediaServerItem item, MediaServerConfig server) {
  final url = item.streamUrl;
  if (url != null && url.isNotEmpty) return url;
  if (server.type == MediaServerType.plex) {
    return PlexService(server).buildStreamUrl('/library/parts/${item.id}/file');
  }
  return JellyfinService(server).buildStreamUrl(item.id);
}

Future<List<MediaServerItem>> _loadEpisodes(
  MediaServerConfig server,
  MediaServerItem item,
) async {
  final showId = item.grandParentId ?? item.parentId;
  if (showId == null || showId.isEmpty) return const [];
  // Keep the wait short: playback opens as soon as this resolves, and a slow
  // server must not make the play button feel unresponsive.
  const timeout = Duration(seconds: 3);
  try {
    if (server.type == MediaServerType.plex) {
      return await PlexService(server)
          .getShowEpisodes(showId)
          .timeout(timeout, onTimeout: () => const []);
    }
    return await JellyfinService(server)
        .getShowEpisodes(showId)
        .timeout(timeout, onTimeout: () => const []);
  } catch (_) {
    return const [];
  }
}

int? _runtimeMinutes(int? durationMs) {
  if (durationMs == null || durationMs <= 0) return null;
  final minutes = (durationMs / 60000).round();
  return minutes > 0 ? minutes : null;
}

String? _ratingLabel(double? rating) {
  if (rating == null || rating <= 0) return null;
  return rating.toStringAsFixed(1);
}
