import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_language.dart';
import 'translations/en.dart';
import 'translations/es.dart';
import 'translations/translations.dart';

export 'app_language.dart';
export 'translations/translations.dart';
export 'translations/en.dart';
export 'translations/es.dart';

const _enTranslations = EnglishTranslations();
const _esTranslations = SpanishTranslations();

class AppLanguageNotifier extends Notifier<AppLanguage> {
  static const _prefKey = 'app_language_pref';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  AppLanguage build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final saved = cached.getString(_prefKey);
      if (saved != null) {
        return AppLanguage.fromCode(saved);
      }
    }
    _load();
    return AppLanguage.es;
  }

  Future<void> _load() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = AppLanguage.fromCode(saved);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(AppLanguage language) async {
    state = language;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString(_prefKey, language.code);
    } catch (_) {}
  }
}

final appLanguageProvider =
    NotifierProvider<AppLanguageNotifier, AppLanguage>(AppLanguageNotifier.new);

final translationsProvider = Provider<AppTranslations>((ref) {
  final language = ref.watch(appLanguageProvider);
  switch (language) {
    case AppLanguage.en:
      return _enTranslations;
    case AppLanguage.es:
      return _esTranslations;
  }
});
