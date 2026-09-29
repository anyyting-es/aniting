import 'dart:io' show Platform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PlayerEngine {
  exoplayer(
    'ExoPlayer (Media3)',
    'Aceleración por hardware nativa, menor consumo de batería, soporte .ass con libass y respaldo a libmpv.',
    'exoplayer',
  ),
  mpv(
    'libmpv',
    'Motor universal con soporte integral para todos los codecs, subtítulos y filtros.',
    'mpv',
  );

  final String label;
  final String description;
  final String key;

  const PlayerEngine(this.label, this.description, this.key);

  String localizedDescription(AppTranslations l10n) {
    switch (this) {
      case PlayerEngine.exoplayer:
        return l10n.exoplayerDesc;
      case PlayerEngine.mpv:
        return l10n.mpvDesc;
    }
  }

  static PlayerEngine get defaultEngine {
    if (Platform.isAndroid) {
      return PlayerEngine.exoplayer;
    }
    return PlayerEngine.mpv;
  }

  static PlayerEngine fromKey(String? key) {
    switch (key) {
      case 'exoplayer':
        return PlayerEngine.exoplayer;
      case 'mpv':
        return PlayerEngine.mpv;
      default:
        return PlayerEngine.defaultEngine;
    }
  }
}

class PlayerEngineNotifier extends Notifier<PlayerEngine> {
  static const _prefKey = 'video_player_engine_pref';
  static SharedPreferences? _cachedPrefs;

  static void setCachedPrefs(SharedPreferences prefs) {
    _cachedPrefs = prefs;
  }

  @override
  PlayerEngine build() {
    final cached = _cachedPrefs;
    if (cached != null) {
      final saved = cached.getString(_prefKey);
      if (saved != null) {
        return PlayerEngine.fromKey(saved);
      }
    }
    _load();
    return PlayerEngine.defaultEngine;
  }

  Future<void> _load() async {
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      final saved = prefs.getString(_prefKey);
      if (saved != null) {
        state = PlayerEngine.fromKey(saved);
      }
    } catch (_) {}
  }

  Future<void> setEngine(PlayerEngine engine) async {
    state = engine;
    try {
      final prefs = _cachedPrefs ?? await SharedPreferences.getInstance();
      _cachedPrefs = prefs;
      await prefs.setString(_prefKey, engine.key);
    } catch (_) {}
  }
}

final playerEngineProvider =
    NotifierProvider<PlayerEngineNotifier, PlayerEngine>(PlayerEngineNotifier.new);
