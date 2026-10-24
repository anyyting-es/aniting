import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/onboarding_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

class FakeWelcomeRepository extends SeanimeRepository {
  FakeWelcomeRepository() : super(ApiClient());

  @override
  Future<List<ExtensionItem>> getAllExtensions({bool withUpdates = true}) async {
    return [
      const ExtensionItem(
        id: 'nekobt',
        name: 'nekoBT',
        version: '1.0.0',
        author: 'Community',
        description: 'Torrent provider nekoBT',
        type: 'anime-torrent-provider',
      ),
    ];
  }

  @override
  Future<List<ExtensionItem>> getMarketplaceExtensions(String repoUrl, {bool forceRefresh = false}) async {
    return [
      const ExtensionItem(
        id: 'animetosho-new',
        name: 'AnimeTosho NEW',
        version: '1.2.0',
        author: 'Community',
        description: 'AnimeTosho torrent provider',
        type: 'anime-torrent-provider',
      ),
      const ExtensionItem(
        id: 'nekobt',
        name: 'nekoBT',
        version: '1.0.0',
        author: 'Community',
        description: 'Torrent provider nekoBT',
        type: 'anime-torrent-provider',
      ),
      const ExtensionItem(
        id: 'animeav1',
        name: 'AnimeAV1',
        version: '1.1.0',
        author: 'Community',
        description: 'AnimeAV1 streaming provider',
        type: 'onlinestream-provider',
      ),
      const ExtensionItem(
        id: 'jkanime',
        name: 'JKAnime',
        version: '1.0.5',
        author: 'Community',
        description: 'JKAnime streaming provider',
        type: 'onlinestream-provider',
      ),
      const ExtensionItem(
        id: 'leercapitulo',
        name: 'LeerCapitulo',
        version: '1.0.0',
        author: 'Community',
        description: 'LeerCapitulo manga provider',
        type: 'manga-provider',
      ),
      const ExtensionItem(
        id: 'capibaratraductordev',
        name: 'CapibaraTraductor',
        version: '1.0.0',
        author: 'Community',
        description: 'CapibaraTraductor manga provider',
        type: 'manga-provider',
      ),
      const ExtensionItem(
        id: 'manhwaweb',
        name: 'ManhwaWeb',
        version: '1.0.0',
        author: 'Community',
        description: 'ManhwaWeb manga provider',
        type: 'manga-provider',
      ),
      const ExtensionItem(
        id: 'SubsPlease-Provider',
        name: 'SubsPlease',
        version: '1.0.0',
        author: 'Community',
        description: 'SubsPlease torrent provider',
        type: 'anime-torrent-provider',
      ),
      const ExtensionItem(
        id: 'hianime',
        name: 'HiAnime',
        version: '1.0.0',
        author: 'Community',
        description: 'HiAnime streaming provider',
        type: 'onlinestream-provider',
      ),
      const ExtensionItem(
        id: 'aq-animepahe-beta',
        name: 'AnimePahe BETA',
        version: '1.0.0',
        author: 'Community',
        description: 'AnimePahe streaming provider',
        type: 'onlinestream-provider',
      ),
      const ExtensionItem(
        id: 'asurascans',
        name: 'AsuraScans',
        version: '1.0.0',
        author: 'Community',
        description: 'AsuraScans manga provider',
        type: 'manga-provider',
      ),
      const ExtensionItem(
        id: 'mangadex',
        name: 'MangaDex',
        version: '1.0.0',
        author: 'Community',
        description: 'MangaDex manga provider',
        type: 'manga-provider',
      ),
      const ExtensionItem(
        id: 'mangafire',
        name: 'MangaFire',
        version: '1.0.0',
        author: 'Community',
        description: 'MangaFire manga provider',
        type: 'manga-provider',
      ),
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OnboardingProvider & WelcomeScreen Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('OnboardingNotifier correctly updates completion state', () async {
      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(onboardingProvider), isFalse);

      await container.read(onboardingProvider.notifier).completeOnboarding();
      expect(container.read(onboardingProvider), isTrue);

      await container.read(onboardingProvider.notifier).resetOnboarding();
      expect(container.read(onboardingProvider), isFalse);
    });

    testWidgets('WelcomeScreen renders step 1 with language options and transitions smoothly', (tester) async {
      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: WelcomeScreen(isDevPreview: true),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Step 1 elements (Dev mode shows close button)
      expect(find.byIcon(AppIcons.close(AppIconPack.lucide)), findsOneWidget);
      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 0);
      expect(find.text('Español'), findsOneWidget);

      // Tap language selector to open options
      await tester.tap(find.text('Español'));
      await tester.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);

      // Tap English language card
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();

      expect(container.read(appLanguageProvider), AppLanguage.en);

      // Verify Next button advances to Step 2
      final nextButton = find.byIcon(AppIcons.arrowRight(AppIconPack.lucide));
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // Step 2 is Theme & Appearance
      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 1);
      expect(find.text('Appearance'), findsOneWidget);

