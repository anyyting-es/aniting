import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GlassEffectsEnabledNotifier extends Notifier<bool> {
  static const String _key = 'glass_effects_enabled_preference';
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
    state = prefs.getBool(_key) ?? true;
  }

  Future<void> toggle() async {
    await setEnabled(!state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final glassEffectsEnabledProvider =
    NotifierProvider<GlassEffectsEnabledNotifier, bool>(
  GlassEffectsEnabledNotifier.new,
);

extension GlassEnabledExtension on bool {
  GlassTier toGlassTier() => this ? GlassTier.full : GlassTier.opaque;
}
