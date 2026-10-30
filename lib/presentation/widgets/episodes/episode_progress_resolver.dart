import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/live_playback_progress_provider.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';

/// Resolves the progress fraction drawn on an episode card or compact tile.
///
/// Priority:
/// 1. The live playback value, but only while that exact episode is playing
///    (the persisted map is flushed every few seconds, so it lags behind).
/// 2. The locally persisted playback progress.
/// 3. The episode's own AniList/AniZip progress.
///
/// Returns `null` when there is nothing meaningful to show.
double? resolveEpisodeProgressFraction(
  WidgetRef ref, {
  required int? mediaId,
  required int episodeNumber,
  required double episodeProgress,
}) {
  if (mediaId == null) {
    return episodeProgress > 0 ? episodeProgress : null;
  }

  final liveFraction = ref.watch(
    livePlaybackProgressProvider.select((live) {
      if (live == null) return null;
      if (live.mediaId != mediaId) return null;
      if (live.episodeNumber != episodeNumber) return null;
      return live.fraction;
    }),
  );
  if (liveFraction != null) return liveFraction;

  final storedFraction = ref.watch(
    playbackProgressPreferencesProvider.select((map) {
      final direct = map['${mediaId}_$episodeNumber'];
      final mediaEntry = map[mediaId.toString()];
      final entry =
          direct ??
          (mediaEntry != null && mediaEntry.episodeNumber == episodeNumber
              ? mediaEntry
              : null);
      if (entry == null || entry.durationMs <= 0 || entry.positionMs <= 0) {
        return null;
      }
      return (entry.positionMs / entry.durationMs).clamp(0.0, 1.0);
    }),
  );

  if (storedFraction != null) return storedFraction;
  return episodeProgress > 0 ? episodeProgress : null;
}
