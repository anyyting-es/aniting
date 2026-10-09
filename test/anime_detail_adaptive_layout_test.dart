import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
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
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_tv_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';
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

class MockMobileLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.mobile;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Adaptive AnimeDetail Layout Tests', () {
    testWidgets('Renders Desktop Layout on wide screen with dual columns, trailer button, and tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 5500);
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
            translationsProvider.overrideWithValue(const EnglishTranslations()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 170000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));

      // Check Desktop layout is rendered
      expect(find.byType(AnimeDetailDesktopLayout), findsOneWidget);

      // Check Desktop Header metadata badges
      expect(find.text('TV'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('85%'), findsOneWidget);

      // Check Right Column elements
      expect(find.text('Mushoku Tensei: Jobless Reincarnation Season 3'), findsOneWidget);
      expect(find.text('Adventure'), findsOneWidget);
      expect(find.text('Drama'), findsOneWidget);
      expect(find.text('Ecchi'), findsOneWidget);

      // Check Action bar brand icons
      expect(find.byTooltip('View on AniList'), findsOneWidget);
      expect(find.byTooltip('View on MyAnimeList'), findsOneWidget);

      // Check Desktop Sections (Episodes title removed per UI design)
      const en = EnglishTranslations();
      expect(find.byType(DesktopEpisodesTab), findsOneWidget);
      expect(find.text(en.relations), findsOneWidget);
      expect(find.text(en.recommendations), findsOneWidget);
      expect(find.text(en.characters), findsOneWidget);

      // Verify sections content in vertical flow
      expect(find.text('Mushoku Tensei Season 2', skipOffstage: false), findsOneWidget);
      expect(find.text('Frieren', skipOffstage: false), findsOneWidget);
      expect(find.text('Rudeus Greyrat', skipOffstage: false), findsOneWidget);
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
      expect(find.text('Comenzar a ver'), findsOneWidget);
      expect(find.text('Detalles'), findsOneWidget);
    });

    testWidgets('Renders Mobile Layout with banner blur enabled without gaps', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
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
            layoutModeProvider.overrideWith(() => MockMobileLayoutModeNotifier()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 170000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AnimeDetailMobileLayout), findsOneWidget);
      expect(find.text('Mushoku Tensei: Jobless Reincarnation Season 3'), findsOneWidget);
    });
  });
}
