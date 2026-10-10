import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TmdbApiKeyNotifier extends Notifier<String> {
  static const String _key = 'tmdb_api_key_v1';
  static const String defaultKey = '11f51d424de962a06b01b8bec43d9afa';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  String build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getString(_key) ?? defaultKey;
    }
    _loadFromPrefs();
    return defaultKey;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null && saved.isNotEmpty) {
      state = saved;
    }
  }

  Future<void> setApiKey(String key) async {
    state = key.trim().isEmpty ? defaultKey : key.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state);
  }
}

final tmdbApiKeyProvider =
    NotifierProvider<TmdbApiKeyNotifier, String>(TmdbApiKeyNotifier.new);
