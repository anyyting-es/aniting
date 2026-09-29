import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum EpisodeViewMode {
  list('Lista detallada', 'list'),
  grid('Cuadrícula compacta', 'grid');

  final String label;
  final String key;
  const EpisodeViewMode(this.label, this.key);

  static EpisodeViewMode fromKey(String? key) {
    if (key == 'grid') return EpisodeViewMode.grid;
    return EpisodeViewMode.list;
  }
}

class EpisodeViewModeNotifier extends Notifier<EpisodeViewMode> {
  static const _prefKey = 'episode_view_mode';

  @override
  EpisodeViewMode build() {
    _load();
    return EpisodeViewMode.list;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = EpisodeViewMode.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setMode(EpisodeViewMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, mode.key);
    } catch (_) {}
  }

  Future<void> toggleMode() async {
    final next = state == EpisodeViewMode.list ? EpisodeViewMode.grid : EpisodeViewMode.list;
    await setMode(next);
  }
}

final episodeViewModeProvider =
    NotifierProvider<EpisodeViewModeNotifier, EpisodeViewMode>(EpisodeViewModeNotifier.new);
