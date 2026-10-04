import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/desktop_nav_style_provider.dart';
import 'package:seanime_app/core/i18n/translations/en.dart';
import 'package:seanime_app/core/i18n/translations/es.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopNavStyle Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Defaults to sidebar when no cached prefs exist', () {
      final notifier = DesktopNavStyleNotifier();
      expect(notifier.build(), DesktopNavStyle.sidebar);
    });

    test('Loads saved style from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'desktop_nav_style_v1': 'floating',
      });
      final prefs = await SharedPreferences.getInstance();
      DesktopNavStyleNotifier.setCachedPrefs(prefs);

      final notifier = DesktopNavStyleNotifier();
      expect(notifier.build(), DesktopNavStyle.floating);
    });

    test('setStyle updates state and persists to SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      DesktopNavStyleNotifier.setCachedPrefs(prefs);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(desktopNavStyleProvider), DesktopNavStyle.sidebar);

      await container.read(desktopNavStyleProvider.notifier).setStyle(DesktopNavStyle.floating);
      expect(container.read(desktopNavStyleProvider), DesktopNavStyle.floating);
      expect(prefs.getString('desktop_nav_style_v1'), 'floating');

      await container.read(desktopNavStyleProvider.notifier).setStyle(DesktopNavStyle.sidebar);
      expect(container.read(desktopNavStyleProvider), DesktopNavStyle.sidebar);
      expect(prefs.getString('desktop_nav_style_v1'), 'sidebar');
    });

    test('Localizations provide valid strings in English and Spanish', () {
      final en = const EnglishTranslations();
      final es = const SpanishTranslations();

      expect(DesktopNavStyle.sidebar.localizedLabel(en), isNotEmpty);
      expect(DesktopNavStyle.floating.localizedLabel(en), isNotEmpty);

      expect(DesktopNavStyle.sidebar.localizedLabel(es), isNotEmpty);
      expect(DesktopNavStyle.floating.localizedLabel(es), isNotEmpty);

      expect(en.desktopNavStyle, isNotEmpty);
      expect(en.desktopNavStyleDesc, isNotEmpty);
      expect(es.desktopNavStyle, isNotEmpty);
      expect(es.desktopNavStyleDesc, isNotEmpty);
    });
  });
}
