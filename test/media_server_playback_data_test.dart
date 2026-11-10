import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/media_servers/models/media_server_config.dart';
import 'package:aniting/core/media_servers/models/media_server_item.dart';
import 'package:aniting/core/media_servers/models/media_server_type.dart';
import 'package:aniting/core/media_servers/services/media_server_playback_data.dart';

MediaServerConfig _plex() => MediaServerConfig(
  id: 'server-1',
  name: 'Plex',
  type: MediaServerType.plex,
  url: 'http://192.168.1.10:32400',
  token: 'token',
  createdAt: DateTime(2026),
);

MediaServerItem _episode({
  required String id,
  required int season,
  required int number,
  String? title,
  String? overview,
  int? durationMs,
  String? airDate,
  int? positionMs,
  double? rating,
  String? streamUrl,
}) {
  return MediaServerItem(
    id: id,
    serverId: 'server-1',
    title: title ?? 'Episode $number',
    type: MediaServerItemType.episode,
    parentTitle: 'Season $season',
    grandParentTitle: 'Frieren: Beyond Journey\'s End',
    grandParentId: 'show-1',
    seasonNumber: season,
    episodeNumber: number,
    overview: overview,
    airDate: airDate,
    durationMs: durationMs,
    playbackPositionMs: positionMs,
    rating: rating,
    streamUrl: streamUrl,
  );
}

void main() {
  group('MediaServerPlaybackData', () {
    test('uses the series title, not the Plex season title', () async {
      final current = _episode(id: 'ep-1', season: 1, number: 1);

      final data = await buildMediaServerPlaybackData(
        item: current,
        server: _plex(),
        showEpisodes: [current],
      );

      expect(data.title, 'Frieren: Beyond Journey\'s End');
      expect(data.details.title, 'Frieren: Beyond Journey\'s End');
    });

    test('keeps a single season and sorts its episodes', () async {
      final first = _episode(id: 'ep-1', season: 1, number: 1);
      final second = _episode(id: 'ep-2', season: 1, number: 2);
      final third = _episode(id: 'ep-3', season: 1, number: 3);
      final otherSeason = _episode(id: 'ep-9', season: 2, number: 1);

      final data = await buildMediaServerPlaybackData(
        item: second,
        server: _plex(),
        showEpisodes: [third, first, otherSeason, second],
      );

      expect(data.details.episodes.map((e) => e.episodeNumber), [1, 2, 3]);
      expect(data.episodes.map((e) => e.number), [1, 2, 3]);
      expect(
        data.episodes.map((e) => e.sourceId),
        ['ep-1', 'ep-2', 'ep-3'],
      );
    });

    test('maps synopsis, runtime, rating and air date for the watch page',
        () async {
      final current = _episode(
        id: 'ep-1',
        season: 1,
        number: 1,
        title: 'The Journey Begins',
        overview: 'Frieren starts her journey.',
        durationMs: 24 * 60 * 1000,
        airDate: '2023-09-29',
        positionMs: 90 * 1000,
        rating: 8.6,
      );

      final data = await buildMediaServerPlaybackData(
        item: current,
        server: _plex(),
        showEpisodes: [current],
      );

      final aniZipEpisode = data.aniZip.getEpisode(1)!;
      expect(aniZipEpisode.displayTitle, 'The Journey Begins');
      expect(aniZipEpisode.synopsis, 'Frieren starts her journey.');
      expect(aniZipEpisode.runtime, 24);
      expect(aniZipEpisode.formattedDuration, '24 min');
      expect(aniZipEpisode.airDate, '2023-09-29');
      expect(aniZipEpisode.rating, '8.6');

      // Episode rail card data.
      expect(data.details.episodes.single.title, 'The Journey Begins');
      expect(
        data.details.episodes.single.description,
        'Frieren starts her journey.',
      );

      // Resume position travels with the direct episode.
      expect(data.episodes.single.startPosition, const Duration(seconds: 90));
    });

    test('a movie gets the movie format so no episode rail is built', () async {
      final movie = MediaServerItem(
        id: 'movie-1',
        serverId: 'server-1',
        title: 'A Silent Voice',
        type: MediaServerItemType.movie,
        overview: 'A story about redemption.',
        durationMs: 130 * 60 * 1000,
        streamUrl: 'http://plex/library/parts/1/file',
      );

      final data = await buildMediaServerPlaybackData(
        item: movie,
        server: _plex(),
      );

      expect(data.details.format, 'MOVIE');
      expect(data.details.title, 'A Silent Voice');
      expect(data.details.totalEpisodes, 1);
      expect(data.details.description, 'A story about redemption.');
      expect(data.episodes, isEmpty);
    });

    test('keeps the episode being played when the server omits it', () async {
      final other = _episode(id: 'ep-2', season: 1, number: 2);
      final playing = _episode(id: 'ep-5', season: 1, number: 5);

      final prepared = prepareMediaServerEpisodes(playing, [other]);

      expect(prepared.map((e) => e.id), ['ep-2', 'ep-5']);
      expect(prepared.map((e) => e.episodeNumber), [2, 5]);
    });

    test('numbers episodes sequentially when the server reports none', () async {
      final noIndex = [
        MediaServerItem(
          id: 'a',
          serverId: 'server-1',
          title: 'First',
          type: MediaServerItemType.episode,
          seasonNumber: 1,
        ),
        MediaServerItem(
          id: 'b',
          serverId: 'server-1',
          title: 'Second',
          type: MediaServerItemType.episode,
          seasonNumber: 1,
        ),
      ];

      final prepared = prepareMediaServerEpisodes(noIndex.first, noIndex);

      expect(prepared.map((e) => e.episodeNumber), [1, 2]);
    });
  });
}
