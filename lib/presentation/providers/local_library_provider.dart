import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/api/websocket_service.dart';
import 'package:seanime_app/data/models/local_file_item.dart';
import 'package:seanime_app/data/models/show_local_file_item.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

import 'package:seanime_app/data/models/anime_entry.dart';

/// Item representando un show o anime emparejado localmente para exploración visual
class LocalMatchedShowItem {
  final int id; // mediaId para Anime, tmdbId para TMDB shows
  final String title;
  final String? coverImage;
  final String type; // 'anime' | 'tv' | 'movie'
  final int episodeCount;
  final int seasonCount;
  final String folderPath;
  final bool isTmdb;
  final List<String> localFilePaths;

  const LocalMatchedShowItem({
    required this.id,
    required this.title,
    this.coverImage,
    required this.type,
    required this.episodeCount,
    this.seasonCount = 1,
    required this.folderPath,
    this.isTmdb = false,
    this.localFilePaths = const [],
  });
}

class LocalLibraryState {
  final bool isLoading;
  final bool isScanning;
  final int scanProgress;
  final String scanStatus;
  final String mainPath;
  final List<String> additionalPaths;
  final Map<String, String> folderTypes; // path -> 'anime' | 'tv' | 'movie' | 'mixed'
  final List<LocalFileItem> localFiles;
  final ShowCollectionItem? showsCollection;
  final List<UnmatchedFolderGroup> unmatchedGroups;
  final List<LocalMatchedShowItem> matchedShows;
  final int matchedShowsCount;
  final int animeCount;
  final int tvShowsCount;
  final int moviesCount;
  final int localEpisodesCount;
  final int unmatchedFilesCount;
  final bool enhancedScan;
  final String? errorMessage;

  const LocalLibraryState({
    this.isLoading = false,
    this.isScanning = false,
    this.scanProgress = 0,
    this.scanStatus = '',
    this.mainPath = '',
    this.additionalPaths = const [],
    this.folderTypes = const {},
    this.localFiles = const [],
    this.showsCollection,
    this.unmatchedGroups = const [],
    this.matchedShows = const [],
    this.matchedShowsCount = 0,
    this.animeCount = 0,
    this.tvShowsCount = 0,
    this.moviesCount = 0,
    this.localEpisodesCount = 0,
    this.unmatchedFilesCount = 0,
    this.enhancedScan = true,
    this.errorMessage,
  });

  LocalLibraryState copyWith({
    bool? isLoading,
    bool? isScanning,
    int? scanProgress,
    String? scanStatus,
    String? mainPath,
    List<String>? additionalPaths,
    Map<String, String>? folderTypes,
    List<LocalFileItem>? localFiles,
    ShowCollectionItem? showsCollection,
    List<UnmatchedFolderGroup>? unmatchedGroups,
    List<LocalMatchedShowItem>? matchedShows,
    int? matchedShowsCount,
    int? animeCount,
    int? tvShowsCount,
    int? moviesCount,
    int? localEpisodesCount,
    int? unmatchedFilesCount,
    bool? enhancedScan,
    String? errorMessage,
  }) {
    return LocalLibraryState(
      isLoading: isLoading ?? this.isLoading,
      isScanning: isScanning ?? this.isScanning,
      scanProgress: scanProgress ?? this.scanProgress,
      scanStatus: scanStatus ?? this.scanStatus,
      mainPath: mainPath ?? this.mainPath,
      additionalPaths: additionalPaths ?? this.additionalPaths,
      folderTypes: folderTypes ?? this.folderTypes,
      localFiles: localFiles ?? this.localFiles,
      showsCollection: showsCollection ?? this.showsCollection,
      unmatchedGroups: unmatchedGroups ?? this.unmatchedGroups,
      matchedShows: matchedShows ?? this.matchedShows,
      matchedShowsCount: matchedShowsCount ?? this.matchedShowsCount,
      animeCount: animeCount ?? this.animeCount,
      tvShowsCount: tvShowsCount ?? this.tvShowsCount,
      moviesCount: moviesCount ?? this.moviesCount,
      localEpisodesCount: localEpisodesCount ?? this.localEpisodesCount,
      unmatchedFilesCount: unmatchedFilesCount ?? this.unmatchedFilesCount,
      enhancedScan: enhancedScan ?? this.enhancedScan,
      errorMessage: errorMessage,
    );
  }
}

class LocalLibraryNotifier extends Notifier<LocalLibraryState> {
  StreamSubscription? _wsSubscription;
  static const String _kFolderTypesPrefKey = 'local_library_folder_types';

