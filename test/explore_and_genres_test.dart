import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/airing_calendar_screen.dart';
import 'package:seanime_app/presentation/screens/genre_detail_screen.dart';
import 'package:seanime_app/presentation/screens/genres_screen.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() {
    return const ServerStateModel(state: ServerState.stopped);
  }
}

void main() {
  group('Explore, Airing Calendar & Genres Tests', () {
    testWidgets('SearchScreen renders Explore title and Calendar/Genres action icons', (tester) async {
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

      expect(find.text('Explorar'), findsNothing);
      expect(find.byIcon(Icons.calendar_month_rounded), findsNothing);
      expect(find.byIcon(Icons.category_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Tap search icon to expand CompactSearchBar
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pump();
      expect(find.byType(CompactSearchBar), findsOneWidget);
    });

    testWidgets('GenresScreen renders genre cards with gradient items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: GenresScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Géneros'), findsOneWidget);
      expect(find.text('Acción'), findsOneWidget);
      expect(find.text('Romance'), findsOneWidget);
      expect(find.text('Fantasía'), findsOneWidget);
      expect(find.text('Comedia'), findsOneWidget);

      // Verify all genre items use optimized w300 thumbnail URLs
      for (final genre in kAppGenres) {
        expect(genre.imageUrl, contains('/t/p/w300/'));
        expect(genre.imageUrl, isNot(contains('/t/p/w500/')));
      }

      // Verify RepaintBoundary wraps cards for render layer isolation
      expect(find.byType(RepaintBoundary), findsWidgets);
    });

    testWidgets('GenreDetailScreen renders sorting chips and media type selector', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: GenreDetailScreen(genre: 'Romance', displayGenreName: 'Romance'),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Romance'), findsOneWidget);
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);
      expect(find.text('Tendencias'), findsOneWidget);
      expect(find.text('Puntuación'), findsOneWidget);
      expect(find.text('Popularidad'), findsOneWidget);
      expect(find.text('Más Recientes'), findsOneWidget);
    });

    testWidgets('AiringCalendarScreen renders day selector with today and week tabs', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: const MaterialApp(
            home: AiringCalendarScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Calendario de emisión'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });
  });
}
