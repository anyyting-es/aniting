import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

/// Sorting modes matching Seanime's continue watching sorting options
enum ContinueWatchingSortMode {
  recent,
  airDateDesc,
  airDateAsc,
  episodeDesc,
  episodeAsc,
  title;

  String get label {
    switch (this) {
      case ContinueWatchingSortMode.recent:
        return 'Visto recientemente';
      case ContinueWatchingSortMode.airDateDesc:
        return 'Emisión reciente';
      case ContinueWatchingSortMode.airDateAsc:
        return 'Emisión antigua';
      case ContinueWatchingSortMode.episodeDesc:
        return 'Episodio más alto';
      case ContinueWatchingSortMode.episodeAsc:
        return 'Episodio más bajo';
      case ContinueWatchingSortMode.title:
        return 'Título (A-Z)';
    }
  }

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case ContinueWatchingSortMode.recent:
        return l10n.sortRecent;
      case ContinueWatchingSortMode.airDateDesc:
        return l10n.sortAirDateDesc;
      case ContinueWatchingSortMode.airDateAsc:
        return l10n.sortAirDateAsc;
      case ContinueWatchingSortMode.episodeDesc:
        return l10n.sortEpisodeDesc;
      case ContinueWatchingSortMode.episodeAsc:
        return l10n.sortEpisodeAsc;
      case ContinueWatchingSortMode.title:
        return l10n.sortTitle;
    }
  }
}

const _kContinueWatchingSortKey = 'pref_continue_watching_sort';

class ContinueWatchingSortNotifier extends Notifier<ContinueWatchingSortMode> {
  @override
  ContinueWatchingSortMode build() {
    _loadPreference();
    return ContinueWatchingSortMode.recent;
  }

  Future<void> _loadPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kContinueWatchingSortKey);
      if (saved != null) {
        state = ContinueWatchingSortMode.values.firstWhere(
          (e) => e.name == saved,
          orElse: () => ContinueWatchingSortMode.recent,
        );
      }
    } catch (_) {}
  }

  Future<void> setSortMode(ContinueWatchingSortMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kContinueWatchingSortKey, mode.name);
    } catch (_) {}
  }
}

final continueWatchingSortProvider =
    NotifierProvider<ContinueWatchingSortNotifier, ContinueWatchingSortMode>(
  ContinueWatchingSortNotifier.new,
);
