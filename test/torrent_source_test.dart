import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

void main() {
  group('Torrent online sources', () {
    test('parses magnet sources with info hash and file index', () {
      final source = OnlinestreamVideoSource.fromJson({
        'server': 'Torrentio',
        'url': 'magnet:?xt=urn:btih:ABC123',
        'type': 'torrent',
        'label': 'Episode.01.1080p.mkv',
        'quality': '1080p',
        'infoHash': 'ABC123',
        'fileIndex': 4,
        'subtitles': const [],
      });

      expect(source.isTorrent, isTrue);
      expect(source.isHls, isFalse);
      expect(source.infoHash, 'ABC123');
      expect(source.fileIndex, 4);
    });

    test('detects magnet URLs even without an explicit type', () {
      final source = OnlinestreamVideoSource.fromJson({
        'server': 'Torrentio',
        'url': 'magnet:?xt=urn:btih:ABC123',
        'quality': '1080p',
      });

      expect(source.isTorrent, isTrue);
    });

    test('HTTP sources are not treated as torrents', () {
      final source = OnlinestreamVideoSource.fromJson({
        'server': 'VidSrc',
        'url': 'https://example.com/master.m3u8',
        'type': 'm3u8',
        'quality': '1080p',
      });

      expect(source.isTorrent, isFalse);
      expect(source.isHls, isTrue);
    });
  });

  group('TMDB IMDb id', () {
    test('reads external_ids.imdb_id for series', () {
      final details = TmdbShowDetails.fromJson({
        'id': 1399,
        'name': 'Game of Thrones',
        'original_name': 'Game of Thrones',
        'external_ids': {'imdb_id': 'tt0944947'},
      });

      expect(details.imdbId, 'tt0944947');
      expect(details.toAnimeDetails().rawMedia?['imdbId'], 'tt0944947');
    });

    test('reads top-level imdb_id for movies', () {
      final details = TmdbShowDetails.fromJson({
        'id': 27205,
        'title': 'Inception',
        'imdb_id': 'tt1375666',
      }, isMovie: true);

      expect(details.imdbId, 'tt1375666');
    });
  });
}
