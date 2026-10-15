import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';

/// Native in-app source for Kawaii Animes (Audio Latino, Castellano y Subtitulado).
/// Queries the Aniting Cloudflare D1 serverless database directly in pure Dart.
class KawaiiOnlineSource {
  final Dio _dio;
  static const String baseUrl = 'https://aniting-api.algienrandomxdd.workers.dev';

  KawaiiOnlineSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                },
              ),
            );

  /// Resolves episodes list for a series by title or mediaId.
  Future<List<OnlinestreamEpisode>> getEpisodes(int mediaId, {String? title}) async {
    try {
      final searchTitle = title?.trim() ?? '';
      if (searchTitle.isNotEmpty) {
        final searchRes = await _dio.get('/search', queryParameters: {'q': searchTitle});
        if (searchRes.statusCode == 200 && searchRes.data != null) {
          final data = searchRes.data is String ? jsonDecode(searchRes.data) : searchRes.data;
          final results = data['results'] as List?;
          if (results != null && results.isNotEmpty) {
            final animeId = results.first['id'];
            if (animeId != null) {
              final epRes = await _dio.get('/episodes', queryParameters: {'animeId': animeId.toString()});
              if (epRes.statusCode == 200 && epRes.data != null) {
                final epData = epRes.data is String ? jsonDecode(epRes.data) : epRes.data;
                final epList = epData['episodes'] as List?;
                if (epList != null && epList.isNotEmpty) {
                  return epList.map((e) {
                    final num = e['num'] is int ? e['num'] as int : int.tryParse(e['num']?.toString() ?? '1') ?? 1;
                    return OnlinestreamEpisode(
                      number: num,
                      title: 'Episodio $num',
                    );
                  }).toList();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('KawaiiOnlineSource.getEpisodes error: $e');
    }
    return [];
  }

  /// Resolves video sources (Latino, Castellano, and Sub streams).
  Future<List<OnlinestreamVideoSource>> getSources({
    required int mediaId,
    required int episodeNumber,
    String? title,
    String? server,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'ep': episodeNumber.toString(),
      };
      if (title != null && title.trim().isNotEmpty) {
        queryParams['title'] = title.trim();
      }
      if (server != null && server.isNotEmpty && server != 'Auto') {
        queryParams['server'] = server;
      }

      final res = await _dio.get('/streams', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final data = res.data is String ? jsonDecode(res.data) : res.data;
        final streamsList = data['streams'] as List?;
        if (streamsList != null && streamsList.isNotEmpty) {
          return streamsList
              .whereType<Map>()
              .map((item) => OnlinestreamVideoSource.fromJson(Map<String, dynamic>.from(item)))
              .toList();
        }
      }
    } catch (e) {
      debugPrint('KawaiiOnlineSource.getSources error: $e');
    }
    return [];
  }
}
