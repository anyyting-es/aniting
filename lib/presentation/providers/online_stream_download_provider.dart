import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
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
  final OnlineStreamDownloader _downloader = OnlineStreamDownloader();
  final Map<String, CancelToken> _cancelTokens = {};
  final Map<String, Process> _runningProcesses = {};

  @override
  OnlineStreamDownloadState build() {
    ref.onDispose(() {
      for (final ct in _cancelTokens.values) {
        ct.cancel('Disposed');
      }
      for (final p in _runningProcesses.values) {
        try {
          p.kill(ProcessSignal.sigkill);
        } catch (_) {}
      }
      _cancelTokens.clear();
      _runningProcesses.clear();
    });
    return const OnlineStreamDownloadState();
  }

  /// Starts downloading an episode from an online video source.
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
    final taskId = '${mediaId}_$episodeNumber';
    if (state.isDownloading(mediaId, episodeNumber)) {
      return DownloadStartResult.alreadyDownloading;
    }

    final repo = ref.read(repositoryProvider);

    // 1. Resolve storage destination directory
    String? destDir = await repo.resolveAnimeDownloadDestination(
      mediaId: mediaId,
      animeTitle: animeTitle,
    );

    if (destDir == null || destDir.isEmpty) {
      debugPrint('Failed to resolve destination folder for anime $mediaId');
      return DownloadStartResult.noDestination;
    }

    final cleanTitle = animeTitle
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .trim();
    final paddedEp = episodeNumber.toString().padLeft(2, '0');
    final fileName = '$cleanTitle - $paddedEp.mp4';
    final isWindows = Platform.isWindows || destDir.contains(r'\');
    final sep = isWindows ? r'\' : '/';
    final savePath = '$destDir$sep$fileName';

    final task = OnlineStreamDownloadTask(
      id: taskId,
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
      savePath: savePath,
      subtitles: source.subtitles,
      status: OnlineStreamDownloadStatus.downloading,
      createdAt: DateTime.now(),
    );

    final currentTasks = Map<String, OnlineStreamDownloadTask>.from(
      state.tasks,
    );
    currentTasks[taskId] = task;
    state = OnlineStreamDownloadState(currentTasks);

    // Register with downloadingEpisodesProvider for global UI badges
    ref
        .read(downloadingEpisodesProvider.notifier)
        .add(
          mediaId,
          episodeNumber,
          torrentName: '$animeTitle - Ep $episodeNumber',
        );

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    _executeDownload(task, cancelToken);
    return DownloadStartResult.started;
  }

  Future<void> _executeDownload(
    OnlineStreamDownloadTask task,
    CancelToken cancelToken,
  ) async {
    final taskId = task.id;

    DateTime lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);

    try {
      await _downloader.download(
        task: task,
        cancelToken: cancelToken,
        onProcessStarted: (process) {
          _runningProcesses[taskId] = process;
          return process;
        },
        onProgress: (progress, bytes, speed) {
          final now = DateTime.now();
          final isFinished = progress >= 0.999;
          final shouldNotifyUi = isFinished || now.difference(lastUiUpdate).inMilliseconds >= 500;
          if (!shouldNotifyUi) return;
          lastUiUpdate = now;

          final current = state.tasks[taskId];
          if (current != null &&
              current.status == OnlineStreamDownloadStatus.downloading) {
            final updated = current.copyWith(
              progress: progress,
              downloadedBytes: bytes,
              speed: speed,
            );
            final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
            map[taskId] = updated;
            state = OnlineStreamDownloadState(map);

            ref
                .read(downloadingEpisodesProvider.notifier)
                .updateProgress(
                  task.mediaId,
                  task.episodeNumber,
                  progress: progress,
                  speed: speed,
                  status: 'downloading',
                );
          }
        },
      );

      // Download completed successfully
      _cleanHandles(taskId);
      final current = state.tasks[taskId];
      if (current != null) {
        final completedTask = current.copyWith(
          status: OnlineStreamDownloadStatus.completed,
          progress: 1.0,
          speed: '',
          completedAt: DateTime.now(),
        );
        final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
        map[taskId] = completedTask;
        state = OnlineStreamDownloadState(map);
      }

      // Record in download history
      ref
          .read(downloadHistoryProvider.notifier)
          .addItem(
            DownloadHistoryItem(
              id: taskId,
              title: '${task.animeTitle} - Ep ${task.episodeNumber}',
              subtitle:
                  '${task.providerName} • ${task.server.toUpperCase()} (${task.quality})',
              size: OnlineStreamDownloader.formatBytes(task.downloadedBytes),
              type: 'anime',
              completedAt: DateTime.now(),
              coverImage: task.thumbnail,
              filePath: task.savePath,
              mediaId: task.mediaId,
            ),
          );

      // Trigger automatic scan on Seanime backend
      final repo = ref.read(repositoryProvider);
      try {
        await repo.scanLibrary();
      } catch (_) {}

      ref.invalidate(downloadedAnimeProvider);
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(animeLibraryEntryProvider);
      ref
          .read(downloadingEpisodesProvider.notifier)
          .remove(task.mediaId, task.episodeNumber);
    } catch (e) {
      _cleanHandles(taskId);
      if (cancelToken.isCancelled) {
        final current = state.tasks[taskId];
        if (current != null) {
          final cancelled = current.copyWith(
            status: OnlineStreamDownloadStatus.cancelled,
            speed: '',
          );
          final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
          map[taskId] = cancelled;
          state = OnlineStreamDownloadState(map);
        }
      } else {
        debugPrint('Online stream download error for $taskId: $e');
        final current = state.tasks[taskId];
        if (current != null) {
          final failed = current.copyWith(
            status: OnlineStreamDownloadStatus.failed,
            error: e.toString(),
            errorCode: e is OnlineStreamDownloadException ? e.code : null,
            speed: '',
          );
          final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
          map[taskId] = failed;
          state = OnlineStreamDownloadState(map);
        }
      }
      ref
          .read(downloadingEpisodesProvider.notifier)
          .remove(task.mediaId, task.episodeNumber);
    }
  }

  void _cleanHandles(String taskId) {
    _cancelTokens.remove(taskId);
    final p = _runningProcesses.remove(taskId);
    if (p != null) {
      try {
        p.kill(ProcessSignal.sigkill);
      } catch (_) {}
    }
  }

  /// Cancels an active download and cleans up any partially written files.
  Future<void> cancelDownload(String taskId) async {
    final ct = _cancelTokens[taskId];
    ct?.cancel('Cancelled by user');
    _cleanHandles(taskId);

    final current = state.tasks[taskId];
    if (current != null) {
      ref
          .read(downloadingEpisodesProvider.notifier)
          .remove(current.mediaId, current.episodeNumber);
      try {
        final f = File(current.savePath);
        if (await f.exists()) await f.delete();
      } catch (_) {}

      final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
      map.remove(taskId);
      state = OnlineStreamDownloadState(map);
    }
  }

  /// Removes a finished/errored task from the manager view.
  void removeTask(String taskId) {
    final map = Map<String, OnlineStreamDownloadTask>.from(state.tasks);
    map.remove(taskId);
    state = OnlineStreamDownloadState(map);
  }
}

final onlineStreamDownloadProvider =
    NotifierProvider<OnlineStreamDownloadNotifier, OnlineStreamDownloadState>(
      OnlineStreamDownloadNotifier.new,
    );
