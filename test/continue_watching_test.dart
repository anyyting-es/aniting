import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/continue_watching_sort_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';

import 'package:seanime_app/presentation/providers/app_providers.dart';

void main() {
  group('Continue Watching Tests', () {
    testWidgets('ContinueWatchingCard does not show center play button', (tester) async {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Frieren',
        progress: 12,
        totalEpisodes: 28,
        status: 'CURRENT',
        currentEpisode: 13,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aniZipDataProvider(1).overrideWith((ref) => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContinueWatchingCard(
                entry: entry,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      // Verify episode badge is present
      expect(find.text('EP 13'), findsOneWidget);

      // Verify NO play button icon exists
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.play_arrow), findsNothing);
    });

    test('AnimeEntry parse updatedAt, airDate, and lastWatchedTime correctly', () {
      final json = {
        'id': 100,
        'mediaId': 100,
        'title': {'userPreferred': 'Attack on Titan'},
        'progress': 5,
        'status': 'CURRENT',
        'updatedAt': 1700000000,
        'airDate': '2024-01-15',
        'lastWatchedTime': 1705000000,
      };

      final entry = AnimeEntry.fromJson(json);
      expect(entry.updatedAt, 1700000000000);
      expect(entry.airDate, '2024-01-15');
      expect(entry.lastWatchedTime, 1705000000000);
      expect(entry.effectiveTimestamp, 1705000000000);
      expect(entry.displayTitle(), 'Attack on Titan');
    });

    test('AnimeEntry effectiveTimestamp precedence: lastWatchedTime > updatedAt > airDate', () {
      final withAirDate = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Show A',
        progress: 1,
        status: 'CURRENT',
        airDate: '2023-01-01',
      );
      expect(withAirDate.effectiveTimestamp, DateTime.parse('2023-01-01').millisecondsSinceEpoch);

      final withUpdatedAt = withAirDate.copyWith(updatedAt: 1680000000000);
      expect(withUpdatedAt.effectiveTimestamp, 1680000000000);

      final withWatched = withUpdatedAt.copyWith(lastWatchedTime: 1700000000000);
      expect(withWatched.effectiveTimestamp, 1700000000000);
    });

    test('Sorting logic Seanime modes: recent, airDateDesc, episodeDesc, title', () {
      final a = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Bleach',
        progress: 10,
        episodeNumber: 10,
        status: 'CURRENT',
        lastWatchedTime: 1000,
        airDate: '2023-01-01',
      );
      final b = AnimeEntry(
        id: 2,
        mediaId: 2,
        title: 'Attack on Titan',
        progress: 25,
        episodeNumber: 25,
        status: 'CURRENT',
        lastWatchedTime: 5000,
        airDate: '2023-06-01',
      );
      final c = AnimeEntry(
        id: 3,
        mediaId: 3,
        title: 'Cyberpunk',
        progress: 4,
        episodeNumber: 4,
        status: 'CURRENT',
        lastWatchedTime: 3000,
        airDate: '2023-03-01',
      );

      final list = [a, b, c];

      // Recent (highest effectiveTimestamp first -> b: 5000, c: 3000, a: 1000)
      final recent = List<AnimeEntry>.from(list)..sort((x, y) => y.effectiveTimestamp.compareTo(x.effectiveTimestamp));
      expect(recent.map((e) => e.mediaId).toList(), [2, 3, 1]);

      // AirDate Desc (b: June > c: March > a: Jan)
      final airDesc = List<AnimeEntry>.from(list)
        ..sort((x, y) => y.airDate!.compareTo(x.airDate!));
      expect(airDesc.map((e) => e.mediaId).toList(), [2, 3, 1]);

      // Episode Desc (b: 25 > a: 10 > c: 4)
      final epDesc = List<AnimeEntry>.from(list)
        ..sort((x, y) => (y.episodeNumber ?? y.progress).compareTo(x.episodeNumber ?? x.progress));
      expect(epDesc.map((e) => e.mediaId).toList(), [2, 1, 3]);

      // Title (A-Z) (b: Attack on Titan > a: Bleach > c: Cyberpunk)
      final title = List<AnimeEntry>.from(list)
        ..sort((x, y) => x.displayTitle().toLowerCase().compareTo(y.displayTitle().toLowerCase()));
      expect(title.map((e) => e.mediaId).toList(), [2, 1, 3]);
    });

    test('ContinueWatchingSortMode labels', () {
      expect(ContinueWatchingSortMode.recent.label, 'Visto recientemente');
      expect(ContinueWatchingSortMode.airDateDesc.label, 'Emisión reciente');
      expect(ContinueWatchingSortMode.airDateAsc.label, 'Emisión antigua');
      expect(ContinueWatchingSortMode.episodeDesc.label, 'Episodio más alto');
      expect(ContinueWatchingSortMode.episodeAsc.label, 'Episodio más bajo');
      expect(ContinueWatchingSortMode.title.label, 'Título (A-Z)');
    });

    test('AnimeEntry.hasNextEpisodeAired filters unreleased episodes correctly', () {
      // 1. Anime with nextAiringEpisode = 8, user watched 7 -> next is 8 (unreleased)
      final unreleased = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Solo Leveling',
        progress: 7,
        status: 'CURRENT',
        nextAiringEpisodeNumber: 8,
      );
      expect(unreleased.hasNextEpisodeAired, false);

      // 2. Anime with nextAiringEpisode = 9, user watched 7 -> next is 8 (aired)
      final aired = unreleased.copyWith(nextAiringEpisodeNumber: 9);
      expect(aired.hasNextEpisodeAired, true);

      // 3. User completed all episodes (progress 12 of 12) -> false
      final completed = unreleased.copyWith(progress: 12, totalEpisodes: 12);
      expect(completed.hasNextEpisodeAired, false);

      // 4. Future airDate -> false
      final futureDate = unreleased.copyWith(
        nextAiringEpisodeNumber: null,
        airDate: DateTime.now().add(const Duration(days: 5)).toIso8601String(),
      );
      expect(futureDate.hasNextEpisodeAired, false);
    });

    testWidgets('ContinueWatchingCard renders correctly in compact mobile size', (tester) async {
      final entry = AnimeEntry(
        id: 2,
        mediaId: 2,
        title: 'One Piece',
        progress: 1080,
        totalEpisodes: 1100,
        status: 'CURRENT',
        currentEpisode: 1081,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aniZipDataProvider(2).overrideWith((ref) => null),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContinueWatchingCard(
                entry: entry,
                width: 220,
                height: 128,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('EP 1081'), findsOneWidget);
      expect(find.text('One Piece'), findsOneWidget);
    });
  });
}
