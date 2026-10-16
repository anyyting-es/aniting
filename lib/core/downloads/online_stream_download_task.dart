import 'package:seanime_app/data/models/onlinestream_models.dart';

enum OnlineStreamDownloadStatus {
  pending,
  resolving,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class OnlineStreamDownloadTask {
  final String id; // '${mediaId}_$episodeNumber'
  final int mediaId;
  final int episodeNumber;
  final String animeTitle;
  final String episodeTitle;
  final String? thumbnail;
  final String providerId;
  final String providerName;
  final String server;
  final String quality;
  final String videoUrl;
  final Map<String, String>? headers;
  final bool isHls;
  final String savePath;
  final OnlineStreamDownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int downloadedBytes;
  final int totalBytes;
  final String speed;
  final String? error;

  /// Machine-readable failure code ('protected', 'invalid', 'unknown') used to
  /// show a localized message instead of a raw error string.
  final String? errorCode;
  final List<OnlinestreamSubtitle> subtitles;
  final DateTime createdAt;
  final DateTime? completedAt;

  const OnlineStreamDownloadTask({
    required this.id,
    required this.mediaId,
    required this.episodeNumber,
    required this.animeTitle,
    required this.episodeTitle,
    this.thumbnail,
    required this.providerId,
    required this.providerName,
    required this.server,
    required this.quality,
    required this.videoUrl,
    this.headers,
    this.isHls = false,
    required this.savePath,
    this.status = OnlineStreamDownloadStatus.pending,
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.speed = '',
    this.error,
    this.errorCode,
    this.subtitles = const [],
    required this.createdAt,
    this.completedAt,
  });

  bool get isDone =>
      status == OnlineStreamDownloadStatus.completed ||
      status == OnlineStreamDownloadStatus.failed ||
      status == OnlineStreamDownloadStatus.cancelled;

  bool get isActive =>
      status == OnlineStreamDownloadStatus.downloading ||
      status == OnlineStreamDownloadStatus.resolving;

  bool get isPaused => status == OnlineStreamDownloadStatus.paused;

  OnlineStreamDownloadTask copyWith({
    String? id,
    int? mediaId,
    int? episodeNumber,
    String? animeTitle,
    String? episodeTitle,
    String? thumbnail,
    String? providerId,
    String? providerName,
    String? server,
    String? quality,
    String? videoUrl,
    Map<String, String>? headers,
    bool? isHls,
    String? savePath,
    OnlineStreamDownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    String? speed,
    String? error,
    String? errorCode,
    List<OnlinestreamSubtitle>? subtitles,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return OnlineStreamDownloadTask(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      animeTitle: animeTitle ?? this.animeTitle,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      thumbnail: thumbnail ?? this.thumbnail,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      server: server ?? this.server,
      quality: quality ?? this.quality,
      videoUrl: videoUrl ?? this.videoUrl,
      headers: headers ?? this.headers,
      isHls: isHls ?? this.isHls,
      savePath: savePath ?? this.savePath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      speed: speed ?? this.speed,
      error: error ?? this.error,
      errorCode: errorCode ?? this.errorCode,
      subtitles: subtitles ?? this.subtitles,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}
