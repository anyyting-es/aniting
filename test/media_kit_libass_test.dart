import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/player/media_kit_player_service.dart';

void main() {
  group('media_kit subtitle rendering', () {
    test('desktop renders subtitles natively with libass', () {
      final configuration = MediaKitPlayerService.configurationFor(
        isAndroid: false,
      );
      expect(configuration.libass, isTrue);
    });

    test('Android keeps Flutter-based subtitles (ExoPlayer handles ASS)', () {
      final configuration = MediaKitPlayerService.configurationFor(
        isAndroid: true,
      );
      expect(configuration.libass, isFalse);
    });

    test('the current desktop host enables libass', () {
      expect(MediaKitPlayerService.usesNativeLibass, isTrue);
    });
  });
}
