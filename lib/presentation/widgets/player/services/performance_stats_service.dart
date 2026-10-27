import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/player/media_kit_player_service.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Polls the public playback state exposed by media_kit.
class PerformanceStatsService {
  final MediaKitPlayerService? mediaKitService;
  final bool isUsingExoPlayer;
  final Duration buffer;

  Timer? _timer;
  final _statsController = StreamController<PerformanceStats>.broadcast();

  PerformanceStatsService({
    required this.mediaKitService,
    required this.isUsingExoPlayer,
    required this.buffer,
  });

  Stream<PerformanceStats> get statsStream => _statsController.stream;

  void startPolling({Duration interval = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _fetch();
    _timer = Timer.periodic(interval, (_) => _fetch());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stopPolling();
    _statsController.close();
  }

  Future<void> _fetch() async {
    if (_statsController.isClosed) return;
    try {
      if (isUsingExoPlayer) {
        _statsController.add(PerformanceStats(
          engine: 'Android ExoPlayer (Media3)',
          videoCodec: 'Hardware MediaCodec',
          resolution: 'Auto Display Native',
          fps: 60.0,
          containerFps: 60.0,
          hwdec: 'SurfaceView / MediaCodec',
          buffer: buffer,
          subtitleFormat: 'libass (.ass estilizado nativo)',
        ));
        return;
      }

      final service = mediaKitService;
      if (service == null) return;
      final state = service.player.state;
      final video = state.videoParams;
      final audio = state.audioParams;
      _statsController.add(PerformanceStats(
        engine: 'media_kit',
        videoCodec: state.track.video.codec,
        resolution: state.width != null && state.height != null
            ? '${state.width}x${state.height}'
            : null,
        aspectRatio: video.aspect?.toStringAsFixed(2),
        fps: state.track.video.fps,
        containerFps: state.track.video.fps,
        bitrate: state.track.video.bitrate,
        audioBitrate: state.audioBitrate?.round(),
        hwdec: 'media_kit native',
        pixelFormat: video.pixelformat,
        audioChannels: audio.channelCount,
        audioSampleRate: audio.sampleRate,
        buffer: state.buffer,
        subtitleFormat: 'libass (media_kit)',
      ));
    } catch (error) {
      debugPrint('[PerformanceStatsService] Error fetching stats: $error');
    }
  }
}
