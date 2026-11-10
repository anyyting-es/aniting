import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aniting/core/preferences/player_desktop_view_provider.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episodes_compact_grid.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episodes_rail.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<AnimeEpisode> episodes;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'player_episode_list_compact': true,
    });
    final prefs = await SharedPreferences.getInstance();
    setPlayerDesktopViewPrefs(prefs);

    episodes = [
      for (var i = 1; i <= 40; i++)
        AnimeEpisode(episodeNumber: i, title: 'Episode $i'),
    ];
  });

  testWidgets(
    'the rail scrolls on its own and reveals the active episode without moving the page',
    (tester) async {
      final pageController = ScrollController();
      addTearDown(pageController.dispose);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ListView(
                controller: pageController,
                children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: 320,
                      height: 300,
                      child: PlayerEpisodesRail(
                        animeTitle: 'Test Anime',
                        mediaId: 1,
                        episodes: episodes,
                        currentEpisodeNumber: 30,
                        onSelectEpisode: (_) {},
                        independentScroll: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 1000, child: Text('page content')),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final railScroll = tester.widget<SingleChildScrollView>(
        find.descendant(
          of: find.byType(PlayerEpisodesRail),
          matching: find.byType(SingleChildScrollView),
        ),
      );
      final railController = railScroll.controller!;

      // The active episode (30) is auto-revealed inside the rail only.
      final revealedOffset = railController.offset;
      expect(revealedOffset, greaterThan(0));
      expect(pageController.offset, 0);

      // Dragging over the episode list scrolls the rail, never the page.
      await tester.drag(
        find.byType(PlayerEpisodesCompactGrid),
        const Offset(0, 200),
      );
      await tester.pumpAndSettle();

      expect(railController.offset, lessThan(revealedOffset));
      expect(pageController.offset, 0);
    },
  );
}
