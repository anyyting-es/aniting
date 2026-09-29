import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_bottom_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_top_bar.dart';
import 'package:seanime_app/presentation/widgets/player/panels/next_episode_card.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('YouTube Watch Page & TV Mode Tests', () {
    testWidgets('NextEpisodeCard renders clean layout without center play icon, with titles and badges', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NextEpisodeCard(
              episode: AnimeEpisode(
                episodeNumber: 2,
                title: 'Encounter with Spirits',
              ),
              animeTitle: 'Frieren: Beyond Journey\'s End',
              synopsis: 'Frieren journeys north and encounters new wonders.',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Episode title is primary
      expect(find.textContaining('Encounter with Spirits'), findsOneWidget);
      // Anime title is omitted from NextEpisodeCard to prevent spilling and redundancy
      expect(find.text('Frieren: Beyond Journey\'s End'), findsNothing);
      // EP badge
      expect(find.text('EP 2'), findsOneWidget);
      // Synopsis
      expect(find.text('Frieren journeys north and encounters new wonders.'), findsOneWidget);
      // Ensure no play arrow icon inside thumbnail
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);

      // Tap card
      await tester.tap(find.byType(NextEpisodeCard));
      expect(tapped, isTrue);
    });

    testWidgets('PlayerInfoPanel renders episode title first, anime title below, and clean previous button', (tester) async {
      final aniZip = AniZipData.fromJson({
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'The Journey Begins'},
            'overview': 'The great adventure concludes and another begins.',
            'rating': '8.8',
            'airdate': '2023-09-29',
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'en': 'It Didn\'t Have to Be Magic'},
            'overview': 'Next step on the northern road.',
            'rating': '8.8',
          },
        },
      });

      final animeDetails = AnimeDetails(
        id: 12345,
        title: 'Frieren',
        episodes: [
          AnimeEpisode(episodeNumber: 1, title: 'The Journey Begins'),
          AnimeEpisode(episodeNumber: 2, title: 'It Didn\'t Have to Be Magic'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: PlayerInfoPanel(
                  mediaId: 12345,
                  animeTitle: 'Frieren',
                  episodeNumber: 2,
                  episodeTitle: 'It Didn\'t Have to Be Magic',
                  animeDetails: animeDetails,
                  aniZipData: aniZip,
                  isLoading: false,
                  isDesktop: false,
                  onSeekToChapter: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // Current episode title appears prominently first with EP prefix
      expect(find.text('EP 2 • It Didn\'t Have to Be Magic'), findsOneWidget);
      // Anime title appears (in header and/or cards)
      expect(find.text('Frieren'), findsWidgets);
      // Episode synopsis appears
      expect(find.text('Next step on the northern road.'), findsOneWidget);

      // Rating has single star icon and clean number without duplicate star
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('8.8'), findsOneWidget);
      expect(find.text('8.8 ★'), findsNothing);

      // Previous episode text-only button
      expect(find.text('← Episodio anterior: Ep. 1'), findsOneWidget);
    });

    testWidgets('PlayerInfoPanel overrides placeholder Episode N with AniZip title and positions previous button below next episode', (tester) async {
      final aniZip = AniZipData.fromJson({
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'The Journey Begins'},
            'overview': 'The great adventure concludes.',
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'es': 'No tenía por qué ser magia', 'en': 'It Didn\'t Have to Be Magic'},
            'overview': 'Next step on the northern road.',
          },
        },
      });

      final animeDetails = AnimeDetails(
        id: 12345,
        title: 'Frieren',
        episodes: [
          // Seanime local/torrent episode collection has generic "Episode 2"
          AnimeEpisode(episodeNumber: 1, title: 'Episode 1'),
          AnimeEpisode(episodeNumber: 2, title: 'Episode 2'),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: PlayerInfoPanel(
                  mediaId: 12345,
                  animeTitle: 'Frieren',
                  episodeNumber: 1,
                  episodeTitle: 'Episode 1',
                  animeDetails: animeDetails,
                  aniZipData: aniZip,
                  isLoading: false,
                  isDesktop: false,
                  onSeekToChapter: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Current episode resolves title from AniZip instead of generic "Episode 1"
      expect(find.text('EP 1 • The Journey Begins'), findsOneWidget);

      // 2. Next episode card resolves AniZip Spanish title instead of placeholder "Episode 2"
      expect(find.text('No tenía por qué ser magia'), findsOneWidget);
      expect(find.text('Ep. 2 • Episode 2'), findsNothing);

      // 3. Next episode card is positioned ABOVE previous episode button (if visible) or next episode exists
      expect(find.byType(NextEpisodeCard), findsOneWidget);
    });
    testWidgets('PlayerTopBar renders sidebar collapse/expand toggle and calls callback', (tester) async {
      bool toggleCalled = false;
      bool isCollapsed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return PlayerTopBar(
                    title: 'DanDaDan',
                    episodeTitle: 'Episodio 1',
                    onBack: () {},
                    onOpenSettings: () {},
                    onToggleSidePanel: () {
                      toggleCalled = true;
                      setState(() => isCollapsed = !isCollapsed);
                    },
                    isSidePanelCollapsed: isCollapsed,
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Initially expanded: should show view_sidebar_rounded
      expect(find.byIcon(Icons.view_sidebar_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_sidebar_outlined), findsNothing);

      // Tap toggle
      await tester.tap(find.byIcon(Icons.view_sidebar_rounded));
      await tester.pump();

      expect(toggleCalled, isTrue);
      // Now collapsed: should show view_sidebar_outlined
      expect(find.byIcon(Icons.view_sidebar_outlined), findsOneWidget);
    });

    testWidgets('PlayerTopBar does not render sidebar toggle when onToggleSidePanel is null', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'DanDaDan',
                onBack: () {},
                onOpenSettings: () {},
                onToggleSidePanel: null,
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.view_sidebar_rounded), findsNothing);
      expect(find.byIcon(Icons.view_sidebar_outlined), findsNothing);
    });

    testWidgets('PlayerBottomBar renders fullscreen toggle button on all platforms', (tester) async {
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(seconds: 30)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 2)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () {},
                onSeekBackward: () {},
                onSeekForward: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () => fullscreenToggled = true,
                isFullscreen: false,
                isDesktopOverride: false, // test mobile
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();

      expect(fullscreenToggled, isTrue);
    });

    testWidgets('PlayerTopBar respects showTitle parameter', (tester) async {
      // Test when showTitle is true
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Frieren',
                episodeTitle: 'Episodio 1',
                showTitle: true,
                onBack: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Frieren'), findsOneWidget);
      expect(find.text('Episodio 1'), findsOneWidget);

      // Test when showTitle is false
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Frieren',
                episodeTitle: 'Episodio 1',
                showTitle: false,
                onBack: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Frieren'), findsNothing);
      expect(find.text('Episodio 1'), findsNothing);
    });

    testWidgets('PlayerBottomBar small mobile mini view renders compact single-row controls and timestamp above', (tester) async {
      bool playPauseCalled = false;
      bool nextEpisodeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5, seconds: 30)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 8)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () => playPauseCalled = true,
                onSeekBackward: () {},
                onSeekForward: () {},
                onNextEpisode: () => nextEpisodeCalled = true,
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isFullscreen: false,
                isDesktopOverride: false, // Mobile small
                currentChapterTitle: 'Intro',
              ),
            ),
          ),
        ),
      );

      // Timestamp & chapter rendered above
      expect(find.text('05:30 / 24:00'), findsOneWidget);
      expect(find.text('• Intro'), findsOneWidget);

      // Compact controls row
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);

      // Tap play/pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(playPauseCalled, isTrue);

      // Tap next episode
      await tester.tap(find.byIcon(Icons.skip_next_rounded));
      expect(nextEpisodeCalled, isTrue);
    });

    testWidgets('PlayerInfoPanel synopsis only displays Más/Menos when text exceeds 3 lines', (tester) async {
      final shortSynopsis = 'A brief one sentence synopsis that easily fits in one line.';
      final longSynopsis = 'This is an exceptionally long paragraph designed to span well across multiple lines of text when rendered within a narrow container. ' * 5;

      // 1. Short synopsis: 'Más' should NOT be present
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                height: 600,
                child: PlayerInfoPanel(
                  animeTitle: 'Anime',
                  episodeNumber: 1,
                  episodeTitle: 'Ep 1',
                  animeDetails: AnimeDetails(id: 1, title: 'Anime', description: shortSynopsis),
                  onSeekToChapter: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Más'), findsNothing);
      expect(find.text('Menos'), findsNothing);

      // 2. Long synopsis: 'Más' SHOULD be present
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 350,
                height: 600,
                child: PlayerInfoPanel(
                  animeTitle: 'Anime',
                  episodeNumber: 1,
                  episodeTitle: 'Ep 1',
                  animeDetails: AnimeDetails(id: 1, title: 'Anime', description: longSynopsis),
                  onSeekToChapter: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Más'), findsOneWidget);
    });

    test('tvModeProvider persists and toggles value properly', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer();

      // Default should be false
      expect(container.read(tvModeProvider), isFalse);

      // Enable TV mode
      await container.read(tvModeProvider.notifier).setEnabled(true);
      expect(container.read(tvModeProvider), isTrue);
      expect(prefs.getBool('app_tv_mode_enabled'), isTrue);

      // Toggle off
      await container.read(tvModeProvider.notifier).toggle();
      expect(container.read(tvModeProvider), isFalse);
      expect(prefs.getBool('app_tv_mode_enabled'), isFalse);
    });
  });
}
