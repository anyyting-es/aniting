import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class DownloadedChapterInfo {
  final String provider;
  final int mediaId;
  final String chapterId;
  final String chapterNumber;
  final String directoryPath;
  final int pageCount;
  final int totalSizeBytes;

  const DownloadedChapterInfo({
    required this.provider,
    required this.mediaId,
    required this.chapterId,
    required this.chapterNumber,
    required this.directoryPath,
    required this.pageCount,
    required this.totalSizeBytes,
  });
}

class MangaOfflineService {
  final Dio _dio;

  MangaOfflineService([Dio? dio]) : _dio = dio ?? Dio();

  /// Guarda la metadata de una obra y descarga su portada y banner a disco.
  Future<void> saveMangaMetadata(MangaEntry entry, {String? customBase}) async {
    try {
      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(
        entry.mediaId,
        slug: entry.title,
        customBase: customBase,
      );

      final metadataFile = File('${seriesDir.path}/metadata.json');
      final coverFile = File('${seriesDir.path}/cover.jpg');
      final bannerFile = File('${seriesDir.path}/banner.jpg');

      String? localCoverPath = entry.localCoverPath;
      String? localBannerPath = entry.localBannerPath;

      // 1. Descargar portada si no existe ya localmente
      if (!await coverFile.exists() && entry.coverImage != null && entry.coverImage!.startsWith('http')) {
        try {
          final res = await _dio.get<List<int>>(
            entry.coverImage!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            await coverFile.writeAsBytes(res.data!);
            localCoverPath = coverFile.path;
          }
        } catch (e) {
          debugPrint('Error downloading manga cover for offline cache: $e');
        }
      } else if (await coverFile.exists()) {
        localCoverPath = coverFile.path;
      }

      // 2. Descargar banner si existe y no está localmente
      if (!await bannerFile.exists() && entry.bannerImage != null && entry.bannerImage!.startsWith('http')) {
        try {
          final res = await _dio.get<List<int>>(
            entry.bannerImage!,
            options: Options(responseType: ResponseType.bytes),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            await bannerFile.writeAsBytes(res.data!);
            localBannerPath = bannerFile.path;
          }
        } catch (_) {}
      } else if (await bannerFile.exists()) {
        localBannerPath = bannerFile.path;
      }

      // 3. Serializar MangaEntry actualizado con rutas locales
      final updatedEntry = entry.copyWith(
        localCoverPath: localCoverPath,
        localBannerPath: localBannerPath,
        isDownloaded: true,
      );

      await metadataFile.writeAsString(
        jsonEncode(updatedEntry.toJson()),
        flush: true,
      );
    } catch (e) {
      debugPrint('Error saving manga metadata: $e');
    }
  }

  /// Lee los metadatos guardados para un manga por ID si existen.
  Future<MangaEntry?> getSavedMangaMetadata(int mediaId, {String? customBase}) async {
    try {
      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(mediaId, customBase: customBase);
      final metadataFile = File('${seriesDir.path}/metadata.json');
      if (await metadataFile.exists()) {
        final content = await metadataFile.readAsString();
        final map = jsonDecode(content) as Map<String, dynamic>;
        final entry = MangaEntry.fromJson(map);

        final coverFile = File('${seriesDir.path}/cover.jpg');
        final coverPath = await coverFile.exists() ? coverFile.path : entry.localCoverPath;

        return entry.copyWith(
          localCoverPath: coverPath,
          isDownloaded: true,
        );
      }
    } catch (e) {
      debugPrint('Error reading saved manga metadata: $e');
    }
    return null;
  }

