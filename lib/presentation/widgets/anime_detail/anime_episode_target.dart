/// Single source of truth for "which episode comes next" on the anime detail
/// screen.
///
/// The action bar ("Continuar EP n") and the episodes list used to compute this
/// independently — the list preferred the locally persisted playback position
/// while the button used the tracked progress — so they could point at
/// different episodes. Both now go through these functions.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Incremented when the player closes.
///
/// The episode carousel listens to this to re-align the resume episode to the
/// left edge even if the target number itself did not change (for example when
/// the user scrolled the list away before pressing "Continue").
class EpisodeResumeAlignmentNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void request() => state++;
}

final episodeResumeAlignmentProvider =
    NotifierProvider<EpisodeResumeAlignmentNotifier, int>(
      EpisodeResumeAlignmentNotifier.new,
    );

/// The episode the user should watch next, based only on the authoritative
/// progress for the active source.
///
/// [progress] is whatever the screen already resolved as authoritative: the
/// AniList entry when the show is tracked there, the offline/local entry
/// otherwise.
int resolveNextEpisodeNumber({
  required int progress,
  int? totalEpisodes,
  String? userStatus,
}) {
  final total = totalEpisodes ?? 0;
  final isCompleted =
      (userStatus?.toUpperCase() == 'COMPLETED') ||
      (total > 0 && progress >= total);

  // A completed show offers the first episode again (rewatch).
  if (isCompleted) return 1;

  var next = progress + 1;
  if (next < 1) next = 1;
  if (total > 0 && next > total) next = total;
  return next;
}

/// Same target as [resolveNextEpisodeNumber], snapped to an episode that
/// actually exists in [episodeNumbers] (lists can start above 1 with absolute
/// numbering, and specials are filtered out).
///
/// The in-progress playback position is honoured **only** when it points at that
/// same episode, i.e. the user is literally in the middle of it. Anything else
/// (e.g. a local position left behind on episode 12 while AniList says 10) is
/// stale and must not override the source of truth.
int resolveTargetEpisodeNumber({
  required List<int> episodeNumbers,
  required int progress,
  int? totalEpisodes,
  String? userStatus,
  int? playbackEpisodeNumber,
  int playbackPositionMs = 0,
  int playbackDurationMs = 0,
}) {
  if (episodeNumbers.isEmpty) return 1;

  final next = resolveNextEpisodeNumber(
    progress: progress,
    totalEpisodes: totalEpisodes,
    userStatus: userStatus,
  );

  var target = next;
  final isMidNextEpisode =
      playbackEpisodeNumber != null &&
      playbackEpisodeNumber == next &&
      playbackDurationMs > 0 &&
      playbackPositionMs > 0 &&
      (playbackPositionMs / playbackDurationMs) > 0.02 &&
      (playbackPositionMs / playbackDurationMs) < 0.95;

  if (isMidNextEpisode) target = playbackEpisodeNumber;

  if (episodeNumbers.contains(target)) return target;
  for (final number in episodeNumbers) {
    if (number >= target) return number;
  }
  return episodeNumbers.last;
}
