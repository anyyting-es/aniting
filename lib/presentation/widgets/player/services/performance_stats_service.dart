import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:aniting/core/player/media_kit_player_service.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

/// Polls the public playback state exposed by media_kit.
class PerformanceStatsService {
  final MediaKitPlayerService? mediaKitService;
  final bool isUsingExoPlayer;
  final Duration buffer;

  Timer? _timer;
  final _statsController = StreamController<PerformanceStats>.broadcast();

  int? _lastVoDrops;
  int? _lastDecoderDrops;
  int? _lastMistimedFrames;

  PerformanceStatsService({
    required this.mediaKitService,
    required this.isUsingExoPlayer,
    required this.buffer,
  });

  Stream<PerformanceStats> get statsStream => _statsController.stream;

  void startPolling({Duration interval = const Duration(seconds: 1)}) {
    _timer?.cancel();
    _lastVoDrops = null;
    _lastDecoderDrops = null;
    _lastMistimedFrames = null;
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

      // `Player.state` only exposes codec/track info. Frame pacing, A/V sync,
      // cache health and the actual hardware decoder live in native mpv
      // properties, and they are exactly what identifies a "mini stutter":
      //   - decoder-frame-drop-count ↑  → decode/GPU too slow
      //   - frame-drop-count ↑ with decoder stable → present/VSync/render path
      //   - demuxer-cache-duration → 0 / cache-buffering-state < 100 → source
      //   - avsync drifting → audio clock/timing
      int? droppedFrames;
      int? decoderDroppedFrames;
      int? mistimedFrames;
      int? cacheBufferingState;
      int? delayedFrames;
      double? avsync;
      double? cacheDuration;
      double? containerFps;
      double? vfFps;
      double? displayFps;
      double? vsyncRatio;
      String? hwdec;
      String? videoSync;
      bool? interpolation;
      bool? displaySyncActive;

      final platform = service.player.platform;
      if (platform is NativePlayer) {
        final props = await Future.wait<String?>([
          _property(platform, 'frame-drop-count'),
          _property(platform, 'decoder-frame-drop-count'),
          _property(platform, 'mistimed-frame-count'),
          _property(platform, 'cache-buffering-state'),
          _property(platform, 'avsync'),
          _property(platform, 'demuxer-cache-duration'),
          _property(platform, 'hwdec-current'),
          _property(platform, 'container-fps'),
          _property(platform, 'estimated-vf-fps'),
          _property(platform, 'display-fps'),
          _property(platform, 'vsync-ratio'),
          _property(platform, 'vo-delayed-frame-count'),
          _property(platform, 'options/video-sync'),
          _property(platform, 'options/interpolation'),
          _property(platform, 'display-sync-active'),
        ]);
        droppedFrames = int.tryParse(props[0] ?? '');
        decoderDroppedFrames = int.tryParse(props[1] ?? '');
        mistimedFrames = int.tryParse(props[2] ?? '');
        cacheBufferingState = int.tryParse(props[3] ?? '');
        avsync = double.tryParse(props[4] ?? '');
        cacheDuration = double.tryParse(props[5] ?? '');
        final currentHwdec = (props[6] ?? '').trim();
        hwdec = currentHwdec.isEmpty ? 'no' : currentHwdec;
        containerFps = double.tryParse(props[7] ?? '');
        vfFps = double.tryParse(props[8] ?? '');
        displayFps = double.tryParse(props[9] ?? '');
        vsyncRatio = double.tryParse(props[10] ?? '');
        delayedFrames = int.tryParse(props[11] ?? '');
        final sync = (props[12] ?? '').trim();
        videoSync = sync.isEmpty ? null : sync;
        final interp = (props[13] ?? '').trim().toLowerCase();
        interpolation = interp.isEmpty ? null : interp == 'yes';
        final ds = (props[14] ?? '').trim().toLowerCase();
        displaySyncActive = ds.isEmpty ? null : ds == 'yes';
      }

      final stats = PerformanceStats(
        engine: platform is NativePlayer ? 'media_kit (libmpv)' : 'media_kit',
        videoCodec: state.track.video.codec,
        resolution: state.width != null && state.height != null
            ? '${state.width}x${state.height}'
            : null,
        aspectRatio: video.aspect?.toStringAsFixed(2),
        fps: vfFps ?? state.track.video.fps,
        containerFps: containerFps ?? state.track.video.fps,
        displayFps: displayFps,
        vsyncRatio: vsyncRatio,
        delayedFrames: delayedFrames,
        videoSync: videoSync,
        interpolation: interpolation,
        displaySyncActive: displaySyncActive,
        bitrate: state.track.video.bitrate,
        audioBitrate: state.audioBitrate?.round(),
        hwdec: hwdec ?? 'media_kit native',
        pixelFormat: video.pixelformat,
        droppedFrames: droppedFrames,
        decoderDroppedFrames: decoderDroppedFrames,
        mistimedFrames: mistimedFrames,
        cacheBufferingState: cacheBufferingState,
        audioChannels: audio.channelCount,
        audioSampleRate: audio.sampleRate,
        avsync: avsync,
        cacheDuration: cacheDuration,
        buffer: state.buffer,
        subtitleFormat: 'libass (media_kit)',
      );
      _statsController.add(stats);
      _logStutter(stats);
    } catch (error) {
      debugPrint('[PerformanceStatsService] Error fetching stats: $error');
    }
  }

  Future<String?> _property(NativePlayer player, String name) async {
    try {
      return await player.getProperty(name);
    } catch (_) {
      return null;
    }
  }

  /// Logs a compact line each time mpv reports new dropped/mistimed frames.
  /// The stats overlay must be open (it starts this poller) for the diagnostic
  /// to be collected.
  void _logStutter(PerformanceStats stats) {
    final vo = stats.droppedFrames ?? 0;
    final decoder = stats.decoderDroppedFrames ?? 0;
    final mistimed = stats.mistimedFrames ?? 0;

    final previousVo = _lastVoDrops;
    final previousDecoder = _lastDecoderDrops;
    final previousMistimed = _lastMistimedFrames;
    _lastVoDrops = vo;
    _lastDecoderDrops = decoder;
    _lastMistimedFrames = mistimed;

    if (previousVo == null || previousDecoder == null || previousMistimed == null) {
      return;
    }

    final deltaVo = vo - previousVo;
    final deltaDecoder = decoder - previousDecoder;
    final deltaMistimed = mistimed - previousMistimed;
    if (deltaVo <= 0 && deltaDecoder <= 0 && deltaMistimed <= 0) return;

    debugPrint(
      '[PlayerDiag] stutter: vo=+$deltaVo (total $vo), '
      'decoder=+$deltaDecoder ($decoder), mistimed=+$deltaMistimed ($mistimed) '
      '| hwdec=${stats.hwdec} cache=${stats.cacheDuration?.toStringAsFixed(2)}s '
      'buffer=${stats.cacheBufferingState}% avsync=${stats.avsync} '
      'fps=${stats.fps} container=${stats.containerFps} '
      'display=${stats.displayFps} vsync=${stats.vsyncRatio} '
      'late=${stats.delayedFrames} sync=${stats.videoSync} '
      'interp=${stats.interpolation} ds=${stats.displaySyncActive} '
      'size=${stats.resolution}',
    );
  }
}
