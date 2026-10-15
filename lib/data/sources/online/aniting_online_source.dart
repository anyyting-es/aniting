import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';

/// Native Dart in-app source for Aniting Universal streaming.
/// Bypasses the Seanime Goja JS runtime and talks directly to the Cloudflare API.
class AnitingOnlineSource {
  final Dio _dio;
  static const String baseUrl = 'https://aniting-api.algienrandomxdd.workers.dev';

  AnitingOnlineSource({Dio? dio})
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

  /// Fetches episodes for an anime by AniList ID.
  Future<List<OnlinestreamEpisode>> getEpisodes(int mediaId) async {
    try {
      final res = await _dio.get('/hd/episodes', queryParameters: {'id': mediaId.toString()});
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        final list = map['episodes'] as List?;
        if (list != null && list.isNotEmpty) {
          return list.map((item) {
            final num = item['number'] is int
                ? item['number'] as int
                : int.tryParse(item['number']?.toString() ?? '1') ?? 1;
            final title = item['title']?.toString();
            return OnlinestreamEpisode(
              number: num,
              title: title,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('AnitingOnlineSource.getEpisodes error for media $mediaId: $e');
    }
    return [];
  }

  /// Resolves video sources (1080p HLS, multi-audio, and multi-subtitles).
  Future<List<OnlinestreamVideoSource>> getSources({
    required int mediaId,
    required int episodeNumber,
    String? server,
    String? title,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'id': mediaId.toString(),
        'ep': episodeNumber.toString(),
      };
      if (title != null && title.trim().isNotEmpty) {
        queryParams['title'] = title.trim();
      }
      if (server != null && server.isNotEmpty && server != 'Auto') {
        queryParams['server'] = server;
      }

      final res = await _dio.get('/universal/streams', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        final streamsList = map['streams'] as List?;
        final globalSubsList = map['subtitles'] as List?;

        final globalSubs = globalSubsList != null
            ? globalSubsList
                .whereType<Map>()
                .map((e) => OnlinestreamSubtitle.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : <OnlinestreamSubtitle>[];

        if (streamsList != null && streamsList.isNotEmpty) {
          final results = <OnlinestreamVideoSource>[];
          for (final item in streamsList.whereType<Map>()) {
            final streamMap = Map<String, dynamic>.from(item);

            // Inherit global subtitles if stream doesn't specify any
            if ((streamMap['subtitles'] == null ||
                    (streamMap['subtitles'] as List).isEmpty) &&
                globalSubs.isNotEmpty) {
              streamMap['subtitles'] = globalSubs
                  .map((s) => {
                        'id': s.id,
                        'url': s.url,
                        'language': s.language,
                        'isDefault': s.isDefault,
                      })
                  .toList();
            }

            results.add(OnlinestreamVideoSource.fromJson(streamMap));
          }
          return results;
        }
      }
    } catch (e) {
      debugPrint('AnitingOnlineSource.getSources error for media $mediaId ep $episodeNumber: $e');
    }
    return [];
  }
}
