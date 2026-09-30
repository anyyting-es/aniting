import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';
import 'package:seanime_app/presentation/widgets/continue_reading_card.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';
import 'package:seanime_app/presentation/widgets/feed_empty_state.dart';
import 'package:seanime_app/presentation/widgets/floating_nav/floating_resume_companion.dart';
import 'package:seanime_app/core/i18n/translations/es.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => const ServerStateModel(state: ServerState.stopped);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User Library Feeds & Progress Tests', () {
    test('PlaybackProgressNotifier saves and loads episode progress correctly', () async {
      final container = ProviderContainer();
      final notifier = container.read(playbackProgressPreferencesProvider.notifier);

      await notifier.saveProgress(
        mediaId: 101,
        episodeNumber: 3,
        positionMs: 60000,
        durationMs: 120000,
      );

      final progress = notifier.getProgress(101, 3);
      expect(progress, isNotNull);
      expect(progress!.fraction, equals(0.5));
      expect(progress.positionMs, equals(60000));
      expect(progress.durationMs, equals(120000));
    });

    testWidgets('ContinueWatchingCard does NOT show progress bar for new user without local progress',
        (tester) async {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 501,
        title: 'Frieren: Beyond Journey\'s End',
        progress: 4,
        totalEpisodes: 28,
        status: 'CURRENT',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
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
      await tester.pump();

      // No LinearProgressIndicator should be rendered
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('EP 5'), findsOneWidget);
    });

    testWidgets('ContinueWatchingCard DOES show progress bar when local progress is saved',
        (tester) async {
      final entry = AnimeEntry(
        id: 1,
        mediaId: 502,
        title: 'Sousou no Frieren',
        progress: 2,
        totalEpisodes: 28,
        status: 'CURRENT',
      );

      final container = ProviderContainer(
        overrides: [
          serverNotifierProvider.overrideWith(MockServerNotifier.new),
        ],
      );
      // Pre-populate 50% watched for episode 3
      await container.read(playbackProgressPreferencesProvider.notifier).saveProgress(
            mediaId: 502,
            episodeNumber: 3,
            positionMs: 600000,
            durationMs: 1200000,
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
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
      await tester.pump();

      // LinearProgressIndicator SHOULD be rendered
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, closeTo(0.5, 0.01));
    });

    testWidgets('ContinueReadingCard displays Chapter - Total and progress fraction',
        (tester) async {
      final manga = MangaEntry(
        id: 10,
        mediaId: 999,
        title: 'Berserk',
        progress: 70,
        totalChapters: 150,
        status: 'CURRENT',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ContinueReadingCard(
                entry: manga,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Should find text with next chapter 71 and total 150: "Chapter 71 - 150"
      expect(find.textContaining('71 - 150'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, closeTo(70 / 150, 0.01));
    });

    testWidgets('DesktopSidebar displays user avatar when avatarUrl is present',
        (tester) async {
      final items = [
        const DesktopSidebarItem(
          icon: Icons.home,
          selectedIcon: Icons.home,
          label: 'Inicio',
          targetIndex: 0,
        ),
        const DesktopSidebarItem(
          icon: Icons.person,
          selectedIcon: Icons.person,
          label: 'Perfil',
          targetIndex: 4,
          avatarUrl: 'https://example.com/avatar.jpg',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                onSearchPressed: () {},
                items: items,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Tooltip for profile exists
      expect(find.byTooltip('Perfil'), findsOneWidget);
      // Profile avatar CachedNetworkImage exists
      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('DesktopSidebar displays icon when avatarUrl is null',
        (tester) async {
      final items = [
        const DesktopSidebarItem(
          icon: Icons.person,
          selectedIcon: Icons.person,
          label: 'Perfil',
          targetIndex: 4,
          avatarUrl: null,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopSidebar(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                onSearchPressed: () {},
                items: items,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('FeedEmptyState renders AniList login CTA when user is not logged in',
        (tester) async {
      bool explored = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeedEmptyState(
                isLoggedIn: false,
                isManga: false,
                onExplore: () => explored = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Conectar con AniList'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);
      expect(find.text('Conecta tu cuenta de AniList para sincronizar tus listas'), findsOneWidget);

      await tester.tap(find.text('Explorar'));
      expect(explored, isTrue);
    });

    testWidgets('FeedEmptyState renders empty library CTA when user is logged in',
        (tester) async {
      bool explored = false;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: FeedEmptyState(
                isLoggedIn: true,
                isManga: false,
                onExplore: () => explored = true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Tu lista de anime está vacía'), findsOneWidget);
      expect(find.text('Explorar'), findsOneWidget);

      await tester.tap(find.text('Explorar'));
      expect(explored, isTrue);
    });

    testWidgets('FloatingResumeCompanion handles zero width without assertion crash',
        (tester) async {
      final session = LastSessionItem(
        mediaType: 'ANIME',
        mediaId: 101,
        title: 'Frieren: Beyond Journey\'s End',
        episodeNumber: 1,
        positionMs: 50000,
        durationMs: 100000,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 0,
                height: 0,
                child: FloatingResumeCompanion(
                  session: session,
                  tWidth: 1.0,
                  width: -52.0, // test negative constraint handling
                  height: 68.0,
                  borderRadius: BorderRadius.circular(34),
                  l10n: const SpanishTranslations(),
                  onTap: () {},
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Should build without throwing negative constraint assertion error
      expect(find.byType(FloatingResumeCompanion), findsOneWidget);
    });
  });
}
