/// Resolved YouTube trailer streams, as returned by the companion server's
/// `/api/v1/trailer/resolve` endpoint.
///
/// YouTube watch pages are not media: the backend runs `yt-dlp` once (6–8 s cold,
/// cached for an hour) and hands back directly playable URLs.
class TrailerStreams {
  final String videoId;
  final String title;
  final String? author;

  /// Seconds.
  final int duration;

  /// Video + audio in a single URL (usually 360p). Simplest path.
  final String? muxedUrl;
  final int? muxedHeight;

  /// Separate tracks: play [videoUrl] and attach [audioUrl] as an external
  /// audio track (libmpv `audio-add`, Media3 `MergingMediaSource`).
  final String? videoUrl;
  final int? videoHeight;
  final String? audioUrl;
  final String? audioCodec;

  final DateTime? expiresAt;
  final int resolutionMs;
  final bool cached;

  const TrailerStreams({
    required this.videoId,
    required this.title,
    this.author,
    this.duration = 0,
    this.muxedUrl,
    this.muxedHeight,
    this.videoUrl,
    this.videoHeight,
    this.audioUrl,
    this.audioCodec,
    this.expiresAt,
    this.resolutionMs = 0,
    this.cached = false,
  });

  /// The URL to hand to a player that can only take one source.
  String? get singleUrl => videoUrl ?? muxedUrl;

  /// True when the best quality needs an external audio track.
  bool get needsExternalAudio =>
      videoUrl != null && audioUrl != null && videoUrl != muxedUrl;

  bool get isExpired {
    final expiry = expiresAt;
    return expiry != null && DateTime.now().isAfter(expiry);
  }

  factory TrailerStreams.fromJson(Map<String, dynamic> json) {
    String? str(String key) {
      final value = json[key];
      if (value is! String) return null;
      return value.isEmpty ? null : value;
    }

    int asInt(Object? value) {
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    return TrailerStreams(
      videoId: str('videoId') ?? '',
      title: str('title') ?? '',
      author: str('author'),
      duration: asInt(json['duration']),
      muxedUrl: str('muxedUrl'),
      muxedHeight: json['muxedHeight'] == null ? null : asInt(json['muxedHeight']),
      videoUrl: str('videoUrl'),
      videoHeight: json['videoHeight'] == null ? null : asInt(json['videoHeight']),
      audioUrl: str('audioUrl'),
      audioCodec: str('audioCodec'),
      expiresAt: DateTime.tryParse(str('expiresAt') ?? '')?.toLocal(),
      resolutionMs: asInt(json['resolutionMs']),
      cached: json['cached'] == true,
    );
  }

  @override
  String toString() =>
      'TrailerStreams($videoId, video=${videoHeight ?? '-'}p, '
      'audio=$audioCodec, muxed=${muxedHeight ?? '-'}p, '
      'cached=$cached, ${resolutionMs}ms)';
}
