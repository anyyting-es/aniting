import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_action_bar.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_characters_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_recommendations_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_relations_tab.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_sidebar.dart';

void main() {
  group('Desktop Anime Detail Overhaul Tests', () {
    test('AnimeDetails preserves characters, relations, recommendations, and trailer in rawMedia', () {
      final json = {
        'id': 12345,
        'title': {'userPreferred': 'Test Anime'},
        'characters': {
          'edges': [
            {
              'role': 'MAIN',
              'node': {
                'id': 1,
                'name': {'userPreferred': 'Test MC'},
              },
            },
          ],
        },
        'relations': {
          'edges': [
            {
              'relationType': 'SEQUEL',
              'node': {
                'id': 12346,
                'title': {'userPreferred': 'Test Sequel'},
              },
            },
          ],
        },
        'recommendations': {
          'edges': [
            {
              'node': {
                'mediaRecommendation': {
                  'id': 999,
                  'title': {'userPreferred': 'Recommended Anime'},
                },
              },
            },
          ],
        },
        'trailer': {
          'id': 'abc123xyz',
          'site': 'youtube',
        },
      };

      final details = AnimeDetails.fromJson(json);

      expect(details.characters.length, 1);
      expect(details.relations.length, 1);
      expect(details.recommendations.length, 1);
      expect(details.trailer?['id'], 'abc123xyz');
    });

    testWidgets('DesktopSidebar renders enlarged poster and no trailer button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DesktopSidebar(
                coverUrl: null,
                format: 'TV',
                status: 'FINISHED',
                airedStr: '2026',
                seasonYearStr: 'SPRING 2026',
                score: 85,
                studio: 'Madhouse',
              ),
            ),
          ),
        ),
      );

      // Verify trailer button is NOT in the sidebar
      expect(find.text('Watch trailer'), findsNothing);
      expect(find.text('No trailer'), findsNothing);

      // Verify metadata items exist
      expect(find.text('Format'), findsOneWidget);
      expect(find.text('TV Show'), findsOneWidget);
      expect(find.text('Studio'), findsOneWidget);
      expect(find.text('Madhouse'), findsOneWidget);
    });

    testWidgets('DesktopActionBar renders trailer button next to play and bookmark', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopActionBar(
              mediaId: 12345,
              title: 'Test Anime',
              progress: 3,
              idMal: 456,
              trailerId: 'youtube_id',
              trailerSite: 'youtube',
              hasTrailer: true,
              currentTab: AnimeDetailTab.online,
              isLocalMode: false,
              onlineEnabled: true,
              torrentEnabled: true,
              onPlayNext: () {},
              onOpenEditEntryModal: (_) {},
              onToggleLocalMode: () {},
              onTabChanged: (_) {},
            ),
          ),
        ),
      );

      // Check play icon
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
      // Check bookmark icon
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
      // Check trailer icon in action bar
      expect(find.byIcon(Icons.smart_display_rounded), findsOneWidget);
      // Check MAL and AniList pills
      expect(find.text('A'), findsOneWidget);
      expect(find.text('MAL'), findsOneWidget);
    });

    testWidgets('DesktopCharactersTab renders characters with role and name', (tester) async {
      final characters = [
        {
          'role': 'MAIN',
          'node': {
            'id': 1,
            'name': {'userPreferred': 'Eren Yeager'},
          },
        },
        {
          'role': 'SUPPORTING',
          'node': {
            'id': 2,
            'name': {'userPreferred': 'Armin Arlert'},
          },
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopCharactersTab(characters: characters),
          ),
        ),
      );

      expect(find.text('Eren Yeager'), findsOneWidget);
      expect(find.text('Armin Arlert'), findsOneWidget);
      expect(find.text('PRINCIPAL'), findsOneWidget);
      expect(find.text('SECUNDARIO'), findsOneWidget);
    });

    testWidgets('DesktopRelationsTab renders relation cards with relation types', (tester) async {
      final relations = [
        {
          'relationType': 'PREQUEL',
          'node': {
            'id': 100,
            'format': 'TV',
            'title': {'userPreferred': 'Season 1'},
          },
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopRelationsTab(relations: relations),
          ),
        ),
      );

      expect(find.text('Season 1'), findsOneWidget);
      expect(find.text('PRECUELA'), findsOneWidget);
    });

    testWidgets('DesktopRecommendationsTab renders recommendation cards', (tester) async {
      final recommendations = [
        {
          'node': {
            'mediaRecommendation': {
              'id': 200,
              'format': 'MOVIE',
              'meanScore': 90,
              'title': {'userPreferred': 'Your Name'},
            },
          },
        },
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DesktopRecommendationsTab(recommendations: recommendations),
          ),
        ),
      );

      expect(find.text('Your Name'), findsOneWidget);
    });
  });
}
