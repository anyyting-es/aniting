import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/player/services/player_shader_service.dart';

void main() {
  group('shaderChainFor', () {
    test('none has no chain', () {
      expect(shaderChainFor('none'), isEmpty);
      expect(shaderChainFor('unknown-preset'), isEmpty);
    });

    test('anime4k presets keep the documented hook order', () {
      for (final id in ['anime4k_mode_a', 'anime4k_mode_b']) {
        final chain = shaderChainFor(id);
        expect(chain.length, 4, reason: id);
        expect(chain.first, endsWith('Anime4K_Clamp_Highlights.glsl'));
        expect(chain[1], contains('Anime4K_Restore_CNN_'));
        expect(chain[2], contains('Anime4K_Upscale_CNN_x2_'));
        expect(chain.last, endsWith('Anime4K_AutoDownscalePre_x2.glsl'));
      }
    });

    test('mode c stops before the downscale guard', () {
      final chain = shaderChainFor('anime4k_mode_c');
      expect(chain.length, 3);
      expect(chain.last, contains('Anime4K_Upscale_CNN_x2_'));
    });

    test('every referenced asset exists in the bundle declaration', () {
      // Guards against renaming a shader file without updating the chain: the
      // paths must live under assets/shaders/, which is what pubspec bundles.
      for (final id in [
        'anime4k_mode_a',
        'anime4k_mode_b',
        'anime4k_mode_c',
        'nvscaler',
        'artcnn',
      ]) {
        for (final asset in shaderChainFor(id)) {
          expect(
            asset.startsWith('assets/shaders/'),
            isTrue,
            reason: '$id -> $asset',
          );
          expect(asset.endsWith('.glsl'), isTrue, reason: '$id -> $asset');
        }
      }
    });

    test('nvscaler and artcnn are single-file chains', () {
      expect(shaderChainFor('nvscaler').single, endsWith('NVScaler.glsl'));
      expect(shaderChainFor('artcnn').single, endsWith('ArtCNN_C4F16.glsl'));
    });
  });
}
