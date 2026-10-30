import 'package:flutter_riverpod/flutter_riverpod.dart';

/// High-frequency playback position used **only** for on-screen indicators
/// (episode progress bars, live badges, etc.).
///
/// This is intentionally separate from `playbackProgressPreferencesProvider`:
/// that one is persisted to disk (and re-encodes the whole offline collection on
/// every flush), so it is only written every few seconds. Widgets that must
/// follow the video in real time watch this provider instead, keeping the
/// persisted state out of the hot path.
class LivePlaybackProgress {
  final int mediaId;
  final int episodeNumber;
  final int positionMs;
  final int durationMs;

  const LivePlaybackProgress({
    required this.mediaId,
    required this.episodeNumber,
    required this.positionMs,
    required this.durationMs,
  });

  double get fraction {
    if (durationMs <= 0) return 0.0;
    return (positionMs / durationMs).clamp(0.0, 1.0);
  }

  LivePlaybackProgress copyWith({
    int? mediaId,
    int? episodeNumber,
    int? positionMs,
    int? durationMs,
  }) {
    return LivePlaybackProgress(
      mediaId: mediaId ?? this.mediaId,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      positionMs: positionMs ?? this.positionMs,
      durationMs: durationMs ?? this.durationMs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LivePlaybackProgress &&
          other.mediaId == mediaId &&
          other.episodeNumber == episodeNumber &&
          other.positionMs == positionMs &&
          other.durationMs == durationMs;

  @override
  int get hashCode =>
      Object.hash(mediaId, episodeNumber, positionMs, durationMs);
}

class LivePlaybackProgressNotifier extends Notifier<LivePlaybackProgress?> {
  @override
  LivePlaybackProgress? build() => null;

  void update({
    required int mediaId,
    required int episodeNumber,
    required int positionMs,
    required int durationMs,
  }) {
    if (mediaId <= 0 || episodeNumber < 1 || durationMs <= 0) return;
    final next = LivePlaybackProgress(
      mediaId: mediaId,
      episodeNumber: episodeNumber,
      positionMs: positionMs,
      durationMs: durationMs,
    );
    if (next == state) return;
    state = next;
  }

  /// Drops the live value (e.g. when the player is closed).
  void clear() {
    if (state != null) state = null;
  }
}

final livePlaybackProgressProvider =
    NotifierProvider<LivePlaybackProgressNotifier, LivePlaybackProgress?>(
      LivePlaybackProgressNotifier.new,
    );
