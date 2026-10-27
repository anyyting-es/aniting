import 'package:flutter/foundation.dart';
import '../../core/i18n/i18n_provider.dart';
import '../repositories/seanime_repository.dart';

class DefaultExtensionsService {
  static const Map<String, String> esRecommended = {
    'jkanime':
        'https://raw.githubusercontent.com/mohaisreal/seanime-ext/main/src/JkAnime/manifest.json',
    'animeav1':
        'https://raw.githubusercontent.com/pal-droid/seanime-providers/main/src/anime/AnimeAV1/manifest.json',
    'aniting-universal':
        'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/src/aniting-universal/manifest.json',
    'animetosho-new':
        'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/src/animetosho-new/manifest.json',
  };

  static const Map<String, String> enRecommended = {
    'animepahe':
        'https://raw.githubusercontent.com/5rahim/hibike/main/src/anime/Animepahe/manifest.json',
    'hianime':
        'https://raw.githubusercontent.com/5rahim/hibike/main/src/anime/Hianime/manifest.json',
    'animetosho-new':
        'https://raw.githubusercontent.com/anyyting-es/aniting-extensions/main/src/animetosho-new/manifest.json',
    'nyaa':
        'https://raw.githubusercontent.com/5rahim/hibike/main/src/torrent/Nyaa/manifest.json',
  };

  /// Installs default recommended streaming and torrent extensions based on language.
  /// Skips any extensions that are already installed.
  static Future<int> installRecommended(
    SeanimeRepository repo, {
    AppLanguage language = AppLanguage.es,
  }) async {
    final targets = language == AppLanguage.es ? esRecommended : enRecommended;
    int installedCount = 0;

    try {
      final existing = await repo.getAllExtensions(withUpdates: false);
      final existingIds = existing.map((e) => e.id).toSet();

      for (final entry in targets.entries) {
        if (existingIds.contains(entry.key)) continue;
        try {
          final ok = await repo.installExtension(entry.value);
          if (ok) {
            installedCount++;
            debugPrint('[DefaultExtensionsService] Installed ${entry.key}');
          }
        } catch (e) {
          debugPrint(
              '[DefaultExtensionsService] Error installing ${entry.key}: $e');
        }
      }
    } catch (e) {
      debugPrint(
          '[DefaultExtensionsService] Failed to load existing extensions: $e');
    }

    return installedCount;
  }
}
