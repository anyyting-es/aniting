import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TMDB session continuity', () {
    test('LastSessionItem persists the TMDB playback context', () {
      const item = LastSessionItem(
        mediaType: 'ANIME',
        mediaId: 1399,
        title: 'Game of Thrones',
        isTmdb: true,
        tmdbMediaType: 'tv',
        tmdbSeason: 2,
        tmdbEnglishTitle: 'Game of Thrones',
        tmdbYear: 2011,
        updatedAt: 123,
      );

      final restored = LastSessionItem.fromJson(item.toJson());

      expect(restored.isTmdb, isTrue);
      expect(restored.tmdbMediaType, 'tv');
      expect(restored.tmdbSeason, 2);
      expect(restored.tmdbEnglishTitle, 'Game of Thrones');
      expect(restored.tmdbYear, 2011);
    });

    test('LastSessionItem reads old sessions without TMDB fields', () {
      final restored = LastSessionItem.fromJson({
        'mediaType': 'ANIME',
        'mediaId': 21,
        'title': 'Cowboy Bebop',
        'isTmdb': false,
        'updatedAt': 1,
      });

      expect(restored.isTmdb, isFalse);
      expect(restored.tmdbMediaType, isNull);
      expect(restored.tmdbSeason, isNull);
    });
  });

  group('TMDB section activation', () {
    test('Shows are enabled by default on a fresh install', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      ShowsSectionEnabledNotifier.setCachedPrefs(prefs);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(showsSectionEnabledProvider), isTrue);
    });

    test('An explicit disabled preference is respected', () async {
      SharedPreferences.setMockInitialValues({'shows_section_enabled': false});
      final prefs = await SharedPreferences.getInstance();
      ShowsSectionEnabledNotifier.setCachedPrefs(prefs);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(showsSectionEnabledProvider), isFalse);
    });
  });
}
