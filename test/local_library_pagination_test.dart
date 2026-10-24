import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/data/services/tmdb_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/local_library_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio TMDB falso que solo cuenta cuántas veces se pide el póster.
class _CountingTmdbService extends TmdbService {
  _CountingTmdbService() : super(apiKey: 'test');

  int detailsCalls = 0;

  @override
  Future<TmdbShowDetails?> getShowDetails(
    int id, {
    String language = 'es-ES',
    bool isMovie = false,
  }) async {
    detailsCalls++;
    return TmdbShowDetails(id: id, name: 'Show $id', isMovie: isMovie);
  }
}

class _FakeLocalLibraryNotifier extends LocalLibraryNotifier {
  _FakeLocalLibraryNotifier(this.initial);

  final LocalLibraryState initial;

  @override
  LocalLibraryState build() => initial;

  @override
  Future<void> loadLibraryData() async {}
}

LocalLibraryState _stateWithShows(int count) {
  return LocalLibraryState(
    mainPath: '/media/anime',
    matchedShows: List.generate(
      count,
      (i) => LocalMatchedShowItem(
        id: 100 + i,
        title: 'TMDB Show $i',
        type: 'tv',
        episodeCount: 10,
        folderPath: '/media/shows/Show $i',
        isTmdb: true,
        localFilePaths: const ['/media/shows/Show 0/ep1.mkv'],
      ),
    ),
    matchedShowsCount: count,
    tvShowsCount: count,
    localEpisodesCount: count * 10,
  );
}

Future<_CountingTmdbService> _pumpScreen(
  WidgetTester tester,
  int showCount,
) async {
  final tmdb = _CountingTmdbService();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localLibraryProvider.overrideWith(
          () => _FakeLocalLibraryNotifier(_stateWithShows(showCount)),
        ),
        tmdbServiceProvider.overrideWithValue(tmdb),
      ],
      child: const MaterialApp(
        home: LocalLibrarySettingsScreen(isEmbedded: true),
      ),
    ),
  );
  await tester.pump();
  return tmdb;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Local Library renders only the first page of shows and loads more on demand',
    (tester) async {
      // Viewport alto para que las 24 tarjetas de la primera página y el
      // botón "Ver más" queden construidos sin necesidad de hacer scroll.
      tester.view.physicalSize = const Size(1200, 5400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 84 shows → primera página de 24, restantes 60.
      final tmdb = await _pumpScreen(tester, 84);

      expect(find.text('TMDB Show 0'), findsOneWidget);
      expect(find.text('TMDB Show 23'), findsOneWidget);
      expect(find.text('TMDB Show 24'), findsNothing);

      // Solo se consultó TMDB por las tarjetas construidas.
      expect(tmdb.detailsCalls, 24);

      // Los rebuilds no relanzan peticiones (póster memoizado por id).
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tmdb.detailsCalls, 24);

      final seeMore = find.byIcon(Icons.expand_more_rounded);
      expect(seeMore, findsOneWidget);
      await tester.tap(seeMore);
      await tester.pump();

      // La segunda página se añade sin reconstruir más allá de la vista.
      expect(find.text('TMDB Show 24'), findsOneWidget);
      expect(find.text('TMDB Show 48'), findsNothing);
      expect(tmdb.detailsCalls, greaterThan(24));
      expect(tmdb.detailsCalls, lessThan(84));
    },
  );
}
