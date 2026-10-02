import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';

/// Servicio de almacenamiento local fuera de línea para el seguimiento de anime y manga.
/// Permite navegar, reproducir episodios, leer capítulos y organizar listas
/// de forma 100% autónoma sin requerir una cuenta de AniList conectada.
class OfflineLibraryService {
  static OfflineLibraryService? _instance;
  static SharedPreferences? _cachedPrefs;

  static const String _kAnimeCollectionKey = 'local_offline_anime_entries_v1';
  static const String _kMangaCollectionKey = 'local_offline_manga_entries_v1';

  static OfflineLibraryService get instance => _instance ??= OfflineLibraryService._();

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
    if (_instance != null) {
      _instance!._preloadFromPrefs(prefs);
    }
  }

  OfflineLibraryService._() {
    if (_cachedPrefs != null) {
      _preloadFromPrefs(_cachedPrefs!);
    } else {
      _initAsync();
    }
  }

  final Map<int, AnimeEntry> _animeEntries = {};
  final Map<int, MangaEntry> _mangaEntries = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  @visibleForTesting
  void clearMemoryForTesting() {
    _animeEntries.clear();
    _mangaEntries.clear();
  }

  Future<void> _initAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _preloadFromPrefs(prefs);
    } catch (e) {
      debugPrint('[OfflineLibraryService] Error in async init: $e');
    }
  }

  void _preloadFromPrefs(SharedPreferences prefs) {
    try {
      // 1. Preload Anime
      final rawAnime = prefs.getString(_kAnimeCollectionKey);
      if (rawAnime != null && rawAnime.isNotEmpty) {
        final decoded = jsonDecode(rawAnime);
        if (decoded is List) {
          _animeEntries.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = AnimeEntry.fromJson(item);
              if (entry.mediaId > 0) {
                _animeEntries[entry.mediaId] = entry;
              }
            }
          }
        }
      }

      // 2. Preload Manga
      final rawManga = prefs.getString(_kMangaCollectionKey);
      if (rawManga != null && rawManga.isNotEmpty) {
        final decoded = jsonDecode(rawManga);
        if (decoded is List) {
          _mangaEntries.clear();
          for (final item in decoded) {
            if (item is Map<String, dynamic>) {
              final entry = MangaEntry.fromJson(item);
              if (entry.mediaId > 0) {
                _mangaEntries[entry.mediaId] = entry;
              }
            }
          }
        }
      }

      _isLoaded = true;
    } catch (e) {
      debugPrint('[OfflineLibraryService] Error preloading data: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // ANIME
  // ═══════════════════════════════════════════════════════════════════════

  /// Retorna la colección completa de anime guardada localmente.
  List<AnimeEntry> getAnimeCollection() {
    final list = _animeEntries.values.toList();
    list.sort((a, b) => b.effectiveTimestamp.compareTo(a.effectiveTimestamp));
    return list;
  }

  /// Retorna la lista de anime en seguimiento para "Seguir Viendo".
  List<AnimeEntry> getContinueWatching({String? langCode}) {
    final list = _animeEntries.values.where((e) {
      final isFinished = e.totalEpisodes != null &&
          e.totalEpisodes! > 0 &&
          e.progress >= e.totalEpisodes!;
      final isDropped = e.status.toUpperCase() == 'DROPPED';
      final isPaused = e.status.toUpperCase() == 'PAUSED';
      final isPlanning = e.status.toUpperCase() == 'PLANNING';
      if (isFinished || isDropped || isPaused || isPlanning) return false;
      return e.status.toUpperCase() == 'CURRENT' || e.status.toUpperCase() == 'WATCHING';
    }).toList();

    list.sort((a, b) => b.effectiveTimestamp.compareTo(a.effectiveTimestamp));

    // Enriquecer con metadata de episodio siguiente desde AniZip en RAM si existe
    return list.map((entry) {
      final nextEp = (entry.episodeNumber != null && entry.episodeNumber! > entry.progress)
          ? entry.episodeNumber!
          : (entry.progress + 1);
      final aniZip = FeedCacheService.instance.getAniZipData(entry.mediaId);
      final epData = aniZip?.getEpisode(nextEp);

      if (epData != null) {
        return entry.copyWith(
          episodeNumber: nextEp,
          currentEpisode: nextEp,
          episodeTitle: epData.displayTitleForLang(langCode).isNotEmpty ? epData.displayTitleForLang(langCode) : entry.episodeTitle,
          episodeThumbnail: (epData.image != null && epData.image!.isNotEmpty) ? epData.image : entry.episodeThumbnail,
        );
      }
      return entry.copyWith(
        episodeNumber: nextEp,
        currentEpisode: nextEp,
      );
    }).toList();
  }

  /// Registra el inicio o reproducción de un episodio para un anime.
  Future<void> recordAnimeWatch({
    required int mediaId,
    required String title,
    int? episodeNumber,
    String? episodeTitle,
    String? episodeThumbnail,
    String? coverImage,
    String? bannerImage,
    String? characterImage,
    int? totalEpisodes,
    List<String>? genres,
    double? score,
    String? format,
    String? description,
    String? coverColor,
    int? year,
    String? englishTitle,
    String? romajiTitle,
  }) async {
    if (mediaId <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _animeEntries[mediaId];
    final epNum = episodeNumber ?? existing?.episodeNumber ?? 1;

    final isCompleted = totalEpisodes != null && totalEpisodes > 0 && epNum >= totalEpisodes;
    final status = isCompleted ? 'COMPLETED' : 'CURRENT';

    if (existing != null) {
      final newProgress = (epNum > 1 && existing.progress < epNum - 1)
          ? epNum - 1
          : existing.progress;

      _animeEntries[mediaId] = existing.copyWith(
        title: title.isNotEmpty && title != 'Anime' ? title : existing.title,
        englishTitle: englishTitle ?? existing.englishTitle,
        romajiTitle: romajiTitle ?? existing.romajiTitle,
        coverImage: coverImage ?? existing.coverImage,
        coverColor: coverColor ?? existing.coverColor,
        bannerImage: bannerImage ?? existing.bannerImage,
        progress: newProgress,
        totalEpisodes: totalEpisodes ?? existing.totalEpisodes,
        status: status,
        score: score ?? existing.score,
        format: format ?? existing.format,
        description: description ?? existing.description,
        genres: (genres != null && genres.isNotEmpty) ? genres : existing.genres,
        currentEpisode: epNum,
        episodeNumber: epNum,
        episodeTitle: (episodeTitle != null && episodeTitle.isNotEmpty) ? episodeTitle : existing.episodeTitle,
        episodeThumbnail: episodeThumbnail ?? existing.episodeThumbnail,
        lastWatchedTime: now,
        updatedAt: now,
        year: year ?? existing.year,
      );
    } else {
      _animeEntries[mediaId] = AnimeEntry(
        id: mediaId,
        mediaId: mediaId,
        title: title,
        englishTitle: englishTitle,
        romajiTitle: romajiTitle,
        coverImage: coverImage,
        coverColor: coverColor,
        bannerImage: bannerImage,
        progress: (epNum > 1) ? epNum - 1 : 0,
        totalEpisodes: totalEpisodes,
        status: status,
        score: score,
        format: format,
        description: description,
        genres: genres ?? [],
        currentEpisode: epNum,
        episodeNumber: epNum,
        episodeTitle: episodeTitle ?? 'Episodio $epNum',
        episodeThumbnail: episodeThumbnail,
        lastWatchedTime: now,
        updatedAt: now,
        year: year,
      );
    }

    await _persistAnime();
  }

  /// Actualiza el progreso completado de un anime (ej. al superar el 80% o manualmente).
  Future<void> updateAnimeProgress({
    required int mediaId,
    required int episodeNumber,
    int? totalEpisodes,
  }) async {
    if (mediaId <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _animeEntries[mediaId];
    if (existing == null) return;

    final tot = totalEpisodes ?? existing.totalEpisodes;
    final isCompleted = tot != null && tot > 0 && episodeNumber >= tot;
    final nextEp = isCompleted ? episodeNumber : episodeNumber + 1;

    _animeEntries[mediaId] = existing.copyWith(
      progress: episodeNumber,
      status: isCompleted ? 'COMPLETED' : 'CURRENT',
      currentEpisode: nextEp,
      episodeNumber: nextEp,
      updatedAt: now,
      lastWatchedTime: now,
    );

    await _persistAnime();
  }

  /// Guarda o actualiza un anime desde el modal de edición de listas (EditEntryModal).
  Future<void> saveAnimeEntryFromEdit({
    required int mediaId,
    required String title,
    required String status,
    double? score,
    int? progress,
    int? totalCount,
    int? repeat,
  }) async {
    if (mediaId <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _animeEntries[mediaId];

    final prog = progress ?? existing?.progress ?? 0;
    final tot = totalCount ?? existing?.totalEpisodes;
    final isCompleted = (status == 'COMPLETED') || (tot != null && tot > 0 && prog >= tot);
    final effStatus = isCompleted ? 'COMPLETED' : status;

    if (existing != null) {
      _animeEntries[mediaId] = existing.copyWith(
        title: title.isNotEmpty ? title : existing.title,
        status: effStatus,
        score: score ?? existing.score,
        progress: prog,
        totalEpisodes: tot,
        updatedAt: now,
      );
    } else {
      _animeEntries[mediaId] = AnimeEntry(
        id: mediaId,
        mediaId: mediaId,
        title: title,
        progress: prog,
        totalEpisodes: tot,
        status: effStatus,
        score: score,
        updatedAt: now,
        lastWatchedTime: now,
      );
    }

    await _persistAnime();
  }

  /// Elimina un anime de la biblioteca local.
  Future<void> deleteAnimeEntry(int mediaId) async {
    _animeEntries.remove(mediaId);
    await _persistAnime();
  }

  Future<void> _persistAnime() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final list = _animeEntries.values.map((e) => e.toJson()).toList();
      await prefs.setString(_kAnimeCollectionKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[OfflineLibraryService] Error persisting anime: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // MANGA
  // ═══════════════════════════════════════════════════════════════════════

  /// Retorna la colección completa de manga guardada localmente.
  List<MangaEntry> getMangaCollection() {
    final list = _mangaEntries.values.toList();
    list.sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    return list;
  }

  /// Retorna la lista de manga en seguimiento para "Seguir Leyendo".
  List<MangaEntry> getContinueReading() {
    final list = _mangaEntries.values.where((e) {
      final isFinished = e.totalChapters != null &&
          e.totalChapters! > 0 &&
          e.progress >= e.totalChapters!;
      final isDropped = e.status.toUpperCase() == 'DROPPED';
      final isPaused = e.status.toUpperCase() == 'PAUSED';
      final isPlanning = e.status.toUpperCase() == 'PLANNING';
      if (isFinished || isDropped || isPaused || isPlanning) return false;
      return e.status.toUpperCase() == 'CURRENT' || e.status.toUpperCase() == 'READING';
    }).toList();

    list.sort((a, b) => (b.updatedAt ?? 0).compareTo(a.updatedAt ?? 0));
    return list;
  }

  /// Registra la lectura de un capítulo de manga.
  Future<void> recordMangaRead({
    required int mediaId,
    required String title,
    required double chapterNumber,
    String? chapterTitle,
    String? coverImage,
    String? bannerImage,
    int? totalChapters,
    List<String>? genres,
    double? score,
    String? description,
    String? format,
    int? year,
    String? englishTitle,
    String? romajiTitle,
  }) async {
    if (mediaId <= 0) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _mangaEntries[mediaId];
    final chInt = chapterNumber.floor();

    final isCompleted = totalChapters != null && totalChapters > 0 && chInt >= totalChapters;
    final status = isCompleted ? 'COMPLETED' : 'CURRENT';

    if (existing != null) {
      final newProgress = chInt > existing.progress ? chInt : existing.progress;
      _mangaEntries[mediaId] = existing.copyWith(
        title: title.isNotEmpty && title != 'Manga' ? title : existing.title,
        englishTitle: englishTitle ?? existing.englishTitle,
        romajiTitle: romajiTitle ?? existing.romajiTitle,
        coverImage: coverImage ?? existing.coverImage,
        bannerImage: bannerImage ?? existing.bannerImage,
        progress: newProgress,
        totalChapters: totalChapters ?? existing.totalChapters,
        status: status,
        score: score ?? existing.score,
        format: format ?? existing.format,
        description: description ?? existing.description,
        genres: (genres != null && genres.isNotEmpty) ? genres : existing.genres,
        currentChapter: chInt,
        chapterTitle: chapterTitle ?? existing.chapterTitle,
        updatedAt: now,
        year: year ?? existing.year,
      );
    } else {
      _mangaEntries[mediaId] = MangaEntry(
        id: mediaId,
        mediaId: mediaId,
        title: title,
        englishTitle: englishTitle,
        romajiTitle: romajiTitle,
        coverImage: coverImage,
        bannerImage: bannerImage,
        progress: chInt,
        totalChapters: totalChapters,
        status: status,
        score: score,
        format: format,
        description: description,
        genres: genres ?? [],
        currentChapter: chInt,
        chapterTitle: chapterTitle,
        updatedAt: now,
        year: year,
      );
    }

    await _persistManga();
  }

  /// Actualiza el progreso de lectura de un manga.
  Future<void> updateMangaProgress({
    required int mediaId,
    required double chapterNumber,
    int? totalChapters,
  }) async {
    if (mediaId <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _mangaEntries[mediaId];
    if (existing == null) return;

    final chInt = chapterNumber.floor();
    final tot = totalChapters ?? existing.totalChapters;
    final isCompleted = tot != null && tot > 0 && chInt >= tot;

    _mangaEntries[mediaId] = existing.copyWith(
      progress: chInt > existing.progress ? chInt : existing.progress,
      status: isCompleted ? 'COMPLETED' : 'CURRENT',
      currentChapter: chInt,
      updatedAt: now,
    );

    await _persistManga();
  }

  /// Guarda o actualiza un manga desde el modal de edición de listas (EditEntryModal).
  Future<void> saveMangaEntryFromEdit({
    required int mediaId,
    required String title,
    required String status,
    double? score,
    int? progress,
    int? totalCount,
  }) async {
    if (mediaId <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final existing = _mangaEntries[mediaId];

    final prog = progress ?? existing?.progress ?? 0;
    final tot = totalCount ?? existing?.totalChapters;
    final isCompleted = (status == 'COMPLETED') || (tot != null && tot > 0 && prog >= tot);
    final effStatus = isCompleted ? 'COMPLETED' : status;

    if (existing != null) {
      _mangaEntries[mediaId] = existing.copyWith(
        title: title.isNotEmpty ? title : existing.title,
        status: effStatus,
        score: score ?? existing.score,
        progress: prog,
        totalChapters: tot,
        updatedAt: now,
      );
    } else {
      _mangaEntries[mediaId] = MangaEntry(
        id: mediaId,
        mediaId: mediaId,
        title: title,
        progress: prog,
        totalChapters: tot,
        status: effStatus,
        score: score,
        updatedAt: now,
      );
    }

    await _persistManga();
  }

  /// Elimina un manga de la biblioteca local.
  Future<void> deleteMangaEntry(int mediaId) async {
    _mangaEntries.remove(mediaId);
    await _persistManga();
  }

  Future<void> _persistManga() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      final list = _mangaEntries.values.map((e) => e.toJson()).toList();
      await prefs.setString(_kMangaCollectionKey, jsonEncode(list));
    } catch (e) {
      debugPrint('[OfflineLibraryService] Error persisting manga: $e');
    }
  }
}
