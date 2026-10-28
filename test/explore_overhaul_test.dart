import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/catalog_search/catalog_search_view.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
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
            home: GlassHost(
              child: Scaffold(
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
        ),
      );
      await tester.pump();

      expect(find.text('Anime'), findsOneWidget);

      // Tap MediaTypeToggle to open menu
      await tester.tap(find.byType(MediaTypeToggle));
      await tester.pumpAndSettle();

      // Tap Manga item in menu
      await tester.tap(find.text('Manga'));
      await tester.pumpAndSettle();

      expect(selected, 'MANGA');
      expect(find.text('Manga'), findsOneWidget);
    });
  });

  group('Explore Screen Search & Toggle Integration Tests', () {
    testWidgets('starts with icon-only search, expands on tap, and collapses on back', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

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

      // CatalogSearchView is now visible with back button
      expect(find.byType(CatalogSearchView), findsOneWidget);

      // Tap back button on the search view
      await tester.tap(find.byKey(const ValueKey('compact_search_back_btn')));
      await tester.pumpAndSettle();

      // Restored icon-only mode
      expect(find.byType(CatalogSearchView), findsNothing);
      expect(find.byIcon(searchIcon), findsOneWidget);
    });
  });
}
