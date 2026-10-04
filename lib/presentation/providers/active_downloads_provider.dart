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

class DownloadingEpisodesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void add(int mediaId, int episodeNumber) {
    state = {...state, '${mediaId}_$episodeNumber'};
  }

  void remove(int mediaId, int episodeNumber) {
    state = state.where((k) => k != '${mediaId}_$episodeNumber').toSet();
  }

  void clearForMedia(int mediaId) {
    state = state.where((k) => !k.startsWith('${mediaId}_')).toSet();
  }

  bool isDownloading(int mediaId, int episodeNumber) {
    return state.contains('${mediaId}_$episodeNumber');
  }
}

final downloadingEpisodesProvider =
    NotifierProvider<DownloadingEpisodesNotifier, Set<String>>(
  DownloadingEpisodesNotifier.new,
);

