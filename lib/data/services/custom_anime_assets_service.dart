import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class CustomAnimeAssets {
  final String? background;
  final String? logo;
  final String? poster;

  const CustomAnimeAssets({
    this.background,
    this.logo,
    this.poster,
  });

  factory CustomAnimeAssets.fromJson(Map<String, dynamic> json) {
    String? normalizeUrl(dynamic raw) {
      if (raw == null) return null;
      final str = raw.toString().trim();
      if (str.isEmpty) return null;
      if (str.startsWith('http://') || str.startsWith('https://')) {
        return str;
      }
      final cleanPath = str.startsWith('/') ? str.substring(1) : str;
      return 'https://image.tmdb.org/t/p/original/$cleanPath';
    }

    return CustomAnimeAssets(
      background: normalizeUrl(json['background'] ?? json['b']),
      logo: normalizeUrl(json['logo'] ?? json['l']),
      poster: normalizeUrl(json['poster'] ?? json['p']),
    );
  }
}

/// Curated local database linking AniList Media ID -> Custom/Season-specific
/// assets (Background, Transparent Logo, Poster).
///
/// TMDB/AniZip frequently group multi-season anime into a single series entry,
/// producing identical/generic backdrops and logos for every cour. This service
/// supplies hand-picked, season-accurate artwork synchronously (frame 0) with
/// top priority over automated API lookups.
///
/// Features:
/// 1. Synchronous Frame-0 lookup via in-memory registry.
/// 2. Live hot-sync from disk in Desktop/Dev environments when Aniting-art saves.
/// 3. Offline-first local persistent caching in app support directory.
/// 4. Background remote sync from GitHub / Aniting-art companion server.
class CustomAnimeAssetsService {
  CustomAnimeAssetsService._();

  static const String remoteSyncUrl =
      'https://raw.githubusercontent.com/anyyting/aniting/main/assets/data/custom_anime_assets.json';

  static final Map<int, CustomAnimeAssets> _registry = {
    // ─── Mushoku Tensei: Isekai Ittara Honki Dasu ───
    108465: const CustomAnimeAssets(
      background: 'https://image.tmdb.org/t/p/original/negH2GNeY3KQiUmtJG6pNuBAzdh.jpg',
      logo: 'https://image.tmdb.org/t/p/original/8hKunCjzL8jfiturHHZfRPfdaLA.png',
      poster: 'https://image.tmdb.org/t/p/original/4502U4n9cfgw33v0xTQMZhTDS6p.jpg',
    ),
    127720: const CustomAnimeAssets(
      background: 'https://image.tmdb.org/t/p/original/pfgndj46RLPVJRWkUSCJBgLJ93w.jpg',
      logo: 'https://image.tmdb.org/t/p/original/8hKunCjzL8jfiturHHZfRPfdaLA.png',
      poster: 'https://image.tmdb.org/t/p/original/MfjgMCzSp8aMQUYx9RclrKDBgV.jpg',
    ),
    146065: const CustomAnimeAssets(
      background: 'https://image.tmdb.org/t/p/original/iv4dQuKE0S6snnn7ntkhPvCKZJY.jpg',
      logo: 'https://image.tmdb.org/t/p/original/2CWGOURAkgYuYqCmmwmkobkQjoU.png',
      poster: 'https://image.tmdb.org/t/p/original/5k50YDXKun42iMsvB2rkorgvwis.jpg',
    ),
    166873: const CustomAnimeAssets(
      background: 'https://image.tmdb.org/t/p/original/5PVrehtE1BXnUB2TscppKE59rCd.jpg',
      logo: 'https://image.tmdb.org/t/p/original/2CWGOURAkgYuYqCmmwmkobkQjoU.png',
      poster: 'https://image.tmdb.org/t/p/original/6bExf47OiO7jpFsln73IVy6j9TL.jpg',
    ),
    178789: const CustomAnimeAssets(
      background: 'https://image.tmdb.org/t/p/original/dTKQR3ScNj14xiaktZnDQQ0W6vM.jpg',
      logo: 'https://image.tmdb.org/t/p/original/5Ab3kV6H7ZZKMxsxtu1bYTM7Qpu.png',
      poster: 'https://image.tmdb.org/t/p/original/6O4gnCiG1KE9bPXINrHiZbFQWU3.jpg',
    ),
  };

