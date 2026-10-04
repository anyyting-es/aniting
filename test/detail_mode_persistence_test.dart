import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeDetailRepo extends SeanimeRepository {
  FakeDetailRepo() : super(ApiClient());

  @override
  Future<AnimeDetails?> getAnimeDetails(int mediaId, {dynamic initialEntry}) async {
    return AnimeDetails(
      id: mediaId,
      title: 'Test Anime',
      format: 'TV',
      score: 80,
      status: 'FINISHED',
      totalEpisodes: 12,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Anime Detail Mode Persistence Tests', () {
    testWidgets('Restores torrent mode when saved in SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pref_anime_detail_mode_12345': 'torrent',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepo()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 12345),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final mobileLayoutFinder = find.byType(AnimeDetailMobileLayout);
      expect(mobileLayoutFinder, findsOneWidget);

      final mobileLayout = tester.widget<AnimeDetailMobileLayout>(mobileLayoutFinder);
      expect(mobileLayout.isLocalMode, isFalse);
      expect(mobileLayout.currentTab, AnimeDetailTab.torrent);
    });

    testWidgets('Restores online mode when saved in SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pref_anime_detail_mode_12345': 'online',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepo()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 12345),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final mobileLayoutFinder = find.byType(AnimeDetailMobileLayout);
      expect(mobileLayoutFinder, findsOneWidget);

      final mobileLayout = tester.widget<AnimeDetailMobileLayout>(mobileLayoutFinder);
      expect(mobileLayout.isLocalMode, isFalse);
      expect(mobileLayout.currentTab, AnimeDetailTab.online);
    });

    testWidgets('Falls back to global last mode if no per-anime mode is saved', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pref_anime_detail_last_mode': 'torrent',
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(FakeDetailRepo()),
          ],
          child: const MaterialApp(
            home: AnimeDetailScreen(mediaId: 99999),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final mobileLayoutFinder = find.byType(AnimeDetailMobileLayout);
      expect(mobileLayoutFinder, findsOneWidget);

      final mobileLayout = tester.widget<AnimeDetailMobileLayout>(mobileLayoutFinder);
      expect(mobileLayout.isLocalMode, isFalse);
      expect(mobileLayout.currentTab, AnimeDetailTab.torrent);
    });
  });
}
