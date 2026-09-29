import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/feed_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FeedCacheService & Serialization Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('AnimeEntry toJson and fromJson preserve all critical fields for Feed', () {
      final original = AnimeEntry(
        id: 42,
        mediaId: 101,
        title: 'Sousou no Frieren',
        romajiTitle: 'Sousou no Frieren',
        englishTitle: 'Frieren: Beyond Journey\'s End',
        nativeTitle: '葬送のフリーレン',
        coverImage: 'https://example.com/cover.jpg',
        coverColor: '#e4a054',
        bannerImage: 'https://example.com/banner.jpg',
        progress: 15,
        totalEpisodes: 28,
        status: 'CURRENT',
        score: 9.3,
        format: 'TV',
        description: 'An adventure ends...',
        genres: ['Adventure', 'Drama', 'Fantasy'],
        currentEpisode: 16,
        episodeNumber: 16,
        episodeTitle: 'Long Lived',
        episodeThumbnail: 'https://example.com/ep16.jpg',
        updatedAt: 1700000000000,
        airDate: '2024-01-05',
        lastWatchedTime: 1700500000000,
        nextAiringEpisodeNumber: 17,
        nextAiringEpisodeAiringAt: 1701000000,
        year: 2023,
      );

      final json = original.toJson();
      final parsed = AnimeEntry.fromJson(json);

      expect(parsed.id, original.id);
      expect(parsed.mediaId, original.mediaId);
      expect(parsed.title, original.title);
      expect(parsed.englishTitle, original.englishTitle);
      expect(parsed.romajiTitle, original.romajiTitle);
      expect(parsed.nativeTitle, original.nativeTitle);
      expect(parsed.coverImage, original.coverImage);
      expect(parsed.coverColor, original.coverColor);
      expect(parsed.bannerImage, original.bannerImage);
      expect(parsed.progress, original.progress);
      expect(parsed.totalEpisodes, original.totalEpisodes);
      expect(parsed.status, original.status);
      expect(parsed.score, original.score);
      expect(parsed.episodeNumber, original.episodeNumber);
      expect(parsed.episodeTitle, original.episodeTitle);
      expect(parsed.episodeThumbnail, original.episodeThumbnail);
      expect(parsed.airDate, original.airDate);
      expect(parsed.lastWatchedTime, original.lastWatchedTime);
      expect(parsed.year, original.year);
    });

    test('FeedCacheService stores and retrieves Anime list synchronously from RAM and asynchronously from SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      FeedCacheService.setCachedPrefs(prefs);
      final cache = FeedCacheService.instance;

      final testList = [
        AnimeEntry(
          id: 1,
          mediaId: 1001,
          title: 'Anime One',
          progress: 3,
          status: 'CURRENT',
          episodeNumber: 4,
          episodeTitle: 'The Journey Begins',
        ),
        AnimeEntry(
          id: 2,
          mediaId: 1002,
          title: 'Anime Two',
          progress: 10,
          status: 'CURRENT',
          episodeNumber: 11,
          episodeTitle: 'Battle Climax',
        ),
      ];

      // Save to cache
      await cache.saveAnimeList(FeedCacheService.kCacheContinueWatchingAnime, testList);

      // 1. Synchronous retrieval from RAM
      final ramList = cache.getAnimeList(FeedCacheService.kCacheContinueWatchingAnime);
      expect(ramList.length, 2);
      expect(ramList[0].title, 'Anime One');
      expect(ramList[1].episodeTitle, 'Battle Climax');

      // 2. Preload simulation in a fresh cache instance
      FeedCacheService.setCachedPrefs(prefs);
      final reloadedList = cache.getAnimeList(FeedCacheService.kCacheContinueWatchingAnime);
      expect(reloadedList.length, 2);
      expect(reloadedList[0].mediaId, 1001);
    });

    test('FeedCacheService stores and retrieves ServerStatus for instant isLoggedIn detection', () async {
      final prefs = await SharedPreferences.getInstance();
      FeedCacheService.setCachedPrefs(prefs);
      final cache = FeedCacheService.instance;

      final status = ServerStatus(
        version: '1.2.3',
        username: 'TestUser',
        avatarUrl: 'https://example.com/avatar.jpg',
        isSettingsConfigured: true,
      );

      await cache.saveServerStatus(status);

      final loaded = cache.getServerStatus();
      expect(loaded, isNotNull);
      expect(loaded!.username, 'TestUser');
      expect(loaded.isLoggedIn, isTrue);

      // Verify clearUserCache removes status and user lists
      await cache.clearUserCache();
      expect(cache.getServerStatus(), isNull);
      expect(cache.getAnimeList(FeedCacheService.kCacheContinueWatchingAnime), isEmpty);
    });

    test('FeedCacheService stores and retrieves Manga list correctly', () async {
      final prefs = await SharedPreferences.getInstance();
      FeedCacheService.setCachedPrefs(prefs);
      final cache = FeedCacheService.instance;

      final mangaList = [
        MangaEntry(
          id: 50,
          mediaId: 50,
          title: 'Chainsaw Man',
          progress: 100,
          status: 'CURRENT',
          currentChapter: 101,
          chapterTitle: 'Chapter 101',
        ),
      ];

      await cache.saveMangaList(FeedCacheService.kCacheContinueReadingManga, mangaList);
      final retrieved = cache.getMangaList(FeedCacheService.kCacheContinueReadingManga);

      expect(retrieved.length, 1);
      expect(retrieved[0].title, 'Chainsaw Man');
      expect(retrieved[0].currentChapter, 101);
    });

    testWidgets('FeedScreen renders cached continue watching immediately without CLS', (tester) async {
      final cachedEntry = AnimeEntry(
        id: 1,
        mediaId: 999,
        title: 'Cached Frieren',
        progress: 10,
        status: 'CURRENT',
        episodeNumber: 11,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(() => _MockServerNotifier(isOnline: true, isLoggedIn: true)),
            continueWatchingProvider.overrideWith((ref) => Future.value([cachedEntry])),
            animeCollectionProvider.overrideWith((ref) => Future.value([cachedEntry])),
            trendingAnimeProvider.overrideWith((ref) => Future.value([])),
            popularAnimeProvider.overrideWith((ref) => Future.value([])),
            recentAnimeProvider.overrideWith((ref) => Future.value([])),
            missedSequelsProvider.overrideWith((ref) => Future.value([])),
            recommendationsProvider.overrideWith((ref) => Future.value([])),
            aniZipDataProvider(999).overrideWith((ref) => null),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pump();

      // Cached content is displayed immediately without waiting in both Continue Watching and Currently Watching
      expect(find.text('Cached Frieren'), findsNWidgets(2));

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

class _MockServerNotifier extends ServerNotifier {
  final bool isOnline;
  final bool isLoggedIn;
  _MockServerNotifier({required this.isOnline, required this.isLoggedIn});

  @override
  ServerStateModel build() {
    return ServerStateModel(
      state: isOnline ? ServerState.running : ServerState.starting,
      status: isLoggedIn
          ? ServerStatus(username: 'TestUser', isSettingsConfigured: true)
          : null,
    );
  }
}

