import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

/// Native Dart in-app source for MangaDex manga reading.
class MangaDexMangaSource {
  final Dio _dio;
  static const String baseUrl = 'https://api.mangadex.org';

  MangaDexMangaSource({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                headers: {
                  'Accept': 'application/json',
                  'User-Agent': 'Aniting/1.0.0 (https://github.com/anyyting-es)',
                },
              ),
            );

  Future<String?> findMangaId(String query) async {
    try {
      final res = await _dio.get('/manga', queryParameters: {
        'title': query.trim(),
        'limit': 5,
        'order[relevance]': 'desc',
      });
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        final data = map['data'] as List?;
        if (data != null && data.isNotEmpty) {
          return data.first['id']?.toString();
        }
      }
    } catch (e) {
      debugPrint('MangaDexMangaSource.findMangaId error: $e');
    }
    return null;
  }

  Future<List<MangaChapter>> getChapters(String mangaId) async {
    try {
      final res = await _dio.get('/manga/$mangaId/feed', queryParameters: {
        'translatedLanguage[]': ['es', 'es-la', 'en'],
        'order[chapter]': 'asc',
        'limit': 500,
      });
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        final list = map['data'] as List?;
        if (list != null && list.isNotEmpty) {
          return list.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            final id = item['id']?.toString() ?? '';
            final attrs = item['attributes'] as Map<String, dynamic>? ?? {};
            final chapter = attrs['chapter']?.toString() ?? '${idx + 1}';
            final title = attrs['title']?.toString() ?? 'Capítulo $chapter';
            final lang = attrs['translatedLanguage']?.toString() ?? 'es';

            return MangaChapter(
              id: id,
              url: 'https://mangadex.org/chapter/$id',
              title: title,
              chapter: chapter,
              index: idx,
              language: lang,
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('MangaDexMangaSource.getChapters error: $e');
    }
    return [];
  }

  Future<List<MangaPage>> getPages(String chapterId) async {
    try {
      final res = await _dio.get('/at-home/server/$chapterId');
      if (res.statusCode == 200 && res.data != null) {
        final raw = res.data;
        final map = raw is String ? jsonDecode(raw) : raw;
        final baseUrl = map['baseUrl']?.toString() ?? '';
        final chapterData = map['chapter'] as Map<String, dynamic>? ?? {};
        final hash = chapterData['hash']?.toString() ?? '';
        final dataFiles = chapterData['data'] as List? ?? [];

        return dataFiles.asMap().entries.map((entry) {
          final idx = entry.key;
          final filename = entry.value.toString();
          return MangaPage(
            url: '$baseUrl/data/$hash/$filename',
            index: idx,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('MangaDexMangaSource.getPages error: $e');
    }
    return [];
  }
}
