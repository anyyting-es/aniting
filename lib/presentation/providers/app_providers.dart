import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/core/preferences/download_preferences_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/data/services/manga_offline_service.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/core/api/websocket_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final serverManagerProvider = Provider<ServerManager>((ref) {
  final client = ref.watch(apiClientProvider);
  return ServerManager(client);
});

final repositoryProvider = Provider<SeanimeRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return SeanimeRepository(client);
});

/// Servicio WebSocket singleton — se conecta cuando el servidor está online.
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final ws = WebSocketService();
  ref.onDispose(() => ws.dispose());
  return ws;
});

class ServerStateModel {
  final ServerState state;
  final ServerStatus? status;
  final String? errorMessage;

  const ServerStateModel({
    required this.state,
    this.status,
    this.errorMessage,
  });

  bool get isOnline => state == ServerState.running || state == ServerState.remote;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerStateModel &&
          runtimeType == other.runtimeType &&
          state == other.state &&
          status == other.status &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(state, status, errorMessage);
}

class ServerNotifier extends Notifier<ServerStateModel> {
  ServerManager get _manager => ref.read(serverManagerProvider);
  SeanimeRepository get _repo => ref.read(repositoryProvider);

  @override
  ServerStateModel build() {
    final cachedStatus = FeedCacheService.instance.getServerStatus();
    Future.microtask(() => initAndAutoStart());
    return ServerStateModel(state: ServerState.starting, status: cachedStatus);
  }

  Future<void> initAndAutoStart() async {
    final cachedStatus = FeedCacheService.instance.getServerStatus();
    state = ServerStateModel(state: ServerState.starting, status: cachedStatus);

    // 1. Check if server is already running
    final isAlive = await _manager.checkHealth();
    if (isAlive) {
      final info = await _repo.getStatus();
      if (info != null) {
        FeedCacheService.instance.saveServerStatus(info);
      }
      state = ServerStateModel(state: _manager.state, status: info ?? cachedStatus);
      _connectWebSocket();
      _repo.ensureOnlineStreamingEnabled();
      _repo.ensureTorrentStreamingEnabled();
      return;
    }

    // 2. Not running: auto-start local server
    final started = await _manager.startLocalServer();
    if (started) {
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (await _manager.checkHealth()) {
          final info = await _repo.getStatus();
          if (info != null) {
            FeedCacheService.instance.saveServerStatus(info);
          }
          state = ServerStateModel(state: ServerState.running, status: info ?? cachedStatus);
          _connectWebSocket();
          _repo.ensureOnlineStreamingEnabled();
          _repo.ensureTorrentStreamingEnabled();
          return;
        }
      }
    }

    state = ServerStateModel(
      state: ServerState.stopped,
      errorMessage: _manager.lastError ?? 'No se pudo conectar al servidor',
    );
  }

  Future<void> checkConnection({String? host, int? port}) async {
    final cachedStatus = FeedCacheService.instance.getServerStatus();
    state = ServerStateModel(state: ServerState.starting, status: cachedStatus);
    final isAlive = await _manager.checkHealth(host: host, port: port);
    if (isAlive) {
      final info = await _repo.getStatus();
      if (info != null) {
        FeedCacheService.instance.saveServerStatus(info);
      }
      state = ServerStateModel(state: _manager.state, status: info ?? cachedStatus);
      _connectWebSocket();
      _repo.ensureOnlineStreamingEnabled();
      _repo.ensureTorrentStreamingEnabled();
    } else {
      state = ServerStateModel(
        state: ServerState.stopped,
        errorMessage: _manager.lastError ?? 'Servidor no detectado',
      );
    }
  }

  Future<void> startLocal() async {
    await initAndAutoStart();
  }

  Future<void> stopServer() async {
    ref.read(webSocketServiceProvider).disconnect();
    await _manager.stopServer();
    state = const ServerStateModel(state: ServerState.stopped);
  }

  /// Conecta el WebSocket al servidor para recibir eventos en tiempo real.
  void _connectWebSocket() {
    final ws = ref.read(webSocketServiceProvider);
    ws.connect(host: _manager.host, port: _manager.port);
  }

  Future<bool> loginWithAnilist(String token) async {
    try {
      final updatedStatus = await _repo.loginWithAnilistToken(token);
      if (updatedStatus != null) {
        await FeedCacheService.instance.saveServerStatus(updatedStatus);
        await _repo.refreshAnilistCollection();
        state = ServerStateModel(state: _manager.state, status: updatedStatus);
        return true;
      }
    } catch (e) {
      debugPrint('Login failed: $e');
      rethrow;
    }
    return false;
  }

  Future<void> logoutAnilist() async {
    try {
      final updatedStatus = await _repo.logoutFromAnilist();
      await FeedCacheService.instance.clearUserCache();
      state = ServerStateModel(state: _manager.state, status: updatedStatus);
    } catch (e) {
      debugPrint('Logout failed: $e');
    }
  }
}