  /// Escanea Anime/aniting/Manga y retorna todas las obras con capítulos descargados
  /// como objetos MangaEntry estándar para la UI.
  Future<List<MangaEntry>> getDownloadedMangaList({String? customBase}) async {
    final results = <MangaEntry>[];
    try {
      final mangaRoot = await AppStoragePaths.getMangaDownloadsDirectory(customBase: customBase);
      if (!await mangaRoot.exists()) return results;

      final entities = mangaRoot.listSync();

      // 1. Obras organizadas en carpetas `<mediaId>` o `<mediaId>_<slug>`
      for (final entity in entities) {
        if (entity is! Directory) continue;

        final dirName = _getDirName(entity);

        // Si es una carpeta de capítulo directo de Seanime backend (ej: comick_123_abc_1) la procesamos luego
        if (_isBackendChapterDir(dirName)) continue;

        final metadataFile = File('${entity.path}/metadata.json');
        final coverFile = File('${entity.path}/cover.jpg');
        final coverPath = coverFile.existsSync() ? coverFile.path : null;

        final downloadedChapters = await _findChaptersInDirectory(entity.path);

        if (metadataFile.existsSync()) {
          try {
            final content = metadataFile.readAsStringSync();
            final map = jsonDecode(content) as Map<String, dynamic>;
            final entry = MangaEntry.fromJson(map);

            results.add(entry.copyWith(
              localCoverPath: coverPath ?? entry.localCoverPath,
              isDownloaded: true,
              downloadedChaptersCount: downloadedChapters.length,
            ));
            continue;
          } catch (e) {
            debugPrint('Error parsing metadata.json in ${entity.path}: $e');
          }
        }

        // Si hay capítulos pero no hay metadata.json, extraer mediaId del nombre de carpeta
        if (downloadedChapters.isNotEmpty) {
          final idStr = dirName.split('_').first;
          final mId = int.tryParse(idStr) ?? 0;
          if (mId > 0) {
            results.add(MangaEntry(
              id: mId,
              mediaId: mId,
              title: _formatFallbackTitle(dirName),
              progress: 0,
              status: 'DOWNLOADED',
              isDownloaded: true,
              downloadedChaptersCount: downloadedChapters.length,
              localCoverPath: coverPath,
            ));
          }
        }
      }

      // 2. Escanear posibles capítulos de backend en la raíz de Anime/aniting/Manga
      final rootBackendChapters = <int, List<DownloadedChapterInfo>>{};
      for (final entity in entities) {
        if (entity is Directory) {
          final dirName = _getDirName(entity);
          if (_isBackendChapterDir(dirName)) {
            final ch = _parseChapterDir(entity.path, dirName);
            if (ch != null) {
              rootBackendChapters.putIfAbsent(ch.mediaId, () => []).add(ch);
            }
          }
        }
      }

      for (final entry in rootBackendChapters.entries) {
        final mId = entry.key;
        final chapters = entry.value;
        // Si ya está en results, actualizar conteo
        final existingIdx = results.indexWhere((e) => e.mediaId == mId);
        if (existingIdx != -1) {
          final current = results[existingIdx];
          results[existingIdx] = current.copyWith(
            downloadedChaptersCount: current.downloadedChaptersCount + chapters.length,
          );
        } else {
          // Intentar obtener metadata guardada
          final saved = await getSavedMangaMetadata(mId, customBase: customBase);
          if (saved != null) {
            results.add(saved.copyWith(
              isDownloaded: true,
              downloadedChaptersCount: chapters.length,
            ));
          } else {
            results.add(MangaEntry(
              id: mId,
              mediaId: mId,
              title: 'Manga $mId',
              progress: 0,
              status: 'DOWNLOADED',
              isDownloaded: true,
              downloadedChaptersCount: chapters.length,
            ));
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting downloaded manga list: $e');
    }

    // Ordenar por título o mediaId
    results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    return results;
  }

  /// Retorna la lista de capítulos descargados para un manga específico.
  Future<List<DownloadedChapterInfo>> getDownloadedChapters(
    int mediaId, {
    String? customBase,
  }) async {
    final list = <DownloadedChapterInfo>[];
    try {
      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(mediaId, customBase: customBase);
      if (await seriesDir.exists()) {
        final chapters = await _findChaptersInDirectory(seriesDir.path);
        list.addAll(chapters);
      }

      // También verificar en la raíz de descargas (formato Seanime backend)
      final mangaRoot = await AppStoragePaths.getMangaDownloadsDirectory(customBase: customBase);
      if (await mangaRoot.exists()) {
        final entities = mangaRoot.listSync();
        for (final entity in entities) {
          if (entity is Directory) {
            final name = _getDirName(entity);
            if (_isBackendChapterDir(name)) {
              final ch = _parseChapterDir(entity.path, name);
              if (ch != null && ch.mediaId == mediaId) {
                // Evitar duplicados por chapterId
                if (!list.any((item) => item.chapterId == ch.chapterId)) {
                  list.add(ch);
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error getting downloaded chapters: $e');
    }

    // Ordenar numéricamente por número de capítulo
    list.sort((a, b) {
      final aNum = double.tryParse(a.chapterNumber) ?? 0.0;
      final bNum = double.tryParse(b.chapterNumber) ?? 0.0;
      return aNum.compareTo(bNum);
    });

    return list;
  }

  /// Retorna las páginas de un capítulo descargado en disco como objetos MangaPage
  /// con URLs que apuntan directamente a archivos locales.
  Future<List<MangaPage>> getDownloadedChapterPages({
    required int mediaId,
    required String provider,
    required String chapterId,
    String? customBase,
  }) async {
    final chapters = await getDownloadedChapters(mediaId, customBase: customBase);
    final target = chapters.cast<DownloadedChapterInfo?>().firstWhere(
          (c) =>
              c != null &&
              c.chapterId == chapterId &&
              (provider.isEmpty || provider == 'local' || c.provider == provider),
          orElse: () => null,
        );

    if (target == null) return [];

    final chDir = Directory(target.directoryPath);
    if (!await chDir.exists()) return [];

    final registryFile = File('${chDir.path}/registry.json');
    final pages = <MangaPage>[];

    if (await registryFile.exists()) {
      try {
        final content = await registryFile.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;

        // registry.json: { "1": { "index": 1, "filename": "1.jpg", ... }, ... }
        final entries = jsonMap.entries.toList();
        entries.sort((a, b) {
          final aIdx = int.tryParse(a.key) ?? 0;
          final bIdx = int.tryParse(b.key) ?? 0;
          return aIdx.compareTo(bIdx);
        });

        for (final entry in entries) {
          final val = entry.value as Map<String, dynamic>;
          final filename = val['filename'] as String? ?? '${entry.key}.jpg';
          final imgFile = File('${chDir.path}/$filename');
          final pageIdx = (val['index'] as num?)?.toInt() ?? (int.tryParse(entry.key) ?? 0);

          pages.add(MangaPage(
            url: imgFile.path,
            index: pageIdx,
          ));
        }
        return pages;
      } catch (e) {
        debugPrint('Error reading registry.json: $e');
      }
    }

    // Fallback: listar imágenes directamente en la carpeta
    final files = chDir
        .listSync()
        .whereType<File>()
        .where((f) {
          final ext = f.path.split('.').last.toLowerCase();
          return ['jpg', 'jpeg', 'png', 'webp', 'gif'].contains(ext);
        })
        .toList();

    files.sort((a, b) {
      final aName = a.uri.pathSegments.last.split('.').first;
      final bName = b.uri.pathSegments.last.split('.').first;
      final aNum = int.tryParse(aName) ?? 0;
      final bNum = int.tryParse(bName) ?? 0;
      return aNum.compareTo(bNum);
    });

    for (int i = 0; i < files.length; i++) {
      pages.add(MangaPage(
        url: files[i].path,
        index: i + 1,
      ));
    }

    return pages;
  }

  /// Elimina un capítulo descargado de disco.
  Future<bool> deleteDownloadedChapter(DownloadedChapterInfo chapter) async {
    try {
      final dir = Directory(chapter.directoryPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        return true;
      }
    } catch (e) {
      debugPrint('Error deleting downloaded chapter: $e');
    }
    return false;
  }

  /// Elimina una serie completa de descargas y su carpeta.
  Future<bool> deleteEntireManga(int mediaId, {String? customBase}) async {
    try {
      final seriesDir = await AppStoragePaths.getMangaSeriesDirectory(mediaId, customBase: customBase);
      if (await seriesDir.exists()) {
        await seriesDir.delete(recursive: true);
      }

      // También eliminar posibles carpetas de capítulo sueltas en la raíz
      final mangaRoot = await AppStoragePaths.getMangaDownloadsDirectory(customBase: customBase);
      if (await mangaRoot.exists()) {
        for (final entity in mangaRoot.listSync()) {
          if (entity is Directory) {
            final name = _getDirName(entity);
            if (_isBackendChapterDir(name)) {
              final parsed = _parseChapterDir(entity.path, name);
              if (parsed != null && parsed.mediaId == mediaId) {
                await entity.delete(recursive: true);
              }
            }
          }
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting entire manga: $e');
      return false;
    }
  }

  /// Calcula el espacio total ocupado por las descargas de manga en bytes.
  Future<int> getTotalMangaStorageBytes({String? customBase}) async {
    int total = 0;
    try {
      final mangaRoot = await AppStoragePaths.getMangaDownloadsDirectory(customBase: customBase);
      if (await mangaRoot.exists()) {
        total = await _calculateDirSize(mangaRoot);
      }
    } catch (_) {}
    return total;
  }

  /// Formatea una cantidad de bytes a una cadena legible (B, KB, MB, GB).
  String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(1024)).floor().clamp(0, suffixes.length - 1);
    final size = bytes / pow(1024, i);
    return '${size.toStringAsFixed(i == 0 ? 0 : 1)} ${suffixes[i]}';
  }

  // ─── MÉTODOS PRIVADOS AUXILIARES ──────────────────────────────────────────

  Future<List<DownloadedChapterInfo>> _findChaptersInDirectory(String parentPath) async {
    final list = <DownloadedChapterInfo>[];
    final parent = Directory(parentPath);
    if (!await parent.exists()) return list;

    // Buscar en subcarpeta "chapters" si existe, o directamente dentro del directorio
    final chaptersSub = Directory('$parentPath/chapters');
    final targetDir = await chaptersSub.exists() ? chaptersSub : parent;

    final entities = targetDir.listSync();
    for (final entity in entities) {
      if (entity is Directory) {
        final name = _getDirName(entity);
        final ch = _parseChapterDir(entity.path, name);
        if (ch != null) {
          list.add(ch);
        }
      }
    }
    return list;
  }

  DownloadedChapterInfo? _parseChapterDir(String fullPath, String dirName) {
    // Formato Seanime: {provider}_{mediaId}_{chapterId}_{chapterNumber}
    // O formato interno: chapter_{chapterNumber}
    final dir = Directory(fullPath);
    final regFile = File('$fullPath/registry.json');
    int pageCount = 0;
    int sizeBytes = 0;

    if (regFile.existsSync()) {
      try {
        final map = jsonDecode(regFile.readAsStringSync()) as Map<String, dynamic>;
        pageCount = map.length;
      } catch (_) {}
    }

    if (pageCount == 0) {
      pageCount = dir
          .listSync()
          .whereType<File>()
          .where((f) => !f.path.endsWith('.json'))
          .length;
    }

    try {
      for (final f in dir.listSync(recursive: true).whereType<File>()) {
        sizeBytes += f.lengthSync();
      }
    } catch (_) {}

    final parts = dirName.split('_');
    if (parts.length >= 4) {
      final provider = parts[0];
      final mediaId = int.tryParse(parts[1]) ?? 0;
      final chapterId = _unescapeChapterId(parts[2]);
      final chapterNumber = parts.sublist(3).join('_');

      return DownloadedChapterInfo(
        provider: provider,
        mediaId: mediaId,
        chapterId: chapterId,
        chapterNumber: chapterNumber,
        directoryPath: fullPath,
        pageCount: pageCount,
        totalSizeBytes: sizeBytes,
      );
    }

    if (dirName.startsWith('chapter_') || dirName.startsWith('capitulo_')) {
      final chNum = dirName.split('_').last;
      return DownloadedChapterInfo(
        provider: 'local',
        mediaId: 0,
        chapterId: dirName,
        chapterNumber: chNum,
        directoryPath: fullPath,
        pageCount: pageCount,
        totalSizeBytes: sizeBytes,
      );
    }

    return null;
  }

  bool _isBackendChapterDir(String name) {
    final parts = name.split('_');
    return parts.length >= 4 && int.tryParse(parts[1]) != null;
  }

  String _unescapeChapterId(String id) {
    return id
        .replaceAll(r'$SLASH$', '/')
        .replaceAll(r'$BSLASH$', '\\')
        .replaceAll(r'$COLON$', ':')
        .replaceAll(r'$ASTERISK$', '*')
        .replaceAll(r'$QUESTION$', '?')
        .replaceAll(r'$QUOTE$', '"')
        .replaceAll(r'$LT$', '<')
        .replaceAll(r'$GT$', '>')
        .replaceAll(r'$PIPE$', '|')
        .replaceAll(r'$DOT$', '.')
        .replaceAll(r'$SPACE$', ' ')
        .replaceAll(r'$UNDERSCORE$', '_');
  }

  String _getDirName(Directory dir) {
    final segments = dir.uri.pathSegments.where((s) => s.isNotEmpty).toList();
    return segments.isNotEmpty ? segments.last : '';
  }

  String _formatFallbackTitle(String folderName) {
    final parts = folderName.split('_');
    if (parts.length > 1) {
      return parts.sublist(1).join(' ').replaceAll('-', ' ').toUpperCase();
    }
    return folderName;
  }

  Future<int> _calculateDirSize(Directory dir) async {
    int bytes = 0;
    try {
      final list = dir.listSync(recursive: true, followLinks: false);
      for (final f in list) {
        if (f is File) {
          bytes += f.lengthSync();
        }
      }
    } catch (_) {}
    return bytes;
  }
}
