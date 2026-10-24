import 'dart:convert';
import 'package:flutter/services.dart';

class TmdbAnimeMapping {
  final int tmdbId;
  final bool isMovie;
  final int tvdbId;

  const TmdbAnimeMapping({
    required this.tmdbId,
    required this.isMovie,
    required this.tvdbId,
  });
}

/// Offline mapping service linking AniList ID -> TMDB/TVDB IDs.
/// Resolves synchronously in O(1) time (0ms) so TMDB assets (logos, backdrops)
/// can be requested directly on frame 0 without waiting for AniZip.
class TmdbMappingService {
  static Map<int, TmdbAnimeMapping>? _cache;
  static bool _isLoading = false;

  /// Loads the pre-bundled cross-reference index from assets/data/anilist_tmdb_map.json
  static Future<void> init() async {
    if (_cache != null || _isLoading) return;
    _isLoading = true;
    try {
      final jsonStr = await rootBundle.loadString('assets/data/anilist_tmdb_map.json');
      final rawMap = jsonDecode(jsonStr) as Map<String, dynamic>;
      final map = <int, TmdbAnimeMapping>{};
      for (final entry in rawMap.entries) {
        final alId = int.tryParse(entry.key);
        final list = entry.value as List<dynamic>;
        if (alId != null && list.length >= 2) {
          map[alId] = TmdbAnimeMapping(
            tmdbId: list[0] as int,
            isMovie: list[1] == 1,
            tvdbId: list.length > 2 ? (list[2] as int) : 0,
          );
        }
      }
      _cache = map;
    } catch (_) {
      _cache = {};
    } finally {
      _isLoading = false;
    }
  }

  /// Synchronously returns TMDB/TVDB mapping for [anilistId], if present.
  static TmdbAnimeMapping? getMapping(int anilistId) {
    return _cache?[anilistId];
  }

  /// Registers a runtime mapping discovered from AniZip or TMDB resolution
  static void registerMapping({
    required int anilistId,
    required int tmdbId,
    required bool isMovie,
    int tvdbId = 0,
  }) {
    if (anilistId <= 0 || tmdbId <= 0) return;
    _cache ??= {};
    _cache![anilistId] = TmdbAnimeMapping(
      tmdbId: tmdbId,
      isMovie: isMovie,
      tvdbId: tvdbId,
    );
  }
}
