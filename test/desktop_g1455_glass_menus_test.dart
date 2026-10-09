import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episodes_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episode_context_menu.dart';
import 'package:seanime_app/core/i18n/translations/en.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/edit_entry/edit_entry_status_dropdown.dart';

import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';

class _FakeEpisodesRepo extends SeanimeRepository {
  _FakeEpisodesRepo() : super(ApiClient());

  @override
  Future<LibraryEntryDetails?> getAnimeLibraryEntry(int mediaId) async => null;
}

void main() {
  group('g1455 Glass Menus & Popovers Tests', () {
    testWidgets('DesktopEpisodesTab uses GlassMenuAnchor for online providers', (tester) async {
      final provider = OnlinestreamProvider(
        id: 'gogoanime',
        name: 'Gogoanime',
        lang: 'en',
        supportsDub: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(_FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodesTab(
                mediaId: 101,
                details: null,
                aniZipData: null,
                progress: 0,
                isLocalMode: false,
                currentTab: AnimeDetailTab.online,
                providers: [provider],
                selectedProvider: provider,
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

      expect(find.byType(GlassMenuAnchor), findsOneWidget);
      expect(find.byType(GlassButton), findsOneWidget);
      expect(find.text('Gogoanime'), findsOneWidget);
    });

    testWidgets('DesktopEpisodeContextMenu opens GlassCard on secondary click', (tester) async {
      final ep = DesktopEpisodeItemData(
        number: 1,
        title: 'Episode 1',
        isWatched: false,
        isDownloaded: false,
        isDownloading: false,
        downloadProgress: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(_FakeEpisodesRepo()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: DesktopEpisodeContextMenu(
                ep: ep,
                mediaId: 101,
                details: null,
                onEpisodeClicked: (_) {},
                child: const SizedBox(
                  key: Key('episode-card'),
                  width: 200,
                  height: 120,
                  child: Text('Card Content'),
                ),
              ),
            ),
          ),
        ),
      );

      // Perform secondary click (right-click)
      await tester.tap(find.byKey(const Key('episode-card')), buttons: 2);
      await tester.pumpAndSettle();

      // GlassCard should be displayed in the general dialog
      expect(find.byType(GlassCard), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('EditEntryStatusDropdown uses GlassPopoverAnchor without extra BackdropFilter', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditEntryStatusDropdown(
              status: 'CURRENT',
              isAnime: true,
              onChanged: (_) {},
              l10n: const EnglishTranslations(),
            ),
          ),
        ),
      );

      expect(find.byType(GlassPopoverAnchor), findsOneWidget);
      // No manual BackdropFilter inside the widget
      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
