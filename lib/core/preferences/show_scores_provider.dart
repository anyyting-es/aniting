import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShowScoresNotifier extends Notifier<bool> {
  static const _prefKey = 'show_scores_on_cards';

  @override
  bool build() {
    _load();
    return false; // Default: false (clean cards by default)
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getBool(_prefKey);
      if (saved != null) {
        state = saved;
      }
    } catch (_) {}
  }

  Future<void> setShowScores(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  Future<void> toggle() async {
    await setShowScores(!state);
  }
}

final showScoresProvider = NotifierProvider<ShowScoresNotifier, bool>(ShowScoresNotifier.new);
