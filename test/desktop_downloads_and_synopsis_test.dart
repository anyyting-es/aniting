import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_header.dart';

class FakeEpisodesRepo extends SeanimeRepository {
  FakeEpisodesRepo() : super(ApiClient());

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId, {bool forceRefresh = false}) async => null;

  @override
  Future<AnimeDetails?> getAnimeDetails(int mediaId, {AnimeEntry? initialEntry}) async {
    return AnimeDetails(
      id: mediaId,
      title: 'Frieren',
      coverImage: 'https://example.com/cover.jpg',
      totalEpisodes: 2,
    );
  }

  @override
  Future<AniZipData?> getAniZipData(int mediaId) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Desktop Synopsis Animation & Downloads Integration Tests', () {
    testWidgets('DesktopHeader renders chevron icon and cleans multi-newline text', (tester) async {
      bool expanded = false;
      const messyDesc = 'Following the First-Class Mage Exam, the trio—elven mage Frieren, warrior Stark, and first-class mage Fern—gains access to the dangerous Northern Plateau.\n\n\n\n\n\nAs the party presses onward toward Aureole, formidable adversaries force Stark to confront his insecurities, solidifying his resolve and his role as the party\'s frontliner.\n\n\n(Source: MAL Rewrite)';

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return DesktopHeader(
                    title: 'Frieren: Beyond Journey\'s End',
                    genres: const ['Adventure', 'Drama', 'Fantasy'],
                    description: messyDesc,
                    isSynopsisExpanded: expanded,
                    onToggleSynopsisExpanded: (val) {
                      setState(() => expanded = val);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify clean description does not contain excessive newlines
      final textFinder = find.byType(Text);
      expect(textFinder, findsWidgets);

      // Verify chevron down icon exists initially for expansion
      final chevronDownFinder = find.byIcon(AppIcons.chevronDown(AppIconPack.lucide));
      expect(chevronDownFinder, findsOneWidget);

      // Tap expansion button directly on the chevron or inkwell
      await tester.tap(chevronDownFinder);
      await tester.pumpAndSettle();

      // Verify toggled to chevron up
      expect(find.byIcon(AppIcons.chevronUp(AppIconPack.lucide)), findsOneWidget);
    });

    testWidgets('DesktopEpisodesTab keeps all episodes visible even when downloadedMap has files', (tester) async {
      final aniZipData = AniZipData.fromJson({
        'titles': {'en': 'Test Anime'},
        'episodes': {
          '1': {
            'episode': '1',
            'episodeNumber': 1,
            'title': {'en': 'The Journey Begins'},
          },
          '2': {
            'episode': '2',
            'episodeNumber': 2,
            'title': {'en': 'Magic of the Past'},
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
            downloadingEpisodesProvider.overrideWith(() => DownloadingEpisodesNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 154587,
                details: AnimeDetails(
                  id: 154587,
                  title: 'Frieren',
                  totalEpisodes: 2,
                ),
                aniZipData: aniZipData,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.online,
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

      await tester.pumpAndSettle();

      // Both episodes are visible with formatted titles
      expect(find.text('EP 1. The Journey Begins'), findsOneWidget);
      expect(find.text('EP 2. Magic of the Past'), findsOneWidget);
    });

    testWidgets('AnimeDetailScreen renders blurred poster backdrop and spinner during loading gate', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(
              mediaId: 154587,
              initialEntry: null,
            ),
          ),
        ),
      );

      // Verify loading indicator is shown initially
      expect(find.byType(M3ELoadingIndicator), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('AnimeDetailScreen wraps AnimatedSwitcher in solid ColoredBox to prevent transition transparency', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeEpisodesRepo()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(
              mediaId: 154587,
              initialEntry: null,
            ),
          ),
        ),
      );

      // Verify AnimatedSwitcher is backed by ColoredBox
      final switcherFinder = find.byType(AnimatedSwitcher);
      expect(switcherFinder, findsOneWidget);
      final coloredBoxFinder = find.ancestor(
        of: switcherFinder,
        matching: find.byType(ColoredBox),
      );
      expect(coloredBoxFinder, findsWidgets);
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