  SeanimeRepository get _repository => ref.read(repositoryProvider);
  WebSocketService get _webSocketService => ref.read(webSocketServiceProvider);

  @override
  LocalLibraryState build() {
    _listenToEvents();
    ref.onDispose(() {
      _wsSubscription?.cancel();
    });
    Future.microtask(() => loadLibraryData());
    return const LocalLibraryState();
  }

  void _invalidateRelatedProviders() {
    FeedCacheService.instance.clearCache(FeedCacheService.kCacheAnimeCollection);
    FeedCacheService.instance.clearCache(FeedCacheService.kCacheContinueWatchingAnime);
    FeedCacheService.instance.clearCache(FeedCacheService.kCacheTrendingAnime);
    ref.invalidate(downloadedAnimeProvider);
    ref.invalidate(animeCollectionProvider);
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(activeDownloadsProvider);
    ref.invalidate(showsCollectionProvider);
    ref.invalidate(tmdbRecommendationsProvider);
    ref.invalidate(tmdbTrendingShowsProvider);
  }

  void _listenToEvents() {
    _wsSubscription?.cancel();
    _wsSubscription = _webSocketService.eventStream.listen((event) {
      final type = event['type'] as String?;
      final payload = event['payload'];

      if (type == 'scan-progress' && payload is num) {
        state = state.copyWith(scanProgress: payload.toInt(), isScanning: true);
      } else if (type == 'scan-status' && payload is String) {
        state = state.copyWith(scanStatus: payload, isScanning: true);
        if (payload.toLowerCase().contains('completed') || payload.toLowerCase().contains('completado')) {
          state = state.copyWith(isScanning: false, scanProgress: 100);
          _invalidateRelatedProviders();
          loadLibraryData();
        }
      }
    });
  }

  Future<void> loadLibraryData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      // 1. Fetch server settings for library paths
      final settings = await _repository.getServerSettings();
      final librarySettings = settings?['library'] as Map<String, dynamic>?;
      final mainPath = librarySettings?['libraryPath'] as String? ?? '';

      final rawAdditional = librarySettings?['libraryPaths'];
      final additionalPaths = <String>[];
      if (rawAdditional is List) {
        for (final p in rawAdditional) {
          if (p is String && p.trim().isNotEmpty) {
            additionalPaths.add(p.trim());
          }
        }
      }

