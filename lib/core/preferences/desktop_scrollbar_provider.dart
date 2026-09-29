import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopScrollbarNotifier extends Notifier<bool> {
  static const String _key = 'desktop_scrollbar_enabled';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  bool build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getBool(_key) ?? true;
    }
    _loadFromPrefs();
    return true;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_key) ?? true;
    state = enabled;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final desktopScrollbarProvider =
    NotifierProvider<DesktopScrollbarNotifier, bool>(DesktopScrollbarNotifier.new);