final serverNotifierProvider =
    NotifierProvider<ServerNotifier, ServerStateModel>(ServerNotifier.new);

// ─── SWR & CACHE HELPERS ───

Future<List<AnimeEntry>> loadAnimeWithCacheAndSwr({
  required Ref ref,
  required String cacheKey,
  required Future<List<AnimeEntry>> Function() fetchFresh,
  bool requireAuth = false,
}) async {
  final cache = FeedCacheService.instance;
  final cached = cache.getAnimeList(cacheKey);
  final serverState = ref.watch(serverNotifierProvider);

  if (!serverState.isOnline) {
    if (cached.isNotEmpty) return cached;
    if (serverState.state == ServerState.starting) {
      final completer = Completer<void>();
      final sub = ref.listen<ServerStateModel>(serverNotifierProvider, (prev, next) {
        if (next.state != ServerState.starting && !completer.isCompleted) {
          completer.complete();
        }
      });
      ref.onDispose(() => sub.close());
      await completer.future;
      final currentState = ref.read(serverNotifierProvider);
      if (!currentState.isOnline) return [];
    } else {
      return [];
    }
  }

  final isLoggedIn = serverState.status?.isLoggedIn ?? false;
  if (requireAuth && !isLoggedIn) {
    return [];
  }

  try {
    final fresh = await fetchFresh();
    if (fresh.isNotEmpty || (requireAuth && isLoggedIn)) {
      await cache.saveAnimeList(cacheKey, fresh);
    }
    return fresh;
  } catch (e) {
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
}

Future<List<MangaEntry>> loadMangaWithCacheAndSwr({
  required Ref ref,
  required String cacheKey,
  required Future<List<MangaEntry>> Function() fetchFresh,
  bool requireAuth = false,
}) async {
  final cache = FeedCacheService.instance;
  final cached = cache.getMangaList(cacheKey);
  final serverState = ref.watch(serverNotifierProvider);

  if (!serverState.isOnline) {
    if (cached.isNotEmpty) return cached;
    if (serverState.state == ServerState.starting) {
      final completer = Completer<void>();
      final sub = ref.listen<ServerStateModel>(serverNotifierProvider, (prev, next) {
        if (next.state != ServerState.starting && !completer.isCompleted) {
          completer.complete();
        }
      });
      ref.onDispose(() => sub.close());
      await completer.future;
      final currentState = ref.read(serverNotifierProvider);
      if (!currentState.isOnline) return [];
    } else {
      return [];
    }
  }

  final isLoggedIn = serverState.status?.isLoggedIn ?? false;
  if (requireAuth && !isLoggedIn) {
    return [];
  }

  try {
    final fresh = await fetchFresh();
    if (fresh.isNotEmpty || (requireAuth && isLoggedIn)) {
      await cache.saveMangaList(cacheKey, fresh);
    }
    return fresh;
  } catch (e) {
    if (cached.isNotEmpty) return cached;
    rethrow;
  }
}

// ─── ANIME PROVIDERS ───

final animeCollectionProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheAnimeCollection,
    requireAuth: true,
    fetchFresh: () => ref.read(repositoryProvider).getLibraryCollection(),
  );
});

final aniZipDataProvider = FutureProvider.family<AniZipData?, int>((ref, mediaId) async {
  if (mediaId <= 0) return null;
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return null;
  return ref.watch(repositoryProvider).getAniZipData(mediaId);
});

final continueWatchingProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheContinueWatchingAnime,
    requireAuth: true,
    fetchFresh: () => ref.read(repositoryProvider).getContinueWatching(),
  );
});

final trendingAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheTrendingAnime,
    fetchFresh: () => ref.read(repositoryProvider).getTrendingAnime(),
  );
});

final popularAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCachePopularAnime,
    fetchFresh: () => ref.read(repositoryProvider).getPopularAnime(),
  );
});

final recentAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheRecentAnime,
    fetchFresh: () => ref.read(repositoryProvider).getRecentAiringAnime(),
  );
});

final missedSequelsProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheMissedSequels,
    requireAuth: true,
    fetchFresh: () => ref.read(repositoryProvider).getMissedSequels(),
  );
});

final recommendationsProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  return loadAnimeWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheRecommendations,
    requireAuth: true,
    fetchFresh: () async {
      final collection = await ref.read(animeCollectionProvider.future);
      if (collection.isEmpty) return [];

      final watchingOrCompleted = collection
          .where((e) => e.status == 'CURRENT' || e.status == 'WATCHING' || e.status == 'COMPLETED')
          .toList();

      if (watchingOrCompleted.isEmpty) return [];

      final allUserMediaIds = collection.map((e) => e.mediaId).toSet();
      final sampleMediaIds = watchingOrCompleted.take(4).map((e) => e.mediaId).toList();

      return ref.read(repositoryProvider).getRecommendationsForUser(
        mediaIds: sampleMediaIds,
        excludeMediaIds: allUserMediaIds,
      );
    },
  );
});

// ─── MANGA PROVIDERS ───

final mangaCollectionProvider = FutureProvider<List<MangaEntry>>((ref) async {
  return loadMangaWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheMangaCollection,
    requireAuth: true,
    fetchFresh: () => ref.read(repositoryProvider).getMangaCollection(),
  );
});

final continueReadingMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  return loadMangaWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheContinueReadingManga,
    requireAuth: true,
    fetchFresh: () => ref.read(repositoryProvider).getContinueReadingManga(),
  );
});

final trendingMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  return loadMangaWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheTrendingManga,
    fetchFresh: () => ref.read(repositoryProvider).getTrendingManga(),
  );
});

final popularMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  return loadMangaWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCachePopularManga,
    fetchFresh: () => ref.read(repositoryProvider).getPopularManga(),
  );
});

final mangaRecommendationsProvider = FutureProvider<List<MangaEntry>>((ref) async {
  return loadMangaWithCacheAndSwr(
    ref: ref,
    cacheKey: FeedCacheService.kCacheMangaRecommendations,
    requireAuth: true,
    fetchFresh: () async {
      final collection = await ref.read(mangaCollectionProvider.future);
      if (collection.isEmpty) return [];

      final readingOrCompleted = collection
          .where((e) =>
              e.status.toUpperCase() == 'CURRENT' ||
              e.status.toUpperCase() == 'READING' ||
              e.status.toUpperCase() == 'COMPLETED')
          .toList();

      if (readingOrCompleted.isEmpty) return [];

      final allUserMediaIds = collection.map((e) => e.mediaId).toSet();
      final sampleMediaIds =
          readingOrCompleted.take(4).map((e) => e.mediaId).toList();

      return ref.read(repositoryProvider).getMangaRecommendationsForUser(
        mediaIds: sampleMediaIds,
        excludeMediaIds: allUserMediaIds,
      );
    },
  );
});

final mangaProvidersListProvider = FutureProvider<List<MangaProvider>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.watch(repositoryProvider).getMangaProviders();
});

// ─── EXPLORE & CURATED PROVIDERS ───

final curatedRomanceAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getAnimeByGenre(genre: 'Romance', sort: 'POPULARITY_DESC', perPage: 12);
});

final curatedActionAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getAnimeByGenre(genre: 'Action', sort: 'POPULARITY_DESC', perPage: 12);
});

final curatedFantasyAnimeProvider = FutureProvider<List<AnimeEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getAnimeByGenre(genre: 'Fantasy', sort: 'POPULARITY_DESC', perPage: 12);
});

final curatedRomanceMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getMangaByGenre(genre: 'Romance', sort: 'POPULARITY_DESC', perPage: 12);
});

final curatedActionMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getMangaByGenre(genre: 'Action', sort: 'POPULARITY_DESC', perPage: 12);
});

final curatedFantasyMangaProvider = FutureProvider<List<MangaEntry>>((ref) async {
  final serverState = ref.watch(serverNotifierProvider);
  if (!serverState.isOnline) return [];
  return ref.read(repositoryProvider).getMangaByGenre(genre: 'Fantasy', sort: 'POPULARITY_DESC', perPage: 12);
});

