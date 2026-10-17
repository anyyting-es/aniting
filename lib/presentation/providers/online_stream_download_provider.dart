import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/downloads/online_stream_download_task.dart';
import 'package:seanime_app/core/downloads/online_stream_downloader.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';

/// Outcome of attempting to start an online stream download.
enum DownloadStartResult {
  /// The download was queued successfully.
  started,

  /// The same episode is already downloading.
  alreadyDownloading,

  /// No destination folder could be resolved (library not configured).
  noDestination,
}

class OnlineStreamDownloadState {
  final Map<String, OnlineStreamDownloadTask> tasks;

  const OnlineStreamDownloadState([this.tasks = const {}]);

  List<OnlineStreamDownloadTask> get allTasks => tasks.values.toList();
  List<OnlineStreamDownloadTask> get activeTasks =>
      tasks.values.where((t) => t.isActive).toList();
  List<OnlineStreamDownloadTask> get pausedTasks =>
      tasks.values.where((t) => t.isPaused).toList();

  /// Tasks surfaced in the download manager: in progress, paused and failed
  /// (failed ones stay visible so the error can be seen and dismissed).
  List<OnlineStreamDownloadTask> get visibleTasks => tasks.values
      .where((t) => t.isActive || t.isPaused || t.status == OnlineStreamDownloadStatus.failed)
      .toList();

  bool isDownloading(int mediaId, int episodeNumber) {
    final task = tasks['${mediaId}_$episodeNumber'];
    return task != null && task.isActive;
  }

  OnlineStreamDownloadTask? getTask(int mediaId, int episodeNumber) {
    return tasks['${mediaId}_$episodeNumber'];
  }
}

class OnlineStreamDownloadNotifier extends Notifier<OnlineStreamDownloadState> {
  StreamSubscription? _wsSubscription;
  Timer? _pollingTimer;
  final Set<String> _recordedCompletedIds = {};

  @override
  OnlineStreamDownloadState build() {
    _initListeners();
    ref.onDispose(() {
      _wsSubscription?.cancel();
      _pollingTimer?.cancel();
    });
    Future.microtask(() => refreshQueue());
    return const OnlineStreamDownloadState();
  }

