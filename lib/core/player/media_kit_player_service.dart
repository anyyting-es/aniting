import 'dart:async';
import 'dart:io' show Platform;

import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Playback service backed directly by package:media_kit.
class MediaKitPlayerService {
  late final Player player;
  late final VideoController videoController;

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

  /// Builds the media_kit configuration. Split out from the constructor so the
  /// libass decision can be unit-tested without spawning a native player.
  static PlayerConfiguration configurationFor({required bool isAndroid}) =>
      PlayerConfiguration(libass: !isAndroid);

  MediaKitPlayerService() {
    player = Player(
      configuration: configurationFor(isAndroid: Platform.isAndroid),
    );
    videoController = VideoController(player);
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
