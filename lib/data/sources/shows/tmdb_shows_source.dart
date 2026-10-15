import 'package:dio/dio.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/data/services/tmdb_service.dart';

/// Native Dart in-app source for TMDB TV shows and movies.
class TmdbShowsSource {
  final TmdbService _service;

  TmdbShowsSource({required String apiKey, Dio? dio})
      : _service = TmdbService(apiKey: apiKey, dio: dio);

  TmdbService get service => _service;

  Future<List<AnimeEntry>> getTrending({String language = 'es-ES', int page = 1}) =>
      _service.getTrendingShows(language: language, page: page);

  Future<List<AnimeEntry>> searchShows(String query, {String language = 'es-ES', int page = 1}) =>
      _service.searchShows(query: query, language: language, page: page);

  Future<TmdbShowDetails?> getShowDetails(int tmdbId, {String language = 'es-ES', bool isMovie = false}) =>
      _service.getShowDetails(tmdbId, language: language, isMovie: isMovie);

  Future<List<TmdbEpisode>> getSeasonEpisodes(int tmdbId, int seasonNumber, {String language = 'es-ES'}) =>
      _service.getSeasonEpisodes(tmdbId, seasonNumber, language: language);
}
