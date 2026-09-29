import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MangaReadingMode {
  webtoon,   // Deslizando continuo vertical
  pagedLtr,  // Página a página Izquierda a Derecha
  pagedRtl,  // Página a página Derecha a Izquierda (Manga tradicional)
}

enum MangaStatusBarMode {
  smart,     // Oculto mientras se lee, visible con controles
  hidden,    // Siempre oculto (inmersivo total)
  visible,   // Siempre visible
}

class MangaReaderPreferences {
  final MangaReadingMode readingMode;
  final MangaStatusBarMode statusBarMode;
  final bool tapToTurnEnabled;
  final bool subtleShadowEnabled;

  const MangaReaderPreferences({
    this.readingMode = MangaReadingMode.webtoon,
    this.statusBarMode = MangaStatusBarMode.smart,
    this.tapToTurnEnabled = true,
    this.subtleShadowEnabled = true,
  });

  MangaReaderPreferences copyWith({
    MangaReadingMode? readingMode,
    MangaStatusBarMode? statusBarMode,
    bool? tapToTurnEnabled,
    bool? subtleShadowEnabled,
  }) {
    return MangaReaderPreferences(
      readingMode: readingMode ?? this.readingMode,
      statusBarMode: statusBarMode ?? this.statusBarMode,
      tapToTurnEnabled: tapToTurnEnabled ?? this.tapToTurnEnabled,
      subtleShadowEnabled: subtleShadowEnabled ?? this.subtleShadowEnabled,
    );
  }
}

class MangaReaderPreferencesNotifier extends Notifier<MangaReaderPreferences> {
  static const String _keyReadingMode = 'manga_reading_mode';
  static const String _keyStatusBarMode = 'manga_status_bar_mode';
  static const String _keyTapToTurn = 'manga_tap_to_turn';
  static const String _keySubtleShadow = 'manga_subtle_shadow';

  @override
  MangaReaderPreferences build() {
    _loadFromPrefs();
    return const MangaReaderPreferences();
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final readingModeIndex = prefs.getInt(_keyReadingMode) ?? 0;
    final statusBarModeIndex = prefs.getInt(_keyStatusBarMode) ?? 0;
    final tapToTurn = prefs.getBool(_keyTapToTurn) ?? true;
    final subtleShadow = prefs.getBool(_keySubtleShadow) ?? true;

    state = MangaReaderPreferences(
      readingMode: MangaReadingMode.values[
          readingModeIndex.clamp(0, MangaReadingMode.values.length - 1)],
      statusBarMode: MangaStatusBarMode.values[
          statusBarModeIndex.clamp(0, MangaStatusBarMode.values.length - 1)],
      tapToTurnEnabled: tapToTurn,
      subtleShadowEnabled: subtleShadow,
    );
  }

  Future<void> setReadingMode(MangaReadingMode mode) async {
    state = state.copyWith(readingMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyReadingMode, mode.index);
  }

  Future<void> setStatusBarMode(MangaStatusBarMode mode) async {
    state = state.copyWith(statusBarMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyStatusBarMode, mode.index);
  }

  Future<void> setTapToTurnEnabled(bool enabled) async {
    state = state.copyWith(tapToTurnEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTapToTurn, enabled);
  }

  Future<void> setSubtleShadowEnabled(bool enabled) async {
    state = state.copyWith(subtleShadowEnabled: enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySubtleShadow, enabled);
  }
}

final mangaReaderPreferencesProvider =
    NotifierProvider<MangaReaderPreferencesNotifier, MangaReaderPreferences>(
  MangaReaderPreferencesNotifier.new,
);
