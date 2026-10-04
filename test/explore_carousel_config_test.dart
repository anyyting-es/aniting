import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/explore_carousel_config.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart';

void main() {
  group('ExploreCarouselConfig Model & Notifier Tests', () {
    test('Parses explore carousel config JSON correctly', () {
      final jsonMap = {
        'version': 2,
        'updated_at': '2026-10-04T02:00:00Z',
        'items': [
          {
            'media_id': 195604,
            'title': 'Black Clover Season 2',
            'horizontal_background': 'https://image.tmdb.org/t/p/original/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg',
            'vertical_background': 'https://image.tmdb.org/t/p/original/hPz1086iC2NSPgs8PKtBplddpvs.jpg',
            'logo': 'https://image.tmdb.org/t/p/original/cs2UFTRhlinuZoqmI1QDuq6RH7R.png',
            'year': 2026,
            'format': 'TV',
            'score': 8.5,
            'genres': ['Action', 'Fantasy'],
          },
        ],
      };

      final config = ExploreCarouselConfig.fromJson(jsonMap);

      expect(config.version, 2);
      expect(config.updatedAt, '2026-10-04T02:00:00Z');
      expect(config.items.length, 1);

      final item = config.items.first;
      expect(item.mediaId, 195604);
      expect(item.title, 'Black Clover Season 2');
      expect(item.horizontalBackground, 'https://image.tmdb.org/t/p/original/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg');
      expect(item.verticalBackground, 'https://image.tmdb.org/t/p/original/hPz1086iC2NSPgs8PKtBplddpvs.jpg');
      expect(item.logo, 'https://image.tmdb.org/t/p/original/cs2UFTRhlinuZoqmI1QDuq6RH7R.png');
      expect(item.year, 2026);
      expect(item.format, 'TV');
      expect(item.score, 8.5);
      expect(item.genres, ['Action', 'Fantasy']);

      final serialized = config.toJson();
      expect(serialized['version'], 2);
      expect(serialized['items'], isA<List>());
    });

    test('ExploreCarouselNotifier fallback contains initial featured anime items', () {
      final notifier = ExploreCarouselNotifier();
      final config = notifier.build();

      expect(config.version, 3);
      expect(config.items.length, 5);

      final ids = config.items.map((e) => e.mediaId).toList();
      expect(ids, containsAll([195604, 195516, 189123, 213805, 178083]));

      final blackClover = config.items.firstWhere((e) => e.mediaId == 195604);
      expect(blackClover.logo, 'https://image.tmdb.org/t/p/w500/j9ZZ7WV5pwLLXbbebyGdMUxbqrc.png');

      // Verify all items have HQ TMDB background and logo
      for (final item in config.items) {
        expect(item.horizontalBackground, isNotNull);
        expect(item.horizontalBackground, startsWith('https://image.tmdb.org/'));
        expect(item.verticalBackground, isNotNull);
        expect(item.logo, isNotNull);
        expect(item.logo, endsWith('.png'));
      }
    });

    test('optimizeTmdbImageUrl downscales TMDB URLs correctly for desktop and mobile', () {
      const originalBackdrop = 'https://image.tmdb.org/t/p/original/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg';
      const originalLogo = 'https://image.tmdb.org/t/p/original/j9ZZ7WV5pwLLXbbebyGdMUxbqrc.png';

      expect(
        optimizeTmdbImageUrl(originalBackdrop, isDesktop: true, isLogo: false),
        'https://image.tmdb.org/t/p/w1280/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg',
      );
      expect(
        optimizeTmdbImageUrl(originalBackdrop, isDesktop: false, isLogo: false),
        'https://image.tmdb.org/t/p/w780/qu9epTZh29fGUkY7ZYc9PVsv0Ig.jpg',
      );
      expect(
        optimizeTmdbImageUrl(originalLogo, isDesktop: true, isLogo: true),
        'https://image.tmdb.org/t/p/w500/j9ZZ7WV5pwLLXbbebyGdMUxbqrc.png',
      );
      expect(
        optimizeTmdbImageUrl(originalLogo, isDesktop: false, isLogo: true),
        'https://image.tmdb.org/t/p/w500/j9ZZ7WV5pwLLXbbebyGdMUxbqrc.png',
      );
    });
  });
}
