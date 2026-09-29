import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsSidebarWidthNotifier extends Notifier<double> {
  static const String _key = 'settings_sidebar_width';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  double build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getDouble(_key) ?? 340.0;
    }
    _loadFromPrefs();
    return 340.0;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final width = prefs.getDouble(_key) ?? 340.0;
    state = width;
  }

  Future<void> setWidth(double width) async {
    final clamped = width.clamp(240.0, 520.0);
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, clamped);
  }
}

final settingsSidebarWidthProvider =
    NotifierProvider<SettingsSidebarWidthNotifier, double>(
        SettingsSidebarWidthNotifier.new);
