import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/data/services/offline_sync_service.dart';

class MockSeanimeRepository extends Fake implements SeanimeRepository {
  bool shouldSucceed = true;
  final List<Map<String, dynamic>> updatedAnime = [];
  final List<Map<String, dynamic>> updatedManga = [];
  final List<Map<String, dynamic>> editedEntries = [];

  @override
  Future<bool> updateAnimeProgress({
    required int mediaId,
    required int episodeNumber,
    int? totalEpisodes,
  }) async {
    if (!shouldSucceed) return false;
    updatedAnime.add({
      'mediaId': mediaId,
      'episodeNumber': episodeNumber,
      'totalEpisodes': totalEpisodes,
    });
    return true;
  }

  @override
  Future<bool> updateMangaProgress({
    required int mediaId,
    required int chapterNumber,
    int? totalChapters,
  }) async {
    if (!shouldSucceed) return false;
    updatedManga.add({
      'mediaId': mediaId,
      'chapterNumber': chapterNumber,
      'totalChapters': totalChapters,
    });
    return true;
  }

  @override
  Future<bool> editAnilistListEntry({
    required int mediaId,
    required String type,
    String? status,
    int? score,
    int? progress,
    Map<String, int>? startedAt,
    Map<String, int>? completedAt,
  }) async {
    if (!shouldSucceed) return false;
    editedEntries.add({
      'mediaId': mediaId,
      'type': type,
      'status': status,
      'score': score,
      'progress': progress,
    });
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineSyncService Tests', () {
    late OfflineSyncService syncService;
    late MockSeanimeRepository mockRepo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      OfflineSyncService.setCachedPrefs(prefs);
      syncService = OfflineSyncService.instance;
      // Clear queue
      syncService.pendingItems.clear();
      mockRepo = MockSeanimeRepository();
      syncService.attachRepository(mockRepo);
    });

    test('Enqueues anime progress and collapses to highest progress', () async {
      mockRepo.shouldSucceed = false; // User is offline

      await syncService.enqueueAnimeProgress(
        mediaId: 101,
        episodeNumber: 3,
        totalEpisodes: 12,
        title: 'Frieren',
      );

      expect(syncService.pendingCount, 1);
      expect(syncService.pendingCountNotifier.value, 1);
      expect(syncService.pendingItems.first.progress, 3);

      // User watches episode 5 offline
      await syncService.enqueueAnimeProgress(
        mediaId: 101,
        episodeNumber: 5,
        totalEpisodes: 12,
        title: 'Frieren',
      );

      // Should still be 1 item, but progress updated to 5
      expect(syncService.pendingCount, 1);
      expect(syncService.pendingItems.first.progress, 5);
    });

    test('Enqueues manga progress and collapses to highest chapter', () async {
      mockRepo.shouldSucceed = false; // User is offline

      await syncService.enqueueMangaProgress(
        mediaId: 202,
        chapterNumber: 12.0,
        totalChapters: 50,
        title: 'Dandadan',
      );

      expect(syncService.pendingCount, 1);
      expect(syncService.pendingItems.first.progress, 12);

      // User reads chapter 14 offline
      await syncService.enqueueMangaProgress(
        mediaId: 202,
        chapterNumber: 14.0,
        totalChapters: 50,
        title: 'Dandadan',
      );

      expect(syncService.pendingCount, 1);
      expect(syncService.pendingItems.first.progress, 14);
    });

    test('Persists pending queue to SharedPreferences', () async {
      mockRepo.shouldSucceed = false; // User is offline

      await syncService.enqueueAnimeProgress(
        mediaId: 303,
        episodeNumber: 1,
        totalEpisodes: 24,
      );

      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('offline_pending_sync_queue_v1');
      expect(raw, isNotNull);
      expect(raw!.contains('anime_303'), isTrue);
    });

    test('Successfully syncs pending queue when online and clears items', () async {
      mockRepo.shouldSucceed = false; // First enqueue while offline

      await syncService.enqueueAnimeProgress(
        mediaId: 404,
        episodeNumber: 8,
        totalEpisodes: 12,
      );
      await syncService.enqueueMangaProgress(
        mediaId: 505,
        chapterNumber: 22.0,
        totalChapters: 100,
      );

      expect(syncService.pendingCount, 2);

      // Connection restored!
      await Future.delayed(const Duration(milliseconds: 50));
      mockRepo.shouldSucceed = true;

      int callbackCount = 0;
      syncService.onSyncCompleted = (count) {
        callbackCount = count;
      };

      final synced = await syncService.syncPending(repository: mockRepo);

      expect(synced, 2);
      expect(callbackCount, 2);
      expect(syncService.pendingCount, 0);
      expect(syncService.pendingCountNotifier.value, 0);
      expect(mockRepo.updatedAnime.length, 1);
      expect(mockRepo.updatedAnime.first['episodeNumber'], 8);
      expect(mockRepo.updatedManga.length, 1);
      expect(mockRepo.updatedManga.first['chapterNumber'], 22);
    });

    test('Does not clear queue when sync fails (offline state)', () async {
      mockRepo.shouldSucceed = false; // Simulate offline

      await syncService.enqueueAnimeProgress(
        mediaId: 606,
        episodeNumber: 4,
        totalEpisodes: 12,
      );

      final synced = await syncService.syncPending(repository: mockRepo);

      expect(synced, 0);
      expect(syncService.pendingCount, 1);
      expect(syncService.pendingCountNotifier.value, 1);
    });
  });
}
