import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/api/api_client.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/library_entry_details.dart';
import 'package:aniting/data/repositories/aniting_repository.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';

class _FakeEpisodesRepo extends AnitingRepository {
  _FakeEpisodesRepo() : super(ApiClient());

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(
    int mediaId, {
    bool forceRefresh = false,
  }) async => null;
}

void main() {
  testWidgets('episode search filters by title and clears back', (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final aniZipData = AniZipData.fromJson({
      'titles': {'en': 'Test Anime'},
      'episodes': {
        for (final entry in {
          1: 'One',
          2: 'Two',
          3: 'Three',
        }.entries)
          '${entry.key}': {
            'episode': '${entry.key}',
            'episodeNumber': entry.key,
            'title': {'en': entry.value},
          },
      },
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(_FakeEpisodesRepo()),
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

    expect(find.text('EP 1. One'), findsOneWidget);
    expect(find.text('EP 2. Two'), findsOneWidget);
    expect(find.text('EP 3. Three'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.search(AppIconPack.lucide)));
    await tester.pumpAndSettle();

    final searchField = find.byType(EditableText);
    expect(searchField, findsOneWidget);

    await tester.enterText(searchField, 'Two');
    await tester.pumpAndSettle();

    expect(find.text('EP 2. Two'), findsOneWidget);
    expect(find.text('EP 1. One'), findsNothing);
    expect(find.text('EP 3. Three'), findsNothing);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.enterText(searchField, '');
    await tester.pumpAndSettle();

    expect(find.text('EP 1. One'), findsOneWidget);
    expect(find.text('EP 2. Two'), findsOneWidget);
    expect(find.text('EP 3. Three'), findsOneWidget);
  });
}
