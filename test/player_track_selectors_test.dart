import 'package:g1455/g1455.dart';
import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/i18n/translations/en.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/presentation/widgets/player/controls/player_bottom_bar.dart';
import 'package:aniting/presentation/widgets/player/controls/player_track_selectors.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';

void main() {
  group('PlayerBottomBar Desktop Track Selectors', () {
    final testAudioTracks = [
      UiTrack(id: '1', title: 'Japanese (FLAC 2.0)', language: 'ja', index: 0, selected: true),
      UiTrack(id: '2', title: 'English (AAC 2.0)', language: 'en', index: 1, selected: false),
    ];

    final testSubtitleTracks = [
      UiTrack(id: 'sub_1', title: 'Spanish (Full)', language: 'es', index: 0, selected: true),
      UiTrack(id: 'sub_2', title: 'English', language: 'en', index: 1, selected: false),
    ];

    testWidgets('Desktop layout renders subtitle and audio buttons to the left of fullscreen', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => GlassHost(child: child!),
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 10)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isDesktopOverride: true,
                audioTracks: testAudioTracks,
                subtitleTracks: testSubtitleTracks,
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: 'sub_1',
                onAudioTrackSelected: (_) {},
                onSubtitleTrackSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      // Verify PlayerSubtitleMenuButton and PlayerAudioMenuButton exist
      expect(find.byType(PlayerSubtitleMenuButton), findsOneWidget);
      expect(find.byType(PlayerAudioMenuButton), findsOneWidget);

      // Verify position relative to fullscreen: Subtitle and Audio are to the left of fullscreen
      final subOffset = tester.getTopLeft(find.byType(PlayerSubtitleMenuButton));
      final audioOffset = tester.getTopLeft(find.byType(PlayerAudioMenuButton));
      final fullscreenFinder = find.byWidgetPredicate(
        (w) => w is IconButton && (w.tooltip?.contains('(F)') ?? false),
      );
      expect(fullscreenFinder, findsOneWidget);
      final fullscreenOffset = tester.getTopLeft(fullscreenFinder);

      expect(subOffset.dx, lessThan(audioOffset.dx));
      expect(audioOffset.dx, lessThan(fullscreenOffset.dx));
    });

    testWidgets('Mobile layout does NOT render desktop subtitle and audio buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => GlassHost(child: child!),
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 10)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isDesktopOverride: false, // Mobile!
                isFullscreen: false,
                audioTracks: testAudioTracks,
                subtitleTracks: testSubtitleTracks,
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: 'sub_1',
                onAudioTrackSelected: (_) {},
                onSubtitleTrackSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PlayerSubtitleMenuButton), findsNothing);
      expect(find.byType(PlayerAudioMenuButton), findsNothing);
    });

    testWidgets('Tapping audio button opens menu and selecting a track calls callback', (tester) async {
      UiTrack? selectedAudio;
      bool menuOpen = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => GlassHost(child: child!),
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 10)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isDesktopOverride: true,
                audioTracks: testAudioTracks,
                subtitleTracks: testSubtitleTracks,
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: 'sub_1',
                onAudioTrackSelected: (t) => selectedAudio = t,
                onSubtitleTrackSelected: (_) {},
                onMenuOpenChanged: (open) => menuOpen = open,
              ),
            ),
          ),
        ),
      );

      // Tap audio button
      await tester.tap(find.byType(PlayerAudioMenuButton));
      await tester.pumpAndSettle();

      expect(menuOpen, isTrue);
      expect(find.text('English (AAC 2.0) • en'), findsOneWidget);

      // Select English track
      await tester.tap(find.text('English (AAC 2.0) • en'));
      await tester.pumpAndSettle();

      expect(selectedAudio?.id, equals('2'));
    });

    testWidgets('Tapping subtitle button opens menu and selecting disable subtitles calls callback with null', (tester) async {
      UiTrack? selectedSub = testSubtitleTracks.first;
      bool calledWithNull = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            builder: (context, child) => GlassHost(child: child!),
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5)),
                duration: const Duration(minutes: 24),
                bufferNotifier: ValueNotifier(const Duration(minutes: 10)),
                isPlaying: true,
                volume: 80,
                onSeek: (_) {},
                onPlayPause: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isDesktopOverride: true,
                audioTracks: testAudioTracks,
                subtitleTracks: testSubtitleTracks,
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: 'sub_1',
                onAudioTrackSelected: (_) {},
                onSubtitleTrackSelected: (t) {
                  selectedSub = t;
                  if (t == null) calledWithNull = true;
                },
              ),
            ),
          ),
        ),
      );

      // Tap subtitle button
      await tester.tap(find.byType(PlayerSubtitleMenuButton));
      await tester.pumpAndSettle();

      // Find "Disable subtitles" option (by block icon or menuItem)
      final disableFinder = find.byIcon(Icons.block);
      expect(disableFinder, findsOneWidget);

      await tester.tap(disableFinder);
      await tester.pumpAndSettle();

      expect(calledWithNull, isTrue);
      expect(selectedSub, isNull);
    });

    testWidgets('Scrolling inside PlayerInVideoTrackPanel isolates scroll and does not scroll parent Scrollable', (tester) async {
      final parentScrollController = ScrollController();

      await tester.pumpWidget(
        MaterialApp(
            builder: (context, child) => GlassHost(child: child!),
            home: Scaffold(
            body: SingleChildScrollView(
              controller: parentScrollController,
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  PlayerInVideoTrackPanel(
                    title: 'Subtitles',
                    titleIcon: Icons.subtitles_rounded,
                    onClose: () {},
                    tracks: testSubtitleTracks,
                    selectedTrackId: 'sub_1',
                    onTrackSelected: (_) {},
                    iconPack: AppIconPack.lucide,
                  ),
                  const SizedBox(height: 2000),
                ],
              ),
            ),
          ),
        ),
      );

      expect(parentScrollController.offset, 0.0);

      // Scroll mouse wheel over PlayerInVideoTrackPanel
      final panelLocation = tester.getCenter(find.byType(PlayerInVideoTrackPanel));
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: panelLocation,
          scrollDelta: const Offset(0, 100),
        ),
      );
      await tester.pumpAndSettle();

      // Parent scroll offset MUST stay 0.0 (no scroll leakage!)
      expect(parentScrollController.offset, 0.0);
    });
  });
}
