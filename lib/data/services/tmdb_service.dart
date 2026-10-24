import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbService {
  final Dio _dio;
  final String apiKey;
  static SharedPreferences? _prefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  TmdbService({
    required this.apiKey,
    Dio? dio,
  }) : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: 'https://api.themoviedb.org/3',
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 12),
              ),
            );

  static const String imageBaseUrl = 'https://image.tmdb.org/t/p/w500';
  static const String backdropBaseUrl = 'https://image.tmdb.org/t/p/w1280';

  /// Fetches trending TV series & Movies combined
  Future<List<AnimeEntry>> getTrendingShows({
    String language = 'es-ES',
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/trending/all/day',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'page': page,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie')
          .map((item) => _mapTmdbToAnimeEntry(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches popular TV shows
  Future<List<AnimeEntry>> getPopularTvShows({
    String language = 'es-ES',
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/tv/popular',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'page': page,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((item) => _mapTmdbToAnimeEntry(item, forceType: 'TV')).toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches top rated TV shows
  Future<List<AnimeEntry>> getTopRatedTvShows({
    String language = 'es-ES',
    int page = 1,
  }) async {
    try {
      final response = await _dio.get(
        '/tv/top_rated',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'page': page,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      return results.map((item) => _mapTmdbToAnimeEntry(item, forceType: 'TV')).toList();
    } catch (_) {
      return [];
    }
  }

  /// Searches multi (TV shows and movies)
  Future<List<AnimeEntry>> searchShows({
    required String query,
    String language = 'es-ES',
    int page = 1,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _dio.get(
        '/search/multi',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
          'query': query.trim(),
          'page': page,
          'include_adult': false,
        },
      );

      final results = response.data['results'] as List<dynamic>? ?? [];
      return results
          .where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie')
          .map((item) => _mapTmdbToAnimeEntry(item))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches recommendations for a specific show or movie
  Future<List<AnimeEntry>> getRecommendations(
    int id, {
    String language = 'es-ES',
    bool isMovie = false,
  }) async {
    try {
      final endpoint = isMovie ? '/movie/$id/recommendations' : '/tv/$id/recommendations';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
          'language': language,
        },
      );
      final results = response.data['results'] as List<dynamic>? ?? [];
      final list = results
          .where((item) => item['media_type'] == 'tv' || item['media_type'] == 'movie' || !item.containsKey('media_type'))
          .map((item) => _mapTmdbToAnimeEntry(item, forceType: isMovie ? 'MOVIE' : 'TV'))
          .toList();
      if (list.isNotEmpty) return list;
    } catch (_) {}
    return getTrendingShows(language: language);
  }

  /// Maps a TMDB json object to an AnimeEntry for UI consistency
  AnimeEntry _mapTmdbToAnimeEntry(Map<String, dynamic> json, {String? forceType}) {
    final isMovie = (forceType == 'MOVIE') || (json['media_type'] == 'movie') || json.containsKey('title');
    final id = json['id'] as int? ?? 0;
    final title = (json['title'] ?? json['name'] ?? 'Show #$id') as String;
    final originalTitle = (json['original_title'] ?? json['original_name']) as String?;
    final overview = json['overview'] as String?;
    final posterPath = json['poster_path'] as String?;
    final backdropPath = json['backdrop_path'] as String?;
    final voteAverage = (json['vote_average'] as num?)?.toDouble();
    final firstAirDate = (json['first_air_date'] ?? json['release_date']) as String?;
    
    int? releaseYear;
    if (firstAirDate != null && firstAirDate.length >= 4) {
      releaseYear = int.tryParse(firstAirDate.substring(0, 4));
    }

    return AnimeEntry(
      id: id,
      mediaId: id,
      title: title,
      englishTitle: title,
      romajiTitle: title,
      nativeTitle: originalTitle,
      coverImage: posterPath != null ? '$imageBaseUrl$posterPath' : null,
      bannerImage: backdropPath != null ? '$backdropBaseUrl$backdropPath' : null,
      progress: 0,
      status: 'RELEASING',
      score: voteAverage != null ? (voteAverage * 10).roundToDouble() : null,
      format: isMovie ? 'MOVIE' : 'TV',
      description: overview,
      year: releaseYear,
      airDate: firstAirDate,
      genres: const [],
      isTmdb: true,
    );
  }

  final Map<String, TmdbShowDetails> _detailsCache = {};
  final Map<String, List<TmdbEpisode>> _seasonEpisodesCache = {};

  /// Fetches complete series or movie details from TMDB
  Future<TmdbShowDetails?> getShowDetails(
    int id, {
    String language = 'es-ES',
    bool isMovie = false,
  }) async {
    final cacheKey = '$id-$language-$isMovie';
    if (_detailsCache.containsKey(cacheKey)) {
      return _detailsCache[cacheKey];
    }
    try {
      final endpoint = isMovie ? '/movie/$id' : '/tv/$id';
      final response = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
          'language': language,
        },
      );
      final details = TmdbShowDetails.fromJson(
        response.data as Map<String, dynamic>,
        isMovie: isMovie,
      );
      _detailsCache[cacheKey] = details;
      return details;
    } catch (_) {
      // If /tv/ failed with 404, fallback check /movie/
      if (!isMovie) {
        try {
          final res = await _dio.get(
            '/movie/$id',
            queryParameters: {
              'api_key': apiKey,
              'language': language,
            },
          );
          final details = TmdbShowDetails.fromJson(
            res.data as Map<String, dynamic>,
            isMovie: true,
          );
          _detailsCache[cacheKey] = details;
          return details;
        } catch (_) {}
      }
      return null;
    }
  }

  /// Fetches the episodes of a specific season of a TV show
  Future<List<TmdbEpisode>> getSeasonEpisodes(
    int seriesId,
    int seasonNumber, {
    String language = 'es-ES',
  }) async {
    final cacheKey = '$seriesId-s$seasonNumber-$language';
    if (_seasonEpisodesCache.containsKey(cacheKey)) {
      return _seasonEpisodesCache[cacheKey]!;
    }
    try {
      final response = await _dio.get(
        '/tv/$seriesId/season/$seasonNumber',
        queryParameters: {
          'api_key': apiKey,
          'language': language,
        },
      );
      final rawList = response.data['episodes'] as List<dynamic>? ?? [];
      final episodes = rawList
          .map((e) => TmdbEpisode.fromJson(e as Map<String, dynamic>))
          .toList();
      _seasonEpisodesCache[cacheKey] = episodes;
      return episodes;
    } catch (_) {
      return [];
    }
  }

  static final Map<String, TmdbMediaAssets?> _assetsCache = {};

  /// Synchronously returns cached assets if already fetched in this session or stored in persistent preferences.
  static TmdbMediaAssets? getCachedAssets(int tmdbId, bool isMovie, {int? tvdbId}) {
    final key1 = '$tmdbId-$tvdbId-$isMovie';
    final key2 = '$tmdbId-0-$isMovie';
    final key3 = '$tmdbId-null-$isMovie';
    final inMem = _assetsCache[key1] ?? _assetsCache[key2] ?? _assetsCache[key3];
    if (inMem != null) return inMem;

    if (_prefs != null) {
      for (final key in [key1, key2, key3]) {
        final raw = _prefs!.getString('tmdb_assets_$key');
        if (raw != null && raw.isNotEmpty) {
          final parts = raw.split('|||');
          final logo = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
          final backdrop = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
          final assets = TmdbMediaAssets(logoUrl: logo, backdropUrl: backdrop);
          _assetsCache[key] = assets;
          return assets;
        }
      }
    }
    return null;
  }

  /// Fetches transparent PNG logo and official backdrop for a show or movie from TMDB.
  /// Resolves via tmdbId directly, or via tvdbId using TMDB's /find endpoint.
  Future<TmdbMediaAssets?> getMediaAssets({
    int? tmdbId,
    int? tvdbId,
    bool isMovie = false,
  }) async {
    final cacheKey = '$tmdbId-$tvdbId-$isMovie';
    if (_assetsCache.containsKey(cacheKey)) {
      return _assetsCache[cacheKey];
    }
    if (_prefs != null) {
      final raw = _prefs!.getString('tmdb_assets_$cacheKey');
      if (raw != null && raw.isNotEmpty) {
        final parts = raw.split('|||');
        final logo = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0] : null;
        final backdrop = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
        final assets = TmdbMediaAssets(logoUrl: logo, backdropUrl: backdrop);
        _assetsCache[cacheKey] = assets;
        return assets;
      }
    }

    try {
      int? resolvedTmdbId = tmdbId;

      // 1. If no tmdbId is given but we have tvdbId, resolve via /find
      if ((resolvedTmdbId == null || resolvedTmdbId <= 0) && tvdbId != null && tvdbId > 0) {
        final findRes = await _dio.get(
          '/find/$tvdbId',
          queryParameters: {
            'api_key': apiKey,
            'external_source': 'tvdb_id',
          },
        );
        final data = findRes.data as Map<String, dynamic>?;
        final tvResults = data?['tv_results'] as List<dynamic>?;
        final movieResults = data?['movie_results'] as List<dynamic>?;

        if (tvResults != null && tvResults.isNotEmpty) {
          resolvedTmdbId = tvResults.first['id'] as int?;
        } else if (movieResults != null && movieResults.isNotEmpty) {
          resolvedTmdbId = movieResults.first['id'] as int?;
        }
      }

      if (resolvedTmdbId == null || resolvedTmdbId <= 0) {
        _assetsCache[cacheKey] = null;
        return null;
      }

      // 2. Fetch images for the resolved TMDB show or movie
      final endpoint = isMovie ? '/movie/$resolvedTmdbId/images' : '/tv/$resolvedTmdbId/images';
      final imgRes = await _dio.get(
        endpoint,
        queryParameters: {
          'api_key': apiKey,
        },
      );

      final logos = (imgRes.data?['logos'] as List<dynamic>?) ?? [];
      final backdrops = (imgRes.data?['backdrops'] as List<dynamic>?) ?? [];

      String? logoUrl;
      if (logos.isNotEmpty) {
        final selectedLogo = logos.firstWhere(
          (l) => l['iso_639_1'] == 'en' || l['iso_639_1'] == 'es',
          orElse: () => logos.first,
        );
        final filePath = selectedLogo['file_path'] as String?;
        if (filePath != null && filePath.isNotEmpty) {
          logoUrl = '$imageBaseUrl$filePath';
        }
      }

      String? backdropUrl;
      if (backdrops.isNotEmpty) {
        // Prioritize textless clean backdrop
        final topBackdrop = backdrops.firstWhere(
          (b) => b['iso_639_1'] == null || b['iso_639_1'] == '',
          orElse: () => backdrops.first,
        );
        final bPath = topBackdrop['file_path'] as String?;
        if (bPath != null && bPath.isNotEmpty) {
          backdropUrl = '$backdropBaseUrl$bPath';
        }
      }

      final assets = TmdbMediaAssets(logoUrl: logoUrl, backdropUrl: backdropUrl);
      _assetsCache[cacheKey] = assets;
      if (_prefs != null) {
        _prefs!.setString('tmdb_assets_$cacheKey', '${logoUrl ?? ""}|||${backdropUrl ?? ""}');
      }
      return assets;
    } catch (_) {}

    _assetsCache[cacheKey] = null;
    return null;
  }

  /// Fetches transparent PNG logo for a show or movie from TMDB.
  /// Resolves via tmdbId directly, or via tvdbId using TMDB's /find endpoint.
  Future<String?> getLogo({
    int? tmdbId,
    int? tvdbId,
    bool isMovie = false,
  }) async {
    final assets = await getMediaAssets(
      tmdbId: tmdbId,
      tvdbId: tvdbId,
      isMovie: isMovie,
    );
    return assets?.logoUrl;
  }
}

class TmdbMediaAssets {
  final String? logoUrl;
  final String? backdropUrl;

  const TmdbMediaAssets({this.logoUrl, this.backdropUrl});
}