import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';

void main() {
  group('AnimeEntry Year Parsing Tests', () {
    test('parses year from startDate object in AniList media', () {
      final json = {
        'id': 101,
        'title': {'userPreferred': 'Frieren'},
        'format': 'TV',
        'startDate': {'year': 2023, 'month': 9, 'day': 29},
        'progress': 10,
        'episodes': 28,
      };

      final entry = AnimeEntry.fromJson(json);
      expect(entry.year, 2023);
    });

    test('parses year from seasonYear in AniList media', () {
      final json = {
        'id': 102,
        'title': {'userPreferred': 'Solo Leveling'},
        'format': 'TV',
        'seasonYear': 2024,
        'progress': 5,
        'episodes': 12,
      };

      final entry = AnimeEntry.fromJson(json);
      expect(entry.year, 2024);
    });

    test('parses year from baseAnime startDate in episode item', () {
      final json = {
        'id': 201,
        'episodeNumber': 3,
        'episodeTitle': 'The Journey Begins',
        'baseAnime': {
          'id': 301,
          'title': {'userPreferred': 'Dungeon Meshi'},
          'startDate': {'year': 2024, 'month': 1, 'day': 4},
          'episodes': 24,
        },
      };

      final entry = AnimeEntry.fromJson(json);
      expect(entry.year, 2024);
      expect(entry.episodeNumber, 3);
    });
  });

  group('AnimeCard Release Year Display Tests', () {
    testWidgets('displays release year and format beneath the card', (tester) async {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 101,
        title: 'Sousou no Frieren',
        progress: 10,
        totalEpisodes: 28,
        status: 'RELEASING',
        format: 'TV',
        year: 2023,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AnimeCard(entry: entry, width: 180),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('2023 • TV'), findsOneWidget);
    });
  });

  group('MangaCard Status and Year Tests', () {
    testWidgets('displays formatted status and year with high contrast', (tester) async {
      final entry = MangaEntry(
        id: 10,
        mediaId: 501,
        title: 'Chainsaw Man',
        progress: 90,
        status: 'RELEASING',
        year: 2018,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: MangaCard(entry: entry, width: 180),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Chainsaw Man'), findsOneWidget);
      // Formatted status instead of raw uppercase RELEASING
      expect(find.textContaining('En emisión'), findsOneWidget);
      expect(find.textContaining('2018'), findsOneWidget);
    });
  });

  group('ContinueWatchingCard Clean Cover & Underneath Metadata Tests', () {
    testWidgets('renders EP N • Title, anime title, and duration below the cover', (tester) async {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 101,
        title: 'Frieren: Beyond Journey\'s End',
        progress: 4,
        episodeNumber: 5,
        episodeTitle: 'Phantoms of the Dead',
        status: 'CURRENT',
      );

      final mockAniZip = AniZipData.fromJson({
        'episodes': {
          '5': {
            'episodeNumber': 5,
            'title': {'en': 'Phantoms of the Dead'},
            'runtime': 24,
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aniZipDataProvider(101).overrideWith((ref) => mockAniZip),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContinueWatchingCard(
                entry: entry,
                width: 280,
                onTap: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check title line underneath
      expect(find.text('EP 5 • Phantoms of the Dead'), findsOneWidget);
      // Check anime title underneath
      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
      // Check small duration underneath
      expect(find.text('24 min'), findsOneWidget);
    });
  });

  group('Card Japanese Typography and Light Mode Contrast Tests', () {
    testWidgets('AnimeCard and MangaCard apply kJapaneseFontFallbacks and high-contrast dark ink in light theme', (tester) async {
      final anime = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: '最強の王様、二度目の人生は何をする？ 第２期',
        status: 'RELEASING',
        progress: 0,
        year: 2026,
        format: 'TV',
      );

      final manga = MangaEntry(
        id: 2,
        mediaId: 2,
        title: 'アンドロイドは経験人数に入りますか？？ 5日間続けて……',
        status: 'RELEASING',
        progress: 0,
        year: 2026,
      );

      final lightTheme = ThemeData(
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          onSurface: Color(0xFF3760BF), // Tokyo Day style non-black textPrimary
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: lightTheme,
            home: Scaffold(
              body: Column(
                children: [
                  AnimeCard(entry: anime, width: 160),
                  MangaCard(entry: manga, width: 160),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      final animeTitleWidget = tester.widget<Text>(find.text('最強の王様、二度目の人生は何をする？ 第２期'));
      expect(animeTitleWidget.style?.fontFamilyFallback, contains('Noto Sans JP'));
      expect(animeTitleWidget.style?.fontWeight, FontWeight.w700);
      expect(animeTitleWidget.style?.color, const Color(0xFF111418));

      final mangaTitleWidget = tester.widget<Text>(find.text('アンドロイドは経験人数に入りますか？？ 5日間続けて……'));
      expect(mangaTitleWidget.style?.fontFamilyFallback, contains('Noto Sans JP'));
      expect(mangaTitleWidget.style?.fontWeight, FontWeight.w700);
      expect(mangaTitleWidget.style?.color, const Color(0xFF111418));
    });
  });
}
