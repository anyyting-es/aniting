import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    OfflineLibraryService.setCachedPrefs(prefs);
    OfflineLibraryService.instance.clearMemoryForTesting();
  });

  group('OfflineLibraryService Tests', () {
    test('Records anime watch and builds continue watching and collection automatically', () async {
      final service = OfflineLibraryService.instance;

      expect(service.getAnimeCollection(), isEmpty);
      expect(service.getContinueWatching(), isEmpty);

      // 1. User starts watching Frieren Ep 1
      await service.recordAnimeWatch(
        mediaId: 154587,
        title: 'Sousou no Frieren',
        episodeNumber: 1,
        episodeTitle: 'The End of the Journey',
        coverImage: 'https://example.com/frieren.jpg',
        totalEpisodes: 28,
        genres: ['Adventure', 'Drama', 'Fantasy'],
        score: 9.3,
      );

      final col = service.getAnimeCollection();
      expect(col.length, 1);
      expect(col.first.mediaId, 154587);
      expect(col.first.title, 'Sousou no Frieren');
      expect(col.first.status, 'CURRENT');
      expect(col.first.progress, 0);

      final cw = service.getContinueWatching();
      expect(cw.length, 1);
      expect(cw.first.mediaId, 154587);
      expect(cw.first.currentEpisode, 1);

      // 2. User completes Episode 1 (e.g. 80% watched sync)
      await service.updateAnimeProgress(
        mediaId: 154587,
        episodeNumber: 1,
        totalEpisodes: 28,
      );

      final cwUpdated = service.getContinueWatching();
      expect(cwUpdated.length, 1);
      expect(cwUpdated.first.progress, 1);
      expect(cwUpdated.first.currentEpisode, 2);

      // 3. User finishes all 28 episodes
      await service.updateAnimeProgress(
        mediaId: 154587,
        episodeNumber: 28,
        totalEpisodes: 28,
      );

      // Should no longer appear in Continue Watching, but remain in Completed collection
      expect(service.getContinueWatching(), isEmpty);
      final completedCol = service.getAnimeCollection();
      expect(completedCol.length, 1);
      expect(completedCol.first.status, 'COMPLETED');
    });

    test('Records manga read and builds continue reading and collection automatically', () async {
      final service = OfflineLibraryService.instance;

      expect(service.getMangaCollection(), isEmpty);
      expect(service.getContinueReading(), isEmpty);

      // 1. User reads Berserk Chapter 1
      await service.recordMangaRead(
        mediaId: 30002,
        title: 'Berserk',
        chapterNumber: 1.0,
        chapterTitle: 'The Black Swordsman',
        coverImage: 'https://example.com/berserk.jpg',
        totalChapters: 364,
      );

      final col = service.getMangaCollection();
      expect(col.length, 1);
      expect(col.first.mediaId, 30002);
      expect(col.first.title, 'Berserk');
      expect(col.first.status, 'CURRENT');

      final cr = service.getContinueReading();
      expect(cr.length, 1);
      expect(cr.first.mediaId, 30002);
    });

    test('Edits and deletes entries offline', () async {
      final service = OfflineLibraryService.instance;

      await service.saveAnimeEntryFromEdit(
        mediaId: 99999,
        title: 'Test Offline Anime',
        status: 'CURRENT',
        score: 8.5,
        progress: 3,
        totalCount: 12,
      );

      expect(service.getAnimeCollection().length, 1);
      expect(service.getAnimeCollection().first.progress, 3);
      expect(service.getAnimeCollection().first.score, 8.5);

      await service.deleteAnimeEntry(99999);
      expect(service.getAnimeCollection(), isEmpty);
    });
  });
}
