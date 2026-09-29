import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TitleLanguage & displayTitle Tests', () {
    final testDetails = AnimeDetails(
      id: 154587,
      title: 'Frieren: Beyond Journey\'s End',
      romajiTitle: 'Sousou no Frieren',
      englishTitle: 'Frieren: Beyond Journey\'s End',
      nativeTitle: '葬送のフリーレン',
      description: 'Elf mage Frieren begins a journey.',
      bannerImage: null,
      coverImage: 'https://example.com/cover.jpg',
      totalEpisodes: 28,
      status: 'FINISHED',
      format: 'TV',
      season: 'FALL',
      seasonYear: 2023,
      genres: ['Adventure', 'Drama', 'Fantasy'],
      score: 93.0,
    );

    final testEntry = AnimeEntry(
      id: 1,
      mediaId: 154587,
      title: 'Sousou no Frieren',
      romajiTitle: 'Sousou no Frieren',
      englishTitle: 'Frieren: Beyond Journey\'s End',
      nativeTitle: '葬送のフリーレン',
      coverImage: 'https://example.com/cover.jpg',
      bannerImage: null,
      progress: 5,
      totalEpisodes: 28,
      format: 'TV',
      status: 'CURRENT',
      score: 93.0,
    );

    test('AnimeDetails.displayTitle respects language preference', () {
      expect(testDetails.displayTitle(TitleLanguage.romaji), 'Sousou no Frieren');
      expect(testDetails.displayTitle(TitleLanguage.english), 'Frieren: Beyond Journey\'s End');
      expect(testDetails.displayTitle(TitleLanguage.native), '葬送のフリーレン');
    });

    test('AnimeEntry.displayTitle respects language preference', () {
      expect(testEntry.displayTitle(TitleLanguage.romaji), 'Sousou no Frieren');
      expect(testEntry.displayTitle(TitleLanguage.english), 'Frieren: Beyond Journey\'s End');
      expect(testEntry.displayTitle(TitleLanguage.native), '葬送のフリーレン');
    });

    test('Falls back gracefully when selected language is missing', () {
      final incompleteDetails = AnimeDetails(
        id: 1,
        title: 'Original Title',
        romajiTitle: null,
        englishTitle: null,
        nativeTitle: '鬼滅の刃',
        description: 'Demon slayer',
        coverImage: '',
      );

      // Romaji requested but missing -> falls back to native
      expect(incompleteDetails.displayTitle(TitleLanguage.romaji), '鬼滅の刃');
      // English requested but missing -> falls back to native
      expect(incompleteDetails.displayTitle(TitleLanguage.english), '鬼滅 de la espada' != '鬼滅の刃' ? '鬼滅の刃' : '鬼滅の刃');
      // Native exists
      expect(incompleteDetails.displayTitle(TitleLanguage.native), '鬼滅の刃');
    });

    test('copyWithAniZipData hydrates missing titles from AniZip', () {
      final blankDetails = AnimeDetails(
        id: 1,
        title: 'Sin título',
        romajiTitle: null,
        englishTitle: null,
        nativeTitle: null,
        description: 'Test',
        coverImage: '',
      );

      final anizip = AniZipData.fromJson({
        'titles': {
          'ja': '進撃の巨人',
          'en': 'Attack on Titan',
          'x-jat': 'Shingeki no Kyojin',
        },
        'episodes': {},
      });

      final hydrated = blankDetails.copyWithAniZipData(anizip);

      expect(hydrated.displayTitle(TitleLanguage.romaji), 'Shingeki no Kyojin');
      expect(hydrated.displayTitle(TitleLanguage.english), 'Attack on Titan');
      expect(hydrated.displayTitle(TitleLanguage.native), '進撃の巨人');
    });

    test('TitleLanguageProvider loads and updates preference', () async {
      SharedPreferences.setMockInitialValues({'user_title_language': 'english'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read to instantiate
      container.read(titleLanguageProvider);
      // Wait for async _load to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify loaded state
      expect(container.read(titleLanguageProvider), TitleLanguage.english);

      // Change state
      await container.read(titleLanguageProvider.notifier).setLanguage(TitleLanguage.native);
      expect(container.read(titleLanguageProvider), TitleLanguage.native);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_title_language'), 'native');
    });
  });
}
