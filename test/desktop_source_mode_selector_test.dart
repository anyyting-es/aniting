import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/desktop/desktop_action_bar.dart';

Widget _buildActionBar({
  required bool showSourceSelector,
  required bool isTmdb,
  AnimeDetailTab currentTab = AnimeDetailTab.online,
  OnlinestreamProvider? selectedProvider = const OnlinestreamProvider(
    id: 'gogo',
    name: 'Gogoanime',
  ),
  ValueChanged<String>? onModeChanged,
  ValueChanged<OnlinestreamProvider?>? onProviderChanged,
}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: DesktopActionBar(
          mediaId: 1,
          title: 'Test Anime',
          progress: 0,
          idMal: 1,
          onlineEnabled: true,
          torrentEnabled: true,
          isTmdb: isTmdb,
          currentTab: currentTab,
          hasLocalFiles: true,
          showSourceSelector: showSourceSelector,
          providers: selectedProvider == null
              ? const []
              : [selectedProvider],
          selectedProvider: selectedProvider,
          onModeChanged: onModeChanged,
          onProviderChanged: onProviderChanged,
          onPlayNext: () {},
          onOpenEditEntryModal: (_) {},
          onTabChanged: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  group('Desktop source mode selector', () {
    testWidgets('shows the Online/Torrent selector and the online extension',
        (tester) async {
      await tester.pumpWidget(
        _buildActionBar(showSourceSelector: true, isTmdb: false),
      );

      expect(find.text('Online Streaming'), findsOneWidget);
      expect(find.text('Gogoanime'), findsOneWidget);
    });

    testWidgets('hides the source selector for TMDB entries', (tester) async {
      await tester.pumpWidget(
        _buildActionBar(showSourceSelector: false, isTmdb: true),
      );

      expect(find.text('Online Streaming'), findsNothing);
      expect(find.text('Gogoanime'), findsNothing);
    });

    testWidgets('torrent mode shows the torrent label and no extension pill',
        (tester) async {
      await tester.pumpWidget(
        _buildActionBar(
          showSourceSelector: true,
          isTmdb: false,
          currentTab: AnimeDetailTab.torrent,
        ),
      );

      expect(find.text('Torrent Streaming'), findsOneWidget);
      expect(find.text('Gogoanime'), findsNothing);
    });
  });
}
