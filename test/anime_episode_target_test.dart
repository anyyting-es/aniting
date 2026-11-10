import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_episode_target.dart';

void main() {
  group('resolveNextEpisodeNumber', () {
    test('first episode on a fresh show', () {
      expect(resolveNextEpisodeNumber(progress: 0, totalEpisodes: 24), 1);
    });

    test('advances with tracked progress', () {
      expect(resolveNextEpisodeNumber(progress: 1, totalEpisodes: 24), 2);
      expect(resolveNextEpisodeNumber(progress: 10, totalEpisodes: 24), 11);
    });

    test('never goes past the last episode', () {
      expect(resolveNextEpisodeNumber(progress: 23, totalEpisodes: 24), 24);
    });

    test('completed shows offer the first episode again', () {
      expect(
        resolveNextEpisodeNumber(
          progress: 24,
          totalEpisodes: 24,
          userStatus: 'COMPLETED',
        ),
        1,
      );
      expect(
        resolveNextEpisodeNumber(
          progress: 23,
          totalEpisodes: 24,
          userStatus: 'current',
        ),
        24,
      );
      // progress == total is treated as completed even if the status says
      // otherwise, matching the tracked-entry behaviour.
      expect(
        resolveNextEpisodeNumber(
          progress: 24,
          totalEpisodes: 24,
          userStatus: 'current',
        ),
        1,
      );
    });

    test('works without a known total', () {
      expect(resolveNextEpisodeNumber(progress: 5), 6);
    });
  });

  group('resolveTargetEpisodeNumber', () {
    final episodes = [for (var i = 1; i <= 12; i++) i];

    test('follows the tracked progress, ignoring stale local playback', () {
      // The reported bug: AniList says 10 watched (button "Continuar EP 11"),
      // but the local playback map still points at episode 12.
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: episodes,
        progress: 10,
        totalEpisodes: 12,
        playbackEpisodeNumber: 12,
        playbackPositionMs: 40 * 60 * 1000,
        playbackDurationMs: 100 * 60 * 1000,
      );
      expect(target, 11);
    });

    test('keeps the next episode when the user is mid-episode', () {
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: episodes,
        progress: 10,
        totalEpisodes: 12,
        playbackEpisodeNumber: 11,
        playbackPositionMs: 20 * 60 * 1000,
        playbackDurationMs: 100 * 60 * 1000,
      );
      expect(target, 11);
    });

    test('ignores an almost finished next episode', () {
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: episodes,
        progress: 10,
        totalEpisodes: 12,
        playbackEpisodeNumber: 11,
        playbackPositionMs: 99 * 60 * 1000,
        playbackDurationMs: 100 * 60 * 1000,
      );
      expect(target, 11);
    });

    test('snaps to the first available episode with absolute numbering', () {
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: const [13, 14, 15, 16],
        progress: 0,
        totalEpisodes: 16,
      );
      expect(target, 13);
    });

    test('snaps forward when the exact episode is missing', () {
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: const [1, 2, 4, 5],
        progress: 2,
      );
      expect(target, 4);
    });

    test('falls back to the last episode when progress overflows', () {
      final target = resolveTargetEpisodeNumber(
        episodeNumbers: const [1, 2, 3],
        progress: 99,
      );
      expect(target, 3);
    });

    test('empty list is safe', () {
      expect(
        resolveTargetEpisodeNumber(episodeNumbers: const [], progress: 3),
        1,
      );
    });
  });
}
