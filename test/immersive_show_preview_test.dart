import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/presentation/widgets/anime_card.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_preview_data.dart';
import 'package:aniting/presentation/widgets/anime_preview/show_quick_view_detector.dart';

void main() {
  const data = ShowPreviewData(
    title: 'Frieren: Beyond Journey\'s End',
    subtitle: 'Sousou no Frieren',
    description: 'A mage walks north.',
    genres: ['Adventure', 'Drama'],
    meta: [
      ShowPreviewMeta('2023', Icons.calendar_today_rounded),
      ShowPreviewMeta('9.2', Icons.star_rounded),
    ],
  );

  Widget buildApp({VoidCallback? onOpenDetails}) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: ShowQuickViewDetector(
              heroTag: 'preview-hero',
              dataBuilder: () => data,
              onOpenDetails: onOpenDetails ?? () {},
              child: const SizedBox(
                width: 200,
                height: 300,
                child: ColoredBox(color: Colors.blueGrey),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('Immersive show preview', () {
    test('fromAnime maps the current episode details', () {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Frieren',
        progress: 5,
        status: 'CURRENT',
        episodeNumber: 6,
        episodeTitle: 'The Hero of the Village',
        episodeThumbnail: 'https://example.com/ep.jpg',
      );

      final data = ShowPreviewData.fromAnime(
        entry,
        TitleLanguage.romaji,
        includeCurrentEpisode: true,
      );

      expect(data.title, 'Frieren');
      expect(data.episode, isNotNull);
      expect(data.episode!.label, 'EP 6');
      expect(data.episode!.title, 'The Hero of the Village');
      expect(data.episode!.imageUrl, 'https://example.com/ep.jpg');
    });

    test('fromAnime drops generic episode titles', () {
      final entry = AnimeEntry(
        id: 2,
        mediaId: 2,
        title: 'Frieren',
        progress: 0,
        status: 'CURRENT',
        episodeTitle: 'Episode 1',
      );

      final data = ShowPreviewData.fromAnime(
        entry,
        TitleLanguage.romaji,
        includeCurrentEpisode: true,
      );

      expect(data.episode!.label, 'EP 1');
      expect(data.episode!.title, isNull);
    });

    testWidgets('right click opens the preview with the metadata', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());

      await tester.tap(
        find.byType(ShowQuickViewDetector),
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('A mage walks north.'), findsOneWidget);
      expect(find.textContaining('2023'), findsOneWidget);

      final closeCenter = tester.getCenter(find.byIcon(Icons.close_rounded));
      expect(
        closeCenter.dx,
        lessThan(100),
        reason: 'the close button must sit on the top-left',
      );
    });

    testWidgets('resting the pointer on a card opens the preview', (
      tester,
    ) async {
      await tester.pumpWidget(buildApp());

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      await gesture.moveTo(tester.getCenter(find.byType(ShowQuickViewDetector)));
      await tester.pump();
      // The detector waits for the pointer to stay still.
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
    });

    testWidgets('right click on an AnimeCard opens the quick actions', (
      tester,
    ) async {
      final entry = AnimeEntry(
        id: 3,
        mediaId: 3,
        title: 'Frieren',
        progress: 0,
        status: 'RELEASING',
        coverImage: 'https://example.com/cover.jpg',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 180,
                  height: 340,
                  child: AnimeCard(entry: entry, animateEntry: false),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byType(ShowQuickViewDetector),
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Añadir a la biblioteca'), findsOneWidget);
      expect(find.text('Marcar como visto'), findsOneWidget);
    });

    testWidgets('episode preview shows the episode data', (tester) async {
      const episodeData = ShowPreviewData(
        title: 'Frieren: Beyond Journey\'s End',
        subtitle: 'Sousou no Frieren',
        episode: ShowPreviewEpisode(
          label: 'EP 6',
          title: 'The Hero of the Village',
          synopsis: 'A village needs help.',
          rating: '8.7',
          duration: '24 min',
          airDate: '29 sep 2023',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: ShowQuickViewDetector(
                  dataBuilder: () => episodeData,
                  onOpenDetails: () {},
                  child: const SizedBox(
                    width: 200,
                    height: 300,
                    child: ColoredBox(color: Colors.blueGrey),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byType(ShowQuickViewDetector),
        buttons: kSecondaryButton,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('EP 6'), findsOneWidget);
      expect(find.textContaining('The Hero of the Village'), findsOneWidget);
      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
      expect(find.text('A village needs help.'), findsOneWidget);
    });
  });
}