  void _initListeners() {
    final ws = ref.read(webSocketServiceProvider);
    _wsSubscription?.cancel();
    _wsSubscription = ws.eventStream.listen((event) {
      final type = event['type'] as String?;
      final payload = event['payload'];

      if (type == 'onlinestream-download-queue-updated') {
        if (payload is List) {
          _applyQueueFromBackend(payload);
        } else {
          refreshQueue();
        }
      }
    });

    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      // Only poll when there are active downloads
      if (state.activeTasks.isNotEmpty) {
        refreshQueue();
      }
    });
  }

  Future<void> refreshQueue() async {
    try {
      final repo = ref.read(repositoryProvider);
      final queue = await repo.getOnlinestreamDownloadQueue();
      _applyTasks(queue);
    } catch (e) {
      debugPrint('Failed to refresh onlinestream download queue: $e');
    }
  }

  void _applyQueueFromBackend(List<dynamic> list) {
    final parsed = list
        .whereType<Map<String, dynamic>>()
        .map(OnlineStreamDownloadTask.fromJson)
        .toList();
    _applyTasks(parsed);
  }

  void _applyTasks(List<OnlineStreamDownloadTask> backendTasks) {
    final map = <String, OnlineStreamDownloadTask>{};
    bool hasNewlyCompleted = false;

    for (final task in backendTasks) {
      map[task.id] = task;

      if (task.isActive) {
        ref.read(downloadingEpisodesProvider.notifier).updateProgress(
              task.mediaId,
              task.episodeNumber,
              progress: task.progress,
              speed: task.speed,
              status: 'downloading',
            );
      } else if (task.status == OnlineStreamDownloadStatus.completed) {
        ref.read(downloadingEpisodesProvider.notifier).remove(
              task.mediaId,
              task.episodeNumber,
            );

        if (!_recordedCompletedIds.contains(task.id)) {
          _recordedCompletedIds.add(task.id);
          hasNewlyCompleted = true;
          ref.read(downloadHistoryProvider.notifier).addItem(
                DownloadHistoryItem(
                  id: task.id,
                  title: '${task.animeTitle} - Ep ${task.episodeNumber}',
                  subtitle:
                      '${task.providerName} • ${task.server.toUpperCase()} (${task.quality})',
                  size: OnlineStreamDownloader.formatBytes(task.downloadedBytes),
                  type: 'anime',
                  completedAt: task.completedAt ?? DateTime.now(),
                  coverImage: task.thumbnail,
                  filePath: task.savePath,
                  mediaId: task.mediaId,
                ),
              );
        }
      } else if (task.status == OnlineStreamDownloadStatus.cancelled ||
          task.status == OnlineStreamDownloadStatus.failed) {
        ref.read(downloadingEpisodesProvider.notifier).remove(
              task.mediaId,
              task.episodeNumber,
            );
      }
    }

    state = OnlineStreamDownloadState(map);

    if (hasNewlyCompleted) {
      ref.invalidate(downloadedAnimeProvider);
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(animeLibraryEntryProvider);
      ref.invalidate(activeDownloadsProvider);
    }
  }

  /// Starts downloading an episode from an online video source directly on the server.
  Future<DownloadStartResult> startDownload({
    required int mediaId,
    required int episodeNumber,
    required String animeTitle,
    required String episodeTitle,
    String? thumbnail,
    required OnlinestreamVideoSource source,
    required String providerId,
    required String providerName,
  }) async {
    if (state.isDownloading(mediaId, episodeNumber)) {
      return DownloadStartResult.alreadyDownloading;
    }

    final repo = ref.read(repositoryProvider);

    try {
      final task = await repo.startOnlinestreamDownload(
        mediaId: mediaId,
        episodeNumber: episodeNumber,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        thumbnail: thumbnail,
        providerId: providerId,
        providerName: providerName,
        server: source.server,
        quality: source.quality,
        videoUrl: source.url,
        headers: source.headers,
        isHls: source.isHls,
        subtitles: source.subtitles,
      );

      if (task != null) {
        final currentMap = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
        currentMap[task.id] = task;
        state = OnlineStreamDownloadState(currentMap);

        ref.read(downloadingEpisodesProvider.notifier).add(
              mediaId,
              episodeNumber,
              torrentName: '$animeTitle - Ep $episodeNumber',
            );

        return DownloadStartResult.started;
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('already downloading')) {
        return DownloadStartResult.alreadyDownloading;
      }
      if (errStr.contains('library path')) {
        return DownloadStartResult.noDestination;
      }
      debugPrint('Error starting onlinestream download on server: $e');
    }

    return DownloadStartResult.noDestination;
  }

  /// Cancels an active download on the server.
  Future<void> cancelDownload(String taskId) async {
    final task = state.tasks[taskId];
    if (task != null) {
      ref.read(downloadingEpisodesProvider.notifier).remove(
            task.mediaId,
            task.episodeNumber,
          );
    }

    final repo = ref.read(repositoryProvider);
    await repo.cancelOnlinestreamDownload(taskId);
    await refreshQueue();
  }

  /// Removes a task from the list or clears completed downloads.
  void removeTask(String taskId) {
    cancelDownload(taskId);
    final currentMap = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
    currentMap.remove(taskId);
    state = OnlineStreamDownloadState(currentMap);
  }

  /// Clears completed, cancelled and failed tasks on the server.
  Future<void> clearCompleted() async {
    final repo = ref.read(repositoryProvider);
    await repo.clearCompletedOnlinestreamDownloads();
    await refreshQueue();
  }
}

final onlineStreamDownloadProvider =
    NotifierProvider<OnlineStreamDownloadNotifier, OnlineStreamDownloadState>(
      OnlineStreamDownloadNotifier.new,
    );
