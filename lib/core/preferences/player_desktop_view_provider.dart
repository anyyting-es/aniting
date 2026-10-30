import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desktop watch-page chrome preferences: the layout mode cycled by the cinema
/// button, whether the episode rail is visible at all, and whether the episode
/// list is rendered as detailed cards or as compact numbered tiles.

class _CachedPrefs {
  static SharedPreferences? instance;
}

/// Layout mode of the desktop watch page: normal / wide / cinema.
class PlayerLayoutModeNotifier extends Notifier<PlayerLayoutMode> {
  static const String _key = 'player_layout_mode';

  @override
  PlayerLayoutMode build() {
    final raw = _CachedPrefs.instance?.getString(_key);
    return PlayerLayoutMode.values.firstWhere(
      (mode) => mode.name == raw,
      orElse: () => PlayerLayoutMode.normal,
    );
  }

  Future<void> setMode(PlayerLayoutMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      await _CachedPrefs.instance?.setString(_key, mode.name);
    } catch (_) {}
  }

  /// Cycles normal → wide → cinema → normal.
  Future<void> cycle() => setMode(state.next);
}

/// Whether the right-hand episode rail is shown on the desktop watch page.
class PlayerEpisodesRailVisibleNotifier extends Notifier<bool> {
  static const String _key = 'player_episodes_rail_visible';

  @override
  bool build() => _CachedPrefs.instance?.getBool(_key) ?? true;

  Future<void> setVisible(bool visible) async {
    if (state == visible) return;
    state = visible;
    try {
      await _CachedPrefs.instance?.setBool(_key, visible);
    } catch (_) {}
  }

  Future<void> toggle() => setVisible(!state);
}

/// Whether the episode list uses the compact numbered grid instead of the
/// detailed cards with artwork and synopsis.
class PlayerEpisodeListCompactNotifier extends Notifier<bool> {
  static const String _key = 'player_episode_list_compact';

  @override
  bool build() => _CachedPrefs.instance?.getBool(_key) ?? false;

  Future<void> setCompact(bool compact) async {
    if (state == compact) return;
    state = compact;
    try {
      await _CachedPrefs.instance?.setBool(_key, compact);
    } catch (_) {}
  }

  Future<void> toggle() => setCompact(!state);
}

final playerLayoutModeProvider =
    NotifierProvider<PlayerLayoutModeNotifier, PlayerLayoutMode>(
      PlayerLayoutModeNotifier.new,
    );

final playerEpisodesRailVisibleProvider =
    NotifierProvider<PlayerEpisodesRailVisibleNotifier, bool>(
      PlayerEpisodesRailVisibleNotifier.new,
    );

final playerEpisodeListCompactProvider =
    NotifierProvider<PlayerEpisodeListCompactNotifier, bool>(
      PlayerEpisodeListCompactNotifier.new,
    );

/// Seeds the synchronous caches so the player chrome renders with the saved
/// preferences on the very first frame.
void setPlayerDesktopViewPrefs(SharedPreferences prefs) {
  _CachedPrefs.instance = prefs;
}
