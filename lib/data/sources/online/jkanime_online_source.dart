import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';

/// Native in-app source for JKAnime (anime subtitulado en español).
/// Pure Dart scraper extracting direct streams from StreamWish, Vidhide, VOE, and Mp4upload.
class JkAnimeOnlineSource {
  final Dio _dio;
  static const String baseUrl = 'https://jkanime.net';
  static const String userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';

  JkAnimeOnlineSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 25),
                headers: {
                  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
                  'User-Agent': userAgent,
                },
              ),
            );

  String _cleanSlug(String href) {
    return href
        .replaceFirst(baseUrl, '')
        .replaceAll(RegExp(r'^/+'), '')
        .replaceAll(RegExp(r'/+$'), '');
  }

  String _b64Decode(String str) {
    try {
      final normalized = base64.normalize(str.trim());
      return utf8.decode(base64.decode(normalized));
    } catch (_) {
      try {
        return utf8.decode(base64.decode(str.trim()));
      } catch (_) {}
    }
    return '';
  }

  /// Searches JKAnime by query and returns anime slug.
  Future<String?> _resolveSlug(String query) async {
    try {
      final cleanQ = query.trim().replaceAll(RegExp(r'[^\w\s-]'), '');
      final res = await _dio.get('/buscar/${Uri.encodeComponent(cleanQ)}/');
      if (res.statusCode == 200 && res.data != null) {
        final html = res.data.toString();
        final match = RegExp(r'class="anime__item__text"[\s\S]*?<a\s+href="([^"]+)"', caseSensitive: false)
            .firstMatch(html);
        if (match != null) {
          final href = match.group(1)?.trim() ?? '';
          final slug = _cleanSlug(href);
          if (slug.isNotEmpty) return slug;
        }
      }
    } catch (e) {
      debugPrint('JkAnimeOnlineSource._resolveSlug error for "$query": $e');
    }
    return null;
  }

  /// Fetches episodes for an anime.
  Future<List<OnlinestreamEpisode>> getEpisodes(int mediaId, {String? title}) async {
    if (title == null || title.trim().isEmpty) return [];
    try {
      final slug = await _resolveSlug(title.trim());
      if (slug == null) return [];

      final res = await _dio.get('/$slug/');
      if (res.statusCode == 200 && res.data != null) {
        final html = res.data.toString();
        final totalMatch = RegExp(r'num_episodios\s*=\s*(\d+)').firstMatch(html) ??
            RegExp(r'data-episodes="(\d+)"').firstMatch(html) ??
            RegExp(r'(\d+)\s*ep[ií]sodios?', caseSensitive: false).firstMatch(html);

        final total = totalMatch != null ? int.tryParse(totalMatch.group(1) ?? '0') ?? 0 : 0;
        if (total > 0) {
          return List.generate(total, (i) {
            final epNum = i + 1;
            return OnlinestreamEpisode(
              number: epNum,
              title: 'Episodio $epNum',
            );
          });
        }
      }
    } catch (e) {
      debugPrint('JkAnimeOnlineSource.getEpisodes error: $e');
    }
    return [];
  }

  /// Resolves video sources for a given episode.
  Future<List<OnlinestreamVideoSource>> getSources({
    required int mediaId,
    required int episodeNumber,
    String? title,
    String? server,
  }) async {
    if (title == null || title.trim().isEmpty) return [];
    try {
      final slug = await _resolveSlug(title.trim());
      if (slug == null) return [];

      final epRes = await _dio.get('/$slug/$episodeNumber/');
      if (epRes.statusCode != 200 || epRes.data == null) return [];

      final html = epRes.data.toString();
      final serversMatch = RegExp(r'var\s+servers\s*=\s*(\[[\s\S]*?\]);').firstMatch(html);
      if (serversMatch == null) return [];

      final jsonStr = serversMatch.group(1);
      if (jsonStr == null) return [];

      final list = jsonDecode(jsonStr) as List?;
      if (list == null || list.isEmpty) return [];

      final sources = <OnlinestreamVideoSource>[];

      for (final item in list.whereType<Map>()) {
        final serverName = (item['server'] ?? '').toString();
        final remote = (item['remote'] ?? '').toString();
        final embedUrl = _b64Decode(remote);

        if (embedUrl.isEmpty) continue;

        // Extract direct streams based on server type
        final norm = serverName.toUpperCase();

        if (norm == 'STREAMWISH') {
          final m3u8 = await _extractStreamWish(embedUrl);
          if (m3u8 != null) {
            sources.add(OnlinestreamVideoSource(
              server: 'StreamWish [Sub]',
              quality: '1080p',
              type: 'm3u8',
              url: m3u8,
              headers: {'Referer': embedUrl, 'User-Agent': userAgent},
            ));
          }
        } else if (norm == 'VOE') {
          final m3u8 = await _extractVoe(embedUrl);
          if (m3u8 != null) {
            sources.add(OnlinestreamVideoSource(
              server: 'VOE [Sub]',
              quality: '1080p',
              type: 'm3u8',
              url: m3u8,
              headers: {'Referer': embedUrl, 'User-Agent': userAgent},
            ));
          }
        }
      }

      return sources;
    } catch (e) {
      debugPrint('JkAnimeOnlineSource.getSources error: $e');
    }
    return [];
  }

  Future<String?> _extractStreamWish(String embedUrl) async {
    try {
      final res = await _dio.get<String>(
        embedUrl,
        options: Options(
          headers: {'User-Agent': userAgent, 'Referer': 'https://jkanime.net/'},
          responseType: ResponseType.plain,
        ),
      );
      final body = res.data ?? '';
      final unpacked = _runUnpack(body);
      final m = RegExp('https?://[^\\s"\'<>]+\\.m3u8[^\\s"\'<>]*').firstMatch(unpacked);
      return m?.group(0);
    } catch (_) {
      return null;
    }
  }

  Future<String?> _extractVoe(String embedUrl) async {
    try {
      final res = await _dio.get<String>(
        embedUrl,
        options: Options(
          headers: {'User-Agent': userAgent, 'Referer': 'https://jkanime.net/'},
          responseType: ResponseType.plain,
        ),
      );
      final body = res.data ?? '';
      final m = RegExp(r'"hls"\s*:\s*"([^"]+)"').firstMatch(body);
      return m?.group(1);
    } catch (_) {
      return null;
    }
  }

  String _runUnpack(String html) {
    final line = html.split('\n').firstWhere(
          (l) => l.contains('eval(function'),
          orElse: () => '',
        );
    if (line.isEmpty) return html;

    try {
      final m = RegExp(r"\}\s*\('([\s\S]*?)'\s*,\s*(\d+)\s*,\s*(\d+)\s*,\s*'([\s\S]*?)'\.split\('\|'\)")
          .firstMatch(line);
      if (m == null) return html;

      String p = m.group(1) ?? '';
      final a = int.tryParse(m.group(2) ?? '10') ?? 10;
      int c = int.tryParse(m.group(3) ?? '0') ?? 0;
      final k = (m.group(4) ?? '').split('|');

      while (c-- > 0) {
        if (c < k.length && k[c].isNotEmpty) {
          p = p.replaceAll(RegExp(r'\b' + c.toRadixString(a) + r'\b'), k[c]);
        }
      }
      return p;
    } catch (_) {
      return html;
    }
  }
}
