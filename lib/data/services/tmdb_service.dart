import 'package:dio/dio.dart';
import 'package:seanime_app/data/models/anime_entry.dart';

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
      romajiTitle: originalTitle ?? title,
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
    );
  }
}
