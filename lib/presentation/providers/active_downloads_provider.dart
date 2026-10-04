import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';

String _formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = 0;
  double d = bytes.toDouble();
  while (d >= 1024 && i < suffixes.length - 1) {
    d /= 1024;
    i++;
  }
  return '${d.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
}

class ActiveDownloadsState {
  final List<Map<String, dynamic>> activeTorrents;
  final List<dynamic> mangaQueue;
  final bool isLoading;

  const ActiveDownloadsState({
    this.activeTorrents = const [],
    this.mangaQueue = const [],
    this.isLoading = false,
  });

  bool get isEmpty => activeTorrents.isEmpty && mangaQueue.isEmpty;

  ActiveDownloadsState copyWith({
    List<Map<String, dynamic>>? activeTorrents,
    List<dynamic>? mangaQueue,
    bool? isLoading,
  }) {
    return ActiveDownloadsState(
      activeTorrents: activeTorrents ?? this.activeTorrents,
      mangaQueue: mangaQueue ?? this.mangaQueue,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActiveDownloadsNotifier extends Notifier<ActiveDownloadsState> {
  Timer? _pollingTimer;
  final Set<String> _scannedHashes = {};
  bool _isScanning = false;

  @override
  ActiveDownloadsState build() {
    _startPolling();
    ref.onDispose(() {
      _pollingTimer?.cancel();
      _pollingTimer = null;
    });
    Future.microtask(() => refresh());
    return const ActiveDownloadsState();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      refresh(silent: true);
    });
  }

  Future<void> refresh({bool silent = false}) async {
    if (!silent) {
      state = state.copyWith(isLoading: true);
    }

    try {
      final repo = ref.read(repositoryProvider);
      final futures = await Future.wait([
        repo.getActiveTorrentList(),
        repo.getMangaDownloadQueue(),
      ]);

      final torrents = futures[0] as List<Map<String, dynamic>>;
      final manga = futures[1];

      state = state.copyWith(
        activeTorrents: torrents,
        mangaQueue: manga,
        isLoading: false,
      );

      // Sync active torrent progress with downloading episodes
      ref.read(downloadingEpisodesProvider.notifier).syncWithTorrents(torrents);

      // Auto-scan detection: when a torrent reaches 100% or completion,
      // automatically trigger a library scan so Seanime indexes the downloaded episode.
      for (final t in torrents) {
        final hash = t['hash']?.toString() ?? '';
        final rawProgress = t['progress'];
        double progress = 0.0;
        if (rawProgress is num) {
          progress = rawProgress.toDouble();
        } else if (rawProgress is String) {
          progress = double.tryParse(rawProgress.replaceAll('%', '').trim()) ?? 0.0;
        }
        if (progress > 1.0) progress /= 100.0;

        final status = (t['status']?.toString() ?? '').toLowerCase();
        final isComplete = progress >= 0.999 || status == 'completed' || status == 'seeding';
        if (isComplete && hash.isNotEmpty && !_scannedHashes.contains(hash) && !_isScanning) {
          _scannedHashes.add(hash);
          final name = t['name']?.toString() ?? 'Torrent';
          final rawSize = t['size'];
          String sizeStr = '';
          if (rawSize is String) {
            sizeStr = rawSize.trim();
          } else if (rawSize is num) {
            sizeStr = _formatBytes(rawSize.toInt());
          }
          ref.read(downloadHistoryProvider.notifier).addItem(
            DownloadHistoryItem(
              id: hash,
              title: name,
              subtitle: 'Descarga completada',
              size: sizeStr,
              type: 'torrent',
              completedAt: DateTime.now(),
            ),
          );
          _triggerScanOnCompleted(repo);
          break;
        }
      }
    } catch (_) {
      if (!silent) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> _triggerScanOnCompleted(dynamic repo) async {
    _isScanning = true;
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      await repo.scanLibrary();
      ref.invalidate(downloadedAnimeProvider);
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(animeLibraryEntryProvider);
    } catch (e) {
      // Ignore scan failure in background
    } finally {
      _isScanning = false;
      ref.invalidate(downloadingEpisodesProvider);
    }
  }

  Future<void> pauseTorrentStream() async {
    await ref.read(repositoryProvider).pauseTorrentStream();
    await refresh(silent: true);
  }

  Future<void> resumeTorrentStream() async {
    await ref.read(repositoryProvider).resumeTorrentStream();
    await refresh(silent: true);
  }

  Future<void> dropTorrentStream() async {
    await ref.read(repositoryProvider).dropTorrentStream();
    ref.read(torrentStreamStatusProvider.notifier).reset();
    await refresh(silent: true);
  }

  Future<void> pauseMangaQueue() async {
    await ref.read(repositoryProvider).stopMangaDownloadQueue();
    await refresh(silent: true);
  }

  Future<void> resumeMangaQueue() async {
    await ref.read(repositoryProvider).startMangaDownloadQueue();
    await refresh(silent: true);
  }

  Future<void> clearMangaQueue() async {
    await ref.read(repositoryProvider).clearMangaDownloadQueue();
    await refresh(silent: true);
  }

  Future<void> resetErroredMangaQueue() async {
    await ref.read(repositoryProvider).resetErroredMangaQueue();
    await refresh(silent: true);
  }

  Future<void> performTorrentClientAction(String hash, String action) async {
    await ref.read(repositoryProvider).performTorrentClientAction(
          hash: hash,
          action: action,
        );
    await refresh(silent: true);
  }
}

final activeDownloadsProvider =
    NotifierProvider<ActiveDownloadsNotifier, ActiveDownloadsState>(
  ActiveDownloadsNotifier.new,
);

class EpisodeDownloadProgress {
  final int mediaId;
  final int episodeNumber;
  final String? hash;
  final String? torrentName;
  final double? progress;
  final String? speed;
  final String? status;

  const EpisodeDownloadProgress({
    required this.mediaId,
    required this.episodeNumber,
    this.hash,
    this.torrentName,
    this.progress,
    this.speed,
    this.status,
  });

  EpisodeDownloadProgress copyWith({
    int? mediaId,
    int? episodeNumber,
    String? hash,
    String? torrentName,
    double? progress,
    String? speed,
    String? status,
  }) {
    return EpisodeDownloadProgress(
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      hash: hash ?? this.hash,
      torrentName: torrentName ?? this.torrentName,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      status: status ?? this.status,
    );
  }
}

class DownloadingEpisodesState {
  final Map<String, EpisodeDownloadProgress> episodes;

  const DownloadingEpisodesState([this.episodes = const {}]);

  bool contains(String key) => episodes.containsKey(key);
  bool isDownloading(int mediaId, int episodeNumber) =>
      episodes.containsKey('${mediaId}_$episodeNumber');
  double? getProgress(int mediaId, int episodeNumber) =>
      episodes['${mediaId}_$episodeNumber']?.progress;
  EpisodeDownloadProgress? getInfo(int mediaId, int episodeNumber) =>
      episodes['${mediaId}_$episodeNumber'];
  bool get isEmpty => episodes.isEmpty;
  bool get isNotEmpty => episodes.isNotEmpty;
  int get length => episodes.length;
  Iterable<String> get keys => episodes.keys;
}

class DownloadingEpisodesNotifier extends Notifier<DownloadingEpisodesState> {
  @override
  DownloadingEpisodesState build() => const DownloadingEpisodesState();

  void add(
    int mediaId,
    int episodeNumber, {
    String? hash,
    String? torrentName,
  }) {
    final key = '${mediaId}_$episodeNumber';
    final current = Map<String, EpisodeDownloadProgress>.from(state.episodes);
    current[key] = EpisodeDownloadProgress(
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      hash: hash,
      torrentName: torrentName,
    );
    state = DownloadingEpisodesState(current);
  }

  void remove(int mediaId, int episodeNumber) {
    final key = '${mediaId}_$episodeNumber';
    if (!state.episodes.containsKey(key)) return;
    final current = Map<String, EpisodeDownloadProgress>.from(state.episodes);
    current.remove(key);
    state = DownloadingEpisodesState(current);
  }

  void clearForMedia(int mediaId) {
    final prefix = '${mediaId}_';
    final current = Map<String, EpisodeDownloadProgress>.from(state.episodes)
      ..removeWhere((k, _) => k.startsWith(prefix));
    state = DownloadingEpisodesState(current);
  }

  bool isDownloading(int mediaId, int episodeNumber) {
    return state.isDownloading(mediaId, episodeNumber);
  }

  double? getProgress(int mediaId, int episodeNumber) {
    return state.getProgress(mediaId, episodeNumber);
  }

  void syncWithTorrents(List<Map<String, dynamic>> activeTorrents) {
    if (state.episodes.isEmpty) return;
    final current = Map<String, EpisodeDownloadProgress>.from(state.episodes);
    bool changed = false;

    for (final entry in state.episodes.entries) {
      final key = entry.key;
      final info = entry.value;

      Map<String, dynamic>? match;
      for (final t in activeTorrents) {
        final tHash = (t['hash']?.toString() ?? '').toLowerCase();
        if (info.hash != null && info.hash!.isNotEmpty && tHash.isNotEmpty) {
          if (tHash == info.hash!.toLowerCase()) {
            match = t;
            break;
          }
        }
        if (info.torrentName != null && info.torrentName!.isNotEmpty) {
          final tName = (t['name']?.toString() ?? '').toLowerCase();
          if (tName == info.torrentName!.toLowerCase()) {
            match = t;
            break;
          }
        }
      }

      if (match != null) {
        final rawProgress = match['progress'];
        double progress = 0.0;
        if (rawProgress is num) {
          progress = rawProgress.toDouble();
        } else if (rawProgress is String) {
          progress = double.tryParse(rawProgress.replaceAll('%', '').trim()) ?? 0.0;
        }
        if (progress > 1.0) progress /= 100.0;
        progress = progress.clamp(0.0, 1.0);

        final downSpeed =
            (match['downSpeed'] ?? match['downloadSpeed'])?.toString() ?? '';
        final status = match['status']?.toString() ?? 'downloading';

        if (info.progress != progress ||
            info.speed != downSpeed ||
            info.status != status) {
          current[key] = info.copyWith(
            progress: progress,
            speed: downSpeed,
            status: status,
          );
          changed = true;
        }
      }
    }

    if (changed) {
      state = DownloadingEpisodesState(current);
    }
  }
}

final downloadingEpisodesProvider =
    NotifierProvider<DownloadingEpisodesNotifier, DownloadingEpisodesState>(
  DownloadingEpisodesNotifier.new,
);


