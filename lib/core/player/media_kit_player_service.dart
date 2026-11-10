import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:aniting/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:aniting/core/player/renderer_info.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

/// Playback service backed directly by package:media_kit.
class MediaKitPlayerService {
  late final Player player;
  late final VideoController videoController;

  /// Opt-in mpv `display-resample` + interpolation (smooth motion).
  final bool smoothMotion;

  String? _currentTitle;
  String? _currentEpisodeTitle;
  SubtitleStylePrefs? _subtitleStyle;

  /// Whether the native backend (libmpv + libass) renders subtitles itself.
  ///
  /// Desktop builds ship libass, so `.ass` files keep their own styling, fonts,
  /// positioning, karaoke and typesetting instead of being flattened to plain
  /// text by media_kit's Flutter subtitle overlay.
  ///
  /// Android is excluded: media_kit's libass path there needs a bundled font
  /// asset (`PlayerConfiguration.libassAndroidFont`) for fontconfig to resolve
  /// families, and the primary Android engine (ExoPlayer) already renders ASS
  /// natively.
  static bool get usesNativeLibass => !Platform.isAndroid;

  /// Enables verbose libmpv logs (console `[MPV]` lines) for playback debugging.
  ///
  /// Desktop: run with the `ANITING_MPV_DEBUG=1` environment variable.
  /// Any platform: build/run with `--dart-define=ANITING_MPV_DEBUG=true`.
  static bool get verboseLogsEnabled {
    if (const bool.fromEnvironment('ANITING_MPV_DEBUG')) return true;
    if (Platform.isAndroid || Platform.isIOS) return false;
    return Platform.environment['ANITING_MPV_DEBUG'] == '1';
  }

  /// Builds the media_kit configuration. Split out from the constructor so the
  /// libass decision can be unit-tested without spawning a native player.
  static PlayerConfiguration configurationFor({
    required bool isAndroid,
    bool verbose = false,
  }) => PlayerConfiguration(
    libass: !isAndroid,
    logLevel: verbose ? MPVLogLevel.info : MPVLogLevel.error,
  );

  MediaKitPlayerService({this.smoothMotion = false}) {
    final verbose = verboseLogsEnabled;
    player = Player(
      configuration: configurationFor(
        isAndroid: Platform.isAndroid,
        verbose: verbose,
      ),
    );
    videoController = VideoController(player);

    // mpv prints the real adapter it got (`GL_VENDOR` / `GL_RENDERER`) at
    // `vo/gpu=debug`. Nothing else consumes this stream, so it stays enabled
    // once and the GPU panel can show the truth on hybrid laptops.
    player.stream.log.listen((log) {
      if (ingestMpvLogLine(log.text)) return;
      if (verbose) {
        debugPrint('[MPV/${log.level}] ${log.text}');
      }
    });
  }

