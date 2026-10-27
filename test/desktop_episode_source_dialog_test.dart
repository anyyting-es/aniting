import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_action_bar.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episode_models.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/desktop/desktop_episode_source_dialog.dart';

void main() {
  group('DesktopEpisodeSourceDialog Tests', () {
    testWidgets('Renders Online, Torrent, and Local options correctly', (tester) async {
      bool torrentClicked = false;

      final ep = DesktopEpisodeItemData(
        number: 1,
        title: 'Episode 1: The Beginning',
        isDownloaded: true,
        localFilePath: '/path/to/ep1.mkv',
      );

      final providers = [
        const OnlinestreamProvider(id: 'gogo', name: 'Gogoanime', supportsDub: true),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDesktopEpisodeSourceDialog(
                      context,
                      episode: ep,
                      animeTitle: 'Attack on Titan',
                      providers: providers,
                      selectedProvider: providers.first,
                      isDubbed: false,
                      onProviderChanged: (_) {},
                      onToggleDubbed: () {},
                      onPlayOnline: () {},
                      onPlayTorrent: () => torrentClicked = true,
                      onPlayLocal: () {},
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Verify episode title
      expect(find.text('Episode 1: The Beginning'), findsOneWidget);

      // Verify sources are rendered
      expect(find.text('Online Streaming'), findsWidgets);
      expect(find.textContaining('Torrent'), findsWidgets);
      expect(find.textContaining('Local'), findsWidgets);

      // Tap torrent source
      await tester.tap(find.textContaining('Torrent').first);
      await tester.pumpAndSettle();
      expect(torrentClicked, isTrue);
    });

    testWidgets('DesktopActionBar D-PAD Left from expand button navigates to adjacent expanded button', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DesktopActionBar(
                mediaId: 100,
                title: 'Test',
                progress: 0,
                idMal: 100,
                onlineEnabled: true,
                torrentEnabled: true,
                currentTab: AnimeDetailTab.online,
                onPlayNext: () {},
                onOpenEditEntryModal: (_) {},
                onTabChanged: (_) {},
              ),
            ),
          ),
        ),
      );

      // Expand secondary tools
      final expandButtonFinder = find.byTooltip('Más opciones');
      expect(expandButtonFinder, findsOneWidget);
      await tester.tap(expandButtonFinder);
      await tester.pumpAndSettle();

      // Focus the expand button directly
      final expandedToggleFinder = find.descendant(
        of: find.byTooltip('Colapsar'),
        matching: find.byType(M3EIconButton),
      );
      final expandNode = tester.widget<M3EIconButton>(expandedToggleFinder).focusNode!;
      expandNode.requestFocus();
      await tester.pump();
      expect(expandNode.hasFocus, isTrue);

      // Send Arrow Left key
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();

      // Verify share button is focused, NOT the edit button (pencil)
      final shareIconFinder = find.byIcon(AppIcons.share(AppIconPack.lucide));
      final shareNode = tester.widget<M3EIconButton>(
        find.ancestor(of: shareIconFinder, matching: find.byType(M3EIconButton)),
      ).focusNode!;
      expect(shareNode.hasFocus, isTrue);
    });
  });
}
