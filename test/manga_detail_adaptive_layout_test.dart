import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/desktop/desktop_manga_action_bar.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/desktop/desktop_manga_header.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/desktop/desktop_manga_sidebar.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/manga_detail_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/manga_detail/manga_detail_mobile_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMangaRepo extends SeanimeRepository {
  FakeMangaRepo() : super(ApiClient());

  @override
  Future<MangaEntry?> getMangaDetails(int mediaId, {MangaEntry? initialEntry}) async => initialEntry;

  @override
  Future<List<MangaProvider>> getMangaProviders() async => [
    const MangaProvider(id: 'mangasee', name: 'MangaSee'),
  ];

  @override
  Future<MangaChapterContainer?> getMangaChapters({
    required int mediaId,
    required String provider,
  }) async => MangaChapterContainer(
    mediaId: mediaId,
    provider: provider,
    chapters: const [
      MangaChapter(id: 'c1', url: '', title: 'Chapter 1', chapter: '1', index: 0),
      MangaChapter(id: 'c2', url: '', title: 'Chapter 2', chapter: '2', index: 1),
    ],
  );

  @override
  Future<Set<String>> getServerDownloadedChapterIds(int mediaId) async => {};
}

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(state: ServerState.running);
}

class MockDesktopLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.desktop;
}

class MockMobileLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.mobile;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final sampleManga = MangaEntry(
    id: 101,
    mediaId: 101,
    title: 'Chainsaw Man',
    englishTitle: 'Chainsaw Man',
    romajiTitle: 'Chainsaw Man',
    nativeTitle: 'チェンソーマン',
    progress: 10,
    totalChapters: 150,
    totalVolumes: 16,
    status: 'RELEASING',
    score: 8.8,
    format: 'MANGA',
    description: 'Denji has a simple dream—to live a happy and peaceful life.',
    genres: ['Action', 'Supernatural'],
    year: 2018,
    rawMedia: {
      'characters': {'edges': []},
      'relations': {'edges': []},
      'recommendations': {'edges': []},
    },
  );

  testWidgets('Renders MangaDetailDesktopLayout when width is 1200', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(FakeMangaRepo()),
          serverNotifierProvider.overrideWith(() => MockServerNotifier()),
          layoutModeProvider.overrideWith(() => MockDesktopLayoutModeNotifier()),
        ],
        child: MaterialApp(
          home: MangaDetailScreen(
            mediaId: 101,
            initialEntry: sampleManga,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MangaDetailDesktopLayout), findsOneWidget);
    expect(find.byType(DesktopMangaSidebar), findsOneWidget);
    expect(find.byType(DesktopMangaHeader), findsOneWidget);
    expect(find.byType(DesktopMangaActionBar), findsOneWidget);

    expect(find.text('Chainsaw Man'), findsWidgets);
    expect(find.text('Capítulos'), findsOneWidget);
    expect(find.text('Personajes'), findsOneWidget);
    expect(find.text('Relaciones'), findsOneWidget);
    expect(find.text('Obras similares'), findsOneWidget);
  });

  testWidgets('Renders MangaDetailMobileLayout when in mobile mode', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(FakeMangaRepo()),
          serverNotifierProvider.overrideWith(() => MockServerNotifier()),
          layoutModeProvider.overrideWith(() => MockMobileLayoutModeNotifier()),
        ],
        child: MaterialApp(
          home: MangaDetailScreen(
            mediaId: 101,
            initialEntry: sampleManga,
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(MangaDetailMobileLayout), findsOneWidget);
    expect(find.byType(MangaDetailDesktopLayout), findsNothing);
  });
}
