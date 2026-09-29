import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/screens/library_screen.dart';
import 'package:seanime_app/presentation/screens/my_lists_screen.dart';

class MockRunningServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
        status: ServerStatus(
          username: 'SeanimeUser',
        ),
      );
}

void main() {
  final testAnime = [
    AnimeEntry(id: 1, mediaId: 1, title: 'Anime 1', status: 'CURRENT', progress: 5),
    AnimeEntry(id: 2, mediaId: 2, title: 'Anime 2', status: 'COMPLETED', progress: 12),
    AnimeEntry(id: 3, mediaId: 3, title: 'Anime 3', status: 'PLANNING', progress: 0),
  ];

  final testManga = [
    MangaEntry(id: 10, mediaId: 10, title: 'Manga 1', status: 'CURRENT', progress: 3),
    MangaEntry(id: 11, mediaId: 11, title: 'Manga 2', status: 'COMPLETED', progress: 50),
  ];

  group('Profile Hub Screen Tests', () {
    testWidgets('LibraryScreen renders profile stats and hub action tiles', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
            animeCollectionProvider.overrideWith((ref) => Future.value(testAnime)),
            mangaCollectionProvider.overrideWith((ref) => Future.value(testManga)),
          ],
          child: const MaterialApp(
            home: LibraryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Username
      expect(find.text('SeanimeUser'), findsOneWidget);

      // Action Tiles
      expect(find.text('Mis Listas'), findsOneWidget);
      expect(find.text('Descargas de Anime'), findsOneWidget);
      expect(find.text('Descargas de Manga'), findsOneWidget);
      expect(find.text('Configuración'), findsOneWidget);

      // Quick settings section
      expect(find.text('Configuraciones Rápidas'), findsOneWidget);
      expect(find.text('Escanear Carpeta Local'), findsOneWidget);

      // Verify NO chevrons/arrows exist in the unboxed profile screen
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('MyListsScreen renders tabs and filter chips for anime and manga', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
            animeCollectionProvider.overrideWith((ref) => Future.value(testAnime)),
            mangaCollectionProvider.overrideWith((ref) => Future.value(testManga)),
          ],
          child: const MaterialApp(
            home: MyListsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mis Listas'), findsOneWidget);
      expect(find.text('Anime'), findsWidgets);
      expect(find.text('Manga'), findsWidgets);

      // Filter chips should be present
      expect(find.text('Viendo'), findsOneWidget);
      expect(find.text('Vistos'), findsOneWidget);
      expect(find.text('Planeados'), findsOneWidget);
    });

    testWidgets('DownloadsScreen renders dual tabs for anime and manga downloads', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
            animeCollectionProvider.overrideWith((ref) => Future.value(testAnime)),
            downloadedMangaListProvider.overrideWith((ref) => Future.value(<MangaEntry>[])),
          ],
          child: const MaterialApp(
            home: DownloadsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Descargas'), findsOneWidget);
      expect(find.text('Anime'), findsWidgets);
      expect(find.text('Manga'), findsWidgets);
    });
  });
}
