import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import '../models/media_server_config.dart';
import '../models/media_server_item.dart';
import '../models/media_server_type.dart';
import 'jellyfin_service.dart';
import 'media_server_playback_data.dart';
import 'plex_service.dart';

/// Launches the player for items hosted on a Plex / Jellyfin media server.
///
/// The metadata and the playable episode list are built by
/// [buildMediaServerPlaybackData], so the watch page behaves like it does for
/// any other source (series title, episode synopsis, duration, air date and the
/// right-hand episode rail), while comments and streaming-source options stay
/// hidden because there is nothing to resolve online.
class MediaServerPlayerHelper {
  /// Opens and plays an item directly from its server.
  ///
  /// [show] and [showEpisodes] are optional: the detail screens already have
  /// them loaded. When they are missing (continue watching, library cards) the
  /// episodes are fetched once so the player can still show its episode rail.
  static Future<void> playDirect({
    required BuildContext context,
    required MediaServerItem item,
    required MediaServerConfig server,
    MediaServerItem? show,
    List<MediaServerItem>? showEpisodes,
  }) async {
    final isEpisode = item.type == MediaServerItemType.episode;
    final playback = await buildMediaServerPlaybackData(
      item: item,
      server: server,
      show: show,
      showEpisodes: showEpisodes,
    );

    // Notify Jellyfin playback start.
    if (server.type == MediaServerType.jellyfin) {
      JellyfinService(server).reportPlaybackStart(item.id);
    }

    final startPosition =
        (item.playbackPositionMs != null && item.playbackPositionMs! > 0)
        ? Duration(milliseconds: item.playbackPositionMs!)
        : null;

    if (!context.mounted) return;

    Navigator.of(context).push(
      VideoPlayerScreen.route(
        videoUrl: mediaServerStreamUrl(item, server),
        title: playback.title,
        episodeTitle: isEpisode ? item.title : null,
        episodeNumber: item.episodeNumber,
        startPosition: startPosition,
        resolvedLoadingLogoUrl: show?.logoUrl,
        resolvedLoadingBannerUrl:
            show?.backdropUrl ?? item.backdropUrl ?? item.thumbUrl,
        animeDetails: playback.details,
        aniZipData: playback.aniZip,
        directEpisodes: playback.episodes.isEmpty ? null : playback.episodes,
        isMediaServerMedia: true,
        hideComments: true,
        onPlaybackStopped: (sourceId, position, duration) {
          final playing = playback.itemsById[sourceId] ?? item;
          final durationMs = duration.inMilliseconds > 0
              ? duration.inMilliseconds
              : (playing.durationMs ?? 0);

          if (server.type == MediaServerType.plex) {
            PlexService(server).reportTimeline(
              ratingKey: playing.id,
              state: 'stopped',
              timeMs: position.inMilliseconds,
              durationMs: durationMs,
            );
          } else {
            JellyfinService(
              server,
            ).reportPlaybackStopped(playing.id, position.inMilliseconds);
          }
        },
      ),
    );
  }
}
