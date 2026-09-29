import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme Palette & Accent Color Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Palette accent colors match their design specifications', () {
      expect(AppPalettes.catppuccin.accent, const Color(0xFFCBA6F7));
      expect(AppPalettes.tokyoNight.accent, const Color(0xFF7AA2F7));
      expect(AppPalettes.nord.accent, const Color(0xFF88C0D0));
      expect(AppPalettes.dracula.accent, const Color(0xFFBD93F9));
      expect(AppPalettes.cyberpunk.accent, const Color(0xFFF0C674));
      expect(AppPalettes.rosePine.accent, const Color(0xFFEBBCBA));
      expect(AppPalettes.gruvboxDark.accent, const Color(0xFFFABD2F));
      expect(AppPalettes.sakura.accent, const Color(0xFFE05A88));
    });

    test('ThemeSettings uses palette accent by default when customAccentIndex is null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = container.read(themeProvider);
      expect(settings.customAccentIndex, isNull);
      expect(settings.customAccent, isNull);

      final themeTokyo = AppThemeBuilder.buildTheme(
        palette: AppPalettes.tokyoNight,
        isDark: true,
        customAccent: settings.customAccent,
      );
      expect(themeTokyo.colorScheme.primary, AppPalettes.tokyoNight.accent);

      final themeNord = AppThemeBuilder.buildTheme(
        palette: AppPalettes.nord,
        isDark: true,
        customAccent: settings.customAccent,
      );
      expect(themeNord.colorScheme.primary, AppPalettes.nord.accent);

      final themeCyberpunk = AppThemeBuilder.buildTheme(
        palette: AppPalettes.cyberpunk,
        isDark: true,
        customAccent: settings.customAccent,
      );
      expect(themeCyberpunk.colorScheme.primary, AppPalettes.cyberpunk.accent);
    });

    test('Changing palette dynamically updates the accent color and clears any custom accent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);

      // Set to Tokyo Night
      await notifier.setPaletteId(AppPalettes.tokyoNightId);
      var state = container.read(themeProvider);
      expect(state.paletteId, AppPalettes.tokyoNightId);
      expect(state.currentPalette.accent, const Color(0xFF7AA2F7));
      expect(state.customAccent, isNull);

      // Set custom accent override to index 5 (Esmeralda / Green)
      await notifier.setAccentColor(5);
      state = container.read(themeProvider);
      expect(state.customAccentIndex, 5);
      expect(state.customAccent, const Color(0xFF50FA7B));

      var builtTheme = AppThemeBuilder.buildTheme(
        palette: state.currentPalette,
        isDark: true,
        customAccent: state.customAccent,
      );
      expect(builtTheme.colorScheme.primary, const Color(0xFF50FA7B));

      // Now switch to Nord palette: custom accent should be cleared so Nord's natural accent takes over!
      await notifier.setPaletteId(AppPalettes.nordId);
      state = container.read(themeProvider);
      expect(state.paletteId, AppPalettes.nordId);
      expect(state.customAccentIndex, isNull);
      expect(state.customAccent, isNull);

      builtTheme = AppThemeBuilder.buildTheme(
        palette: state.currentPalette,
        isDark: true,
        customAccent: state.customAccent,
      );
      expect(builtTheme.colorScheme.primary, AppPalettes.nord.accent);
    });

    test('Explicitly setting accentColor to null resets to theme default accent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(themeProvider.notifier);
      await notifier.setAccentColor(2); // Cian
      expect(container.read(themeProvider).customAccentIndex, 2);

      await notifier.setAccentColor(null);
      expect(container.read(themeProvider).customAccentIndex, isNull);
      expect(container.read(themeProvider).customAccent, isNull);
    });
  });
}
