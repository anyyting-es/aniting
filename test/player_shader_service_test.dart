import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/i18n/translations/en.dart';
import 'package:seanime_app/core/i18n/translations/es.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_shader_service.dart';

void main() {
  group('PlayerShaderService and ShaderPreset Tests', () {
    test('Default preset is none and presets list is correctly populated', () {
      final service = PlayerShaderService();
      expect(service.currentPreset, equals(ShaderPreset.none));
      expect(ShaderPreset.presets.length, equals(6));
      expect(ShaderPreset.presets.first.isNone, isTrue);
    });

    test('ShaderPreset localized names render properly in EN and ES', () {
      const en = EnglishTranslations();
      const es = SpanishTranslations();

      final modeA = ShaderPreset.presets.firstWhere((p) => p.id == 'anime4k_mode_a');
      expect(modeA.localizedName(en), equals('Anime4K - Mode A'));
      expect(modeA.localizedName(es), equals('Anime4K - Modo A'));

      final nonePreset = ShaderPreset.none;
      expect(nonePreset.localizedName(en), equals('Disabled'));
      expect(nonePreset.localizedName(es), equals('Desactivado'));

      final nvscaler = ShaderPreset.presets.firstWhere((p) => p.id == 'nvscaler');
      expect(nvscaler.localizedName(en), equals('NVScaler'));
      expect(nvscaler.localizedName(es), equals('NVScaler'));
    });

    test('applyPreset updates currentPreset safely when mpv is null', () async {
      final service = PlayerShaderService();
      final modeB = ShaderPreset.presets.firstWhere((p) => p.id == 'anime4k_mode_b');

      await service.applyPreset(null, modeB);
      expect(service.currentPreset, equals(modeB));

      await service.applyPreset(null, ShaderPreset.none);
      expect(service.currentPreset, equals(ShaderPreset.none));
    });
  });
}
