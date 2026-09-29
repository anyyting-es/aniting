import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/feed_screen.dart';
import 'package:seanime_app/presentation/screens/library_screen.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

class MockLoggedInServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
        status: ServerStatus(username: 'TestUser'),
      );
}

void main() {
  group('Font Selection and Theme Tests', () {
    test('Available fonts contains curated fonts', () {
      expect(kAvailableFonts.any((f) => f.id == 'system'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'inter'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'poppins'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'outfit'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'rubik'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'nunito'), isTrue);
      expect(kAvailableFonts.any((f) => f.id == 'jetbrains_mono'), isTrue);
    });

    test('Theme builder applies font family correctly', () {
      final interTheme = AppThemeBuilder.buildTheme(
        seedColor: Colors.deepPurple,
        isDark: true,
        fontId: 'inter',
      );
      expect(interTheme.appBarTheme.titleTextStyle?.fontFamily, isNotNull);

      final systemTheme = AppThemeBuilder.buildTheme(
        seedColor: Colors.deepPurple,
        isDark: true,
        fontId: 'system',
      );
      expect(systemTheme.appBarTheme.titleTextStyle?.fontFamily, isNull);
    });
  });

  group('Main Screens Headerless & Profile Hub Tests', () {
    testWidgets('FeedScreen is headerless and has TopStatusBarGlass', (tester) async {
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

      // No standard AppBar or SliverAppBar
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Inicio'), findsNothing);
      // TopStatusBarGlass is present
      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });

    testWidgets('FeedScreen section headers render at 16px left', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockLoggedInServerNotifier.new),
            continueWatchingProvider.overrideWith((ref) => Future.value([
                  AnimeEntry(
                    id: 1,
                    mediaId: 1,
                    title: 'Test Anime',
                    progress: 1,
                    status: 'CURRENT',
                    episodeNumber: 1,
                  ),
                ])),
            animeCollectionProvider.overrideWith((ref) => Future.value([])),
            missedSequelsProvider.overrideWith((ref) => Future.value([])),
            recommendationsProvider.overrideWith((ref) => Future.value([])),
            trendingAnimeProvider.overrideWith((ref) => Future.value([])),
            popularAnimeProvider.overrideWith((ref) => Future.value([])),
            recentAnimeProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final sectionHeaderTopLeft = tester.getTopLeft(find.text('Seguir Viendo'));
      expect(sectionHeaderTopLeft.dx, 16.0);
    });

    testWidgets('SearchScreen is headerless and provides SearchBar and TopStatusBarGlass', (tester) async {
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

      expect(find.byType(AppBar), findsNothing);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byType(TopStatusBarGlass), findsOneWidget);
    });

    testWidgets('LibraryScreen is headerless and renders Profile Hub tiles', (tester) async {
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
      await tester.pumpAndSettle();

      // No header
      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(TopStatusBarGlass), findsOneWidget);

      // Hub Navigation Tiles
      expect(find.text('Mis Listas'), findsOneWidget);
      expect(find.text('Descargas de Anime'), findsOneWidget);
      expect(find.text('Descargas de Manga'), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);
      expect(find.text('Configuraciones Rápidas'), findsOneWidget);
    });
  });
}
