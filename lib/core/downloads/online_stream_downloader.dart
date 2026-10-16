import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/downloads/hls_download_engine.dart';
import 'package:seanime_app/core/downloads/online_stream_download_task.dart';

typedef DownloadProgressCallback = void Function(
  double progress,
  int downloadedBytes,
  String speed,
);

/// Raised when the download finished but did not produce a playable video
/// (e.g. the source was encrypted/DRM protected). Carries a [code] so the UI
/// can display a localized message.
class OnlineStreamDownloadException implements Exception {
  final String code;
  final String message;

  const OnlineStreamDownloadException(this.code, this.message);

  @override
  String toString() => message;
}

class OnlineStreamDownloader {
  final Dio _dio;

  OnlineStreamDownloader({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 25),
              receiveTimeout: const Duration(seconds: 40),
            ),
          );

  static bool? _cachedFfmpegAvailable;

  /// Checks if ffmpeg is executable on the current host system.
  static Future<bool> isFfmpegAvailable() async {
    if (_cachedFfmpegAvailable != null) return _cachedFfmpegAvailable!;
    if (Platform.isAndroid || Platform.isIOS) {
      _cachedFfmpegAvailable = false;
      return false;
    }
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      _cachedFfmpegAvailable = res.exitCode == 0;
    } catch (_) {
      _cachedFfmpegAvailable = false;
    }
    return _cachedFfmpegAvailable!;
  }

  /// Executes the download of an online stream task with progress and cancellation.
  Future<void> download({
    required OnlineStreamDownloadTask task,
    required DownloadProgressCallback onProgress,
    required CancelToken cancelToken,
    Process? Function(Process p)? onProcessStarted,
  }) async {
    final destFile = File(task.savePath);
    final parentDir = destFile.parent;
    if (!await parentDir.exists()) {
      await parentDir.create(recursive: true);
    }

    if (task.isHls) {
      final hasFfmpeg = await isFfmpegAvailable();
      if (hasFfmpeg) {
        await _downloadHlsWithFfmpeg(
          task: task,
          onProgress: onProgress,
          cancelToken: cancelToken,
          onProcessStarted: onProcessStarted,
        );
      } else {
        await _downloadHlsWithEngine(
          task: task,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );
      }
    } else {
      await _downloadDirectWithDio(
        task: task,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
    }

    // Verify that we actually produced a playable media file. Without this an
    // encrypted/unrecognized source would silently save hundreds of MB of
    // garbage that no player can open.
    await _validateOutput(task.savePath);

    // Download external subtitles if provided
    await _downloadSubtitles(task, parentDir);
  }

  /// Downloads external subtitle tracks alongside the video file.
  Future<void> _downloadSubtitles(
    OnlineStreamDownloadTask task,
    Directory targetDir,
  ) async {
    if (task.subtitles.isEmpty) return;

    final baseName = task.savePath.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
    for (final sub in task.subtitles) {
      if (sub.url.isEmpty) continue;
      try {
        final lang = sub.language.toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '_',
        );
        final ext = sub.url.endsWith('.srt')
            ? 'srt'
            : (sub.url.endsWith('.ass') ? 'ass' : 'vtt');
        final subPath = '$baseName.$lang.$ext';
        final subFile = File(subPath);

        if (!await subFile.exists()) {
          final res = await _dio.get<List<int>>(
            sub.url,
            options: Options(
              responseType: ResponseType.bytes,
              headers: task.headers,
            ),
          );
          if (res.data != null && res.data!.isNotEmpty) {
            await subFile.writeAsBytes(res.data!);
          }
        }
      } catch (e) {
        debugPrint('Failed to download subtitle track for ${task.id}: $e');
      }
    }
  }

  /// Downloads direct HTTP/HTTPS files using Dio with Range and chunk streaming.
  Future<void> _downloadDirectWithDio({
    required OnlineStreamDownloadTask task,
    required DownloadProgressCallback onProgress,
    required CancelToken cancelToken,
  }) async {
    int lastBytes = 0;
    DateTime lastTime = DateTime.now();

    await _dio.download(
      task.videoUrl,
      task.savePath,
      cancelToken: cancelToken,
      options: Options(
        headers: task.headers,
        receiveTimeout: const Duration(minutes: 10),
      ),
      onReceiveProgress: (received, total) {
        final now = DateTime.now();
        final elapsedMs = now.difference(lastTime).inMilliseconds;
        String speed = '';
        if (elapsedMs >= 500) {
          final bytesDiff = received - lastBytes;
          final bytesPerSec = (bytesDiff / (elapsedMs / 1000)).round();
          speed = formatSpeed(bytesPerSec);
          lastBytes = received;
          lastTime = now;
        }

        final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, received, speed);
      },
    );
  }

  /// Remuxes and downloads HLS streams via local FFmpeg binary.
  Future<void> _downloadHlsWithFfmpeg({
    required OnlineStreamDownloadTask task,
    required DownloadProgressCallback onProgress,
    required CancelToken cancelToken,
    Process? Function(Process p)? onProcessStarted,
  }) async {
    final args = <String>['-y'];

    if (task.headers != null && task.headers!.isNotEmpty) {
      final headerStr = task.headers!.entries
          .map((e) => '${e.key}: ${e.value}\r\n')
          .join();
      args.addAll(['-headers', headerStr]);
    }

    args.addAll([
      '-i',
      task.videoUrl,
      '-c',
      'copy',
      '-bsf:a',
      'aac_adtstoasc',
      '-progress',
      'pipe:1',
      task.savePath,
    ]);

    final process = await Process.start('ffmpeg', args);
    onProcessStarted?.call(process);

    cancelToken.whenCancel.then((_) {
      try {
        process.kill(ProcessSignal.sigkill);
      } catch (_) {}
    });

    final completer = Completer<void>();
    int downloadedBytes = 0;
    String currentSpeed = '';
    double currentProgress = 0.0;

    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          final trimmed = line.trim();
          if (trimmed.startsWith('total_size=')) {
            final rawSize = trimmed.replaceFirst('total_size=', '').trim();
            downloadedBytes = int.tryParse(rawSize) ?? downloadedBytes;
          } else if (trimmed.startsWith('speed=')) {
            final rawSpd = trimmed.replaceFirst('speed=', '').trim();
            if (rawSpd.isNotEmpty) currentSpeed = rawSpd;
          } else if (trimmed.startsWith('out_time_ms=')) {
            final rawMs = trimmed.replaceFirst('out_time_ms=', '').trim();
            final ms = int.tryParse(rawMs);
            if (ms != null && ms > 0) {
              // Standard anime episode ~24 minutes = 1440000000 microseconds
              const defaultDurationUs = 1440000000;
              currentProgress = (ms / defaultDurationUs).clamp(0.0, 0.99);
            }
          } else if (trimmed.startsWith('progress=end')) {
            currentProgress = 1.0;
          }

          onProgress(currentProgress, downloadedBytes, currentSpeed);
        });

    process.stderr.transform(utf8.decoder).listen((_) {});

    process.exitCode.then((code) {
      if (cancelToken.isCancelled) {
        if (!completer.isCompleted) {
          completer.completeError(
            DioException(
              requestOptions: RequestOptions(path: task.videoUrl),
              type: DioExceptionType.cancel,
              message: 'Download cancelled by user',
            ),
          );
        }
      } else if (code == 0) {
        onProgress(1.0, downloadedBytes, '');
        if (!completer.isCompleted) completer.complete();
      } else {
        if (!completer.isCompleted) {
          completer.completeError(
            Exception('FFmpeg download failed with exit code $code'),
          );
        }
      }
    });

    await completer.future;
  }

  /// Downloads HLS using the pure-Dart engine. Handles master playlists,
  /// `#EXT-X-MAP` init segments, `#EXT-X-BYTERANGE` and AES-128 encryption.
  /// This is the fallback used on Android/iOS, where no ffmpeg is available.
  Future<void> _downloadHlsWithEngine({
    required OnlineStreamDownloadTask task,
    required DownloadProgressCallback onProgress,
    required CancelToken cancelToken,
  }) async {
    final engine = HlsDownloadEngine(dio: _dio);
    try {
      await engine.download(
        url: task.videoUrl,
        savePath: task.savePath,
        preferredQuality: task.quality,
        headers: task.headers,
        cancelToken: cancelToken,
        onProgress: (progress, bytes, bytesPerSecond) {
          onProgress(progress, bytes, formatSpeed(bytesPerSecond));
        },
      );
    } on HlsDownloadException catch (e) {
      throw OnlineStreamDownloadException(
        e.failure == HlsDownloadFailure.protected ? 'protected' : 'unknown',
        e.message,
      );
    }
  }

  /// Ensures the downloaded file is a real media container. This prevents a
  /// broken/encrypted download from being reported as "completed".
  Future<void> _validateOutput(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const OnlineStreamDownloadException(
        'unknown',
        'Downloaded file is missing',
      );
    }
    if (await file.length() < 1024) {
      await _safeDelete(file);
      throw const OnlineStreamDownloadException(
        'unknown',
        'Downloaded file is empty or too small',
      );
    }

    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final header = await raf.read(4096);
      if (!isValidMediaHeader(header)) {
        await _safeDelete(file);
        throw const OnlineStreamDownloadException(
          'invalid',
          'The source could not be played: the downloaded data is not a valid '
              'video file (it may be protected or corrupted).',
        );
      }
    } finally {
      await raf?.close();
    }
  }

  Future<void> _safeDelete(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// True when [header] starts with a known media container signature.
  static bool isValidMediaHeader(Uint8List header) {
    if (header.length < 12) return false;

    // ISO BMFF: MP4 (ftyp), fMP4 init (styp) or fragment (moof/moov).
    if (_matches(header, 4, 'ftyp') ||
        _matches(header, 4, 'styp') ||
        _matches(header, 4, 'moof') ||
        _matches(header, 4, 'moov')) {
      return true;
    }
    // MPEG-TS: sync byte 0x47 at the start of each 188-byte packet.
    if (header[0] == 0x47 && (header.length < 189 || header[188] == 0x47)) {
      return true;
    }
    // Matroska / WebM.
    if (header[0] == 0x1A &&
        header[1] == 0x45 &&
        header[2] == 0xDF &&
        header[3] == 0xA3) {
      return true;
    }
    // RIFF (AVI/WebP) and Ogg.
    if (_matches(header, 0, 'RIFF') || _matches(header, 0, 'OggS')) {
      return true;
    }
    // FLV.
    if (header[0] == 0x46 && header[1] == 0x4C && header[2] == 0x56) {
      return true;
    }
    return false;
  }

  static bool _matches(Uint8List bytes, int offset, String ascii) {
    if (offset + ascii.length > bytes.length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (bytes[offset + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }

  static String formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
  }
}
