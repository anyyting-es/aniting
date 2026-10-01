import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() {
    return const ServerStateModel(state: ServerState.running);
  }
}

void main() {
  group('Downloaded Anime Provider & DownloadsScreen Tests', () {
    test('AnimeEntry hasLocalFiles properly detects local files', () {
      final entryWithLocal = AnimeEntry(
        id: 1,
        mediaId: 101,
        title: 'Downloaded Anime',
        progress: 0,
        status: 'CURRENT',
        mainFileCount: 3,
        hasLocalFiles: true,
      );

      final entryWithoutLocal = AnimeEntry(
        id: 2,
        mediaId: 102,
        title: 'Online Watchlist Anime',
        progress: 0,
        status: 'CURRENT',
        mainFileCount: 0,
        hasLocalFiles: false,
      );

      expect(entryWithLocal.hasLocalFiles, isTrue);
      expect(entryWithLocal.mainFileCount, 3);

      expect(entryWithoutLocal.hasLocalFiles, isFalse);
      expect(entryWithoutLocal.mainFileCount, 0);
    });

    testWidgets('DownloadsScreen renders empty state when downloadedAnimeProvider is empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
            downloadedAnimeProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DownloadsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tab bar should show 'Anime' and 'Manga'
      expect(find.text('Anime'), findsOneWidget);
      expect(find.text('Manga'), findsOneWidget);

      // Empty state text
      expect(find.text('No hay anime descargado'), findsOneWidget);
    });

    testWidgets('DownloadsScreen displays downloaded anime when downloadedAnimeProvider has items', (tester) async {
      final downloadedItem = AnimeEntry(
        id: 10,
        mediaId: 999,
        title: 'Frieren: Beyond Journey\'s End',
        progress: 0,
        status: 'CURRENT',
        mainFileCount: 12,
        hasLocalFiles: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockServerNotifier.new),
            downloadedAnimeProvider.overrideWith((ref) => Future.value([downloadedItem])),
          ],
          child: const MaterialApp(
            home: DownloadsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('1 anime descargados'), findsOneWidget);
      expect(find.byType(AnimeCard), findsOneWidget);
    });
  });
}
