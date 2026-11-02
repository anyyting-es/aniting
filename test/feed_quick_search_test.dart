import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/quick_search/feed_quick_search.dart';

class _FakeRepository extends SeanimeRepository {
  _FakeRepository() : super(ApiClient());

  @override
  Future<List<AnimeEntry>> searchAnime(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async {
    if (!query.toLowerCase().contains('frieren')) return const [];
    return [
      AnimeEntry(
        id: 1,
        mediaId: 1,
        title: 'Frieren: Beyond Journey\'s End',
        progress: 0,
        status: 'FINISHED',
        totalEpisodes: 28,
        format: 'TV',
        year: 2023,
        description: 'A mage walks north.',
        genres: const ['Adventure'],
        score: 9.2,
      ),
    ];
  }

  @override
  Future<List<MangaEntry>> searchManga(
    String query, {
    int page = 1,
    int perPage = 20,
  }) async => const [];
}

void main() {
  group('Feed quick search', () {
    late Object? selected;

    Widget buildApp() => ProviderScope(
      overrides: [repositoryProvider.overrideWithValue(_FakeRepository())],
      child: MaterialApp(
        builder: (context, child) =>
            GlassHost(backdrop: const Color(0xFF101014), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  selected = await showFeedQuickSearch(
                    context: context,
                    isManga: false,
                  );
                },
                child: const Text('open quick search'),
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('opens the floating glass field with a prompt', (tester) async {
      selected = null;
      await tester.pumpWidget(buildApp());

      await tester.tap(find.text('open quick search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(GlassTextField), findsOneWidget);
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);

      // Escape dismisses without a selection.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(find.byType(GlassTextField), findsNothing);
      expect(selected, isNull);
    });

    testWidgets('searches live and returns the tapped entry', (tester) async {
      selected = null;
      await tester.pumpWidget(buildApp());

      await tester.tap(find.text('open quick search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(find.byType(EditableText), 'frieren');
      await tester.pump();
      // Debounce.
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);

      await tester.tap(find.text('Frieren: Beyond Journey\'s End'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      expect(selected, isA<AnimeEntry>());
      expect((selected as AnimeEntry).mediaId, 1);
      expect(find.byType(GlassTextField), findsNothing);
    });

    testWidgets('right-click opens the preview and Escape closes it first', (
      tester,
    ) async {
      selected = null;
      await tester.pumpWidget(buildApp());

      await tester.tap(find.text('open quick search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(find.byType(EditableText), 'frieren');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 50));

      const title = 'Frieren: Beyond Journey\'s End';
      expect(find.text(title), findsOneWidget);

      await tester.tap(find.text(title), buttons: kSecondaryButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Preview pane: synopsis plus a second copy of the title.
      expect(find.text('A mage walks north.'), findsOneWidget);
      expect(find.text(title), findsNWidgets(2));

      // Escape closes the preview, not the palette.
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('A mage walks north.'), findsNothing);
      expect(find.byType(GlassTextField), findsOneWidget);
      expect(selected, isNull);
    });

    testWidgets('right arrow opens the preview and left arrow closes it', (
      tester,
    ) async {
      selected = null;
      await tester.pumpWidget(buildApp());

      await tester.tap(find.text('open quick search'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));

      await tester.enterText(find.byType(EditableText), 'frieren');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('A mage walks north.'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('A mage walks north.'), findsNothing);
      expect(find.byType(GlassTextField), findsOneWidget);
    });
  });
}
