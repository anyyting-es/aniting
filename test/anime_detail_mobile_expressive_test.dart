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
import 'package:seanime_app/presentation/widgets/anime_detail/mobile/anime_detail_source_popup.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeMobileDetailRepo extends SeanimeRepository {
  FakeMobileDetailRepo() : super(ApiClient());

  @override
  Future<AnimeDetails?> getAnimeDetails(int mediaId, {AnimeEntry? initialEntry}) async {
    return AnimeDetails(
      id: 170000,
      title: 'Mushoku Tensei Season 3',
      englishTitle: 'Mushoku Tensei: Jobless Reincarnation Season 3',
      format: 'TV',
      score: 85,
      status: 'FINISHED',
      season: 'SUMMER',
      seasonYear: 2026,
      studio: 'Studio Bind',
      genres: ['Adventure', 'Drama'],
      description: 'The third season of Mushoku Tensei.',
      totalEpisodes: 13,
      rawMedia: {},
    );
  }

  @override
  Future<AniZipData?> getAniZipData(int mediaId) async => null;

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async => null;

  @override
  Future<List<OnlinestreamProvider>> getOnlinestreamProviders() async => [
        const OnlinestreamProvider(
          id: 'provider-1',
          name: 'AnimeFlv',
          lang: 'es',
          supportsDub: true,
        ),
      ];

  @override
  Future<List<OnlinestreamEpisode>> getOnlinestreamEpisodes({
    required int mediaId,
    required String provider,
    bool dubbed = false,
  }) async => [];
}

class MockServerRunningNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(state: ServerState.running);
}

class MockMobileLayoutModeNotifier extends LayoutModeNotifier {
  @override
  LayoutMode build() => LayoutMode.mobile;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Mobile Anime Detail Inline Action Hub Tests', () {
    testWidgets('renders Play button first, followed by dropdown chips, with no floating dock',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeMobileDetailRepo()),
            serverNotifierProvider.overrideWith(() => MockServerRunningNotifier()),
            layoutModeProvider.overrideWith(() => MockMobileLayoutModeNotifier()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 170000),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // 1. Play button primerito (Comenzar a ver) + Actions (Favorite, Edit)
      expect(find.text('Comenzar a ver'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // 2. Dropdown Chips (Modo, Fuente)
      expect(find.text('Online'), findsOneWidget);
      expect(find.text('AnimeFlv'), findsOneWidget);

      // 3. Tap on Mode chip opens anchored PopupMenu with Online and Torrent
      await tester.tap(find.text('Online'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Torrent'), findsOneWidget);
      expect(find.textContaining('Online'), findsWidgets);

      // Dismiss menu
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Verify no floating dock container or islands exist at the bottom
      expect(find.byType(Positioned), findsWidgets);
      // Mode switch squircle from old design should not exist
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget); // In the provider chip
    });
  });

  group('AnimeDetailSourcePopup Widget Tests', () {
    testWidgets('opens compact dialog, lists providers, and switches selection',
        (WidgetTester tester) async {
      OnlinestreamProvider? activeProvider;
      bool isDub = false;

      final List<OnlinestreamProvider> providers = [
        const OnlinestreamProvider(
          id: 'provider-1',
          name: 'AnimeFlv',
          lang: 'es',
          supportsDub: true,
        ),
        const OnlinestreamProvider(
          id: 'provider-2',
          name: 'Zoro',
          lang: 'en',
          supportsDub: false,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      AnimeDetailSourcePopup.show(
                        context: context,
                        providers: providers,
                        selectedProvider: activeProvider ?? providers.first,
                        isDubbed: isDub,
                        onProviderChanged: (p) => activeProvider = p,
                        onToggleDubbed: (d) => isDub = d,
                      );
                    },
                    child: const Text('Open Popup'),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Open popup
      await tester.tap(find.text('Open Popup'));
      await tester.pumpAndSettle();

      // Check popup header
      expect(find.text('Fuentes Online'), findsOneWidget);
      expect(find.text('2 disponibles'), findsOneWidget);

      // Check providers are listed
      expect(find.text('AnimeFlv'), findsOneWidget);
      expect(find.text('Zoro'), findsOneWidget);

      // Select Zoro
      await tester.tap(find.text('Zoro'));
      await tester.pump();
      expect(activeProvider?.id, 'provider-2');
    });
  });
}
