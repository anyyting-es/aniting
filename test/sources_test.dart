import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/sources/sources.dart';

void main() {
  group('Native In-App Sources Tests', () {
    test('AnitingOnlineSource instantiates with correct default baseUrl', () {
      final source = AnitingOnlineSource();
      expect(AnitingOnlineSource.baseUrl, equals('https://aniting-api.algienrandomxdd.workers.dev'));
      expect(source, isNotNull);
    });

    test('AnimeToshoTorrentSource instantiates with correct baseUrl', () {
      final source = AnimeToshoTorrentSource();
      expect(AnimeToshoTorrentSource.baseUrl, equals('https://feed.animetosho.net'));
      expect(source, isNotNull);
    });

    test('MangaDexMangaSource instantiates with correct baseUrl', () {
      final source = MangaDexMangaSource();
      expect(MangaDexMangaSource.baseUrl, equals('https://api.mangadex.org'));
      expect(source, isNotNull);
    });

    test('TmdbShowsSource instantiates and exposes service', () {
      final source = TmdbShowsSource(apiKey: 'dummy_key');
      expect(source.service, isNotNull);
      expect(source.service.apiKey, equals('dummy_key'));
    });
  });
}
