import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';

class FakeEpisodesRepo extends SeanimeRepository {
  FakeEpisodesRepo() : super(ApiClient());

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async => null;
}

void main() {
  group('DesktopEpisodesTab Logic, Pagination & Dimmed Watched Tests', () {
    testWidgets('Watched episodes do not have checkmark icon and use dimmed opacity', (tester) async {
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Test Anime'},
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'Episode 1'},
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'en': 'Episode 2'},
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 1,
                details: null,
                aniZipData: aniZipData,
                progress: 1, // Episode 1 is watched, 2 is unwatched
                isLocalMode: false,
                currentTab: AnimeDetailTab.torrent,
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
              ),
            ),
          ),
        ),
      );

      // Verify no check icon anywhere
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Verify AnimatedOpacity widgets exist for cards
      final opacityFinders = find.byType(AnimatedOpacity);
      expect(opacityFinders, findsWidgets);

      // Find the card opacities
      final animatedOpacities = tester.widgetList<AnimatedOpacity>(opacityFinders).toList();
      final hasDimmedWatched = animatedOpacities.any((o) => o.opacity < 0.6);
      expect(hasDimmedWatched, isTrue);
    });

    testWidgets('Torrent mode uses AniList/AniZip episodes list 100%', (tester) async {
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Test Anime'},
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'AniZip Ep 1'},
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'en': 'AniZip Ep 2'},
          },
        },
      });

      final onlineEpisodes = [
        const OnlinestreamEpisode(
          number: 10,
          title: 'Online Stream Ep 10',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 1,
                details: null,
                aniZipData: aniZipData,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.torrent, // Torrent mode
                providers: const [],
                selectedProvider: null,
                isDubbed: false,
                onlineEpisodes: onlineEpisodes,
                loadingEpisodeNumber: null,
                fallbackCoverImage: null,
                onProviderChanged: (_) {},
                onToggleDubbed: () {},
                onEpisodeClicked: (_) {},
                onToggleLocalMode: () {},
                onTabChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // In Torrent mode, it should display AniZip episodes, NOT online stream episodes
      expect(find.textContaining('AniZip Ep 1'), findsOneWidget);
      expect(find.textContaining('Online Stream Ep 10'), findsNothing);
    });

    testWidgets('Online mode uses selected provider online episodes list', (tester) async {
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Test Anime'},
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'AniZip Ep 1'},
          },
        },
      });

      final onlineEpisodes = [
        const OnlinestreamEpisode(
          number: 1,
          title: 'Special Provider Cut 1',
        ),
        const OnlinestreamEpisode(
          number: 2,
          title: 'Special Provider Cut 2',
        ),
      ];

      final provider = const OnlinestreamProvider(
        id: 'gogoanime',
        name: 'Gogoanime',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 1,
                details: null,
                aniZipData: aniZipData,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.online, // Online streaming mode
                providers: [provider],
                selectedProvider: provider,
                isDubbed: false,
                onlineEpisodes: onlineEpisodes,
                loadingEpisodeNumber: null,
                fallbackCoverImage: null,
                onProviderChanged: (_) {},
                onToggleDubbed: () {},
                onEpisodeClicked: (_) {},
                onToggleLocalMode: () {},
                onTabChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // In Online mode, it should display the provider's episodes
      expect(find.textContaining('Special Provider Cut 1'), findsOneWidget);
      expect(find.textContaining('Special Provider Cut 2'), findsOneWidget);
    });

    testWidgets('Pagination renders at most 20 episodes and navigates with Siguiente', (tester) async {
      // 35 episodes
      final Map<String, dynamic> epMap = {};
      for (int i = 1; i <= 35; i++) {
        epMap['$i'] = {
          'episode': '$i',
          'episodeNumber': i,
          'title': {'en': 'Episode $i Title'},
        };
      }
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Long Anime'},
        'episodes': epMap,
      });

      tester.view.physicalSize = const Size(1920, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DesktopEpisodesTab(
                  mediaId: 1,
                  details: null,
                  aniZipData: aniZipData,
                  progress: 0,
                  isLocalMode: false,
                  currentTab: AnimeDetailTab.torrent,
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
                ),
              ),
            ),
          ),
        ),
      );

      // First page: Episodes 1 through 20 are present
      expect(find.textContaining('EP 1.'), findsOneWidget);
      expect(find.textContaining('EP 20.'), findsOneWidget);
      // Episode 21 should NOT be on page 1
      expect(find.textContaining('EP 21.'), findsNothing);

      // Pagination indicators
      expect(find.text('Siguiente'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);

      // Tap 'Siguiente'
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Now on page 2: Episodes 21 to 35 should be visible
      expect(find.textContaining('EP 21.'), findsOneWidget);
      expect(find.textContaining('EP 35.'), findsOneWidget);
      expect(find.textContaining('EP 1.'), findsNothing);
    });

    testWidgets('DesktopEpisodesTab filters out specials, openings, endings, recaps and duplicate episode numbers', (tester) async {
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Dandadan'},
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'That\'s How Love Starts, Ya Know!'},
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'en': 'That\'s a Space Alien, Ya Know!'},
          },
          'S1': {
            'episode': 'S1',
            'episodeNumber': 1,
            'title': {'en': 'Oni and Momo Too Extra Episode'},
          },
          'S2': {
            'episode': 'S2',
            'episodeNumber': 0,
            'title': {'en': 'Creditless Opening Theme'},
          },
          'S3': {
            'episode': 'S3',
            'episodeNumber': 0,
            'title': {'en': 'Creditless Ending Theme'},
          },
          'S4': {
            'episode': 'S4',
            'episodeNumber': 1,
            'title': {'en': 'Web Teaser Preview'},
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 1,
                details: null,
                aniZipData: aniZipData,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.torrent,
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
              ),
            ),
          ),
        ),
      );

      // Verify canon episodes are present
      expect(find.textContaining('That\'s How Love Starts, Ya Know!'), findsOneWidget);
      expect(find.textContaining('That\'s a Space Alien, Ya Know!'), findsOneWidget);

      // Verify specials, openings, endings, recaps, and extra episodes are filtered out
      expect(find.textContaining('Oni and Momo Too'), findsNothing);
      expect(find.textContaining('Creditless Opening'), findsNothing);
      expect(find.textContaining('Creditless Ending'), findsNothing);
      expect(find.textContaining('Web Teaser'), findsNothing);
    });
  });
}