// ─── OFFLINE MANGA PROVIDERS ─────────────────────────────────────────────────

final mangaOfflineServiceProvider = Provider<MangaOfflineService>((ref) {
  return MangaOfflineService();
});

/// Obras con capítulos descargados disponibles en disco (offline) o servidor Go
final downloadedMangaListProvider = FutureProvider<List<MangaEntry>>((ref) async {
  final service = ref.watch(mangaOfflineServiceProvider);
  final downloadPrefs = ref.watch(downloadPreferencesProvider);
  final repo = ref.watch(repositoryProvider);
  final serverState = ref.watch(serverNotifierProvider);

  final results = <MangaEntry>[];
  final mediaIds = <int>{};

  // 1. Obtener descargas gestionadas por el servidor Go (si está online)
  if (serverState.isOnline) {
    try {
      final serverDownloads = await repo.getMangaDownloadsList();
      for (final raw in serverDownloads) {
        if (raw is Map<String, dynamic>) {
          final mediaId = raw['mediaId'] as int? ?? 0;
          if (mediaId <= 0) continue;

          int downloadedCount = 0;
          final downloadData = raw['downloadData'];
          if (downloadData is Map<String, dynamic>) {
            for (final list in downloadData.values) {
              if (list is List) downloadedCount += list.length;
            }
          }

          // Solo incluir si tiene al menos 1 capítulo descargado
          if (downloadedCount == 0) continue;

          final media = raw['media'] as Map<String, dynamic>?;
          final titleMap = media?['title'] as Map<String, dynamic>?;
          final title = titleMap?['userPreferred'] as String? ??
              titleMap?['romaji'] as String? ??
              titleMap?['english'] as String? ??
              'Manga $mediaId';

          final coverMap = media?['coverImage'] as Map<String, dynamic>?;
          final coverImage = coverMap?['large'] as String? ?? coverMap?['extraLarge'] as String?;
          final bannerImage = media?['bannerImage'] as String?;

          results.add(MangaEntry(
            id: mediaId,
            mediaId: mediaId,
            title: title,
            coverImage: coverImage,
            bannerImage: bannerImage,
            progress: 0,
            status: 'DOWNLOADED',
            isDownloaded: true,
            downloadedChaptersCount: downloadedCount,
          ));
          mediaIds.add(mediaId);
        }
      }
    } catch (e) {
      debugPrint('Error getting server manga downloads list: $e');
    }
  }

  // 2. Obtener descargas locales en disco (offline service)
  try {
    final localList = await service.getDownloadedMangaList(customBase: downloadPrefs.customBasePath);
    for (final local in localList) {
      // Solo agregar si tiene capítulos descargados y no está ya en la lista
      if (local.downloadedChaptersCount > 0 && !mediaIds.contains(local.mediaId)) {
        results.add(local);
        mediaIds.add(local.mediaId);
      }
    }
  } catch (e) {
    debugPrint('Error getting local manga downloads list: $e');
  }

  results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  return results;
});

/// Capítulos descargados para una obra específica (mediaId)
final downloadedMangaChaptersProvider =
    FutureProvider.family<List<DownloadedChapterInfo>, int>((ref, mediaId) async {
  final service = ref.watch(mangaOfflineServiceProvider);
  final downloadPrefs = ref.watch(downloadPreferencesProvider);
  return service.getDownloadedChapters(mediaId, customBase: downloadPrefs.customBasePath);
});

/// Resuelve la imagen del personaje principal (MC) de la obra para la barra de sesión activa
final sessionMcImageProvider =
    FutureProvider.family<String?, ({int mediaId, bool isAnime})>((ref, arg) async {
  if (arg.mediaId <= 0) return null;
  final repo = ref.watch(repositoryProvider);
  try {
    if (arg.isAnime) {
      final details = await repo.getAnimeDetails(arg.mediaId).catchError((_) => null);
      final mc = details?.mainCharacterImage;
      if (mc != null && mc.isNotEmpty) return mc;
      return details?.coverImage;
    } else {
      final cached = FeedCacheService.instance.getMangaList(FeedCacheService.kCacheMangaCollection);
      for (final entry in cached) {
        if (entry.mediaId == arg.mediaId) {
          return entry.coverImage;
        }
      }
      return null;
    }
  } catch (_) {
    return null;
  }
});