      // 2. Load folder types from local storage
      final prefs = await SharedPreferences.getInstance();
      final rawFolderTypes = prefs.getString(_kFolderTypesPrefKey);
      final folderTypes = <String, String>{};
      if (rawFolderTypes != null && rawFolderTypes.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawFolderTypes) as Map<String, dynamic>;
          decoded.forEach((k, v) {
            if (v is String) folderTypes[k] = v;
          });
        } catch (_) {}
      }

      // Default main path and additional paths to 'anime' if not set
      if (mainPath.isNotEmpty && !folderTypes.containsKey(mainPath)) {
        folderTypes[mainPath] = _inferFolderType(mainPath);
      }
      for (final p in additionalPaths) {
        if (!folderTypes.containsKey(p)) {
          folderTypes[p] = _inferFolderType(p);
        }
      }

      // 3. Fetch local anime files, shows collection & raw library collection
      final rawAnimeFiles = await _repository.getLocalFiles();
      final rawShowsCol = await _repository.getShowsCollection();
      final rawCol = await _repository.getRawLibraryCollection();

      final allConfiguredPaths = <String>[
        if (mainPath.isNotEmpty) mainPath.replaceAll('\\', '/').toLowerCase(),
        ...additionalPaths.map((p) => p.replaceAll('\\', '/').toLowerCase()),
      ];

      // If no library paths configured at all, wipe any stale files from state and server
      if (allConfiguredPaths.isEmpty) {
        if (rawAnimeFiles.isNotEmpty || (rawShowsCol != null && rawShowsCol.shows.isNotEmpty)) {
          _repository.scanShows().ignore();
          _repository.scanLibrary().ignore();
          _invalidateRelatedProviders();
        }

        state = state.copyWith(
          isLoading: false,
          mainPath: '',
          additionalPaths: const [],
          folderTypes: folderTypes,
          localFiles: const [],
          showsCollection: null,
          unmatchedGroups: const [],
          matchedShows: const [],
          matchedShowsCount: 0,
          animeCount: 0,
          tvShowsCount: 0,
          moviesCount: 0,
          localEpisodesCount: 0,
          unmatchedFilesCount: 0,
        );
        _invalidateRelatedProviders();
        return;
      }

      bool isPathInConfigured(String p) {
        if (p.isEmpty) return false;
        final norm = p.replaceAll('\\', '/').toLowerCase();
        return allConfiguredPaths.any((cp) => norm.startsWith(cp));
      }

      final animeFiles = rawAnimeFiles.where((f) => isPathInConfigured(f.path)).toList();
      final showsCol = rawShowsCol != null
          ? ShowCollectionItem(
              shows: rawShowsCol.shows.where((s) => s.files.isEmpty || isPathInConfigured(s.files.first.path)).toList(),
              unmatched: rawShowsCol.unmatched.where((u) => isPathInConfigured(u.path)).toList(),
              totalFiles: rawShowsCol.shows
                  .where((s) => s.files.isEmpty || isPathInConfigured(s.files.first.path))
                  .fold<int>(0, (sum, s) => sum + s.files.length) + rawShowsCol.unmatched.where((u) => isPathInConfigured(u.path)).length,
              matchedShowsCount: rawShowsCol.shows.where((s) => s.tmdbId > 0 && (s.files.isEmpty || isPathInConfigured(s.files.first.path))).length,
              localEpisodesCount: rawShowsCol.shows
                  .where((s) => s.files.isEmpty || isPathInConfigured(s.files.first.path))
                  .fold<int>(0, (sum, s) => sum + s.files.length),
              unmatchedFilesCount: rawShowsCol.unmatched.where((u) => isPathInConfigured(u.path)).length,
            )
          : null;

      // 4. Calculate statistics and unmatched groups
      final matchedMediaIds = <int>{};
      int animeEps = 0;
      final unmatchedFiles = <LocalFileItem>[];

      for (final f in animeFiles) {
        animeEps++;
        if (f.isMatched) {
          matchedMediaIds.add(f.mediaId);
        } else if (f.isUnmatched) {
          unmatchedFiles.add(f);
        }
      }

      // Merge unmatched from rawCol if any
      if (rawCol != null) {
        final rawUnmatchedList = rawCol['unmatchedLocalFiles'] as List?;
        if (rawUnmatchedList != null) {
          for (final item in rawUnmatchedList) {
            if (item is Map) {
              final parsed = LocalFileItem.fromJson(Map<String, dynamic>.from(item));
              if (parsed.isUnmatched && isPathInConfigured(parsed.path) && !unmatchedFiles.any((e) => e.path == parsed.path)) {
                unmatchedFiles.add(parsed);
              }
            }
          }
        }
        final rawUnmatchedGroups = rawCol['unmatchedGroups'] as List?;
        if (rawUnmatchedGroups != null) {
          for (final g in rawUnmatchedGroups) {
            if (g is Map && g['localFiles'] is List) {
              for (final fItem in g['localFiles'] as List) {
                if (fItem is Map) {
                  final parsed = LocalFileItem.fromJson(Map<String, dynamic>.from(fItem));
                  if (parsed.isUnmatched && isPathInConfigured(parsed.path) && !unmatchedFiles.any((e) => e.path == parsed.path)) {
                    unmatchedFiles.add(parsed);
                  }
                }
              }
            }
          }
        }
      }

      // Add unmatched from shows collection if any
      if (showsCol != null) {
        for (final sf in showsCol.unmatched) {
          if (isPathInConfigured(sf.path) && !unmatchedFiles.any((e) => e.path == sf.path)) {
            unmatchedFiles.add(LocalFileItem(
              path: sf.path,
              name: sf.name,
              mediaId: 0,
              parsedTitle: sf.parsedTitle,
              parsedSeason: '${sf.season}',
              parsedEpisode: '${sf.episode}',
              folderPath: sf.folderPath,
              folderName: sf.folderName,
            ));
          }
        }
      }

      // Group unmatched files by folder path
      final groupMap = <String, List<LocalFileItem>>{};
      for (final f in unmatchedFiles) {
        final key = f.folderPath.isNotEmpty ? f.folderPath : f.folderName;
        groupMap.putIfAbsent(key, () => []).add(f);
      }

      final unmatchedGroups = groupMap.entries.map((entry) {
        final groupFiles = entry.value;
        final first = groupFiles.first;
        final guessed = first.parsedTitle ?? first.folderName;
        final lower = first.folderPath.toLowerCase();
        final isTmdbGuess = lower.contains('serie') ||
            lower.contains('show') ||
            lower.contains('tv') ||
            lower.contains('movie') ||
            lower.contains('pelicula') ||
            lower.contains('película');
        return UnmatchedFolderGroup(
          folderPath: first.folderPath,
          folderName: first.folderName,
          guessedTitle: guessed,
          files: groupFiles,
          isTmdb: isTmdbGuess,
        );
      }).toList();

      int tvCount = 0;
      int movieCount = 0;
      if (showsCol != null) {
        for (final s in showsCol.shows) {
          if (s.mediaType == 'movie') {
            movieCount++;
          } else {
            tvCount++;
          }
        }
      }

      // Build matched items (Anime + TV Shows + Movies)
      final matchedShows = <LocalMatchedShowItem>[];
      final animeGrouped = <int, List<LocalFileItem>>{};
      for (final f in animeFiles) {
        if (f.isMatched) {
          animeGrouped.putIfAbsent(f.mediaId, () => []).add(f);
        }
      }

      final cachedAnime = FeedCacheService.instance.getAnimeList(FeedCacheService.kCacheAnimeCollection);
      final animeMetaMap = <int, AnimeEntry>{};
      for (final a in cachedAnime) {
        animeMetaMap[a.mediaId] = a;
      }

      for (final entry in animeGrouped.entries) {
        final mId = entry.key;
        final files = entry.value;
        final first = files.first;
        final meta = animeMetaMap[mId];

        final title = meta?.title.isNotEmpty == true
            ? meta!.title
            : (first.parsedTitle ?? first.folderName);
        final cover = meta?.coverImage;

        matchedShows.add(LocalMatchedShowItem(
          id: mId,
          title: title,
          coverImage: cover,
          type: 'anime',
          episodeCount: files.length,
          seasonCount: 1,
          folderPath: first.folderPath,
          isTmdb: false,
          localFilePaths: files.map((f) => f.path).toList(),
        ));
      }

      if (showsCol != null) {
        for (final s in showsCol.shows) {
          final firstFile = s.files.isNotEmpty ? s.files.first : null;
          matchedShows.add(LocalMatchedShowItem(
            id: s.tmdbId,
            title: s.title.isNotEmpty ? s.title : (firstFile?.parsedTitle ?? 'Show'),
            coverImage: null,
            type: s.mediaType == 'movie' ? 'movie' : 'tv',
            episodeCount: s.episodeCount > 0 ? s.episodeCount : s.files.length,
            seasonCount: s.seasonCount > 0 ? s.seasonCount : s.seasons.length,
            folderPath: firstFile?.folderPath ?? '',
            isTmdb: true,
            localFilePaths: s.files.map((f) => f.path).toList(),
          ));
        }
      }

      matchedShows.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

      final totalLocalEps = animeEps + (showsCol?.localEpisodesCount ?? 0);
      final totalMatched = matchedMediaIds.length + (showsCol?.matchedShowsCount ?? 0);

      state = state.copyWith(
        isLoading: false,
        mainPath: mainPath,
        additionalPaths: additionalPaths,
        folderTypes: folderTypes,
        localFiles: animeFiles,
        showsCollection: showsCol,
        unmatchedGroups: unmatchedGroups,
        matchedShows: matchedShows,
        matchedShowsCount: totalMatched,
        animeCount: matchedMediaIds.length,
        tvShowsCount: tvCount,
        moviesCount: movieCount,
        localEpisodesCount: totalLocalEps,
        unmatchedFilesCount: unmatchedFiles.length,
      );

      _invalidateRelatedProviders();
    } catch (e) {
      debugPrint('[LocalLibraryNotifier] Error loading data: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  String _inferFolderType(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('movie') || lower.contains('pelicula') || lower.contains('película')) {
      return 'movie';
    }
    if (lower.contains('serie') || lower.contains('show') || lower.contains('tv')) {
      return 'tv';
    }
    return 'anime';
  }

  Future<void> setFolderType(String folderPath, String type) async {
    final next = Map<String, String>.from(state.folderTypes);
    next[folderPath] = type;
    state = state.copyWith(folderTypes: next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFolderTypesPrefKey, jsonEncode(next));
  }

  void toggleEnhancedScan(bool value) {
    state = state.copyWith(enhancedScan: value);
  }

  Future<bool> setMainPath(String newPath, {String type = 'anime'}) async {
    final trimmed = newPath.trim();
    bool ok;
    if (trimmed.isEmpty && state.mainPath.isNotEmpty) {
      ok = await _repository.removeLibraryFolder(state.mainPath, isMain: true);
      if (!ok) {
        ok = await _repository.patchServerSetting('library.libraryPath', '');
      }
    } else {
      ok = await _repository.patchServerSetting('library.libraryPath', trimmed);
    }

    if (ok) {
      final nextTypes = Map<String, String>.from(state.folderTypes);
      if (trimmed.isNotEmpty) {
        nextTypes[trimmed] = type;
      } else if (state.mainPath.isNotEmpty) {
        nextTypes.remove(state.mainPath);
      }
      state = state.copyWith(folderTypes: nextTypes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFolderTypesPrefKey, jsonEncode(nextTypes));

      await _repository.scanShows(folderTypes: nextTypes);
      await _repository.scanLibrary();
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> addAdditionalPath(String newPath, {String type = 'anime'}) async {
    final trimmed = newPath.trim();
    if (trimmed.isEmpty || state.additionalPaths.contains(trimmed) || state.mainPath == trimmed) {
      return false;
    }
    final next = [...state.additionalPaths, trimmed];
    final ok = await _repository.patchServerSetting('library.libraryPaths', next);
    if (ok) {
      await setFolderType(trimmed, type);
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> removeAdditionalPath(String pathToRemove) async {
    final next = state.additionalPaths.where((p) => p != pathToRemove).toList();
    bool ok = await _repository.removeLibraryFolder(pathToRemove, isMain: false);
    if (!ok) {
      ok = await _repository.patchServerSetting('library.libraryPaths', next);
    }
    if (ok) {
      final nextTypes = Map<String, String>.from(state.folderTypes)..remove(pathToRemove);
      state = state.copyWith(folderTypes: nextTypes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kFolderTypesPrefKey, jsonEncode(nextTypes));

      await _repository.scanShows(folderTypes: nextTypes);
      await _repository.scanLibrary();
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> scanLibrary() async {
    if (state.isScanning) return false;
    state = state.copyWith(
      isScanning: true,
      scanProgress: 0,
      scanStatus: 'Iniciando escaneo...',
    );

    try {
      final success = await _repository.scanLibrary(enhanced: state.enhancedScan);
      await _repository.scanShows(folderTypes: state.folderTypes);

      if (!success) {
        state = state.copyWith(isScanning: false, scanStatus: 'Error al iniciar escaneo');
      } else {
        _invalidateRelatedProviders();
      }

      Future.delayed(const Duration(seconds: 2), () {
        _invalidateRelatedProviders();
        loadLibraryData();
      });
      return success;
    } catch (e) {
      state = state.copyWith(isScanning: false, scanStatus: e.toString());
      return false;
    }
  }

  Future<bool> manualMatchGroup(UnmatchedFolderGroup group, int mediaId) async {
    final paths = group.files.map((f) => f.path).toList();
    final ok = await _repository.manualMatchLocalFiles(paths, mediaId);
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> matchShowGroup({
    required UnmatchedFolderGroup group,
    required int tmdbId,
    required String mediaType,
    required String title,
  }) async {
    final paths = group.files.map((f) => f.path).toList();
    final ok = await _repository.matchShow(
      paths: paths,
      folderPath: group.folderPath,
      tmdbId: tmdbId,
      mediaType: mediaType,
      title: title,
    );
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> unmatchAnime(int mediaId) async {
    final ok = await _repository.bulkActionAnimeEntry(mediaId, 'unmatch');
    if (!ok) {
      final paths = state.localFiles
          .where((f) => f.mediaId == mediaId)
          .map((f) => f.path)
          .toList();
      if (paths.isNotEmpty) {
        await _repository.updateLocalFilesAction(paths, 'unmatch');
      }
    }
    _invalidateRelatedProviders();
    await loadLibraryData();
    return true;
  }

  Future<bool> unmatchShowItem(LocalMatchedShowItem item) async {
    bool ok;
    if (item.isTmdb) {
      ok = await _repository.unmatchShow(
        paths: item.localFilePaths,
        folderPath: item.folderPath,
      );
    } else {
      ok = await unmatchAnime(item.id);
    }
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> unmatchShowGroup(UnmatchedFolderGroup group) async {
    final paths = group.files.map((f) => f.path).toList();
    final okShow = await _repository.unmatchShow(
      paths: paths,
      folderPath: group.folderPath,
    );
    final okAnime = await _repository.updateLocalFilesAction(paths, 'unmatch');
    _invalidateRelatedProviders();
    await loadLibraryData();
    return okShow || okAnime;
  }

  Future<bool> ignoreGroup(UnmatchedFolderGroup group) async {
    final paths = group.files.map((f) => f.path).toList();
    final ok = await _repository.updateLocalFilesAction(paths, 'ignore');
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> unmatchFile(String path) async {
    final ok = await _repository.updateLocalFilesAction([path], 'unmatch');
    await _repository.unmatchShow(paths: [path]);
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }
}

final localLibraryProvider =
    NotifierProvider.autoDispose<LocalLibraryNotifier, LocalLibraryState>(LocalLibraryNotifier.new);

