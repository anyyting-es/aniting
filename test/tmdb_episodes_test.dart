import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/data/services/tmdb_service.dart';

class _EpisodeAdapter implements HttpClientAdapter {
  String? lastPath;
  Map<String, dynamic>? lastQuery;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastQuery = options.queryParameters;
    return ResponseBody.fromString(
      jsonEncode({
        'episodes': [
          {
            'id': 3946240,
            'name': 'El final de la aventura',
            'episode_number': 1,
            'season_number': 1,
            'overview': 'El grupo del Héroe derrota al Rey Demonio.',
            'runtime': 26,
            'still_path': '/still.jpg',
            'air_date': '2023-09-29',
            'vote_average': 8.9,
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('TMDB season episodes request uses the show and season in the path',
      () async {
    final adapter = _EpisodeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
    dio.httpClientAdapter = adapter;
    final service = TmdbService(apiKey: 'test-key', dio: dio);

    final episodes = await service.getSeasonEpisodes(209867, 1);

    expect(adapter.lastPath, '/tv/209867/season/1');
    expect(adapter.lastQuery?['api_key'], 'test-key');
    expect(episodes, hasLength(1));
    expect(episodes.first.episodeNumber, 1);
    expect(episodes.first.seasonNumber, 1);
    expect(episodes.first.name, 'El final de la aventura');
  });

  test('different seasons are not served from the same cache entry', () async {
    final adapter = _EpisodeAdapter();
    final dio = Dio(BaseOptions(baseUrl: 'https://api.themoviedb.org/3'));
    dio.httpClientAdapter = adapter;
    final service = TmdbService(apiKey: 'test-key', dio: dio);

    await service.getSeasonEpisodes(209867, 1);
    expect(adapter.lastPath, '/tv/209867/season/1');

    await service.getSeasonEpisodes(209867, 2);
    expect(adapter.lastPath, '/tv/209867/season/2');
  });
}
