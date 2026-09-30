import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/anime_full_details_screen.dart';
import 'package:seanime_app/presentation/widgets/anizip_episode_list.dart';
import 'package:seanime_app/presentation/widgets/episode_item_widget.dart';

class FakeDetailRepository extends SeanimeRepository {
  FakeDetailRepository() : super(ApiClient());

  @override
  Future<AnimeDetails?> getAnimeDetails(int mediaId, {AnimeEntry? initialEntry}) async => null;

  @override
  Future<AniZipData?> getAniZipData(int mediaId) async => null;

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async => null;

  @override
  Future<List<OnlinestreamProvider>> getOnlinestreamProviders() async => [];
}

class MockRunningServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
      );
}

void main() {
  group('Episode UI Components Tests', () {
    testWidgets('EpisodeListItem renders clean layout with EP number, duration, title, and synopsis',
        (WidgetTester tester) async {
      bool playTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpisodeListItem(
                episodeNumber: 5,
                duration: '24 min',
                title: 'The Journey Continues',
                synopsis: 'Frieren and Fern arrive at a new village.',
                onPlay: () => playTapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check EP Number and Duration
      expect(find.text('EP 5'), findsOneWidget);
      expect(find.text('24 min'), findsOneWidget);

      // Check Title and Synopsis
      expect(find.text('The Journey Continues'), findsOneWidget);
      expect(find.text('Frieren and Fern arrive at a new village.'), findsOneWidget);

      // Verify play button is removed from episode card
      expect(find.byIcon(Icons.play_circle_fill_rounded), findsNothing);
      await tester.tap(find.text('The Journey Continues'));
      expect(playTapped, isTrue);
    });

    testWidgets('Long press on EpisodeListItem opens full episode details modal',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: EpisodeListItem(
                episodeNumber: 12,
                duration: '23 min',
                title: 'A Real Hero',
                originalTitle: 'Hontou no Yuusha',
                synopsis: 'Full detailed synopsis explaining the past memories.',
                airDate: '15 dic 2023',
                rating: '4.9',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Long-press the episode item
      await tester.longPress(find.text('A Real Hero'));
      await tester.pumpAndSettle();

      // Verify modal sheet is opened
      expect(find.text('Hontou no Yuusha'), findsOneWidget);

      // Scroll to see synopsis if needed
      await tester.scrollUntilVisible(
        find.text('Sinopsis del episodio'),
        100,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.text('Sinopsis del episodio'), findsOneWidget);
      expect(find.text('Full detailed synopsis explaining the past memories.'), findsWidgets);
      expect(find.text('15 dic 2023'), findsOneWidget);
      expect(find.text('4.9'), findsOneWidget);
    });

    testWidgets('EpisodeGridItem renders compact square without image', (WidgetTester tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EpisodeGridItem(
              episodeNumber: 8,
              title: 'Gravekeeper',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('EP 8'), findsOneWidget);
      expect(find.text('Gravekeeper'), findsOneWidget);

      await tester.tap(find.text('EP 8'));
      expect(tapped, isTrue);
    });

    testWidgets('AniZipEpisodeListView filters out unreleased future episodes',
        (WidgetTester tester) async {
      final mockData = AniZipData(
        episodeCount: 3,
        specialCount: 0,
        episodes: [
          AniZipEpisode(
            episode: '1',
            episodeNumber: 1,
            titleMap: {'es': 'Aired Episode 1'},
            isSpecial: false,
            airDate: '2023-10-01',
          ),
          AniZipEpisode(
            episode: '2',
            episodeNumber: 2,
            titleMap: {'es': 'Aired Episode 2'},
            isSpecial: false,
            airDate: '2023-10-08',
          ),
          AniZipEpisode(
            episode: '3',
            episodeNumber: 3,
            titleMap: {'es': 'Future Unreleased Episode 3'},
            isSpecial: false,
            // Air date far in the future
            airDate: '2099-12-31',
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

      // Only released episodes should be visible
      expect(find.text('Aired Episode 1'), findsOneWidget);
      expect(find.text('Aired Episode 2'), findsOneWidget);
      expect(find.text('Future Unreleased Episode 3'), findsNothing);
      expect(find.text('• 2 disponibles'), findsOneWidget);
    });

    testWidgets('AnimeFullDetailsScreen renders stats, characters, relations, and staff without episodes',
        (WidgetTester tester) async {
      final mockDetails = AnimeDetails(
        id: 154587,
        title: 'Sousou no Frieren',
        romajiTitle: 'Sousou no Frieren',
        score: 91,
        format: 'TV',
        totalEpisodes: 28,
        status: 'FINISHED',
        studio: 'Madhouse',
        description: 'The story of an elf mage after the demon king was defeated.',
        genres: ['Aventura', 'Drama', 'Fantasía'],
        rawMedia: {
          'duration': 24,
          'meanScore': 90,
          'characters': {
            'edges': [
              {
                'role': 'MAIN',
                'node': {
                  'id': 1,
                  'name': {'full': 'Frieren'},
                },
              },
            ],
          },
          'relations': {
            'edges': [
              {
                'relationType': 'SIDE_STORY',
                'node': {
                  'id': 2,
                  'format': 'SPECIAL',
                  'title': {'userPreferred': 'Sousou no Frieren: Mini Anime'},
                },
              },
            ],
          },
          'staff': {
            'edges': [
              {
                'role': 'Director',
                'node': {
                  'id': 10,
                  'name': {'full': 'Keiichirou Saitou'},
                },
              },
            ],
          },
        },
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: AnimeFullDetailsScreen(
              mediaId: 154587,
              animeDetails: mockDetails,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and details
      expect(find.text('Sousou no Frieren'), findsWidgets);
      expect(find.textContaining('Madhouse'), findsWidgets);
      expect(find.text('Aventura'), findsOneWidget);

      // Check stats
      expect(find.text('91%'), findsOneWidget);
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);

      // Check character and relations sections
      expect(find.text('Personajes y Elenco'), findsOneWidget);
      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('Relaciones y Obras Conectadas'), findsOneWidget);
      expect(find.text('Sousou no Frieren: Mini Anime'), findsOneWidget);
      expect(find.text('Equipo Principal (Staff)'), findsOneWidget);
      expect(find.text('Keiichirou Saitou'), findsOneWidget);
    });

    testWidgets('AnimeDetailScreen renders local mode button in top bar and only Torrent and Online in bottom tabs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepository()),
            serverNotifierProvider.overrideWith(() => MockRunningServerNotifier()),
          ],
          child: MaterialApp(
            home: AnimeDetailScreen(
              mediaId: 154587,
              initialEntry: AnimeEntry(
                id: 1,
                mediaId: 154587,
                title: 'Sousou no Frieren',
                format: 'TV',
                totalEpisodes: 28,
                status: 'FINISHED',
                progress: 5,
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Check ClampingScrollPhysics is applied to CustomScrollView
      final scrollView = tester.widget<CustomScrollView>(find.byType(CustomScrollView));
      expect(scrollView.physics, isA<ClampingScrollPhysics>());

      // Check Local button in top bar and Info button
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Check mode dropdown chip is present with Online
      expect(find.text('Online'), findsOneWidget);

      // Tap mode chip to open popup menu with Torrent option
      await tester.tap(find.text('Online'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Torrent'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Tap the local button in top bar to switch to Local mode
      await tester.tap(find.byIcon(Icons.folder_outlined));
      await tester.pump(const Duration(milliseconds: 100));

      // Check local folder icon is now filled (active in top bar and mode chip)
      expect(find.byIcon(Icons.folder_rounded), findsWidgets);

      await tester.pump(const Duration(seconds: 1));

      // Dispose
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  });
}