  static bool _isLoading = false;
  static DateTime? _lastDiskModified;

  /// Loads pre-bundled assets, checks disk file, and triggers background sync
  static Future<void> init() async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      // 1. Hot read from disk file if available (Desktop / Dev)
      _checkDiskUpdatesSync();

      // 2. Load from root bundle assets
      try {
        final jsonStr = await rootBundle.loadString('assets/data/custom_anime_assets.json');
        _parseAndMerge(jsonStr);
      } catch (_) {}

      // 3. Check persistent cached file in app support directory
      await _loadFromLocalSupportCache();

      // 4. Background remote sync without blocking UI
      unawaited(_syncRemote());
    } finally {
      _isLoading = false;
    }
  }

  /// Returns custom assets registered for [mediaId] in O(1) time, or null if none.
  static CustomAnimeAssets? getAssets(int mediaId) {
    _checkDiskUpdatesSync();
    return _registry[mediaId];
  }

  /// Whether custom curated assets exist for [mediaId].
  static bool hasAssets(int mediaId) {
    _checkDiskUpdatesSync();
    return _registry.containsKey(mediaId);
  }

  /// Dynamically registers or updates assets for a given [mediaId].
  static void register({
    required int mediaId,
    String? background,
    String? logo,
    String? poster,
  }) {
    if (mediaId <= 0) return;
    _registry[mediaId] = CustomAnimeAssets.fromJson({
      'background': background,
      'logo': logo,
      'poster': poster,
    });
  }

  /// Synchronously checks if the JSON file on disk was modified (Desktop / Dev).
  /// This enables instant live updates from Aniting-art into the running app.
  static void _checkDiskUpdatesSync() {
    try {
      final file = File('assets/data/custom_anime_assets.json');
      if (file.existsSync()) {
        final mod = file.lastModifiedSync();
        if (_lastDiskModified == null || mod.isAfter(_lastDiskModified!)) {
          _lastDiskModified = mod;
          final str = file.readAsStringSync();
          _parseAndMerge(str);
        }
      }
    } catch (_) {}
  }

  /// Parses JSON string and merges entries into the in-memory registry.
  static void _parseAndMerge(String jsonStr) {
    try {
      final rawMap = jsonDecode(jsonStr);
      if (rawMap is! Map<String, dynamic>) return;
      for (final entry in rawMap.entries) {
        final id = int.tryParse(entry.key);
        if (id != null && entry.value is Map<String, dynamic>) {
          _registry[id] = CustomAnimeAssets.fromJson(entry.value as Map<String, dynamic>);
        }
      }
    } catch (_) {}
  }

  /// Loads cached JSON from application support directory if available.
  static Future<void> _loadFromLocalSupportCache() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheFile = File('${dir.path}/custom_anime_assets.json');
      if (await cacheFile.exists()) {
        final str = await cacheFile.readAsString();
        _parseAndMerge(str);
      }
    } catch (_) {}
  }

  /// Background sync from local companion server or remote repository
  static Future<void> _syncRemote() async {
    // 1. Try local curator server if running locally during dev
    try {
      final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
      final request = await client.getUrl(Uri.parse('http://127.0.0.1:3333/api/assets'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        _parseAndMerge(content);
        await _saveToSupportCache(content);
        client.close();
        return;
      }
      client.close();
    } catch (_) {}

    // 2. Try remote repository URL (GitHub raw)
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(Uri.parse(remoteSyncUrl));
      final response = await request.close();
      if (response.statusCode == 200) {
        final content = await response.transform(utf8.decoder).join();
        _parseAndMerge(content);
        await _saveToSupportCache(content);
      }
      client.close();
    } catch (_) {}
  }

  static Future<void> _saveToSupportCache(String content) async {
    try {
      final dir = await getApplicationSupportDirectory();
      final cacheFile = File('${dir.path}/custom_anime_assets.json');
      await cacheFile.writeAsString(content, flush: true);
    } catch (_) {}
  }
}
