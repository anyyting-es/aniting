import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enables the YouTube-style ambient glow around / behind the video.
///
/// Normal layout paints a soft halo around the frame; wide and cinema modes
/// paint the blurred frame behind the video so the letterbox bars take its
/// colours. Enabled by default to preserve the existing look.
class PlayerAmbientGlowNotifier extends Notifier<bool> {
  static const _prefKey = 'player_ambient_glow_enabled';

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, enabled);
    } catch (_) {}
  }
}

final playerAmbientGlowProvider =
    NotifierProvider<PlayerAmbientGlowNotifier, bool>(
      PlayerAmbientGlowNotifier.new,
    );
