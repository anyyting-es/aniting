import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TitleLanguage {
  romaji('Romaji', 'Ej: Sousou no Frieren', 'romaji'),
  english('Inglés', 'Ej: Frieren: Beyond Journey\'s End', 'english'),
  native('Nativo (Japonés)', 'Ej: 葬送のフリーレン', 'native');

  final String label;
  final String example;
  final String key;
  const TitleLanguage(this.label, this.example, this.key);

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case TitleLanguage.romaji:
        return l10n.titleRomaji;
      case TitleLanguage.english:
        return l10n.titleEnglish;
      case TitleLanguage.native:
        return l10n.titleNative;
    }
  }

  String localizedExample(AppTranslations l10n) {
    final prefix = l10n.titleExample;
    switch (this) {
      case TitleLanguage.romaji:
        return '$prefix Sousou no Frieren';
      case TitleLanguage.english:
        return '$prefix Frieren: Beyond Journey\'s End';
      case TitleLanguage.native:
        return '$prefix 葬送のフリーレン';
    }
  }

  static TitleLanguage fromKey(String? key) {
    switch (key) {
      case 'english':
        return TitleLanguage.english;
      case 'native':
        return TitleLanguage.native;
      case 'romaji':
      default:
        return TitleLanguage.romaji;
    }
  }
}

class TitleLanguageNotifier extends Notifier<TitleLanguage> {
  static const _prefKey = 'user_title_language';

  @override
  TitleLanguage build() {
    _load();
    return TitleLanguage.romaji;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = TitleLanguage.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setLanguage(TitleLanguage language) async {
    state = language;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, language.key);
    } catch (_) {}
  }
}

final titleLanguageProvider =
    NotifierProvider<TitleLanguageNotifier, TitleLanguage>(TitleLanguageNotifier.new);
