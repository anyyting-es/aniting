import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/player/mpv/mpv.dart' as mpv;
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Native MPV Player Service powered by libmpv (without media_kit).
/// Uses native child window embedding (wid) on Windows and native Wayland video plane on Linux,
/// eliminating Flutter texture copying bottlenecks and offering flawless 4K/60fps/120fps video.
class MpvPlayerService {
  late final mpv.Player _player;

  String? _currentTitle;
  String? _currentEpisodeTitle;
  SubtitleStylePrefs? _lastSubtitlePrefs;

  MpvPlayerService({int? viewportWidth, int? viewportHeight}) {
    _player = mpv.Player(hardwareDecoding: true);
    _applyPlezyMpvConfigurations();
  }

  mpv.Player get player => _player;

  String? get currentTitle => _currentTitle;
  String? get currentEpisodeTitle => _currentEpisodeTitle;

  /// Applies optimal MPV properties inspired by Plezy's player backend
  void _applyPlezyMpvConfigurations() {
    try {
      // Hardware decoding
      if (Platform.isAndroid) {
        _safeSetProperty('hwdec', 'mediacodec,mediacodec-copy');
        _safeSetProperty('hwdec-codecs', 'all');
      } else if (Platform.isMacOS || Platform.isIOS) {
        _safeSetProperty('hwdec', 'videotoolbox');
        _safeSetProperty('hwdec-codecs', 'all');
      } else if (Platform.isWindows) {
        _safeSetProperty('hwdec', 'd3d11va,auto');
        _safeSetProperty('hwdec-codecs', 'all');
      } else {
        _safeSetProperty('hwdec', 'auto-safe,auto');
        _safeSetProperty('hwdec-codecs', 'all');
      }

      _safeSetProperty('vd-lavc-threads', '0');

      // HDR Tone Mapping & Color Space
      _safeSetProperty('target-colorspace-hint', 'no');
      _safeSetProperty('tone-mapping', 'auto');
      _safeSetProperty('gamut-mapping-mode', 'auto');
      _safeSetProperty('hdr-compute-peak', 'no');
      if (!Platform.isLinux) {
        _safeSetProperty('video-sync', 'display-resample');
      } else {
        _safeSetProperty('video-sync', 'audio');
      }
      _safeSetProperty('interpolation', 'no');

      // Demuxer caching
      try {
        final cacheDir = Directory('${Directory.systemTemp.path}/aniting/mpv_cache');
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

      // Network & HLS stream reconnection resilience
      _safeSetProperty('network-timeout', '15');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('hls-bitrate', 'max');
      _safeSetProperty('ytdl', 'no');

      // Seeking optimizations
      _safeSetProperty('hr-seek', 'yes');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('keep-open', 'yes');

      // Subtitles: native libass with full styling, embedded MKV fonts, and fuzzy auto-match
      _safeSetProperty('sub-visibility', 'yes');
      _safeSetProperty('sub-auto', 'fuzzy');
      _safeSetProperty('sub-ass', 'yes');
      _safeSetProperty('sub-ass-override', 'scale');
      _safeSetProperty('sub-scale', '1.0');
      _safeSetProperty('sub-ass-force-margins', 'yes');
      _safeSetProperty('sub-ass-vsfilter-color-compat', 'basic');
      _safeSetProperty('embeddedfonts', 'yes');

      if (Platform.isAndroid) {
        _safeSetProperty('sub-fonts-dir', '/system/fonts');
        _safeSetProperty('sub-font', 'Roboto');
        _safeSetProperty('sub-font-provider', 'none');
      } else {
        _safeSetProperty('sub-font-provider', 'auto');
        _safeSetProperty('sub-font', 'sans-serif');
      }

      // Plain text subtitle styling
      _safeSetProperty('sub-color', '#FFFFFFFF');
      _safeSetProperty('sub-back-color', '#00000000');
      _safeSetProperty('sub-border-color', '#FF000000');
      _safeSetProperty('sub-border-size', '3.0');
      _safeSetProperty('sub-bold', 'yes');
      _safeSetProperty('sub-font-size', '48');

      // Audio
      _safeSetProperty('audio-channels', 'auto-safe');
      _safeSetProperty('audio-normalize-downmix', 'yes');

      // Disable internal MPV OSD
      _safeSetProperty('osd-level', '0');
      _safeSetProperty('osd-playing-msg', '');
    } catch (e) {
      debugPrint('Warning applying libmpv properties: $e');
    }
  }

  void _safeSetProperty(String name, String value) {
    _player.setProperty(name, value).catchError((e) {
      debugPrint('[MpvPlayerService] Error setting property $name=$value: $e');
    });
  }

  /// Manually set custom MPV property
  Future<void> setProperty(String name, String value) async {
    await _player.setProperty(name, value);
  }

  /// Get property value
  Future<String?> getProperty(String name) async {
    return _player.getProperty(name);
  }

  /// Execute a native libmpv command (e.g. ['change-list', 'glsl-shaders', 'clr', ''])
  Future<void> command(List<String> args) async {
    try {
      await _player.command(args);
    } catch (e) {
      debugPrint('[MpvPlayerService] Error executing command $args: $e');
    }
  }

  /// Fetches MKV chapters / segments from libmpv
  Future<List<PlayerChapter>> getChapters() async {
    try {
      final raw = await _player.getProperty('chapter-list');
      if (raw != null && raw.isNotEmpty && raw != '[]') {
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

    final bool effectiveOnlineStream = !isTorrentStream && (isOnlineStream ||
        ((url.startsWith('http://') || url.startsWith('https://')) &&
            !url.contains('127.0.0.1') &&
            !url.contains('localhost')));

    if (effectiveOnlineStream) {
      _safeSetProperty('demuxer-lavf-probesize', '65536');
      _safeSetProperty('demuxer-lavf-analyzeduration', '0.5');
      _safeSetProperty('demuxer-lavf-buffersize', '524288');
      _safeSetProperty(
        'stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,multiple_requests=1,http_persistent=1',
      );
      _safeSetProperty('network-timeout', '10');
      _safeSetProperty('tls-verify', 'no');
      _safeSetProperty('hr-seek', 'no');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('demuxer-readahead-secs', '10');
      _safeSetProperty('cache-secs', '15');
      _safeSetProperty('demuxer-max-bytes', '67108864');
    } else if (isTorrentStream) {
      _safeSetProperty('demuxer-lavf-probesize', '1048576');
      _safeSetProperty('demuxer-lavf-analyzeduration', '2.0');
      _safeSetProperty('demuxer-lavf-buffersize', '65536');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('network-timeout', '60');
      _safeSetProperty('hr-seek', 'no');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('demuxer-readahead-secs', '20');
      _safeSetProperty('cache-secs', '30');
      _safeSetProperty('demuxer-max-bytes', '67108864');
    } else {
      _safeSetProperty('demuxer-lavf-probesize', '1048576');
      _safeSetProperty('demuxer-lavf-analyzeduration', '1.0');
      _safeSetProperty('demuxer-lavf-buffersize', '131072');
      _safeSetProperty('stream-lavf-o', 'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5');
      _safeSetProperty('network-timeout', '15');
      _safeSetProperty('tls-verify', 'yes');
      _safeSetProperty('hr-seek', 'yes');
      _safeSetProperty('hr-seek-framedrop', 'yes');
      _safeSetProperty('demuxer-readahead-secs', '15');
      _safeSetProperty('cache-secs', '25');
      _safeSetProperty('demuxer-max-bytes', '33554432');
    }

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

    await _player.open(
      mpv.Media(
        url,
        headers: httpHeaders,
        start: startPosition,
      ),
      play: true,
    );

    if (_lastSubtitlePrefs != null) {
      applySubtitleStyle(_lastSubtitlePrefs!);
    }
  }

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> playOrPause() => _player.playOrPause();
  Future<void> seek(Duration position) => _player.seek(position);
  Future<void> setRate(double rate) => _player.setRate(rate);
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Future<void> setAudioTrack(mpv.AudioTrack track) => _player.selectAudioTrack(track);
  Future<void> setSubtitleTrack(mpv.SubtitleTrack track) => _player.selectSubtitleTrack(track);

  /// Configure video aspect/fit mode (FIT vs COVER/ZOOM vs STRETCH)
  void setBoxFit(PlayerFitMode fitMode) {
    switch (fitMode) {
      case PlayerFitMode.contain:
        _safeSetProperty('panscan', '0.0');
        _safeSetProperty('video-aspect-override', '-1');
        break;
      case PlayerFitMode.cover:
        _safeSetProperty('panscan', '1.0');
        _safeSetProperty('video-aspect-override', '-1');
        break;
      case PlayerFitMode.fill:
        _safeSetProperty('panscan', '0.0');
        _safeSetProperty('video-aspect-override', '0');
        break;
    }
  }

  /// Applies subtitle styling preferences (font, colors, borders, shadows, ASS override)
  void applySubtitleStyle(SubtitleStylePrefs prefs) {
    _lastSubtitlePrefs = prefs;
    try {
      const baseFontSize = 48;
      String targetFont = prefs.fontFamily;
      if (Platform.isAndroid || Platform.isIOS) {
        if (targetFont == 'Trebuchet MS' || targetFont == 'OpenDyslexic' || targetFont == 'sans-serif') {
          targetFont = 'Roboto';
        }
      }
      _safeSetProperty('sub-font', targetFont);
      _safeSetProperty('sub-font-size', '$baseFontSize');
      _safeSetProperty('sub-scale', '${prefs.fontSizeMultiplier}');
      _safeSetProperty('sub-bold', prefs.bold ? 'yes' : 'no');
      _safeSetProperty('sub-italic', prefs.italic ? 'yes' : 'no');
      _safeSetProperty('sub-color', SubtitleStylePrefs.toMpvHexColor(prefs.textColor));
      _safeSetProperty('sub-back-color', SubtitleStylePrefs.toMpvHexColor(prefs.backgroundColor));

      switch (prefs.borderStyle) {
        case SubtitleBorderStyle.none:
          _safeSetProperty('sub-border-size', '0');
          _safeSetProperty('sub-shadow-offset', '0');
          break;
        case SubtitleBorderStyle.outline:
          _safeSetProperty('sub-border-size', '${prefs.borderSize}');
          _safeSetProperty('sub-border-color', SubtitleStylePrefs.toMpvHexColor(prefs.borderColor));
          _safeSetProperty('sub-shadow-offset', '0');
          break;
        case SubtitleBorderStyle.dropShadow:
          _safeSetProperty('sub-border-size', '0.5');
          _safeSetProperty('sub-border-color', SubtitleStylePrefs.toMpvHexColor(prefs.borderColor));
          _safeSetProperty('sub-shadow-offset', '${prefs.borderSize.clamp(1.0, 5.0)}');
          _safeSetProperty('sub-shadow-color', SubtitleStylePrefs.toMpvHexColor(prefs.borderColor));
          break;
        case SubtitleBorderStyle.raised:
        case SubtitleBorderStyle.depressed:
          _safeSetProperty('sub-border-size', '${(prefs.borderSize * 0.7).clamp(1.0, 4.0)}');
          _safeSetProperty('sub-border-color', SubtitleStylePrefs.toMpvHexColor(prefs.borderColor));
          _safeSetProperty('sub-shadow-offset', '${(prefs.borderSize * 0.6).clamp(1.0, 4.0)}');
          _safeSetProperty('sub-shadow-color', SubtitleStylePrefs.toMpvHexColor(prefs.borderColor));
          break;
      }

      if (prefs.overrideAss) {
        _safeSetProperty('sub-ass-override', 'force');
      } else {
        _safeSetProperty('sub-ass-override', 'scale');
      }
    } catch (e) {
      debugPrint('[MpvPlayerService] Error applying subtitle style: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _player.pause();
    } catch (_) {}
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
