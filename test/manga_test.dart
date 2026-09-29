import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/widgets/continue_reading_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

void main() {
  group('Manga Data Models Tests', () {
    test('MangaEntry.fromJson parses basic fields and listData correctly', () {
      final json = {
        'id': 101,
        'media': {
          'id': 101,
          'title': {
            'romaji': 'Sousou no Frieren',
            'english': 'Frieren: Beyond Journey\'s End',
            'native': '葬送のフリーレン',
          },
          'coverImage': {
            'extraLarge': 'https://example.com/cover.jpg',
          },
          'bannerImage': 'https://example.com/banner.jpg',
          'format': 'MANGA',
          'chapters': 130,
          'averageScore': 88,
          'genres': ['Adventure', 'Drama', 'Fantasy'],
        },
        'listData': {
          'progress': 45,
          'score': 9.0,
          'status': 'CURRENT',
        },
      };

      final entry = MangaEntry.fromJson(json);

      expect(entry.mediaId, 101);
      expect(entry.title, 'Frieren: Beyond Journey\'s End');
      expect(entry.englishTitle, 'Frieren: Beyond Journey\'s End');
      expect(entry.romajiTitle, 'Sousou no Frieren');
      expect(entry.progress, 45);
      expect(entry.totalChapters, 130);
      expect(entry.status, 'CURRENT');
      expect(entry.format, 'MANGA');
      expect(entry.genres, contains('Adventure'));
      expect(entry.displayTitle(TitleLanguage.romaji), 'Sousou no Frieren');
      expect(entry.displayTitle(TitleLanguage.english), 'Frieren: Beyond Journey\'s End');
    });

    test('MangaChapter and MangaChapterContainer parse correctly', () {
      final containerJson = {
        'mediaId': 101,
        'provider': 'manga-dex',
        'chapters': [
          {
            'id': 'chap-1',
            'url': 'https://example.com/ch1',
            'title': 'The End of the Journey',
            'chapter': '1',
            'index': 0,
            'scanlator': 'Kirei Cake',
            'language': 'en',
            'updatedAt': '2020-04-28',
          },
          {
            'id': 'chap-2',
            'url': 'https://example.com/ch2',
            'title': 'The Priest\'s Lie',
            'chapter': '2',
            'index': 1,
            'scanlator': 'Kirei Cake',
            'language': 'en',
            'updatedAt': '2020-05-05',
          },
        ],
      };

      final container = MangaChapterContainer.fromJson(containerJson);

      expect(container.mediaId, 101);
      expect(container.provider, 'manga-dex');
      expect(container.chapters.length, 2);
      expect(container.chapters[0].chapter, '1');
      expect(container.chapters[0].chapterNumber, 1.0);
      expect(container.chapters[1].chapter, '2');
      expect(container.chapters[1].chapterNumber, 2.0);
    });

    test('Chapter chunking splits 120 chapters into blocks of 30 correctly (menor a mayor)', () {
      final chapters = List.generate(120, (i) {
        final num = i + 1;
        return MangaChapter(
          id: 'ch-$num',
          url: 'https://example.com/$num',
          title: 'Chapter $num',
          chapter: '$num',
          index: i,
        );
      });

      // Default sort ascending (menor a mayor)
      chapters.sort((a, b) => a.chapterNumber.compareTo(b.chapterNumber));
      expect(chapters.first.chapterNumber, 1.0);
      expect(chapters.last.chapterNumber, 120.0);

      const blockSize = 30;
      final totalBlocks = (chapters.length / blockSize).ceil();
      expect(totalBlocks, 4); // 1-30, 31-60, 61-90, 91-120

      // Block 0
      final block0 = chapters.sublist(0, 30);
      expect(block0.length, 30);
      expect(block0.first.chapterNumber, 1.0);
      expect(block0.last.chapterNumber, 30.0);

      // Block 1
      final block1 = chapters.sublist(30, 60);
      expect(block1.length, 30);
      expect(block1.first.chapterNumber, 31.0);
      expect(block1.last.chapterNumber, 60.0);

      // Block 3
      final block3 = chapters.sublist(90, 120);
      expect(block3.length, 30);
      expect(block3.first.chapterNumber, 91.0);
      expect(block3.last.chapterNumber, 120.0);
    });

    test('Dynamic chapter search and hide-read filter logic works correctly', () {
      final chapters = List.generate(100, (i) {
        final num = i + 1;
        return MangaChapter(
          id: 'ch-$num',
          url: 'https://example.com/$num',
          title: 'Chapter $num',
          chapter: '$num',
          index: i,
        );
      });

      // 1. Hide read chapters when progress is 40
      const progress = 40;
      final unread = chapters.where((c) => c.chapterNumber > progress).toList();
      expect(unread.first.chapterNumber, 41.0);
      expect(unread.length, 60);

      // 2. Numeric search for "75" returns chapters starting from 75 onwards
      final queryNum = double.tryParse('75');
      expect(queryNum, 75.0);
      final from75 = chapters.where((c) => c.chapterNumber >= queryNum!).toList();
      expect(from75.first.chapterNumber, 75.0);
      expect(from75.last.chapterNumber, 100.0);
      expect(from75.length, 26);
    });
  });

  group('Manga Widgets Tests', () {
    testWidgets('MangaCard renders title and progress badge', (tester) async {
      final entry = MangaEntry(
        id: 201,
        mediaId: 201,
        title: 'Chainsaw Man',
        romajiTitle: 'Chainsaw Man',
        englishTitle: 'Chainsaw Man',
        progress: 12,
        totalChapters: 150,
        status: 'CURRENT',
        score: 8.7,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 160,
                child: MangaCard(entry: entry),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Chainsaw Man'), findsOneWidget);
      expect(find.textContaining('12'), findsOneWidget);
    });

    testWidgets('ContinueReadingCard displays chapter and progress', (tester) async {
      final entry = MangaEntry(
        id: 301,
        mediaId: 301,
        title: 'One Piece',
        progress: 1100,
        totalChapters: 1200,
        status: 'CURRENT',
      );

      bool tapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ContinueReadingCard(
                entry: entry,
                onTap: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('One Piece'), findsOneWidget);
      expect(find.textContaining('1101'), findsOneWidget);

      await tester.tap(find.byType(ContinueReadingCard));
      expect(tapped, isTrue);
    });
  });
}
