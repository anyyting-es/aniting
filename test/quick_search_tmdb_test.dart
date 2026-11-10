import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/section_visibility_provider.dart';
import 'package:aniting/core/server/server_manager.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/services/tmdb_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/quick_search/feed_quick_search.dart';

class LoggedOutServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.running);
}

class DisabledAnimeCatalog extends AnimeSectionEnabledNotifier {
  @override
  bool build() => false;
}

class FakeTmdbSearchService extends TmdbService {
  FakeTmdbSearchService() : super(apiKey: 'test');

  int calls = 0;

  @override
  Future<List<AnimeEntry>> searchShows({
    required String query,
    String language = 'es-ES',
    int page = 1,
  }) async {
    calls++;
    if (!query.toLowerCase().contains('frieren')) return const [];
    return [
      AnimeEntry(
        id: 209867,
        mediaId: 209867,
        title: 'Frieren: Tras finalizar el viaje',
        coverImage: 'https://example.com/frieren.jpg',
        progress: 0,
        status: 'RELEASING',
        format: 'TV',
        isTmdb: true,
      ),
    ];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Ctrl+K quick search does not fall back to TMDB when disabled',
      (tester) async {
    final tmdb = FakeTmdbSearchService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(LoggedOutServerNotifier.new),
          animeSectionEnabledProvider.overrideWith(DisabledAnimeCatalog.new),
          tmdbServiceProvider.overrideWithValue(tmdb),
          translationsProvider.overrideWithValue(const SpanishTranslations()),
        ],
        child: MaterialApp(
          builder: (context, child) => GlassHost(child: child!),
          home: const Scaffold(body: FeedQuickSearch(isManga: false)),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(find.byType(EditableText), 'frieren');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.textContaining('Frieren'), findsNothing);
    expect(tmdb.calls, 0);
  });
}
