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

  MediaKitPlayerService() {
    player = Player();
    videoController = VideoController(player);
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

  Future<List<PlayerChapter>> getChapters() async => [];

  void applySubtitleStyle(SubtitleStylePrefs prefs) {}

  Future<void> dispose() async {
    await player.dispose();
  }
}
