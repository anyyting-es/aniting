import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/services/manga_offline_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempTestDir;

  setUp(() async {
    tempTestDir = await Directory.systemTemp.createTemp('seanime_downloader_test_');
  });

  tearDown(() async {
    if (await tempTestDir.exists()) {
      await tempTestDir.delete(recursive: true);
    }
  });

  group('MangaEntry Offline Serialization Tests', () {
    test('MangaEntry serializes to JSON and deserializes back faithfully', () {
      final entry = MangaEntry(
        id: 9999,
        mediaId: 9999,
        title: 'Chainsaw Man',
        romajiTitle: 'Chainsaw Man',
        englishTitle: 'Chainsaw Man',
        nativeTitle: 'チェンソーマン',
        coverImage: 'https://example.com/cover.jpg',
        bannerImage: 'https://example.com/banner.jpg',
        description: 'Denji has a simple dream...',
        format: 'MANGA',
        status: 'RELEASING',
        totalChapters: 180,
        genres: ['Action', 'Supernatural'],
        progress: 120,
        score: 9.5,
        year: 2018,
        localCoverPath: '/mock/path/cover.jpg',
        localBannerPath: '/mock/path/banner.jpg',
        isDownloaded: true,
        downloadedChaptersCount: 15,
      );

      final jsonMap = entry.toJson();
      expect(jsonMap['id'], 9999);
      expect(jsonMap['isDownloaded'], true);
      expect(jsonMap['downloadedChaptersCount'], 15);
      expect(jsonMap['localCoverPath'], '/mock/path/cover.jpg');

      final reconstructed = MangaEntry.fromJson(jsonMap);
      expect(reconstructed.id, 9999);
      expect(reconstructed.mediaId, 9999);
      expect(reconstructed.title, 'Chainsaw Man');
      expect(reconstructed.isDownloaded, true);
      expect(reconstructed.downloadedChaptersCount, 15);
      expect(reconstructed.localCoverPath, '/mock/path/cover.jpg');
      expect(reconstructed.localBannerPath, '/mock/path/banner.jpg');
      expect(reconstructed.genres, contains('Supernatural'));
      expect(reconstructed.progress, 120);
    });
  });

  group('AppStoragePaths Directory Structure Tests', () {
    test('Resolves proper Manga and Anime directories under customBase', () async {
      final base = tempTestDir.path;

      final mangaDir = await AppStoragePaths.getMangaDownloadsDirectory(customBase: base);
      expect(mangaDir.path, equals('$base/Manga'));
      expect(await mangaDir.exists(), isTrue);

      final animeDir = await AppStoragePaths.getAnimeDownloadsDirectory(customBase: base);
      expect(animeDir.path, equals('$base/Anime'));
      expect(await animeDir.exists(), isTrue);
    });

    test('Resolves series directory with slug or id fallback', () async {
      final base = tempTestDir.path;

      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(
        1001,
        slug: 'one-piece',
        customBase: base,
      );
      expect(seriesDir.path, equals('$base/Manga/1001_one-piece'));
      expect(await seriesDir.exists(), isTrue);

      final fallbackDir = await AppStoragePaths.getMangaSeriesDirectory(
        2002,
        customBase: base,
      );
      expect(fallbackDir.path, equals('$base/Manga/2002'));
      expect(await fallbackDir.exists(), isTrue);
    });

    test('getDefaultDownloadsBasePath resolves to Documents/Anime/aniting', () async {
      final defaultBasePath = await AppStoragePaths.getDefaultDownloadsBasePath();
      expect(defaultBasePath, contains('Anime/aniting'));
    });
  });

  group('MangaOfflineService Operations Tests', () {
    late MangaOfflineService service;

    setUp(() {
      service = MangaOfflineService();
    });

    test('formatBytes produces readable strings', () {
      expect(service.formatBytes(0), '0 B');
      expect(service.formatBytes(512), '512 B');
      expect(service.formatBytes(1024), '1.0 KB');
      expect(service.formatBytes(1048576), '1.0 MB');
      expect(service.formatBytes(1073741824), '1.0 GB');
    });

    test('Saves and reads back manga metadata.json', () async {
      final base = tempTestDir.path;
      final entry = MangaEntry(
        id: 54321,
        mediaId: 54321,
        title: 'Berserk',
        romajiTitle: 'Berserk',
        englishTitle: 'Berserk',
        description: 'Guts is a wanderer...',
        format: 'MANGA',
        status: 'RELEASING',
        totalChapters: 375,
        genres: ['Action', 'Fantasy', 'Horror'],
        progress: 100,
        score: 10.0,
      );

      await service.saveMangaMetadata(entry, customBase: base);

      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(54321, customBase: base);
      final metaFile = File('${seriesDir.path}/metadata.json');
      expect(await metaFile.exists(), isTrue);

      final retrieved = await service.getSavedMangaMetadata(54321, customBase: base);
      expect(retrieved, isNotNull);
      expect(retrieved!.mediaId, 54321);
      expect(retrieved.title, 'Berserk');
      expect(retrieved.genres, contains('Horror'));
    });

    test('Discovers downloaded chapters, reads registry.json and lists pages', () async {
      final base = tempTestDir.path;

      // 1. Crear metadata de serie
      final entry = MangaEntry(
        id: 777,
        mediaId: 777,
        title: 'Spy x Family',
        format: 'MANGA',
        status: 'RELEASING',
        progress: 0,
      );
      await service.saveMangaMetadata(entry, customBase: base);
      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(777, customBase: base);
      expect(await seriesDir.exists(), isTrue);

      // 2. Crear carpeta de capítulo con registry.json y 3 páginas simuladas
      final chapterDir = Directory('${seriesDir.path}/manga-dex_777_ch1_1');
      await chapterDir.create(recursive: true);

      final registry = {
        '1': {'index': 1, 'filename': '1.jpg', 'pageNumber': 1},
        '2': {'index': 2, 'filename': '2.jpg', 'pageNumber': 2},
        '3': {'index': 3, 'filename': '3.jpg', 'pageNumber': 3},
      };
      await File('${chapterDir.path}/registry.json').writeAsString(jsonEncode(registry));
      await File('${chapterDir.path}/1.jpg').writeAsString('page 1 mock image');
      await File('${chapterDir.path}/2.jpg').writeAsString('page 2 mock image');
      await File('${chapterDir.path}/3.jpg').writeAsString('page 3 mock image');

      // 3. Obtener lista de mangas descargados
      final downloadedList = await service.getDownloadedMangaList(customBase: base);
      expect(downloadedList.length, 1);
      expect(downloadedList.first.mediaId, 777);
      expect(downloadedList.first.isDownloaded, isTrue);
      expect(downloadedList.first.downloadedChaptersCount, 1);

      // 4. Obtener capítulos descargados
      final chapters = await service.getDownloadedChapters(777, customBase: base);
      expect(chapters.length, 1);
      expect(chapters.first.chapterId, 'ch1');
      expect(chapters.first.chapterNumber, '1');
      expect(chapters.first.provider, 'manga-dex');

      // 5. Cargar páginas del capítulo
      final pages = await service.getDownloadedChapterPages(
        mediaId: 777,
        provider: 'manga-dex',
        chapterId: 'ch1',
        customBase: base,
      );
      expect(pages.length, 3);
      expect(pages[0].index, 1);
      expect(pages[0].url.endsWith('1.jpg'), isTrue);
      expect(pages[1].index, 2);
      expect(pages[2].index, 3);

      // 6. Eliminar capítulo
      final deleted = await service.deleteDownloadedChapter(chapters.first);
      expect(deleted, isTrue);
      expect(await chapterDir.exists(), isFalse);

      final chaptersAfter = await service.getDownloadedChapters(777, customBase: base);
      expect(chaptersAfter, isEmpty);
    });
  });
}
