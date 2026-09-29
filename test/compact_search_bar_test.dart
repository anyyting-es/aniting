import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/feed_screen.dart';
import 'package:seanime_app/presentation/screens/manga_feed_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/continue_reading_card.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';

class MockServerNotifierOnline extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.running);
}

class FakeSeanimeRepository extends SeanimeRepository {
  FakeSeanimeRepository() : super(ApiClient());

  @override
  Future<List<AnimeEntry>> searchAnime(String query, {int page = 1, int perPage = 20}) async {
    if (query.contains('frieren')) {
      return [
        AnimeEntry(
          id: 154587,
          mediaId: 154587,
          title: 'Sousou no Frieren',
          format: 'TV',
          progress: 0,
          status: 'FINISHED',
        ),
      ];
    }
    return [];
  }

  @override
  Future<List<MangaEntry>> searchManga(String query, {int page = 1, int perPage = 20}) async {
    if (query.contains('berserk')) {
      return [
        MangaEntry(
          id: 30002,
          mediaId: 30002,
          title: 'Berserk',
          progress: 0,
          status: 'RELEASING',
        ),
      ];
    }
    return [];
  }
}

void main() {
  group('CompactSearchBar Widget Tests', () {
    testWidgets('Renders hint text, search icon, and handles text input', (tester) async {
      final controller = TextEditingController();
      String changedText = '';
      bool backTapped = false;
      bool clearTapped = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CompactSearchBar(
                controller: controller,
                hintText: 'Buscar anime...',
                onChanged: (val) => changedText = val,
                onBack: () => backTapped = true,
                onClear: () => clearTapped = true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byKey(const ValueKey('compact_search_back_btn')), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Naruto');
      await tester.pump();

      expect(changedText, 'Naruto');
      // When text is entered, back button and clear button appear
      expect(find.byKey(const ValueKey('compact_search_back_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('compact_search_clear_btn')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('compact_search_back_btn')));
      await tester.pump();
      expect(backTapped, isTrue);

      await tester.tap(find.byKey(const ValueKey('compact_search_clear_btn')));
      await tester.pump();
      expect(clearTapped, isTrue);
    });
  });

  group('Feed Screens In-Page Search Integration Tests', () {
    testWidgets('FeedScreen shows feed when query empty, transitions to results on typing, and restores feed on back', (tester) async {
      final fakeRepo = FakeSeanimeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(fakeRepo),
            serverNotifierProvider.overrideWith(MockServerNotifierOnline.new),
            continueWatchingProvider.overrideWith((ref) => Future.value([
              AnimeEntry(id: 1, mediaId: 1, title: 'Continue Watching Anime', progress: 1, status: 'CURRENT'),
            ])),
            animeCollectionProvider.overrideWith((ref) => Future.value([])),
            missedSequelsProvider.overrideWith((ref) => Future.value([])),
            recommendationsProvider.overrideWith((ref) => Future.value([])),
            trendingAnimeProvider.overrideWith((ref) => Future.value([])),
            popularAnimeProvider.overrideWith((ref) => Future.value([])),
            recentAnimeProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: FeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Search bar is present
      expect(find.byType(CompactSearchBar), findsOneWidget);
      // Background feed is visible while query is empty
      expect(find.byType(ContinueWatchingCard), findsOneWidget);

      // Type a search query
      await tester.enterText(find.byType(TextField), 'frieren');
      await tester.pump(); // Triggers state change to searching
      await tester.pump(const Duration(milliseconds: 400)); // Debounce timer
      await tester.pumpAndSettle(); // Complete async search

      // Results are shown directly on the screen (no modal!)
      expect(find.byType(AnimeCard), findsOneWidget);
      expect(find.text('Sousou no Frieren'), findsOneWidget);
      // Feed content is now replaced by search results
      expect(find.byType(ContinueWatchingCard), findsNothing);

      // Tap back button
      await tester.tap(find.byKey(const ValueKey('compact_search_back_btn')));
      await tester.pumpAndSettle();

      // Normal feed is immediately restored!
      expect(find.byType(ContinueWatchingCard), findsOneWidget);
      expect(find.text('Sousou no Frieren'), findsNothing);
    });

    testWidgets('MangaFeedScreen transitions to manga search results on typing and restores feed on back', (tester) async {
      final fakeRepo = FakeSeanimeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(fakeRepo),
            serverNotifierProvider.overrideWith(MockServerNotifierOnline.new),
            continueReadingMangaProvider.overrideWith((ref) => Future.value([
              MangaEntry(id: 10, mediaId: 10, title: 'Reading Manga Item', progress: 1, status: 'CURRENT'),
            ])),
            mangaCollectionProvider.overrideWith((ref) => Future.value([])),
            trendingMangaProvider.overrideWith((ref) => Future.value([])),
            popularMangaProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: MangaFeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(CompactSearchBar), findsOneWidget);
      expect(find.byType(ContinueReadingCard), findsOneWidget);

      // Search for Berserk
      await tester.enterText(find.byType(TextField), 'berserk');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // Results shown in-place
      expect(find.byType(MangaCard), findsOneWidget);
      expect(find.text('Berserk'), findsOneWidget);
      expect(find.byType(ContinueReadingCard), findsNothing);

      // Tap back button to exit search
      await tester.tap(find.byKey(const ValueKey('compact_search_back_btn')));
      await tester.pumpAndSettle();

      // Restored!
      expect(find.byType(ContinueReadingCard), findsOneWidget);
      expect(find.text('Berserk'), findsNothing);
    });

    testWidgets('CompactSearchBar preserves TextField element and focus when typing toggles back/clear buttons', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CompactSearchBar(
                controller: controller,
                focusNode: focusNode,
                hintText: 'Buscar anime...',
              ),
            ),
          ),
        ),
      );

      final textFieldFinder = find.byType(TextField);
      await tester.tap(textFieldFinder);
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      final elementBefore = tester.element(textFieldFinder);

      // Type first letter -> triggers showBackButton and clear button appearance
      await tester.enterText(textFieldFinder, 'a');
      await tester.pump();

      final elementAfter = tester.element(textFieldFinder);
      // Element MUST be identical - no unmounting/remounting
      expect(identical(elementBefore, elementAfter), isTrue);
      expect(focusNode.hasFocus, isTrue);

      // Clear text
      await tester.enterText(textFieldFinder, '');
      await tester.pump();

      final elementAfterClear = tester.element(textFieldFinder);
      expect(identical(elementBefore, elementAfterClear), isTrue);
      expect(focusNode.hasFocus, isTrue);
    });
  });
}
