import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';

void main() {
  group('SubtitleStylePrefs & toMpvHexColor Tests', () {
    test('toMpvHexColor formats ARGB into #AARRGGBB correctly for mpv', () {
      // Opaque black (0xFF000000) -> #FF000000 (Alpha FF, Red 00, Green 00, Blue 00)
      expect(SubtitleStylePrefs.toMpvHexColor(0xFF000000), '#FF000000');

      // Fully transparent (0x00000000) -> #00000000
      expect(SubtitleStylePrefs.toMpvHexColor(0x00000000), '#00000000');

      // Opaque white (0xFFFFFFFF) -> #FFFFFFFF
      expect(SubtitleStylePrefs.toMpvHexColor(0xFFFFFFFF), '#FFFFFFFF');

      // Opaque yellow (0xFFFFF176) -> #FFFFF176
      expect(SubtitleStylePrefs.toMpvHexColor(0xFFFFF176), '#FFFFF176');

      // 50% semi-transparent black (0x80000000) -> #80000000
      expect(SubtitleStylePrefs.toMpvHexColor(0x80000000), '#80000000');

      // Opaque cyan (0xFF80D8FF) -> #FF80D8FF
      expect(SubtitleStylePrefs.toMpvHexColor(0xFF80D8FF), '#FF80D8FF');
    });

    test('SubtitleStylePrefs default values and copyWith work properly', () {
      const prefs = SubtitleStylePrefs();
      expect(prefs.overrideAss, false);
      expect(prefs.fontSizeMultiplier, 1.0);
      expect(prefs.fontFamily, 'sans-serif');
      expect(prefs.textColor, 0xFFFFFFFF);
      expect(prefs.borderStyle, SubtitleBorderStyle.outline);

      final modified = prefs.copyWith(
        overrideAss: true,
        fontSizeMultiplier: 1.25,
        fontFamily: 'Trebuchet MS',
        textColor: 0xFFFFF176,
      );

      expect(modified.overrideAss, true);
      expect(modified.fontSizeMultiplier, 1.25);
      expect(modified.fontFamily, 'Trebuchet MS');
      expect(modified.textColor, 0xFFFFF176);
    });

    test('SubtitleStylePrefs serialization and deserialization roundtrip', () {
      const original = SubtitleStylePrefs(
        fontFamily: 'Trebuchet MS',
        fontSizeMultiplier: 1.3,
        bold: true,
        italic: true,
        textColor: 0xFFFFF176,
        backgroundColor: 0x80000000,
        borderStyle: SubtitleBorderStyle.dropShadow,
        borderColor: 0xFF000000,
        borderSize: 4.0,
        overrideAss: true,
      );

      final jsonString = original.toJson();
      final restored = SubtitleStylePrefs.fromJson(jsonString);

      expect(restored.fontFamily, 'Trebuchet MS');
      expect(restored.fontSizeMultiplier, 1.3);
      expect(restored.bold, true);
      expect(restored.italic, true);
      expect(restored.textColor, 0xFFFFF176);
      expect(restored.backgroundColor, 0x80000000);
      expect(restored.borderStyle, SubtitleBorderStyle.dropShadow);
      expect(restored.borderColor, 0xFF000000);
      expect(restored.borderSize, 4.0);
      expect(restored.overrideAss, true);
    });
  });
}
