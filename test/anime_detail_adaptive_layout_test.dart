import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_tv_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDetailRepo extends SeanimeRepository {
  FakeDetailRepo() : super(ApiClient());

  @override
  Future<AnimeDetails?> getAnimeDetails(int mediaId, {AnimeEntry? initialEntry}) async {
    return AnimeDetails(
      id: mediaId,
      title: 'Mushoku Tensei Season 3',
      englishTitle: 'Mushoku Tensei: Jobless Reincarnation Season 3',
      format: 'TV',
      score: 85,
      status: 'FINISHED',
      season: 'SUMMER',
      seasonYear: 2026,
      studio: 'Studio Bind',
      genres: ['Adventure', 'Drama', 'Ecchi'],
      description: 'The third season of Mushoku Tensei.',
      totalEpisodes: 13,
      rawMedia: {
        'idMal': 50000,
        'trailer': {'id': 'dQw4w9WgXcQ', 'site': 'youtube'},
        'startDate': {'year': 2026, 'month': 7, 'day': 4},
        'endDate': {'year': 2026, 'month': 9, 'day': 27},
        'characters': {
          'edges': [
            {
              'role': 'MAIN',
              'node': {
                'id': 101,
                'name': {'userPreferred': 'Rudeus Greyrat'},
              },
            },
          ],
        },
        'relations': {
          'edges': [
            {
              'relationType': 'PREQUEL',
              'node': {
                'id': 154587,
                'format': 'TV',
                'title': {'userPreferred': 'Mushoku Tensei Season 2'},
              },
            },
          ],
        },
        'recommendations': {
          'edges': [
            {
              'node': {
                'mediaRecommendation': {
                  'id': 99999,
                  'title': {'userPreferred': 'Frieren'},
                },
              },
            },
          ],
        },
      },
    );
  }

  @override
  Future<AniZipData?> getAniZipData(int mediaId) async => null;

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async => null;

  @override
  Future<List<OnlinestreamProvider>> getOnlinestreamProviders() async => [];
}

class MockServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
      );
}

class MockDesktopLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.desktop;
}

class MockTvLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.tv;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Adaptive AnimeDetail Layout Tests', () {
    testWidgets('Renders Desktop Layout on wide screen with dual columns, trailer button, and tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepo()),
            serverNotifierProvider.overrideWith(() => MockServerNotifier()),
            layoutModeProvider.overrideWith(() => MockDesktopLayoutModeNotifier()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 170000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Check Desktop layout is rendered
      expect(find.byType(AnimeDetailDesktopLayout), findsOneWidget);

      // Check Left Column elements
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('TV Show'), findsOneWidget);
      expect(find.text('Status'), findsOneWidget);
      expect(find.text('FINISHED'), findsOneWidget);
      expect(find.text('Average score'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);

      // Check Right Column elements
      expect(find.text('Mushoku Tensei: Jobless Reincarnation Season 3'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('Ecchi'), findsOneWidget);

      // Check Action bar
      expect(find.text('A'), findsOneWidget);
      expect(find.text('MAL'), findsOneWidget);

      // Check Desktop Tabs
      expect(find.text('Episodes'), findsOneWidget);
      expect(find.text('Characters'), findsOneWidget);
      expect(find.text('Related'), findsOneWidget);
      expect(find.text('More like this'), findsOneWidget);

      // Switch to Characters tab
      await tester.tap(find.text('Characters'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Rudeus Greyrat'), findsOneWidget);

      // Switch to Related tab
      await tester.tap(find.text('Related'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Mushoku Tensei Season 2'), findsOneWidget);

      // Switch to More like this tab
      await tester.tap(find.text('More like this'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Frieren'), findsOneWidget);
    });

    testWidgets('Renders TV Layout when LayoutMode.tv is active', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepo()),
            serverNotifierProvider.overrideWith(() => MockServerNotifier()),
            layoutModeProvider.overrideWith(() => MockTvLayoutModeNotifier()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 170000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Check TV layout is rendered
      expect(find.byType(AnimeDetailTvLayout), findsOneWidget);
      expect(find.text('Empezar a ver'), findsOneWidget);
      expect(find.text('Detalles'), findsOneWidget);
    });
  });
}