  /// media_kit's libmpv defaults to `network-timeout=5`, which is too short for
  /// torrent streams: the first read can take longer while pieces are being
  /// fetched, and mpv would abort the connection and give up. Remote HLS/HTTP
  /// streams also benefit from a more tolerant timeout.
  Future<void> _ensureNetworkTimeout() async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty('network-timeout', '30');
    } catch (_) {}
    try {
      // `vo/gpu=debug` exposes the real adapter for the GPU panel. When
      // ANITING_MPV_DEBUG is on, raise everything to info so decoder/cache/
      // frame-pacing warnings reach the console too.
      await platform.setProperty(
        'msg-level',
        verboseLogsEnabled ? 'all=info,vo/gpu=debug' : 'vo/gpu=debug',
      );
    } catch (_) {}

    // Network streams (HLS proxied through the companion server) stutter when
    // mpv keeps its conservative default read-ahead: a slow segment drains the
    // cache and playback waits. These are cheap in memory and let mpv ride out
    // a slow segment instead of rebuffering.
    for (final entry in <String, String>{
      // media_kit leaves `hwdec` unset and mpv's default is `no`, i.e. software
      // decoding. On a laptop doing everything on the iGPU, 1080p HEVC 10-bit or
      // 4K is guaranteed to stutter. `auto-safe` only enables decoders mpv
      // considers stable for the platform (d3d11va / vaapi / mediacodec).
      'hwdec': 'auto-safe',
      'cache': 'yes',
      'cache-pause': 'yes',
      'demuxer-max-bytes': '64MiB',
      'demuxer-max-back-bytes': '32MiB',
      'demuxer-readahead-secs': '30',
      'cache-secs': '30',
      // 24 fps on a 60 Hz panel produces a 3:2 cadence (2.5 vsyncs/frame)
      // that looks like random micro-stutter even with zero dropped frames.
      // Display sync + interpolation resamples the presentation to the panel.
      if (smoothMotion) ...{
        'video-sync': 'display-resample',
        'interpolation': 'yes',
        'tscale': 'oversample',
      },
    }.entries) {
      try {
        await platform.setProperty(entry.key, entry.value);
      } catch (_) {}
    }
  }

  /// Adds an external subtitle as its own mpv track.
  ///
  /// `sub-add` is used instead of `setSubtitleTrack` because the latter replaces
  /// the current selection: online sources expose several languages at once and
  /// all of them must show up in the track picker.
  ///
  /// [select] wins the active track; otherwise the track is registered with
  /// `auto`, which only takes over when nothing else is selected.
  Future<void> addExternalSubtitle({
    required String url,
    String? title,
    String? language,
    bool select = false,
  }) async {
    if (url.isEmpty) return;
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.command([
        'sub-add',
        url,
        select ? 'select' : 'auto',
        title ?? '',
        language ?? '',
      ]);
    } catch (e) {
      debugPrint('[MediaKit] sub-add failed ($language • $url): $e');
    }
  }

  String? get currentTitle => _currentTitle;
  String? get currentEpisodeTitle => _currentEpisodeTitle;

  Future<void> open(
    String url, {
    String? title,
    String? episodeTitle,
    Duration? startPosition,
    Map<String, String>? httpHeaders,
  }) async {
    _currentTitle = title;
    _currentEpisodeTitle = episodeTitle;
    // Make sure the subtitle style is in place before the file (and its
    // embedded/external ASS tracks) starts rendering.
    final style = _subtitleStyle;
    if (style != null) {
      await _applySubtitleProperties(style);
    }
    await _ensureNetworkTimeout();
    await player.open(
      Media(url, httpHeaders: httpHeaders, start: startPosition),
      play: true,
    );
  }

  Future<void> play() => player.play();
  Future<void> pause() => player.pause();
  Future<void> stop() => player.stop();
  Future<void> playOrPause() => player.playOrPause();
  Future<void> seek(Duration position) => player.seek(position);
  Future<void> setRate(double rate) => player.setRate(rate);
  Future<void> setVolume(double volume) => player.setVolume(volume);

  Future<void> setAudioTrack(AudioTrack track) => player.setAudioTrack(track);
  Future<void> setSubtitleTrack(SubtitleTrack track) =>
      player.setSubtitleTrack(track);

  /// Sync offsets (milliseconds). The native backend expects seconds.
  Future<void> setSubtitleDelay(int milliseconds) => _setProperty(
    'sub-delay',
    (milliseconds / 1000).toStringAsFixed(3),
  );

  Future<void> setAudioDelay(int milliseconds) => _setProperty(
    'audio-delay',
    (milliseconds / 1000).toStringAsFixed(3),
  );

  Future<List<PlayerChapter>> getChapters() async => [];

  /// Applies the user's subtitle style to the native renderer.
  ///
  /// These `--sub-*` options always drive the default style used for plain
  /// subtitles (SRT/VTT). ASS files keep their own styling unless
  /// [SubtitleStylePrefs.overrideAss] is on, which switches mpv to
  /// `sub-ass-override=force`.
  void applySubtitleStyle(SubtitleStylePrefs prefs) {
    _subtitleStyle = prefs;
    // Live update: re-apply immediately so changes are visible mid-playback.
    unawaited(_applySubtitleProperties(prefs));
  }

  Future<void> _applySubtitleProperties(SubtitleStylePrefs prefs) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;

    final hasBorder = prefs.borderStyle != SubtitleBorderStyle.none;
    final properties = <String, String>{
      'sub-ass-override': prefs.overrideAss ? 'force' : 'no',
      'sub-font-size': (52 * prefs.fontSizeMultiplier)
          .round()
          .clamp(16, 160)
          .toString(),
      'sub-bold': prefs.bold ? 'yes' : 'no',
      'sub-italic': prefs.italic ? 'yes' : 'no',
      'sub-color': SubtitleStylePrefs.toMpvHexColor(prefs.textColor),
      'sub-back-color': SubtitleStylePrefs.toMpvHexColor(prefs.backgroundColor),
      'sub-border-size': hasBorder
          ? prefs.borderSize.clamp(0.0, 10.0).toStringAsFixed(1)
          : '0',
      'sub-border-color': SubtitleStylePrefs.toMpvHexColor(prefs.borderColor),
      'sub-shadow-offset':
          prefs.borderStyle == SubtitleBorderStyle.dropShadow ? '2' : '0',
    };

    final family = prefs.fontFamily.trim();
    if (family.isNotEmpty && family != 'sans-serif') {
      properties['sub-font'] = family;
    }

    await Future.wait(
      properties.entries.map((entry) async {
        try {
          await platform.setProperty(entry.key, entry.value);
        } catch (_) {}
      }),
    );
  }

  Future<void> _setProperty(String key, String value) async {
    final platform = player.platform;
    if (platform is! NativePlayer) return;
    try {
      await platform.setProperty(key, value);
    } catch (_) {}
  }

  Future<void> dispose() async {
    await player.dispose();
  }
}