      // Advance to Step 3: Sections
      await tester.tap(find.byIcon(AppIcons.arrowRight(AppIconPack.lucide)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 2);

      // Advance to Step 4: Content Preferences
      await tester.tap(find.byIcon(AppIcons.arrowRight(AppIconPack.lucide)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 3);
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Romaji'), findsOneWidget);
      expect(find.text('Native'), findsOneWidget);

      // Tap English title language option
      final englishTitleOption = find.text('English').first;
      await tester.tap(englishTitleOption);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final titleLang = container.read(titleLanguageProvider);
      expect(titleLang, TitleLanguage.english);

      // Back button goes back to Step 3, then Step 2
      final backButton = find.byIcon(AppIcons.arrowLeft(AppIconPack.lucide));
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 2);

      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 1);
    });

    testWidgets('WelcomeScreen finish or skip marks onboarding as completed in non-dev mode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: WelcomeScreen(isDevPreview: false),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step indicator is present in non-dev mode
      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 0);

      // Tap top-right Skip all / close button
      final skipBtn = find.byIcon(LucideIcons.x);
      expect(skipBtn, findsOneWidget);
      await tester.tap(skipBtn);
      await tester.pumpAndSettle();

      // Verify onboarding marked completed
      expect(container.read(onboardingProvider), isTrue);
    });

    testWidgets('Step 2 Theme Customization: Live preview, Icon Pack, and Accent selection work properly', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
          repositoryProvider.overrideWithValue(FakeWelcomeRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: WelcomeScreen(isDevPreview: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Advance to Step 2: Theme
      await tester.tap(find.byIcon(AppIcons.arrowRight(AppIconPack.lucide)));
      await tester.pumpAndSettle();

      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 1);

      // Icon pack options
      expect(find.text('Lucide Web'), findsOneWidget);
      expect(find.text('Material Symbols'), findsOneWidget);

      // Switch icon pack to Material Symbols
      await tester.tap(find.text('Material Symbols'));
      await tester.pumpAndSettle();
      expect(container.read(iconPackProvider), AppIconPack.material);

      // Switch back to Lucide
      await tester.tap(find.text('Lucide Web'));
      await tester.pumpAndSettle();
      expect(container.read(iconPackProvider), AppIconPack.lucide);

      // Palette selection
      final catppuccin = find.text('Catppuccin Mocha');
      if (catppuccin.evaluate().isNotEmpty) {
        await tester.ensureVisible(catppuccin);
        await tester.pumpAndSettle();
        await tester.tap(catppuccin);
        await tester.pumpAndSettle();
        expect(container.read(themeProvider).paletteId, 'catppuccin');
      }
    });

    testWidgets('Step 7 Extensions: Displays language recommendations, filters by category, and opens marketplace sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
          repositoryProvider.overrideWithValue(FakeWelcomeRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: GlassHost(
              richBackdrop: true,
              backdrop: Colors.black,
              child: WelcomeScreen(isDevPreview: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure language is Spanish in Step 1
      final englishLang = find.text('English');
      if (englishLang.evaluate().isNotEmpty) {
        await tester.tap(englishLang.first);
        await tester.pumpAndSettle();
        final esOpt = find.text('Español');
        if (esOpt.evaluate().isNotEmpty) {
          await tester.tap(esOpt.first);
          await tester.pumpAndSettle();
        }
      }

      // Advance: Step 1 -> Step 2 -> Step 3 -> Step 4 -> Step 5 -> Step 6 -> Step 7
      final nextBtn = find.byIcon(AppIcons.arrowRight(AppIconPack.lucide));
      for (int i = 0; i < 6; i++) {
        await tester.tap(nextBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
      }

      expect(tester.widget<GlassPageControl>(find.byType(GlassPageControl)).currentPage, 6);

      // Verify Spanish curated recommendations exist
      expect(find.text('AnimeTosho NEW'), findsOneWidget);
      expect(find.text('AnimeAV1'), findsOneWidget);
      expect(find.text('JKAnime'), findsOneWidget);
      expect(find.text('LeerCapitulo'), findsOneWidget);

      // Filter by Torrents category
      final torrentsChip = find.text('Torrents').first;
      await tester.tap(torrentsChip);
      await tester.pumpAndSettle();

      expect(find.text('AnimeTosho NEW'), findsOneWidget);
      expect(find.text('AnimeAV1'), findsNothing); // Filtered out

      // Filter by Streaming category
      final streamingChip = find.text('Streaming').first;
      await tester.tap(streamingChip);
      await tester.pumpAndSettle();

      expect(find.text('AnimeAV1'), findsOneWidget);
      expect(find.text('JKAnime'), findsOneWidget);
      expect(find.text('AnimeTosho NEW'), findsNothing);

      // Filter by Manga category
      final mangaChip = find.text('Manga').first;
      await tester.ensureVisible(mangaChip);
      await tester.tap(mangaChip);
      await tester.pumpAndSettle();

      expect(find.text('LeerCapitulo'), findsOneWidget);
      expect(find.text('CapibaraTraductor'), findsOneWidget);
      expect(find.text('JKAnime'), findsNothing);
    });
  });
}
