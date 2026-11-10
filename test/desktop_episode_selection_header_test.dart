import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aniting/core/api/api_client.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/library_entry_details.dart';
import 'package:aniting/data/repositories/aniting_repository.dart';
import 'package:aniting/data/services/offline_library_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';

class _FakeEpisodesRepo extends AnitingRepository {
  _FakeEpisodesRepo() : super(ApiClient());

  int? lastMarkedProgress;

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(
    int mediaId, {
    bool forceRefresh = false,
  }) async => null;

  @override
  Future<bool> updateAnimeProgress({
    required int mediaId,
    required int episodeNumber,
    int? totalEpisodes,
  }) async {
    lastMarkedProgress = episodeNumber;
    return true;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(const {});
    OfflineLibraryService.instance.clearMemoryForTesting();
  });

  testWidgets('Selection mode replaces the episodes header with batch actions',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final aniZipData = AniZipData.fromJson({
      'titles': {'en': 'Test Anime'},
      'episodes': {
        for (int i = 1; i <= 3; i++)
          '$i': {
            'episode': '$i',
            'episodeNumber': i,
            'title': {'en': 'Episode $i'},
          },
      },
    });

    final fakeRepo = _FakeEpisodesRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopEpisodesTab(
              mediaId: 1,
              details: null,
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
    await tester.pump();

    expect(find.text('Episodios'), findsOneWidget);

    await tester.longPress(find.byKey(const ValueKey('grid_ep_1')));
    await tester.pumpAndSettle();

    expect(find.text('Episodios'), findsNothing);
    expect(find.text('1 seleccionados'), findsOneWidget);
    expect(find.text('Seleccionar todos'), findsOneWidget);
    expect(find.text('Descargar (1)'), findsOneWidget);
    expect(find.text('Marcar vistos'), findsOneWidget);

    await tester.tap(find.text('Seleccionar todos'));
    await tester.pump();
    expect(find.text('3 seleccionados'), findsOneWidget);
    expect(find.text('Deseleccionar'), findsOneWidget);
    expect(find.text('Descargar (3)'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.close(AppIconPack.lucide)));
    await tester.pumpAndSettle();
    expect(find.text('Episodios'), findsOneWidget);
    expect(find.text('3 seleccionados'), findsNothing);

    // Marking EP3 as watched must mark EP1 and EP2 too (linear progress).
    await tester.longPress(find.byKey(const ValueKey('grid_ep_3')));
    await tester.pumpAndSettle();
    expect(find.text('1 seleccionados'), findsOneWidget);

    await tester.tap(find.text('Marcar vistos'));
    await tester.pumpAndSettle();

    expect(fakeRepo.lastMarkedProgress, 3);
    expect(OfflineLibraryService.instance.getAnimeEntry(1)?.progress, 3);
    expect(find.text('Episodios'), findsOneWidget);
  });
}
