import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BannerBlurNotifier extends Notifier<bool> {
  static const String _key = 'banner_blur_enabled';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  bool build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getBool(_key) ?? false;
    }
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? false;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final bannerBlurProvider =
    NotifierProvider<BannerBlurNotifier, bool>(BannerBlurNotifier.new);
