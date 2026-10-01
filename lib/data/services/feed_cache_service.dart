import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';

/// Top-level function for compute() — must be static/top-level
String _encodeJson(List<Map<String, dynamic>> data) => jsonEncode(data);

/// Servicio de caché ultrarrápido (RAM + SharedPreferences) para el feed y la biblioteca.
///
/// Proporciona acceso sincrónico (0ms) en memoria a los datos de la última sesión
/// para eliminar el Content Layout Shift (CLS) y soportar el patrón Stale-While-Revalidate (SWR).
class FeedCacheService {
  static FeedCacheService? _instance;
  static SharedPreferences? _cachedPrefs;

  static FeedCacheService get instance => _instance ??= FeedCacheService._();

  FeedCacheService._() {
    if (_cachedPrefs != null) {
      _preloadFromPrefs(_cachedPrefs!);
    }
  }

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
    if (_instance != null) {
      _instance!._preloadFromPrefs(prefs);
    }
  }

  // Cache keys
  static const String kCacheContinueWatchingAnime = 'feed_cache_cw_anime';
  static const String kCacheAnimeCollection = 'feed_cache_col_anime';
  static const String kCacheTrendingAnime = 'feed_cache_trending_anime';
  static const String kCachePopularAnime = 'feed_cache_popular_anime';
  static const String kCacheRecentAnime = 'feed_cache_recent_anime';
  static const String kCacheMissedSequels = 'feed_cache_missed_sequels';
  static const String kCacheRecommendations = 'feed_cache_recommendations';

  static const String kCacheContinueReadingManga = 'feed_cache_cr_manga';
  static const String kCacheMangaCollection = 'feed_cache_col_manga';
  static const String kCacheTrendingManga = 'feed_cache_trending_manga';
  static const String kCachePopularManga = 'feed_cache_popular_manga';
  static const String kCacheMangaRecommendations = 'feed_cache_manga_recommendations';

  static const String kCacheServerStatus = 'feed_cache_server_status';

  // RAM cache for synchronous 0ms lookups
  final Map<String, List<AnimeEntry>> _animeListsCache = {};
  final Map<String, List<MangaEntry>> _mangaListsCache = {};
  ServerStatus? _serverStatusCache;

  void _preloadFromPrefs(SharedPreferences prefs) {
    // 1. Preload Anime lists
    final animeKeys = [
      kCacheContinueWatchingAnime,
      kCacheAnimeCollection,
      kCacheTrendingAnime,
      kCachePopularAnime,
      kCacheRecentAnime,
      kCacheMissedSequels,
      kCacheRecommendations,
    ];
    for (final key in animeKeys) {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            _animeListsCache[key] = decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => AnimeEntry.fromJson(e))
                .toList();
          }
        } catch (e) {
          debugPrint('FeedCacheService: error preloading anime list $key: $e');
        }
      }
    }

    // 2. Preload Manga lists
    final mangaKeys = [
      kCacheContinueReadingManga,
      kCacheMangaCollection,
      kCacheTrendingManga,
      kCachePopularManga,
      kCacheMangaRecommendations,
    ];
    for (final key in mangaKeys) {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            _mangaListsCache[key] = decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => MangaEntry.fromJson(e))
                .toList();
          }
        } catch (e) {
          debugPrint('FeedCacheService: error preloading manga list $key: $e');
        }
      }
    }

    // 3. Preload ServerStatus
    final rawStatus = prefs.getString(kCacheServerStatus);
    if (rawStatus != null && rawStatus.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawStatus);
        if (decoded is Map<String, dynamic>) {
          _serverStatusCache = ServerStatus.fromJson(decoded);
        }
      } catch (e) {
        debugPrint('FeedCacheService: error preloading server status: $e');
      }
    }
  }

  // --- ANIME CACHE METHODS ---

  List<AnimeEntry> getAnimeList(String key) {
    if (_animeListsCache.containsKey(key)) {
      return UnmodifiableListView(_animeListsCache[key]!);
    }
    final prefs = _cachedPrefs;
    if (prefs != null) {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final list = decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => AnimeEntry.fromJson(e))
                .toList();
            _animeListsCache[key] = list;
            return UnmodifiableListView(list);
          }
        } catch (_) {}
      }
    }
    return [];
  }

  Future<void> saveAnimeList(String key, List<AnimeEntry> list) async {
    _animeListsCache[key] = List<AnimeEntry>.from(list);
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final listCopy = list.map((e) => e.toJson()).toList();
      final encoded = await compute(_encodeJson, listCopy);
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('FeedCacheService: error saving anime list $key: $e');
    }
  }

  // --- MANGA CACHE METHODS ---

  List<MangaEntry> getMangaList(String key) {
    if (_mangaListsCache.containsKey(key)) {
      return UnmodifiableListView(_mangaListsCache[key]!);
    }
    final prefs = _cachedPrefs;
    if (prefs != null) {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) {
            final list = decoded
                .whereType<Map<String, dynamic>>()
                .map((e) => MangaEntry.fromJson(e))
                .toList();
            _mangaListsCache[key] = list;
            return UnmodifiableListView(list);
          }
        } catch (_) {}
      }
    }
    return [];
  }

  Future<void> saveMangaList(String key, List<MangaEntry> list) async {
    _mangaListsCache[key] = List<MangaEntry>.from(list);
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final listCopy = list.map((e) => e.toJson()).toList();
      final encoded = await compute(_encodeJson, listCopy);
      await prefs.setString(key, encoded);
    } catch (e) {
      debugPrint('FeedCacheService: error saving manga list $key: $e');
    }
  }

  // --- SERVER STATUS CACHE METHODS ---

  ServerStatus? getServerStatus() {
    if (_serverStatusCache != null) return _serverStatusCache;
    final prefs = _cachedPrefs;
    if (prefs != null) {
      final raw = prefs.getString(kCacheServerStatus);
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _serverStatusCache = ServerStatus.fromJson(decoded);
            return _serverStatusCache;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> saveServerStatus(ServerStatus status) async {
    _serverStatusCache = status;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final encoded = jsonEncode(status.toJson());
      await prefs.setString(kCacheServerStatus, encoded);
    } catch (e) {
      debugPrint('FeedCacheService: error saving server status: $e');
    }
  }

  // --- ANIZIP PERSISTENT CACHE METHODS ---

  final Map<int, AniZipData> _aniZipMemoryCache = {};

  AniZipData? getAniZipData(int mediaId) {
    if (_aniZipMemoryCache.containsKey(mediaId)) {
      return _aniZipMemoryCache[mediaId];
    }
    final prefs = _cachedPrefs;
    if (prefs != null) {
      final raw = prefs.getString('feed_cache_anizip_$mediaId');
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            final data = AniZipData.fromJson(decoded);
            _aniZipMemoryCache[mediaId] = data;
            return data;
          }
        } catch (_) {}
      }
    }
    return null;
  }

  Future<void> saveAniZipRaw(int mediaId, Map<String, dynamic> rawJson) async {
    try {
      _aniZipMemoryCache[mediaId] = AniZipData.fromJson(rawJson);
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString('feed_cache_anizip_$mediaId', jsonEncode(rawJson));
    } catch (e) {
      debugPrint('FeedCacheService: error saving anizip cache for $mediaId: $e');
    }
  }

  // --- CLEAR CACHE METHODS ---

  Future<void> clearUserCache() async {
    _animeListsCache.remove(kCacheContinueWatchingAnime);
    _animeListsCache.remove(kCacheAnimeCollection);
    _animeListsCache.remove(kCacheMissedSequels);
    _animeListsCache.remove(kCacheRecommendations);

    _mangaListsCache.remove(kCacheContinueReadingManga);
    _mangaListsCache.remove(kCacheMangaCollection);

    _serverStatusCache = null;

    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      await prefs.remove(kCacheContinueWatchingAnime);
      await prefs.remove(kCacheAnimeCollection);
      await prefs.remove(kCacheMissedSequels);
      await prefs.remove(kCacheRecommendations);
      await prefs.remove(kCacheContinueReadingManga);
      await prefs.remove(kCacheMangaCollection);
      await prefs.remove(kCacheServerStatus);
    } catch (_) {}
  }

  Future<void> clearAll() async {
    _animeListsCache.clear();
    _mangaListsCache.clear();
    _serverStatusCache = null;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final allKeys = [
        kCacheContinueWatchingAnime,
        kCacheAnimeCollection,
        kCacheTrendingAnime,
        kCachePopularAnime,
        kCacheRecentAnime,
        kCacheMissedSequels,
        kCacheRecommendations,
        kCacheContinueReadingManga,
        kCacheMangaCollection,
        kCacheTrendingManga,
        kCachePopularManga,
        kCacheServerStatus,
      ];
      for (final key in allKeys) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }
}
