import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/services/custom_anime_assets_service.dart';

void main() {
  group('CustomAnimeAssetsService Tests', () {
    test('Resolves Mushoku Tensei Season 1 Part 1 assets correctly', () {
      final assets = CustomAnimeAssetsService.getAssets(108465);
      expect(assets, isNotNull);
      expect(assets!.background, 'https://image.tmdb.org/t/p/original/negH2GNeY3KQiUmtJG6pNuBAzdh.jpg');
      expect(assets.logo, 'https://image.tmdb.org/t/p/original/8hKunCjzL8jfiturHHZfRPfdaLA.png');
      expect(assets.poster, 'https://image.tmdb.org/t/p/original/4502U4n9cfgw33v0xTQMZhTDS6p.jpg');
    });

    test('Resolves Mushoku Tensei Season 1 Part 2 assets correctly', () {
      final assets = CustomAnimeAssetsService.getAssets(127720);
      expect(assets, isNotNull);
      expect(assets!.background, 'https://image.tmdb.org/t/p/original/pfgndj46RLPVJRWkUSCJBgLJ93w.jpg');
      expect(assets.logo, 'https://image.tmdb.org/t/p/original/8hKunCjzL8jfiturHHZfRPfdaLA.png');
      expect(assets.poster, 'https://image.tmdb.org/t/p/original/MfjgMCzSp8aMQUYx9RclrKDBgV.jpg');
    });

    test('Resolves Mushoku Tensei Season 2 Part 1 assets correctly', () {
      final assets = CustomAnimeAssetsService.getAssets(146065);
      expect(assets, isNotNull);
      expect(assets!.background, 'https://image.tmdb.org/t/p/original/iv4dQuKE0S6snnn7ntkhPvCKZJY.jpg');
      expect(assets.logo, 'https://image.tmdb.org/t/p/original/2CWGOURAkgYuYqCmmwmkobkQjoU.png');
      expect(assets.poster, 'https://image.tmdb.org/t/p/original/5k50YDXKun42iMsvB2rkorgvwis.jpg');
    });

    test('Resolves Mushoku Tensei Season 2 Part 2 assets correctly', () {
      final assets = CustomAnimeAssetsService.getAssets(166873);
      expect(assets, isNotNull);
      expect(assets!.background, 'https://image.tmdb.org/t/p/original/5PVrehtE1BXnUB2TscppKE59rCd.jpg');
      expect(assets.logo, 'https://image.tmdb.org/t/p/original/2CWGOURAkgYuYqCmmwmkobkQjoU.png');
      expect(assets.poster, 'https://image.tmdb.org/t/p/original/6bExf47OiO7jpFsln73IVy6j9TL.jpg');
    });

    test('Resolves Mushoku Tensei Season 3 Part 1 assets correctly', () {
      final assets = CustomAnimeAssetsService.getAssets(178789);
      expect(assets, isNotNull);
      expect(assets!.background, 'https://image.tmdb.org/t/p/original/dTKQR3ScNj14xiaktZnDQQ0W6vM.jpg');
      expect(assets.logo, 'https://image.tmdb.org/t/p/original/5Ab3kV6H7ZZKMxsxtu1bYTM7Qpu.png');
      expect(assets.poster, 'https://image.tmdb.org/t/p/original/6O4gnCiG1KE9bPXINrHiZbFQWU3.jpg');
    });

    test('Hot-reads assets directly from disk json for newly added show', () {
      final assets = CustomAnimeAssetsService.getAssets(14813);
      expect(assets, isNotNull);
      expect(assets!.background, contains('c5Zh0fYgbUtoJZZOtEW1x3Rz4OS.jpg'));
      expect(assets.logo, contains('6MBxb0bA85ugmGooZNVPMMclf70.png'));
    });

    test('Returns null for uncurated media ID and supports dynamic register', () {
      expect(CustomAnimeAssetsService.getAssets(99999999), isNull);
      expect(CustomAnimeAssetsService.hasAssets(99999999), isFalse);

      CustomAnimeAssetsService.register(
        mediaId: 99999999,
        background: 'https://example.com/bg.jpg',
        logo: 'https://example.com/logo.png',
      );

      expect(CustomAnimeAssetsService.hasAssets(99999999), isTrue);
      final registered = CustomAnimeAssetsService.getAssets(99999999);
      expect(registered!.background, 'https://example.com/bg.jpg');
      expect(registered.logo, 'https://example.com/logo.png');
    });
  });
}
