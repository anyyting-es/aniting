import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Enables mpv display-resample + interpolation.
///
/// This is the only reliable way to remove the 24 fps → 60 Hz 3:2 judder that
/// many people perceive as random "mini tirones" while every drop counter
/// stays at zero. It costs GPU and can introduce slight motion smoothing, so
/// it stays opt-in.
class PlayerSmoothMotionNotifier extends Notifier<bool> {
  static const _prefKey = 'player_smooth_motion_enabled';

  @override
  bool build() {
    _load();
    return false;
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

final playerSmoothMotionProvider =
    NotifierProvider<PlayerSmoothMotionNotifier, bool>(
      PlayerSmoothMotionNotifier.new,
    );
