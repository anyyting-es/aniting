import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_bottom_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_gesture_overlay.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_top_bar.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/overlays/performance_stats_overlay.dart';
import 'package:seanime_app/presentation/widgets/player/overlays/seek_feedback_toast.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/player_settings_sheet.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector_sheet.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';

void main() {
  group('Player UI Components Tests', () {
    testWidgets('SeekFeedbackToast displays correct icon and label', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SeekFeedbackToast(text: '+10 s'),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.byIcon(Icons.fast_forward_rounded), findsOneWidget);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SeekFeedbackToast(text: '-10 s'),
          ),
        ),
      );

      expect(find.text('10'), findsOneWidget);
      expect(find.byIcon(Icons.fast_rewind_rounded), findsOneWidget);
    });

    testWidgets('PerformanceStatsOverlay displays metrics and triggers onClose', (tester) async {
      bool closed = false;
      const stats = PerformanceStats(
        engine: 'libmpv',
        videoCodec: 'h264',
        resolution: '1920x1080',
        fps: 23.98,
        hwdec: 'auto-safe',
        audioCodec: 'aac',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  PerformanceStatsOverlay(
                    statsNotifier: ValueNotifier<PerformanceStats?>(stats),
                    onClose: () => closed = true,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Stats de Reproducción'), findsOneWidget);
      expect(find.text('libmpv'), findsOneWidget);
      expect(find.text('h264'), findsOneWidget);
      expect(find.text('1920x1080'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closed, isTrue);
    });

    testWidgets('PlayerTopBar renders title and settings trigger without center buttons', (tester) async {
      bool backed = false;
      bool settingsOpened = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Sousou no Frieren',
                episodeTitle: 'Episodio 1: El fin del viaje',
                onBack: () => backed = true,
                onOpenSettings: () => settingsOpened = true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Sousou no Frieren'), findsOneWidget);
      expect(find.text('Episodio 1: El fin del viaje'), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      expect(backed, isTrue);

      await tester.tap(find.byIcon(Icons.settings_outlined));
      expect(settingsOpened, isTrue);
    });

    testWidgets('PlayerSettingsSheet renders Fuente and opens source details', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    PlayerSettingsSheet.show(
                      context: context,
                      chapters: const [],
                      currentPosition: Duration.zero,
                      onChapterSelected: (_) {},
                      audioTracks: const [],
                      subtitleTracks: const [],
                      selectedAudioTrackId: null,
                      selectedSubtitleTrackId: null,
                      onAudioTrackSelected: (_) {},
                      onSubtitleTrackSelected: (_) {},
                      subtitleDelayMs: 0,
                      onSubtitleDelayChanged: (_) {},
                      audioDelayMs: 0,
                      onAudioDelayChanged: (_) {},
                      playbackRate: 1.0,
                      onPlaybackRateChanged: (_) {},
                      activeShaderPreset: ShaderPreset.none,
                      onShaderPresetSelected: (_) {},
                      isStatsVisible: false,
                      onStatsVisibilityChanged: (_) {},
                      fitMode: PlayerFitMode.contain,
                      onFitModeChanged: (_) {},
                      isUsingExoPlayer: true,
                      videoSource: 'AnimePahe • Kwik (1080p)',
                      videoUrl: 'https://example.com/video.mp4',
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('Fuente'), 100);
      await tester.pumpAndSettle();

      expect(find.text('Fuente'), findsOneWidget);
      expect(find.text('AnimePahe • Kwik (1080p)'), findsOneWidget);

      // Tap Fuente item to open sub-screen
      await tester.tap(find.text('Fuente'));
      await tester.pumpAndSettle();

      expect(find.text('Fuente de Video'), findsOneWidget);
      expect(find.text('Transmisión Online'), findsOneWidget);
      expect(find.text('https://example.com/video.mp4'), findsOneWidget);
      expect(find.text('Copiar enlace'), findsOneWidget);
      expect(find.text('ExoPlayer'), findsOneWidget);
    });

    testWidgets('PlayerBottomBar renders playback controls and fullscreen toggle', (tester) async {
      bool playPaused = false;
      bool toggledFullscreen = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 5, seconds: 30)),
                duration: const Duration(minutes: 24, seconds: 0),
                bufferNotifier: ValueNotifier(const Duration(minutes: 8, seconds: 0)),
                isPlaying: true,
                volume: 85.0,
                onSeek: (_) {},
                onPlayPause: () => playPaused = true,
                onSeekBackward: () {},
                onSeekForward: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () => toggledFullscreen = true,
                currentChapterTitle: 'Opening: Yuusha',
                isDesktopOverride: true,
              ),
            ),
          ),
        ),
      );

      // Play/pause button (shows pause icon when playing)
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.pause_rounded));
      expect(playPaused, isTrue);

      // Time display (normal text) and Chapter title
      expect(find.text('05:30 / 24:00'), findsOneWidget);
      expect(find.text('• Opening: Yuusha'), findsOneWidget);

      // Fullscreen button
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      expect(toggledFullscreen, isTrue);
    });

    testWidgets('PlayerSettingsSheet unified slide-in modal navigation and chapters support', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      ShaderPreset selectedPreset = ShaderPreset.none;
      int subDelay = 0;
      bool statsVisible = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () {
                    PlayerSettingsSheet.show(
                      context: ctx,
                      chapters: const [
                        PlayerChapter(index: 0, title: 'Intro', start: Duration.zero, end: Duration(seconds: 90)),
                        PlayerChapter(index: 1, title: 'Opening', start: Duration(seconds: 90), end: Duration(seconds: 180)),
                      ],
                      onChapterSelected: (_) {},
                      audioTracks: const [
                        UiTrack(id: '1', index: 0, title: 'Japonés', language: 'ja', selected: true),
                        UiTrack(id: '2', index: 1, title: 'Español', language: 'es', selected: false),
                      ],
                      subtitleTracks: const [
                        UiTrack(id: '1', index: 0, title: 'Español [Full ASS]', language: 'es', selected: true),
                      ],
                      selectedAudioTrackId: '1',
                      selectedSubtitleTrackId: '1',
                      onAudioTrackSelected: (_) {},
                      onSubtitleTrackSelected: (_) {},
                      subtitleDelayMs: subDelay,
                      onSubtitleDelayChanged: (v) => subDelay = v,
                      audioDelayMs: 0,
                      onAudioDelayChanged: (_) {},
                      playbackRate: 1.0,
                      onPlaybackRateChanged: (_) {},
                      activeShaderPreset: selectedPreset,
                      onShaderPresetSelected: (p) => selectedPreset = p,
                      isStatsVisible: statsVisible,
                      onStatsVisibilityChanged: (v) => statsVisible = v,
                      fitMode: PlayerFitMode.contain,
                      onFitModeChanged: (_) {},
                      isUsingExoPlayer: false,
                    );
                  },
                  child: const Text('Open Settings'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open settings modal
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      // Main menu items
      expect(find.text('Ajustes'), findsOneWidget);
      expect(find.text('Capítulos'), findsOneWidget);
      expect(find.text('Pistas de Audio'), findsOneWidget);
      expect(find.text('Subtítulos'), findsOneWidget);
      expect(find.text('Sync de Subtítulos'), findsOneWidget);
      expect(find.text('Sync de Audio'), findsOneWidget);
      expect(find.text('Velocidad'), findsOneWidget);
      expect(find.text('Shaders GLSL'), findsOneWidget);
      expect(find.text('Gestos en pantalla'), findsOneWidget);
      expect(find.text('Stats en pantalla'), findsOneWidget);
      expect(find.text('Ajuste de Pantalla'), findsOneWidget);

      // Verify Shaders default to Desactivado
      expect(find.text('Desactivado'), findsWidgets);

      // Test stats toggle (tap row)
      await tester.tap(find.text('Stats en pantalla'));
      await tester.pumpAndSettle();
      expect(statsVisible, isTrue);

      // Navigate to Shaders subview
      await tester.tap(find.text('Shaders GLSL'));
      await tester.pumpAndSettle();

      expect(find.text('Shaders GLSL'), findsWidgets);
      expect(find.text('Anime4K - Modo A'), findsOneWidget);
      expect(find.text('NVScaler'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget); // Badge on Desactivado

      // Select Anime4K
      await tester.tap(find.text('Anime4K - Modo A'));
      await tester.pumpAndSettle();
      expect(selectedPreset.id, 'anime4k_mode_a');

      // Return to main menu via Back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Navigate to Sync de Subtítulos
      await tester.tap(find.text('Sync de Subtítulos'));
      await tester.pumpAndSettle();

      expect(find.text('Sincronización de Subtítulos'), findsOneWidget);
      expect(find.text('0 ms (Sincronizado)'), findsOneWidget);
      expect(find.text('+50ms'), findsOneWidget);

      // Tap +50ms
      await tester.tap(find.text('+50ms'));
      expect(subDelay, 50);

      // Return to main menu via Back button
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Ajustes'), findsOneWidget);
    });

    test('TorrentStreamLaunchInfo holds launch parameters correctly', () {
      bool disposed = false;
      final info = TorrentStreamLaunchInfo(
        mediaId: 101,
        videoUrl: 'http://localhost:43211/stream/video.mkv',
        title: 'Frieren',
        episodeTitle: 'The End of the Journey',
        episodeNumber: 1,
        videoSource: 'Torrent • [SubsPlease] Frieren - 01.mkv',
        onDispose: () => disposed = true,
      );

      expect(info.mediaId, 101);
      expect(info.videoUrl, 'http://localhost:43211/stream/video.mkv');
      expect(info.title, 'Frieren');
      expect(info.episodeTitle, 'The End of the Journey');
      expect(info.episodeNumber, 1);
      expect(info.videoSource, 'Torrent • [SubsPlease] Frieren - 01.mkv');
      info.onDispose();
      expect(disposed, isTrue);
    });

    testWidgets('PlayerGestureOverlay triggers play/pause on click on desktop', (tester) async {
      bool playPaused = false;
      bool fullscreenToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              height: 600,
              child: PlayerGestureOverlay(
                gesturesEnabled: true,
                onToggleControls: () {},
                onDoubleTapPlayPause: () => playPaused = true,
                onSeekBackward: () {},
                onSeekForward: () {},
                onToggleFullscreen: () => fullscreenToggled = true,
                volume: 80,
                onVolumeChanged: (_) {},
                brightness: 0.5,
                onBrightnessChanged: (_) {},
                isDesktopOverride: true,
              ),
            ),
          ),
        ),
      );

      // Single tap on center zone triggers play/pause on desktop after double-tap window expires
      await tester.tap(find.byType(PlayerGestureOverlay));
      await tester.pump(const Duration(milliseconds: 350));
      expect(playPaused, isTrue);

      // Double tap triggers fullscreen on desktop
      await tester.tap(find.byType(PlayerGestureOverlay));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(PlayerGestureOverlay));
      await tester.pump(const Duration(milliseconds: 350));
      expect(fullscreenToggled, isTrue);
    });

    testWidgets('PlayerInfoPanel does not show next episode for movies even if AniZip has specials', (tester) async {
      final movieDetails = AnimeDetails(
        id: 20954,
        title: 'A Silent Voice',
        format: 'MOVIE',
        totalEpisodes: 1,
      );

      final movieAniZip = AniZipData.fromJson({
        'episodes': {
          '1': {
            'episode': '1',
            'length': 130,
            'title': {'en': 'Complete Movie'},
          },
          'S2': {
            'episode': 'S2',
            'length': 2,
            'title': {'en': 'Speed of Youth'},
          },
        },
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 800,
                child: PlayerInfoPanel(
                  animeTitle: 'A Silent Voice',
                  episodeNumber: 1,
                  episodeTitle: 'Complete Movie',
                  animeDetails: movieDetails,
                  aniZipData: movieAniZip,
                  chapters: const [],
                  onSeekToChapter: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify that "Película" is displayed instead of "EP 1 • Complete Movie"
      expect(find.text('Película'), findsOneWidget);
      expect(find.textContaining('EP 1'), findsNothing);

      // Verify that "Siguiente episodio" is NOT displayed
      expect(find.text('Siguiente episodio'), findsNothing);

      // Verify that special "Speed of Youth" is NOT displayed as next episode
      expect(find.text('Speed of Youth'), findsNothing);
    });
  });
}
