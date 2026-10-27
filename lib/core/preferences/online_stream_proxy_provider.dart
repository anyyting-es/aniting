import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnlineStreamProxyNotifier extends Notifier<bool> {
  static const _prefKey = 'player_online_stream_proxy_enabled';

  @override
  bool build() {
    _load();
    return true; // enabled by default for maximum stability
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

final onlineStreamProxyProvider = NotifierProvider<OnlineStreamProxyNotifier, bool>(
  OnlineStreamProxyNotifier.new,
);
