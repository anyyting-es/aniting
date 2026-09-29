import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' as path_provider;

/// Gestiona la resolución y estructura de carpetas de almacenamiento para Aniting.
///
/// Separa de manera estricta:
/// 1. Working / Cache Directory (Caché temporal, chunks de streaming, sockets)
/// 2. Downloads Directory (Descargas permanentes en Aniting/Downloads/Manga y Aniting/Downloads/Anime)
class AppStoragePaths {
  AppStoragePaths._();

  /// Nombre de la carpeta raíz de la aplicación para descargas
  static const String appFolderName = 'Aniting';
  static const String downloadsSubfolder = 'Downloads';
  static const String mangaSubfolder = 'Manga';
  static const String animeSubfolder = 'Anime';

  /// Obtiene la ruta predeterminada para el directorio de descargas base:
  /// ej: /storage/emulated/0/Download/Aniting/Downloads (Android) o ~/Downloads/Aniting/Downloads (Desktop)
  static Future<String> getDefaultDownloadsBasePath() async {
    if (Platform.isAndroid) {
      // En Android, preferimos la carpeta pública Download del sistema (tiene permisos en Android 10+)
      const primaryExt = '/storage/emulated/0';
      final primaryDir = Directory(primaryExt);
      if (primaryDir.existsSync()) {
        return '$primaryExt/Download/$appFolderName/$downloadsSubfolder';
      }

      try {
        final externalDir = await path_provider.getExternalStorageDirectory();
        if (externalDir != null) {
          return '${externalDir.path}/$appFolderName/$downloadsSubfolder';
        }
      } catch (e) {
        debugPrint('Error getting Android external storage dir: $e');
      }

      final docs = await path_provider.getApplicationDocumentsDirectory();
      return '${docs.path}/$appFolderName/$downloadsSubfolder';
    }

    // Desktop (Linux, Windows, macOS)
    try {
      final downloadsDir = await path_provider.getDownloadsDirectory();
      if (downloadsDir != null) {
        return '${downloadsDir.path}/$appFolderName/$downloadsSubfolder';
      }
    } catch (e) {
      debugPrint('Error getting desktop downloads dir: $e');
    }

    // Fallback con variables de entorno HOME / USERPROFILE
    final home = Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE'] ??
        Directory.current.path;
    return '$home/Downloads/$appFolderName/$downloadsSubfolder';
  }

  /// Retorna y asegura la creación del directorio base de descargas:
  /// `<base>/Aniting/Downloads`
  static Future<Directory> getDownloadsDirectory({String? customBase}) async {
    final basePath = customBase != null && customBase.trim().isNotEmpty
        ? customBase.trim()
        : await getDefaultDownloadsBasePath();
    final dir = Directory(basePath);
    try {
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } catch (e) {
      // Fallback: si falla la creación (permisos), usar documentos internos de la app
      debugPrint('Error creating downloads dir at $basePath: $e');
      final docs = await path_provider.getApplicationDocumentsDirectory();
      final fallback = Directory('${docs.path}/$appFolderName/$downloadsSubfolder');
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback;
    }
  }

  /// Retorna y asegura la creación del directorio de descargas de Manga:
  /// `<base>/Aniting/Downloads/Manga`
  static Future<Directory> getMangaDownloadsDirectory({String? customBase}) async {
    final baseDir = await getDownloadsDirectory(customBase: customBase);
    final mangaDir = Directory('${baseDir.path}/$mangaSubfolder');
    if (!await mangaDir.exists()) {
      await mangaDir.create(recursive: true);
    }
    return mangaDir;
  }

  /// Retorna y asegura la creación del directorio de descargas de Anime:
  /// `<base>/Aniting/Downloads/Anime`
  static Future<Directory> getAnimeDownloadsDirectory({String? customBase}) async {
    final baseDir = await getDownloadsDirectory(customBase: customBase);
    final animeDir = Directory('${baseDir.path}/$animeSubfolder');
    if (!await animeDir.exists()) {
      await animeDir.create(recursive: true);
    }
    return animeDir;
  }

  /// Retorna la carpeta de un Manga en disco, buscando si ya existe por ID
  /// o creándola con el patrón: `<mediaId>_<slug>` o `<mediaId>`.
  static Future<Directory> getMangaSeriesDirectory(
    int mediaId, {
    String? slug,
    String? customBase,
  }) async {
    final mangaRoot = await getMangaDownloadsDirectory(customBase: customBase);

    // 1. Verificar si ya existe una carpeta para este ID
    if (await mangaRoot.exists()) {
      final entries = mangaRoot.listSync();
      for (final entry in entries) {
        if (entry is Directory) {
          final segments = entry.uri.pathSegments.where((s) => s.isNotEmpty).toList();
          final dirName = segments.isNotEmpty ? segments.last : '';
          if (dirName == '$mediaId' || dirName.startsWith('${mediaId}_')) {
            return entry;
          }
        }
      }
    }

    // 2. Si no existe, crear con `<mediaId>_<slug>` sanitizado
    final sanitizedSlug = slug != null && slug.trim().isNotEmpty
        ? _sanitizeFolderName(slug.trim())
        : null;
    final folderName = sanitizedSlug != null && sanitizedSlug.isNotEmpty
        ? '${mediaId}_$sanitizedSlug'
        : '$mediaId';

    final targetDir = Directory('${mangaRoot.path}/$folderName');
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    return targetDir;
  }

  static String _sanitizeFolderName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }
}
