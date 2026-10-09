import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/airing_calendar_screen.dart';
import 'package:seanime_app/presentation/screens/genre_detail_screen.dart';
import 'package:seanime_app/presentation/screens/genres_screen.dart';
import 'package:seanime_app/presentation/screens/search_screen.dart';
import 'package:seanime_app/presentation/widgets/catalog_search/catalog_search_view.dart';

import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/airing_schedule.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() {
    return const ServerStateModel(state: ServerState.stopped);
  }
}

class FakeCalendarRepository extends SeanimeRepository {
  FakeCalendarRepository() : super(ApiClient());

  @override
  Future<List<AiringScheduleItem>> getAiringSchedule({
    int? startTimestamp,
    int? endTimestamp,
    int page = 1,
    int perPage = 50,
    int maxItems = 250,
  }) async => [];

  @override
  Future<List<AnimeEntry>> discoverAnime({
    String? search,
    List<String>? genres,
    List<String>? tags,
    String? season,
    int? year,
    String? format,
    String? status,
    int? minScore,
    bool isAdult = false,
    String sort = 'TRENDING_DESC',
    int page = 1,
    int perPage = 24,
  }) async => [];

  @override
  Future<List<MangaEntry>> discoverManga({
    String? search,
    List<String>? genres,
    List<String>? tags,
    int? year,
    String? format,
    String? status,
    int? minScore,
    bool isAdult = false,
    String sort = 'TRENDING_DESC',
    int page = 1,
    int perPage = 24,
  }) async => [];
}

void main() {
  group('Explore, Airing Calendar & Genres Tests', () {
    testWidgets('SearchScreen renders Explore title and Calendar/Genres action icons', (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
            repositoryProvider.overrideWithValue(FakeCalendarRepository()),
          ],
          child: const MaterialApp(
            home: SearchScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(AppIcons.category()), findsOneWidget);
      expect(find.byIcon(AppIcons.search()), findsOneWidget);

      // Tap search icon to expand CatalogSearchView
      await tester.tap(find.byIcon(AppIcons.search()));
      await tester.pumpAndSettle();
      expect(find.byType(CatalogSearchView), findsOneWidget);
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
            translationsProvider.overrideWithValue(const SpanishTranslations()),
            repositoryProvider.overrideWithValue(FakeCalendarRepository()),
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
