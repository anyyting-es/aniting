import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TvModeNotifier extends Notifier<bool> {
  static const _prefKey = 'app_tv_mode_enabled';

  @override
  bool build() {
    _load();
    return false; // disabled by default
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

  Future<void> toggle() async {
    await setEnabled(!state);
  }
}

final tvModeProvider = NotifierProvider<TvModeNotifier, bool>(
  TvModeNotifier.new,
);
