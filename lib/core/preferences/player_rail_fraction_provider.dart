import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Width of the desktop player's right episode rail, expressed as a fraction of
/// the page width so the rail scales down together with the video when the
/// window shrinks. Dragging the divider changes the fraction.
class PlayerRailFractionNotifier extends Notifier<double> {
  static const String _key = 'player_rail_fraction';
  static const double minFraction = 0.24;
  static const double maxFraction = 0.5;
  static const double defaultFraction = 0.4;

  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  double build() {
    if (_cachedPrefs != null) {
      return _cachedPrefs!.getDouble(_key) ?? defaultFraction;
    }
    _loadFromPrefs();
    return defaultFraction;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getDouble(_key) ?? defaultFraction;
  }

  Future<void> setFraction(double fraction) async {
    final clamped = fraction.clamp(minFraction, maxFraction);
    state = clamped;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_key, clamped);
  }
}

final playerRailFractionProvider =
    NotifierProvider<PlayerRailFractionNotifier, double>(
      PlayerRailFractionNotifier.new,
    );
