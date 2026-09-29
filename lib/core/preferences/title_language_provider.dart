import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TitleLanguage {
  romaji('Romaji', 'Ej: Sousou no Frieren', 'romaji'),
  english('Inglés', 'Ej: Frieren: Beyond Journey\'s End', 'english'),
  native('Nativo (Japonés)', 'Ej: 葬送のフリーレン', 'native');

  final String label;
  final String example;
  final String key;
  const TitleLanguage(this.label, this.example, this.key);

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
