import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DesktopWindowTransparencyState {
  final bool enabled;
  final double opacity;

  const DesktopWindowTransparencyState({
    required this.enabled,
    required this.opacity,
  });

  DesktopWindowTransparencyState copyWith({
    bool? enabled,
    double? opacity,
  }) {
    return DesktopWindowTransparencyState(
      enabled: enabled ?? this.enabled,
      opacity: opacity ?? this.opacity,
    );
  }
}

class DesktopWindowTransparencyNotifier extends Notifier<DesktopWindowTransparencyState> {
  static const String _keyEnabled = 'desktop_window_transparency_enabled';
  static const String _keyOpacity = 'desktop_window_transparency_opacity';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  DesktopWindowTransparencyState build() {
    if (_cachedPrefs != null) {
      final enabled = _cachedPrefs!.getBool(_keyEnabled) ?? false;
      final opacity = _cachedPrefs!.getDouble(_keyOpacity) ?? 0.85;
      return DesktopWindowTransparencyState(enabled: enabled, opacity: opacity.clamp(0.40, 1.0));
    }
    _loadFromPrefs();
    return const DesktopWindowTransparencyState(enabled: false, opacity: 0.85);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? false;
    final opacity = prefs.getDouble(_keyOpacity) ?? 0.85;
    state = DesktopWindowTransparencyState(enabled: enabled, opacity: opacity.clamp(0.40, 1.0));
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setBool(_keyEnabled, enabled);
  }

  Future<void> setOpacity(double opacity) async {
    final clamped = opacity.clamp(0.40, 1.0);
    state = state.copyWith(opacity: clamped);
    final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
    _cachedPrefs = prefs;
    await prefs.setDouble(_keyOpacity, clamped);
  }
}

final desktopWindowTransparencyProvider =
    NotifierProvider<DesktopWindowTransparencyNotifier, DesktopWindowTransparencyState>(
  DesktopWindowTransparencyNotifier.new,
);
