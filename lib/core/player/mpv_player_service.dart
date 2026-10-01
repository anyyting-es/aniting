import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// MPV Player Service powered by media_kit with optimized libmpv engine
/// configuration inspired by Plezy (hardware acceleration, smart demuxer buffering,
/// audio normalization and native libass subtitle rendering with MKV chapter support).
class MpvPlayerService {
  late final Player _player;
  late final VideoController _videoController;

  String? _currentTitle;
  String? _currentEpisodeTitle;

  MpvPlayerService({int? viewportWidth, int? viewportHeight}) {
    _player = Player(
      configuration: const PlayerConfiguration(
        libass: true,
        bufferSize: 16 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );

    // Limit texture resolution to the actual viewport size instead of the video's
    // native resolution. Without this, a 4K video creates a 3840x2160 OpenGL texture
    // that Flutter's raster thread must composite on every frame, starving the UI.
    // With viewport-sized textures, the GPU scales during mpv_render_context_render()
    // (which is much cheaper) and Flutter only composites a small texture.
    _videoController = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: true,
        hwdec: 'auto',
        width: viewportWidth,
        height: viewportHeight,
      ),
    );

    _applyPlezyMpvConfigurations();
  }

  Player get player => _player;
  VideoController get videoController => _videoController;

  String? get currentTitle => _currentTitle;
  String? get currentEpisodeTitle => _currentEpisodeTitle;

  /// Applies optimal MPV properties inspired by Plezy's player backend
  void _applyPlezyMpvConfigurations() {
    try {
      // Hardware decoding: direct zero-copy keeping decoded frames in GPU VRAM
      if (Platform.isAndroid) {
        _safeSetProperty('hwdec', 'mediacodec,mediacodec-copy');
        _safeSetProperty('hwdec-codecs', 'all');
      } else if (Platform.isMacOS || Platform.isIOS) {
        _safeSetProperty('hwdec', 'videotoolbox');
        _safeSetProperty('hwdec-codecs', 'all');
      } else if (Platform.isWindows) {
        // Direct zero-copy D3D11VA avoids copying 10-bit HEVC frames to host RAM (d3d11va-copy)
        _safeSetProperty('hwdec', 'd3d11va,auto');
        _safeSetProperty('hwdec-codecs', 'all');
      } else {
        // GNU/Linux: direct VA-API zero-copy
        _safeSetProperty('hwdec', 'vaapi,auto');
        _safeSetProperty('hwdec-codecs', 'all');
      }

      // Balanced thread management (0 auto-detects based on CPU cores, avoiding restriction for Hi10P anime that must decode on CPU)
      // vd-lavc-dr removed because direct rendering causes context lockups with media_kit's EGL texture sharing
      _safeSetProperty('vd-lavc-threads', '0');

      // HDR Tone Mapping & Color Space (auto lets mpv pick the best algorithm for vo=libmpv, avoiding bt.2446a which needs gpu-next)
      // hdr-compute-peak disabled to prevent GPU saturation from per-frame histogram analysis
      _safeSetProperty('target-colorspace-hint', 'no');
      _safeSetProperty('tone-mapping', 'auto');
      _safeSetProperty('gamut-mapping-mode', 'auto');
      _safeSetProperty('hdr-compute-peak', 'no');
      _safeSetProperty('video-sync', 'display-resample');
      _safeSetProperty('interpolation', 'no');

      // Demuxer caching: 32MB forward RAM buffer, 10MB rewind RAM buffer, spilling larger cache to SSD
      try {
        final cacheDir = Directory('${Directory.systemTemp.path}/seanime/mpv_cache');
        if (!cacheDir.existsSync()) {
          cacheDir.createSync(recursive: true);
        }
        _safeSetProperty('demuxer-cache-dir', cacheDir.path);
        _safeSetProperty('demuxer-cache-unlink-files', 'immediate');
      } catch (_) {}

      _safeSetProperty('demuxer-max-bytes', '33554432'); // 32 MB in RAM
      _safeSetProperty('demuxer-max-back-bytes', '10485760'); // 10 MB in RAM
      _safeSetProperty('demuxer-readahead-secs', '15');
      _safeSetProperty('cache', 'yes');
      _safeSetProperty('cache-secs', '25');

      // Network & HLS stream reconnection resilience (inspired by Plezy)
      _safeSetProperty('network-timeout', '15');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('hls-bitrate', 'max');
      _safeSetProperty('ytdl', 'no');

      // Seeking optimizations: exact frame seeking without lag
      _safeSetProperty('hr-seek', 'yes');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('keep-open', 'yes');

      // Subtitles: native libass with full styling, embedded MKV fonts, and fuzzy auto-match
      _safeSetProperty('sub-auto', 'fuzzy');
      _safeSetProperty('sub-ass', 'yes');
      _safeSetProperty('sub-ass-override', 'no');
      _safeSetProperty('sub-ass-force-margins', 'yes');
      // basic instead of full to avoid expensive color conversions for every subtitle line
      _safeSetProperty('sub-ass-vsfilter-color-compat', 'basic');
      _safeSetProperty('embeddedfonts', 'yes');
      _safeSetProperty('sub-font-provider', 'auto');

      // Plain text subtitle styling (SRT, VTT, etc.): clean white bold text, transparent bg, black outline
      _safeSetProperty('sub-color', '#FFFFFFFF');
      _safeSetProperty('sub-back-color', '#00000000');
      _safeSetProperty('sub-border-color', '#FF000000');
      _safeSetProperty('sub-border-size', '3.0');
      _safeSetProperty('sub-bold', 'yes');
      _safeSetProperty('sub-font', 'sans-serif');
      _safeSetProperty('sub-font-size', '48');

      // Audio: auto-safe channel mapping and volume downmix normalization
      _safeSetProperty('audio-channels', 'auto-safe');
      _safeSetProperty('audio-normalize-downmix', 'yes');

      // Disable internal MPV OSD so no unwanted chapter or file notices are displayed on-screen
      _safeSetProperty('osd-level', '0');
      _safeSetProperty('osd-playing-msg', '');
    } catch (e) {
      debugPrint('Warning applying libmpv properties: $e');
    }
  }

  void _safeSetProperty(String name, String value) {
    try {
      (_player.platform as dynamic)?.setProperty(name, value);
    } catch (_) {
      // Best-effort property application
    }
  }

  /// Manually set custom MPV property
  Future<void> setProperty(String name, String value) async {
    _safeSetProperty(name, value);
  }

  /// Fetches MKV chapters / segments from libmpv
  Future<List<PlayerChapter>> getChapters() async {
    try {
      final raw = await (_player.platform as dynamic)?.getProperty('chapter-list');
      if (raw != null && raw is String && raw.isNotEmpty && raw != '[]') {
        final decoded = jsonDecode(raw) as List;
        final List<PlayerChapter> rawList = [];
        for (int i = 0; i < decoded.length; i++) {
          final item = decoded[i] as Map<String, dynamic>;
          final title = (item['title'] as String?)?.trim();
          final timeSec = (item['time'] as num?)?.toDouble() ?? 0.0;
          rawList.add(PlayerChapter(
            index: i,
            title: (title != null && title.isNotEmpty) ? title : 'Capítulo ${i + 1}',
            start: Duration(milliseconds: (timeSec * 1000).round()),
          ));
        }

        final List<PlayerChapter> chapters = [];
        for (int i = 0; i < rawList.length; i++) {
          final nextStart = (i + 1 < rawList.length) ? rawList[i + 1].start : null;
          chapters.add(PlayerChapter(
            index: rawList[i].index,
            title: rawList[i].title,
            start: rawList[i].start,
            end: nextStart,
          ));
        }
        return chapters;
      }
    } catch (e) {
      debugPrint('[MpvPlayerService] Error fetching chapters: $e');
    }
    return [];
  }

  /// Seek to a specific chapter index
  Future<void> seekToChapter(int index) async {
    await setProperty('chapter', '$index');
  }

  Future<void> open(
    String url, {
    String? title,
    String? episodeTitle,
    Duration? startPosition,
    Map<String, String>? httpHeaders,
    bool isOnlineStream = false,
  }) async {
    _currentTitle = title;
    _currentEpisodeTitle = episodeTitle;

    final bool isTorrentStream = url.contains('torrentstream') ||
        url.contains('/torrent') ||
        (url.contains('127.0.0.1') && url.contains('torrent'));

    // Detect if this is an online stream (HLS / m3u8 or remote HTTP/HTTPS) vs local media / torrent
    final bool effectiveOnlineStream = !isTorrentStream && (isOnlineStream ||
        ((url.startsWith('http://') || url.startsWith('https://')) &&
            !url.contains('127.0.0.1') &&
            !url.contains('localhost')));

    if (effectiveOnlineStream) {
      // ── ONLINE STREAMING MODE (HLS / m3u8 / remote CDN) ────────────────────
      // 1. Probing optimization: reduce demuxer probing to 64KB & 0.5s (instead of 5MB / 5.0s)
      //    Starts playback in ~100ms instead of waiting seconds to analyze codecs.
      _safeSetProperty('demuxer-lavf-probesize', '65536');
      _safeSetProperty('demuxer-lavf-analyzeduration', '0.5');
      _safeSetProperty('demuxer-lavf-buffersize', '524288'); // 512 KB network buffer

      // 2. HTTP persistent connection & reconnection: keep socket open for all HLS chunks (.ts/.m4s)
      //    Avoids repeating TCP + TLS 1.3 handshakes for every 2-second segment.
      _safeSetProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,multiple_requests=1,http_persistent=1',
      );
      _safeSetProperty('network-timeout', '10');
      _safeSetProperty('tls-verify', 'no'); // Prevents SSL handshakes stalling on anime CDNs

      // 3. Fast seeking: seek to nearest keyframe without network decoding freezes
      _safeSetProperty('hr-seek', 'no');
      _safeSetProperty('hr-seek-framedrop', 'yes');

      // 4. Agile readahead buffer: starts immediately with low initial buffer requirement
      _safeSetProperty('demuxer-readahead-secs', '10');
      _safeSetProperty('cache-secs', '15');
      _safeSetProperty('demuxer-max-bytes', '67108864'); // 64 MB RAM cache for online video
    } else if (isTorrentStream) {
      // ── TORRENT STREAMING MODE (P2P Local Stream) ──────────────────────────
      // Torrent streams are sequential HTTP streams powered by the local Go backend.
      // 1. Fast probing: 1MB probe size so playback starts quickly as chunks arrive.
      _safeSetProperty('demuxer-lavf-probesize', '1048576');
      _safeSetProperty('demuxer-lavf-analyzeduration', '2.0');
      _safeSetProperty('demuxer-lavf-buffersize', '65536');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('network-timeout', '60');

      // 2. Coarse keyframe seeking: avoids requesting unbuffered torrent byte ranges that stall the pipeline.
      _safeSetProperty('hr-seek', 'no');
      _safeSetProperty('hr-seek-framedrop', 'yes');

      // 3. Generous forward cache to prevent underruns during piece download variation.
      _safeSetProperty('demuxer-readahead-secs', '20');
      _safeSetProperty('cache-secs', '30');
      _safeSetProperty('demuxer-max-bytes', '67108864'); // 64 MB RAM cache
    } else {
      // ── LOCAL FILE PLAYBACK MODE (High Fidelity from SSD/Storage) ───────────
      _safeSetProperty('demuxer-lavf-probesize', '5000000');
      _safeSetProperty('demuxer-lavf-analyzeduration', '5');
      _safeSetProperty('demuxer-lavf-buffersize', '32768');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('network-timeout', '15');
      _safeSetProperty('tls-verify', 'yes');
      _safeSetProperty('hr-seek', 'yes');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('demuxer-readahead-secs', '15');
      _safeSetProperty('cache-secs', '25');
      _safeSetProperty('demuxer-max-bytes', '33554432'); // 32 MB
    }

    // Apply Plezy-style header propagation to ensure HLS segment chunks inherit referer/user-agent
    if (httpHeaders != null && httpHeaders.isNotEmpty) {
      final userAgent = httpHeaders['User-Agent'] ?? httpHeaders['user-agent'];
      if (userAgent != null && userAgent.isNotEmpty) {
        _safeSetProperty('user-agent', userAgent);
      }
      final referer = httpHeaders['Referer'] ?? httpHeaders['referer'];
      if (referer != null && referer.isNotEmpty) {
        _safeSetProperty('referrer', referer);
      }
      final headerFields = httpHeaders.entries
          .map((e) => '${e.key}: ${e.value}')
          .join('\r\n');
      _safeSetProperty('http-header-fields', headerFields);
    }

    if (startPosition != null && startPosition > Duration.zero) {
      _safeSetProperty('start', (startPosition.inMilliseconds / 1000.0).toString());
    } else {
      _safeSetProperty('start', 'none');
    }

    await _player.open(
      Media(
        url,
        httpHeaders: httpHeaders,
      ),
      play: true,
    );
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> playOrPause() => _player.playOrPause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setRate(double rate) => _player.setRate(rate);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setAudioTrack(AudioTrack track) => _player.setAudioTrack(track);
  Future<void> setSubtitleTrack(SubtitleTrack track) => _player.setSubtitleTrack(track);

  Future<void> dispose() async {
    await _player.dispose();
  }
}
