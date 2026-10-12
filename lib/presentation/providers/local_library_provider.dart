import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/api/websocket_service.dart';
import 'package:seanime_app/data/models/local_file_item.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

class LocalLibraryState {
  final bool isLoading;
  final bool isScanning;
  final int scanProgress;
  final String scanStatus;
  final String mainPath;
  final List<String> additionalPaths;
  final List<LocalFileItem> localFiles;
  final List<UnmatchedFolderGroup> unmatchedGroups;
  final int matchedShowsCount;
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
    this.localFiles = const [],
    this.unmatchedGroups = const [],
    this.matchedShowsCount = 0,
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
    List<LocalFileItem>? localFiles,
    List<UnmatchedFolderGroup>? unmatchedGroups,
    int? matchedShowsCount,
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
      localFiles: localFiles ?? this.localFiles,
      unmatchedGroups: unmatchedGroups ?? this.unmatchedGroups,
      matchedShowsCount: matchedShowsCount ?? this.matchedShowsCount,
      localEpisodesCount: localEpisodesCount ?? this.localEpisodesCount,
      unmatchedFilesCount: unmatchedFilesCount ?? this.unmatchedFilesCount,
      enhancedScan: enhancedScan ?? this.enhancedScan,
      errorMessage: errorMessage,
    );
  }
}

class LocalLibraryNotifier extends Notifier<LocalLibraryState> {
  StreamSubscription? _wsSubscription;

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
    ref.invalidate(downloadedAnimeProvider);
    ref.invalidate(animeCollectionProvider);
    ref.invalidate(continueWatchingProvider);
    ref.invalidate(activeDownloadsProvider);
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

      // 2. Fetch local files
      final files = await _repository.getLocalFiles();

      // 3. Calculate statistics and unmatched groups
      final matchedMediaIds = <int>{};
      int totalLocalEps = 0;
      final unmatchedFiles = <LocalFileItem>[];

      for (final f in files) {
        totalLocalEps++;
        if (f.isMatched) {
          matchedMediaIds.add(f.mediaId);
        } else if (f.isUnmatched) {
          unmatchedFiles.add(f);
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
        return UnmatchedFolderGroup(
          folderPath: first.folderPath,
          folderName: first.folderName,
          guessedTitle: guessed,
          files: groupFiles,
        );
      }).toList();

      state = state.copyWith(
        isLoading: false,
        mainPath: mainPath,
        additionalPaths: additionalPaths,
        localFiles: files,
        unmatchedGroups: unmatchedGroups,
        matchedShowsCount: matchedMediaIds.length,
        localEpisodesCount: totalLocalEps,
        unmatchedFilesCount: unmatchedFiles.length,
      );
      if (matchedMediaIds.isNotEmpty) {
        _invalidateRelatedProviders();
      }
    } catch (e) {
      debugPrint('[LocalLibraryNotifier] Error loading data: $e');
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void toggleEnhancedScan(bool value) {
    state = state.copyWith(enhancedScan: value);
  }

  Future<bool> setMainPath(String newPath) async {
    final trimmed = newPath.trim();
    final ok = await _repository.patchServerSetting('library.libraryPath', trimmed);
    if (ok) {
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> addAdditionalPath(String newPath) async {
    final trimmed = newPath.trim();
    if (trimmed.isEmpty || state.additionalPaths.contains(trimmed) || state.mainPath == trimmed) {
      return false;
    }
    final next = [...state.additionalPaths, trimmed];
    final ok = await _repository.patchServerSetting('library.libraryPaths', next);
    if (ok) {
      await loadLibraryData();
    }
    return ok;
  }

  Future<bool> removeAdditionalPath(String pathToRemove) async {
    final next = state.additionalPaths.where((p) => p != pathToRemove).toList();
    final ok = await _repository.patchServerSetting('library.libraryPaths', next);
    if (ok) {
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
      if (!success) {
        state = state.copyWith(isScanning: false, scanStatus: 'Error al iniciar escaneo');
      } else {
        _invalidateRelatedProviders();
      }
      // Reload will also trigger from WebSocket or next timeout
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
    if (ok) {
      _invalidateRelatedProviders();
      await loadLibraryData();
    }
    return ok;
  }
}

final localLibraryProvider =
    NotifierProvider.autoDispose<LocalLibraryNotifier, LocalLibraryState>(LocalLibraryNotifier.new);
