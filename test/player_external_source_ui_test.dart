import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_chat_panel.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_source_card.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_watch_content.dart';

/// A Plex/Jellyfin (or TMDB) entry has no local comments thread and no online
/// sources to switch, so the player must not render either of them.
void main() {
  final details = AnimeDetails(
    id: 0,
    title: 'Frieren: Beyond Journey\'s End',
    description: 'After the party defeats the Demon King...',
    format: 'TV',
    totalEpisodes: 2,
    episodes: [
      AnimeEpisode(episodeNumber: 1, title: 'The Journey Begins'),
      AnimeEpisode(episodeNumber: 2, title: 'It Didn\'t Have to Be Magic'),
    ],
  );

  final aniZip = AniZipData(
    titles: {'en': 'Frieren: Beyond Journey\'s End'},
    episodeCount: 2,
    episodes: [
      AniZipEpisode(
        episode: '1',
        episodeNumber: 1,
        titleMap: {'en': 'The Journey Begins'},
        overview: 'Frieren starts her journey.',
        runtime: 24,
        airDate: '2023-09-29',
        isSpecial: false,
      ),
    ],
  );

  Widget wrap(Widget child) =>
      ProviderScope(child: MaterialApp(home: Scaffold(body: child)));

  group('External source watch page', () {
    testWidgets('PlayerWatchContent hides the comments thread', (tester) async {
      await tester.pumpWidget(
        wrap(
          SingleChildScrollView(
            child: PlayerWatchContent(
              animeTitle: 'Frieren: Beyond Journey\'s End',
              episodeNumber: 1,
              episodeTitle: 'The Journey Begins',
              animeDetails: details,
              aniZipData: aniZip,
              onSeekToChapter: (_) {},
              showComments: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PlayerChatPanel), findsNothing);
      // The metadata is still rendered for external libraries.
      expect(find.text('Frieren starts her journey.'), findsOneWidget);
    });

    testWidgets('PlayerInfoPanel drops the chat tab and the source card', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 800,
            child: PlayerInfoPanel(
              animeTitle: 'Frieren: Beyond Journey\'s End',
              episodeNumber: 1,
              episodeTitle: 'The Journey Begins',
              animeDetails: details,
              aniZipData: aniZip,
              onSeekToChapter: (_) {},
              playbackOrigin: PlayerPlaybackOrigin.mediaServer,
              showComments: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PlayerSourceCard), findsNothing);
      final segmented = tester.widget<SegmentedButton<bool>>(
        find.byType(SegmentedButton<bool>),
      );
      expect(segmented.segments.length, 1);
      expect(find.text('Frieren starts her journey.'), findsOneWidget);
    });
  });
}
