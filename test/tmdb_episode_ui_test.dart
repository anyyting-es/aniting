import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/i18n/translations/es.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/episode_item.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_season_switcher.dart';

void main() {
  testWidgets('TMDB episodes render with the Anime episode component',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWithValue(const SpanishTranslations()),
        ],
        child: MaterialApp(
          builder: (context, child) => GlassHost(child: child!),
          home: Scaffold(
            body: SingleChildScrollView(
              child: DesktopEpisodesTab(
                mediaId: 209867,
                details: AnimeDetails(
                  id: 209867,
                  title: 'Frieren',
                  format: 'TV',
                  totalEpisodes: 28,
                  isTmdb: true,
                ),
                aniZipData: null,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.online,
                providers: const [],
                selectedProvider: null,
                isDubbed: false,
                onlineEpisodes: const [],
                loadingEpisodeNumber: null,
                fallbackCoverImage: null,
                onProviderChanged: (_) {},
                onToggleDubbed: () {},
                onEpisodeClicked: (_) {},
                onToggleLocalMode: () {},
                onTabChanged: (_) {},
                isTmdb: true,
                tmdbEpisodes: const [
                  EpisodeItem(
                    id: 'tmdb_1_1',
                    number: 1,
                    seasonNumber: 1,
                    title: 'El final de la aventura',
                    synopsis: 'El grupo del Héroe derrota al Rey Demonio.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Episodios'), findsOneWidget);
    expect(find.textContaining('El final de la aventura'), findsWidgets);
    expect(find.text('Todos'), findsNothing);
    expect(find.text('No vistos'), findsNothing);
  });

  testWidgets('Season 0 is labelled Specials', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWithValue(const SpanishTranslations()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopSeasonSwitcher(
              seasons: const [0, 1],
              selectedSeason: 1,
              onSeasonChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Especiales'), findsOneWidget);
    expect(find.text('Temporada 1'), findsOneWidget);
  });
}
