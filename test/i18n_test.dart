import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('i18n & Localization Tests', () {
    test('AppLanguage fromCode maps properly and defaults to Spanish', () {
      expect(AppLanguage.fromCode('en'), AppLanguage.en);
      expect(AppLanguage.fromCode('es'), AppLanguage.es);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.es);
      expect(AppLanguage.fromCode(null), AppLanguage.es);
    });

    test('English and Spanish translations provide non-empty values for all keys', () {
      const en = EnglishTranslations();
      const es = SpanishTranslations();

      expect(en.navHome, 'Home');
      expect(es.navHome, 'Inicio');

      expect(en.navExplore, 'Explore');
      expect(es.navExplore, 'Explorar');

      expect(en.navProfile, 'Library');
      expect(es.navProfile, 'Perfil');

      expect(en.settingsTitle, 'Settings');
      expect(es.settingsTitle, 'Configuración');

      expect(en.appLanguage, 'App Language');
      expect(es.appLanguage, 'Idioma de la Aplicación');

      expect(en.playbackStats, 'Playback Stats');
      expect(es.playbackStats, 'Stats de Reproducción');

      // Newly added player & modal keys
      expect(en.engine, 'Engine');
      expect(es.engine, 'Motor');

      expect(en.automatic, 'Automatic');
      expect(es.automatic, 'Automático');

      expect(en.videoCodec, 'Video Codec');
      expect(es.videoCodec, 'Códec Video');

      expect(en.resolution, 'Resolution');
      expect(es.resolution, 'Resolución');

      expect(en.droppedFrames, 'Dropped Frames');
      expect(es.droppedFrames, 'Cuadros perdidos');

      expect(en.hwDecoder, 'Decoder (HW)');
      expect(es.hwDecoder, 'Decodificador (HW)');

      expect(en.videoBitrate, 'Video Bitrate');
      expect(es.videoBitrate, 'Bitrate Video');

      expect(en.audioBitrate, 'Audio Bitrate');
      expect(es.audioBitrate, 'Bitrate Audio');

      expect(en.demuxerCache, 'Demuxer Cache');
      expect(es.demuxerCache, 'Caché Demuxer');

      expect(en.subtitles, 'Subtitles');
      expect(es.subtitles, 'Subtítulos');

      expect(en.copyCode, 'Copy code');
      expect(es.copyCode, 'Copiar código');

      expect(en.searchAnimePlaceholder, 'e.g., Frieren, Dandadan, Bleach...');
      expect(es.searchAnimePlaceholder, 'Ej: Frieren, Dandadan, Bleach...');

      expect(en.normal, 'Normal');
      expect(es.normal, 'Normal');

      expect(en.disabled, 'Disabled');
      expect(es.disabled, 'Desactivado');

      expect(en.noChapters, 'No chapters available');
      expect(es.noChapters, 'No hay capítulos disponibles');

      expect(en.noAudioTracks, 'No audio tracks found');
      expect(es.noAudioTracks, 'No se encontraron pistas de audio');

      expect(en.noSubtitleTracks, 'No subtitle tracks found');
      expect(es.noSubtitleTracks, 'No se encontraron pistas de subtítulos');

      expect(en.switchingToMpvNotice, 'Switching to libmpv for format compatibility...');
      expect(es.switchingToMpvNotice, 'Conmutando a libmpv por compatibilidad de formato...');
    });

    test('AppLanguageNotifier persists language and translationsProvider updates reactively', () async {
      SharedPreferences.setMockInitialValues({'app_language_pref': 'es'});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Trigger build
      final initialLang = container.read(appLanguageProvider);
      expect(initialLang, AppLanguage.es);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(appLanguageProvider), AppLanguage.es);
      expect(container.read(translationsProvider).navHome, 'Inicio');

      // Switch to English
      await container.read(appLanguageProvider.notifier).setLanguage(AppLanguage.en);
      expect(container.read(appLanguageProvider), AppLanguage.en);
      expect(container.read(translationsProvider).navHome, 'Home');
      expect(container.read(translationsProvider).settingsTitle, 'Settings');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('app_language_pref'), 'en');
    });
  });
}
