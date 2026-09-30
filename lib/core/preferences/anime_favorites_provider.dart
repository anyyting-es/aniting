import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kAnimeFavoritesKey = 'user_favorite_anime_ids_v1';

class AnimeFavoritesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() {
    _load();
    return <int>{};
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_kAnimeFavoritesKey) ?? [];
      state = list.map((e) => int.tryParse(e)).whereType<int>().toSet();
    } catch (_) {}
  }

  bool isFavorite(int mediaId) => state.contains(mediaId);

  bool toggleFavorite(int mediaId) {
    final next = Set<int>.from(state);
    final isFav = next.contains(mediaId);
    if (isFav) {
      next.remove(mediaId);
    } else {
      next.add(mediaId);
    }
    state = next;
    _persist();
    return !isFav;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _kAnimeFavoritesKey,
        state.map((id) => id.toString()).toList(),
      );
    } catch (_) {}
  }
}

final animeFavoritesProvider =
    NotifierProvider<AnimeFavoritesNotifier, Set<int>>(() {
  return AnimeFavoritesNotifier();
});
