import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/api/api_client.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/library_entry_details.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
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

AniZipData _aniZipWithCollidingSpecials() => AniZipData.fromJson({
      'titles': {'en': 'Test Anime'},
      'episodes': {
        '1': {
          'episode': '1',
          'episodeNumber': 1,
          'title': {'en': 'Canonical One'},
        },
        '2': {
          'episode': '2',
          'episodeNumber': 2,
          'title': {'en': 'Canonical Two'},
        },
        'S1': {
          'episode': 'S1',
          'seasonNumber': 0,
          'episodeNumber': 52,
          'title': {'en': 'Special One'},
        },
        'S2': {
          'episode': 'S2',
          'seasonNumber': 0,
          'episodeNumber': 53,
          'title': {'en': 'Special Two'},
        },
      },
    });

AniZipData _aniZip() => AniZipData.fromJson({
      'titles': {'en': 'Test Anime'},
      'episodes': {
        '1': {
          'episode': '1',
          'episodeNumber': 1,
          'title': {'en': 'Canonical One'},
        },
        '2': {
          'episode': '2',
          'episodeNumber': 2,
          'title': {'en': 'Canonical Two'},
        },
      },
    });

AniZipData _emptyAniZip() => AniZipData.fromJson({'episodes': {}});

AnimeDetails _detailsWithAnimapEpisodes() => AnimeDetails(
      id: 1,
      title: 'Test Anime',
      episodes: [
        AnimeEpisode(
          episodeNumber: 1,
          title: 'Clouds and Rain',
          description: 'Episode one synopsis.',
          image: 'https://example.com/ep1.jpg',
        ),
        AnimeEpisode(
          episodeNumber: 2,
          title: 'Stop and Go',
          description: 'Episode two synopsis.',
          image: 'https://example.com/ep2.jpg',
        ),
        AnimeEpisode(
          episodeNumber: 3,
          title: 'Shifting Shadows',
          image: 'https://example.com/ep3.jpg',
        ),
      ],
    );

Widget _buildTab({
  required List<OnlinestreamEpisode> onlineEpisodes,
  required AniZipData aniZipData,
  AnimeDetails? details,
}) {
  const provider = OnlinestreamProvider(id: 'test', name: 'Test Source');
  return ProviderScope(
    overrides: [repositoryProvider.overrideWithValue(_FakeEpisodesRepo())],
    child: MaterialApp(
      home: Scaffold(
        body: DesktopEpisodesTab(
          mediaId: 1,
          details: details,
          aniZipData: aniZipData,
          progress: 0,
          isLocalMode: false,
          currentTab: AnimeDetailTab.online,
          providers: const [provider],
          selectedProvider: provider,
          isDubbed: false,
          onlineEpisodes: onlineEpisodes,
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
  );
}

void main() {
  test('AnimeEpisode.fromJson prefers Animap episodeTitle/image over stubs',
      () {
    final ep = AnimeEpisode.fromJson({
      'episodeNumber': 1,
      'displayTitle': 'Episode 1',
      'episodeTitle': 'Clouds and Rain',
      'episodeMetadata': {
        'image': 'https://example.com/animap-ep1.jpg',
        'overview': 'The group meets at school.',
      },
    });

    expect(ep.title, 'Clouds and Rain');
    expect(ep.image, 'https://example.com/animap-ep1.jpg');
    expect(ep.description, 'The group meets at school.');
  });

  testWidgets('online provider list is enriched from Animap when AniZip is empty',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTab(
        aniZipData: _emptyAniZip(),
        details: _detailsWithAnimapEpisodes(),
        onlineEpisodes: const [
          OnlinestreamEpisode(number: 1, title: 'Episodio 1'),
          OnlinestreamEpisode(number: 2, title: 'Episodio 2'),
          OnlinestreamEpisode(number: 3, title: 'Episodio 3'),
          OnlinestreamEpisode(number: 4, title: 'Episodio 4'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Clouds and Rain'), findsOneWidget);
    expect(find.textContaining('Stop and Go'), findsOneWidget);
    expect(find.textContaining('Shifting Shadows'), findsOneWidget);
  });

  testWidgets('online provider with extra episodes shows the provider list',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTab(
        aniZipData: _aniZip(),
        onlineEpisodes: const [
          OnlinestreamEpisode(number: 1, title: 'Provider One'),
          OnlinestreamEpisode(number: 2, title: 'Provider Two'),
          OnlinestreamEpisode(number: 3, title: 'Provider Three'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Provider Three'), findsOneWidget);
    expect(find.textContaining('Canonical One'), findsNothing);
  });

  testWidgets('online provider with missing episodes shows only provider list',
      (tester) async {
    await tester.pumpWidget(
      _buildTab(
        aniZipData: _aniZip(),
        onlineEpisodes: const [
          OnlinestreamEpisode(number: 1, title: 'Provider One'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Provider One'), findsOneWidget);
    expect(find.textContaining('Provider Two'), findsNothing);
    expect(find.textContaining('Canonical Two'), findsNothing);
  });

  testWidgets('specials never override main episode metadata by number',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      _buildTab(
        aniZipData: _aniZipWithCollidingSpecials(),
        onlineEpisodes: const [
          OnlinestreamEpisode(number: 1, title: 'Episode 1'),
          OnlinestreamEpisode(number: 2, title: 'Episode 2'),
          OnlinestreamEpisode(number: 3, title: 'Episode 3'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Canonical One'), findsOneWidget);
    expect(find.textContaining('Canonical Two'), findsOneWidget);
    expect(find.textContaining('Special One'), findsNothing);
    expect(find.textContaining('Special Two'), findsNothing);
  });

  testWidgets('1:1 provider list keeps the canonical AniList episodes',
      (tester) async {
    await tester.pumpWidget(
      _buildTab(
        aniZipData: _aniZip(),
        onlineEpisodes: const [
          OnlinestreamEpisode(number: 1, title: 'Provider One'),
          OnlinestreamEpisode(number: 2, title: 'Provider Two'),
        ],
      ),
    );
    await tester.pump();

    expect(find.textContaining('Canonical One'), findsOneWidget);
    expect(find.textContaining('Canonical Two'), findsOneWidget);
    expect(find.textContaining('Provider One'), findsNothing);
  });
}
