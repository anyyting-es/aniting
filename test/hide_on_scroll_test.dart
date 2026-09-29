import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/feed_screen.dart';
import 'package:seanime_app/presentation/screens/library_screen.dart';
import 'package:seanime_app/presentation/screens/manga_feed_screen.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

void main() {
  group('TopStatusBarGlass Widget Tests', () {
    testWidgets('Renders glass effect with BackdropFilter when padding.top > 0 and visible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
            child: Scaffold(
              body: Stack(
                children: const [
                  TopStatusBarGlass(isVisible: true),
                ],
              ),
            ),
          ),
        ),
      );

      final glassFinder = find.byType(TopStatusBarGlass);
      expect(glassFinder, findsOneWidget);

      final backdropFinder = find.byType(BackdropFilter);
      expect(backdropFinder, findsOneWidget);

      final animatedOpacityFinder = find.descendant(
        of: glassFinder,
        matching: find.byType(AnimatedOpacity),
      );
      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder);
      expect(animatedOpacity.opacity, 1.0);
    });

    testWidgets('Has opacity 0.0 when isVisible is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(padding: EdgeInsets.only(top: 32)),
            child: Scaffold(
              body: Stack(
                children: const [
                  TopStatusBarGlass(isVisible: false),
                ],
              ),
            ),
          ),
        ),
      );

      final animatedOpacityFinder = find.descendant(
        of: find.byType(TopStatusBarGlass),
        matching: find.byType(AnimatedOpacity),
      );
      final animatedOpacity = tester.widget<AnimatedOpacity>(animatedOpacityFinder);
      expect(animatedOpacity.opacity, 0.0);
    });
  });

  group('Main Screens Glass Overlay Presence Tests', () {
    testWidgets('FeedScreen contains TopStatusBarGlass overlay', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });

    testWidgets('MangaFeedScreen contains TopStatusBarGlass overlay', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: MangaFeedScreen(),
          ),
        ),
      );

      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });

    testWidgets('SearchScreen contains TopStatusBarGlass overlay', (tester) async {
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

      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });

    testWidgets('LibraryScreen contains TopStatusBarGlass overlay', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );

      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });
  });
}
