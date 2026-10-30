import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/widgets/player/viewport/ambient_video_glow.dart';

void main() {
  group('AmbientVideoGlow.canPaintFrame', () {
    test('rejects the 1x1 placeholder texture used by media_kit', () {
      // media_kit creates a 1x1 surface to initialise the render context
      // before the real video size is known. Painting it (blurred and scaled)
      // shows a flat square of colour behind the player.
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 1, 1)),
        isFalse,
      );
    });

    test('rejects a missing rectangle', () {
      expect(AmbientVideoGlow.canPaintFrame(null), isFalse);
    });

    test('rejects a degenerate rectangle', () {
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 0, 0)),
        isFalse,
      );
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 1920, 0)),
        isFalse,
      );
    });

    test('accepts a real video frame size', () {
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 1920, 1080)),
        isTrue,
      );
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 640, 360)),
        isTrue,
      );
      // Just above the placeholder threshold.
      expect(
        AmbientVideoGlow.canPaintFrame(const Rect.fromLTWH(0, 0, 2, 2)),
        isTrue,
      );
    });
  });
}
