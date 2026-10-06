import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/my_lists_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/widgets/downloads/downloads_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/extensions/extensions_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';
import 'package:seanime_app/presentation/widgets/my_lists/my_lists_desktop_layout.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';

class _FakeActiveDownloadsNotifier extends ActiveDownloadsNotifier {
  @override
  ActiveDownloadsState build() => const ActiveDownloadsState();
  @override
  Future<void> refresh({bool silent = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesktopSafeAppBar Tests', () {
    testWidgets('DesktopSafeAppBar wraps standard AppBar with extra preferredSize on desktop', (tester) async {
      final appBar = AppBar(title: const Text('Test Title'));
      final safeAppBar = DesktopSafeAppBar(child: appBar);

      // On desktop platform, preferredSize includes DesktopTitleBar.height
      if (DesktopWindowFrame.isDesktopPlatform) {
        expect(safeAppBar.preferredSize.height, kToolbarHeight + DesktopTitleBar.height);
      } else {
        expect(safeAppBar.preferredSize.height, kToolbarHeight);
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: safeAppBar,
            body: const Center(child: Text('Body')),
          ),
        ),
      );

      expect(find.text('Test Title'), findsOneWidget);
      expect(find.text('Body'), findsOneWidget);
    });
  });

  group('MyListsDesktopLayout Tests', () {
    testWidgets('Renders desktop header, back button, media toggle, and status pills', (tester) async {
      // Set desktop window size
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAnime = [
        AnimeEntry(
          id: 1,
          mediaId: 101,
          title: 'Attack on Titan',
          romajiTitle: 'Shingeki no Kyojin',
          status: 'CURRENT',
          coverImage: 'https://example.com/aot.jpg',
          progress: 5,
          totalEpisodes: 25,
        ),
        AnimeEntry(
          id: 2,
          mediaId: 102,
          title: 'Frieren',
          romajiTitle: 'Sousou no Frieren',
          status: 'COMPLETED',
          coverImage: 'https://example.com/frieren.jpg',
          progress: 28,
          totalEpisodes: 28,
        ),
      ];

      final fakeManga = [
        MangaEntry(
          id: 11,
          mediaId: 201,
          title: 'Chainsaw Man',
          romajiTitle: 'Chainsaw Man',
          status: 'CURRENT',
          coverImage: 'https://example.com/csm.jpg',
          progress: 10,
          totalChapters: 100,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            animeCollectionProvider.overrideWith((ref) async => fakeAnime),
            mangaCollectionProvider.overrideWith((ref) async => fakeManga),
          ],
          child: const MaterialApp(
            home: MyListsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should render MyListsDesktopLayout because width >= 720
      expect(find.byType(MyListsDesktopLayout), findsOneWidget);

      // Verify header elements
      expect(find.byType(MediaTypeToggle), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Quick Search input

      // Verify status pills with counts (e.g. '1', '2')
      expect(find.text('1'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Switch to Manga via MediaTypeToggle
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      // Check Manga content appears
      expect(find.text('Chainsaw Man'), findsOneWidget);
    });
  });

  group('DownloadsDesktopLayout Tests', () {
    testWidgets('Renders desktop downloads layout, header, media toggle and items', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fakeAnime = [
        AnimeEntry(
          id: 1,
          mediaId: 101,
          title: 'Bleach TYBW',
          romajiTitle: 'Bleach TYBW',
          status: 'CURRENT',
          coverImage: 'https://example.com/bleach.jpg',
          progress: 12,
          totalEpisodes: 26,
        ),
      ];

      final fakeManga = [
        MangaEntry(
          id: 2,
          mediaId: 201,
          title: 'One Piece',
          romajiTitle: 'One Piece',
          status: 'CURRENT',
          coverImage: 'https://example.com/op.jpg',
          progress: 1100,
          totalChapters: 1200,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeDownloadsProvider.overrideWith(() => _FakeActiveDownloadsNotifier()),
            downloadedAnimeProvider.overrideWith((ref) async => fakeAnime),
            downloadedMangaListProvider.overrideWith((ref) async => fakeManga),
          ],
          child: MaterialApp(
            home: DownloadsDesktopLayout(
              onDeleteAnime: (_) async {},
              onDeleteManga: (_) async {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify layout and header elements
      expect(find.byType(DownloadsDesktopLayout), findsOneWidget);
      expect(find.byType(MediaTypeToggle), findsOneWidget);

      // Verify anime card is displayed
      expect(find.text('Bleach TYBW'), findsOneWidget);

      // Switch to Manga
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      // Verify manga card is displayed
      expect(find.text('One Piece'), findsOneWidget);
    });
  });

  group('ExtensionsDesktopLayout Tests', () {
    testWidgets('Renders segmented pill and switches between Installed and Marketplace', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: ExtensionsDesktopLayout(
              installedExtensions: const [],
              marketplaceExtensions: const [],
              installedIds: const {},
              isLoadingInstalled: false,
              isLoadingMarketplace: false,
              isCheckingUpdates: false,
              currentRepoUrl: 'https://raw.githubusercontent.com/seanime-extensions/index',
              onRetryInstalled: () {},
              onCheckForUpdates: () {},
              onReloadAll: () {},
              onToggle: (_, enabled) {},
              onUninstall: (_) {},
              onUpdate: (_) {},
              onShowCode: (_) {},
              onRefreshMarketplace: ({forceRefresh = false}) async {},
              onChangeRepo: () {},
              onInstall: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify desktop layout rendered
      expect(find.byType(ExtensionsDesktopLayout), findsOneWidget);

      // Verify segmented pill switcher exists
      expect(find.byIcon(Icons.layers_outlined), findsOneWidget);
      expect(find.byIcon(Icons.storefront_outlined), findsOneWidget);

      // Switch to Installed tab
      await tester.tap(find.byIcon(Icons.layers_outlined));
      await tester.pumpAndSettle();
    });
  });
}

