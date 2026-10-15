import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/data/models/torrent_models.dart';

/// Native Dart in-app source for AnimeTosho torrents.
class AnimeToshoTorrentSource {
  final Dio _dio;
  static const String baseUrl = 'https://feed.animetosho.net';

  AnimeToshoTorrentSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                },
              ),
            );

  Future<List<TorrentItem>> searchTorrents({
    required String query,
    int? aid,
    int? eid,
    int limit = 50,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'cat': '2020',
        'limit': limit.clamp(1, 100),
      };
      if (query.trim().isNotEmpty) {
        queryParams['q'] = query.trim();
      }
      if (aid != null && aid > 0) {
        queryParams['aid'] = aid.toString();
      }
      if (eid != null && eid > 0) {
        queryParams['eid'] = eid.toString();
      }

      final res = await _dio.get('/feed/json', queryParameters: queryParams);
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final list = raw is String ? jsonDecode(raw) as List? : raw as List?;
        if (list != null && list.isNotEmpty) {
          return list.whereType<Map>().map((item) {
            final map = Map<String, dynamic>.from(item);
            final sizeBytes = map['total_size'] is int
                ? map['total_size'] as int
                : int.tryParse(map['total_size']?.toString() ?? '0') ?? 0;

            final seeders = map['seeders'] is int ? map['seeders'] as int : 0;
            final leechers = map['leechers'] is int ? map['leechers'] as int : 0;

            return TorrentItem(
              name: map['title']?.toString() ?? 'Sin nombre',
              provider: 'AnimeTosho',
              size: sizeBytes,
              formattedSize: _formatBytes(sizeBytes),
              seeders: seeders > 100000 ? 0 : seeders,
              leechers: leechers > 100000 ? 0 : leechers,
              link: map['link']?.toString() ?? map['article_url']?.toString(),
              downloadUrl: map['torrent_url']?.toString(),
              magnetLink: map['magnet_uri']?.toString(),
              infoHash: map['info_hash']?.toString().toLowerCase(),
              isBestRelease: map['is_seadex'] == true,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('AnimeToshoTorrentSource.searchTorrents error: $e');
    }
    return [];
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
