import 'package:dio/dio.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbService {
  final Dio _dio;
  final String apiKey;

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
}
