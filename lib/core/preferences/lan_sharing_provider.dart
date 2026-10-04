import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages the LAN server sharing toggle and server display name.
///
/// When enabled, the local Seanime server binds to `0.0.0.0` (all interfaces)
/// and a UDP beacon is broadcast every 3 seconds so other devices on the same
/// Wi-Fi can auto-discover and connect to this server.
class LanSharingNotifier extends Notifier<bool> {
  static const _key = 'lan_sharing_enabled';

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_key) ?? false;
    if (state != value) state = value;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, state);
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
  }
}

final lanSharingProvider =
    NotifierProvider<LanSharingNotifier, bool>(LanSharingNotifier.new);

/// Manages the user-visible name of this server on the LAN.
class LanServerNameNotifier extends Notifier<String> {
  static const _key = 'lan_server_name';
  static const _defaultName = 'Aniting Server';

  @override
  String build() {
    _load();
    return _defaultName;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_key);
    if (value != null && value.isNotEmpty && state != value) {
      state = value;
    }
  }

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = trimmed;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, trimmed);
  }
}

final lanServerNameProvider =
    NotifierProvider<LanServerNameNotifier, String>(LanServerNameNotifier.new);
