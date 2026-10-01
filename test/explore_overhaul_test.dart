import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/explore_hero_carousel.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() {
    return const ServerStateModel(state: ServerState.stopped);
  }
}

void main() {
  group('MediaTypeToggle Tests', () {
    testWidgets('renders Anime and Manga segments and handles tap', (tester) async {
      String selected = 'ANIME';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return MediaTypeToggle(
                    selected: selected,
                    onSelected: (val) => setState(() => selected = val),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);

      // Tap Manga
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      expect(selected, 'MANGA');
    });
  });

  group('ExploreHeroCarousel Tests', () {
    testWidgets('renders items, badges, title, and indicator dots', (tester) async {
      final items = [
        ExploreCarouselItem(
          mediaId: 101,
          title: 'Hero Anime',
          format: 'TV',
          score: 8.5,
          year: 2024,
          genres: ['Action', 'Fantasy'],
          onTap: () {},
        ),
        ExploreCarouselItem(
          mediaId: 102,
          title: 'Second Anime',
          format: 'MOVIE',
          score: 9.0,
          year: 2025,
          genres: ['Sci-Fi'],
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExploreHeroCarousel(items: items),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hero Anime'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('8.5'), findsOneWidget);
      expect(find.text('Action • Fantasy'), findsOneWidget);
      expect(find.text('2024'), findsOneWidget);
      expect(find.byType(PageView), findsOneWidget);
    });

    testWidgets('loops infinitely forward from last item to first item without rewinding', (tester) async {
      final items = [
        ExploreCarouselItem(
          mediaId: 101,
          title: 'Hero Anime',
          format: 'TV',
          onTap: () {},
        ),
        ExploreCarouselItem(
          mediaId: 102,
          title: 'Second Anime',
          format: 'MOVIE',
          onTap: () {},
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ExploreHeroCarousel(items: items),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Hero Anime'), findsOneWidget);

      final pageView = tester.widget<PageView>(find.byType(PageView));
      final controller = pageView.controller!;

      // Advance by 1 page: to 'Second Anime' (item 1, last item)
      controller.jumpToPage(controller.page!.round() + 1);
      await tester.pump();
      expect(find.text('Second Anime'), findsOneWidget);

      // Advance by 1 page again: wraps seamlessly forward to 'Hero Anime' (item 0)
      controller.jumpToPage(controller.page!.round() + 1);
      await tester.pump();
      expect(find.text('Hero Anime'), findsOneWidget);
    });
  });

  group('Explore Screen Search & Toggle Integration Tests', () {
    testWidgets('starts with icon-only search, expands on tap, and collapses on back', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );
      await tester.pump();

      final searchIcon = AppIcons.search(AppIconPack.lucide);

      // Starts in icon-only mode
      expect(find.byType(CompactSearchBar), findsNothing);
      expect(find.byType(MediaTypeToggle), findsOneWidget);
      expect(find.byIcon(searchIcon), findsOneWidget);

      // Tap search icon
      await tester.tap(find.byIcon(searchIcon));
      await tester.pumpAndSettle();

      // CompactSearchBar is now visible
      expect(find.byType(CompactSearchBar), findsOneWidget);

      // Tap back button on the search bar
      await tester.tap(find.byKey(const ValueKey('compact_search_back_btn')));
      await tester.pumpAndSettle();

      // Restored icon-only mode
      expect(find.byType(CompactSearchBar), findsNothing);
      expect(find.byIcon(searchIcon), findsOneWidget);
    });
  });
}
