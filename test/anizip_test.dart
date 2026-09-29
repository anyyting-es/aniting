import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/anizip_episode_list.dart';

void main() {
  group('AniZip Data & Episode Parsing Tests', () {
    final mockJson = {
      'titles': {
        'en': 'Attack on Titan',
        'ja': '進撃の巨人',
        'x-jat': 'Shingeki no Kyojin',
      },
      'episodeCount': 2,
      'specialCount': 1,
      'episodes': {
        '1': {
          'episodeNumber': 1,
          'seasonNumber': 1,
          'title': {
            'es': 'A ti, dentro de 2000 años',
            'en': 'To You, in 2000 Years',
            'ja': '二千年前の君へ',
          },
          'airDate': '2013-04-07',
          'runtime': 24,
          'overview': 'Humans live enclosed within huge walls.',
          'image': 'https://example.com/ep1.jpg',
          'rating': '8.5',
        },
        '2': {
          'episodeNumber': 2,
          'seasonNumber': 1,
          'title': {
            'en': 'That Day',
            'x-jat': 'Sono Hi',
          },
          'airDate': '2013-04-14',
          'runtime': 24,
          'overview': 'The fall of Shiganshina.',
          'image': 'https://example.com/ep2.jpg',
        },
        'S1': {
          'episodeNumber': 1,
          'seasonNumber': 0,
          'title': {
            'en': "Ilse`s Notebook",
          },
          'airDate': '2013-12-09',
          'runtime': 25,
          'overview': "Special OVA episode.",
        },
      },
      'mappings': {
        'anilist_id': 16498,
        'mal_id': 16498,
        'thetvdb_id': 267440,
      }
    };

    test('Parses AniZipData correctly from JSON', () {
      final data = AniZipData.fromJson(mockJson);

      expect(data.episodeCount, 2);
      expect(data.specialCount, 1);
      expect(data.episodes.length, 3);
      expect(data.mainEpisodes.length, 2);
      expect(data.specialEpisodes.length, 1);

      // Verify title priority (Spanish first)
      final ep1 = data.mainEpisodes[0];
      expect(ep1.episodeNumber, 1);
      expect(ep1.displayTitle, 'A ti, dentro de 2000 años');
      expect(ep1.formattedDuration, '24 min');
      expect(ep1.formattedAirDate, '7 abr 2013');
      expect(ep1.rating, '8.5');
      expect(ep1.isSpecial, false);

      // Verify English fallback if Spanish is absent
      final ep2 = data.mainEpisodes[1];
      expect(ep2.episodeNumber, 2);
      expect(ep2.displayTitle, 'That Day');
      expect(ep2.originalTitle, 'Sono Hi');

      // Verify Special episode parsing & backtick cleaning
      final s1 = data.specialEpisodes[0];
      expect(s1.isSpecial, true);
      expect(s1.episodeBadge, 'SP 1');
      expect(s1.displayTitle, "Ilse's Notebook");

      // Verify mappings
      expect(data.mappings?.anilistId, 16498);
      expect(data.mappings?.thetvdbId, 267440);
    });

    test('getEpisode only returns main episodes and never specials (movie with S2 test)', () {
      final movieJson = {
        'episodes': {
          '1': {
            'episode': '1',
            'length': 130,
            'title': {'en': 'Complete Movie'},
          },
          'S1': {
            'episode': 'S1',
            'length': 25,
            'title': {'en': 'Special Program'},
          },
          'S2': {
            'episode': 'S2',
            'length': 2,
            'title': {'en': 'Speed of Youth'},
          },
        },
      };

      final movieData = AniZipData.fromJson(movieJson);

      // Episode 1 is the main movie
      final ep1 = movieData.getEpisode(1);
      expect(ep1, isNotNull);
      expect(ep1!.displayTitle, 'Complete Movie');
      expect(ep1.isSpecial, false);

      // Episode 2 should NOT return S2 (Speed of Youth)
      final ep2 = movieData.getEpisode(2);
      expect(ep2, isNull);

      // S2 should be accessible via getSpecial(2)
      final sp2 = movieData.getSpecial(2);
      expect(sp2, isNotNull);
      expect(sp2!.displayTitle, 'Speed of Youth');
      expect(sp2.isSpecial, true);
    });
  });

  group('AniZipEpisodeListView Widget Tests', () {
    testWidgets('Renders only main episodes and handles search without special tabs', (WidgetTester tester) async {
      final mockData = AniZipData(
        episodeCount: 2,
        specialCount: 1,
        episodes: [
          AniZipEpisode(
            episode: '1',
            episodeNumber: 1,
            titleMap: {'es': 'Inicio del viaje'},
            isSpecial: false,
            runtime: 24,
            airDate: '2023-01-01',
            overview: 'Primer episodio emocionante.',
          ),
          AniZipEpisode(
            episode: '2',
            episodeNumber: 2,
            titleMap: {'en': 'Second Battle'},
            isSpecial: false,
            runtime: 24,
            airDate: '2023-01-08',
            overview: 'La batalla continúa.',
          ),
          AniZipEpisode(
            episode: 'S1',
            episodeNumber: 1,
            titleMap: {'es': 'Especial de Navidad'},
            isSpecial: true,
            runtime: 15,
            airDate: '2023-12-25',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AniZipEpisodeListView(
                  aniZipData: mockData,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header (AniZip badge removed)
      expect(find.text('Episodios'), findsOneWidget);
      expect(find.text('AniZip'), findsNothing);
      expect(find.text('• 2 disponibles'), findsOneWidget);

      // Verify NO special tabs exist
      expect(find.text('Principales (2)'), findsNothing);
      expect(find.text('Especiales (1)'), findsNothing);
      expect(find.text('Todos (3)'), findsNothing);

      // Verify NO Descargado badge exists
      expect(find.text('Descargado'), findsNothing);

      // Only main episodes are visible
      expect(find.text('Inicio del viaje'), findsOneWidget);
      expect(find.text('Second Battle'), findsOneWidget);
      expect(find.text('Especial de Navidad'), findsNothing);

      // Tap Search icon
      await tester.tap(find.byIcon(Icons.search_rounded));
      await tester.pumpAndSettle();

      // Type in search field
      await tester.enterText(find.byType(TextField), 'Battle');
      await tester.pumpAndSettle();

      expect(find.text('Second Battle'), findsOneWidget);
      expect(find.text('Inicio del viaje'), findsNothing);
    });

    testWidgets('Triggers onPlayEpisode when play icon is tapped', (WidgetTester tester) async {
      AniZipEpisode? playedEp;
      final mockData = AniZipData(
        episodeCount: 1,
        specialCount: 0,
        episodes: [
          AniZipEpisode(
            episode: '1',
            episodeNumber: 1,
            titleMap: {'es': 'Episodio 1'},
            isSpecial: false,
            runtime: 24,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AniZipEpisodeListView(
                  aniZipData: mockData,
                  onPlayEpisode: (ep) => playedEp = ep,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Episodio 1'), findsOneWidget);
      await tester.tap(find.text('Episodio 1'));
      await tester.pumpAndSettle();

      expect(playedEp, isNotNull);
      expect(playedEp?.episodeNumber, 1);
    });

    testWidgets('Paginates episodes to 24 per page in list mode, unpaginated in grid mode', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final episodesList = List.generate(30, (i) {
        final epNum = i + 1;
        return AniZipEpisode(
          episode: '$epNum',
          episodeNumber: epNum,
          titleMap: {'es': 'Episodio $epNum'},
          isSpecial: false,
          runtime: 24,
        );
      });

      final mockData = AniZipData(
        episodeCount: 30,
        specialCount: 0,
        episodes: episodesList,
      );

      // 1. List mode test
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AniZipEpisodeListView(
                  aniZipData: mockData,
                  viewMode: EpisodeViewMode.list,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should show episode 1 to 24 on page 1
      expect(find.text('Episodio 1'), findsOneWidget);
      expect(find.text('Episodio 24'), findsOneWidget);
      expect(find.text('Episodio 25'), findsNothing);

      // Pagination indicator and buttons
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('Siguiente (24 ep)'), findsOneWidget);

      // Navigate to page 2
      await tester.tap(find.text('Siguiente (24 ep)'));
      await tester.pumpAndSettle();

      // Page 2 shows episode 25 to 30
      expect(find.text('Episodio 1'), findsNothing);
      expect(find.text('Episodio 25'), findsOneWidget);
      expect(find.text('Episodio 30'), findsOneWidget);
      expect(find.text('2 / 2'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);

      // 2. Grid mode test (should show all 30 without pagination)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AniZipEpisodeListView(
                  aniZipData: mockData,
                  viewMode: EpisodeViewMode.grid,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsNothing);
      expect(find.text('Siguiente (24 ep)'), findsNothing);
      expect(find.text('Episodio 1'), findsOneWidget);
      expect(find.text('Episodio 30'), findsOneWidget);
    });
  });
}
