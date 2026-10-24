import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/wallpaper_preferences_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('AppWallpaperState default values and validation', () {
    const defaultState = AppWallpaperState();
    expect(defaultState.enabled, isFalse);
    expect(defaultState.filePath, isNull);
    expect(defaultState.opacity, 0.35);
    expect(defaultState.blur, 10.0);
    expect(defaultState.hasValidWallpaper, isFalse);
    expect(defaultState.fileName, isEmpty);

    const withFile = AppWallpaperState(
      enabled: true,
      filePath: '/tmp/frieren_river.jpg',
      opacity: 0.5,
      blur: 15.0,
    );
    expect(withFile.fileName, 'frieren_river.jpg');
    expect(withFile.opacity, 0.5);
    expect(withFile.blur, 15.0);
  });

  test('AppWallpaperNotifier updates opacity and blur with clamping', () async {
    final prefs = await SharedPreferences.getInstance();
    AppWallpaperNotifier.setCachedPrefs(prefs);

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(wallpaperPreferencesProvider.notifier);

    await notifier.setOpacity(0.75);
    expect(container.read(wallpaperPreferencesProvider).opacity, 0.75);

    await notifier.setBlur(25.0);
    expect(container.read(wallpaperPreferencesProvider).blur, 25.0);

    // Test clamping
    await notifier.setOpacity(1.5);
    expect(container.read(wallpaperPreferencesProvider).opacity, 0.95);

    await notifier.setOpacity(-0.5);
    expect(container.read(wallpaperPreferencesProvider).opacity, 0.05);

    await notifier.setBlur(60.0);
    expect(container.read(wallpaperPreferencesProvider).blur, 40.0);

    await notifier.setBlur(-10.0);
    expect(container.read(wallpaperPreferencesProvider).blur, 0.0);
  });
}
