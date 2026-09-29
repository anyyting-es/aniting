import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_top_bar.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/player_settings_sheet.dart';

void main() {
  group('TorrentStreamStatus Model Tests', () {
    test('parses from JSON correctly', () {
      final json = {
        'uploadProgress': 500000,
        'downloadProgress': 524288000,
        'progressPercentage': 50.0,
        'downloadSpeed': '4.5 MB/s',
        'uploadSpeed': '250 KB/s',
        'size': '1.0 GB',
        'seeders': 24,
      };

      final status = TorrentStreamStatus.fromJson(json);

      expect(status.uploadProgress, 500000);
      expect(status.downloadProgress, 524288000);
      expect(status.progressPercentage, 50.0);
      expect(status.downloadSpeed, '4.5 MB/s');
      expect(status.uploadSpeed, '250 KB/s');
      expect(status.size, '1.0 GB');
      expect(status.seeders, 24);
      expect(status.isComplete, isFalse);
      expect(status.formattedDownloaded, contains('500'));
    });

    test('calculates ETA properly based on speed and remaining bytes', () {
      // 50% of 1GB downloaded (500MB left) at 5 MB/s -> ~100s -> 1m 40s
      final status = TorrentStreamStatus(
        downloadProgress: 524288000, // 500MB
        progressPercentage: 50.0,
        downloadSpeed: '5 MB/s',
        size: '1.0 GB',
      );

      final eta = status.etaString;
      expect(eta, contains('m'));
      expect(eta, contains('s'));
    });

    test('returns "Completado" when progress is 100%', () {
      const status = TorrentStreamStatus(
        downloadProgress: 1048576000,
        progressPercentage: 100.0,
        downloadSpeed: '0 B/s',
        size: '1.0 GB',
      );

      expect(status.isComplete, isTrue);
      expect(status.etaString, 'Completado');
    });

    test('returns "--" when download speed is 0 or empty', () {
      const status = TorrentStreamStatus(
        downloadProgress: 1000,
        progressPercentage: 10.0,
        downloadSpeed: '',
      );

      expect(status.etaString, '--');
    });
  });

  group('PlayerTopBar Floating Torrent Indicators Tests', () {
    testWidgets('shows floating minimal icons on top bar when enabled', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const testStatus = TorrentStreamStatus(
        downloadProgress: 524288000,
        progressPercentage: 65.4,
        downloadSpeed: '4.2 MB/s',
        uploadSpeed: '180 KB/s',
        size: '1.1 GB',
        seeders: 22,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            torrentStreamStatusProvider.overrideWith(
              () => _FakeTorrentStatusNotifier(testStatus),
            ),
            torrentProgressOverlayEnabledProvider.overrideWith(
              () => _FakeOverlayEnabledNotifier(true),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Frieren: Beyond Journey\'s End',
                episodeTitle: 'The End of the Journey',
                videoSource: 'Torrent • [SubsPlease] Frieren - 01 (1080p).mkv',
                videoUrl: 'http://127.0.0.1:43211/api/v1/torrentstream/stream/video.mkv',
                onBack: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      // Verify floating indicator values on the top bar
      expect(find.text('4.2 MB/s'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.textContaining('65%'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
      expect(find.byIcon(Icons.people_outline_rounded), findsOneWidget);
    });

    testWidgets('hides floating indicators when disabled', (tester) async {
      const testStatus = TorrentStreamStatus(
        downloadProgress: 524288000,
        progressPercentage: 65.4,
        downloadSpeed: '4.2 MB/s',
        uploadSpeed: '180 KB/s',
        size: '1.1 GB',
        seeders: 22,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            torrentStreamStatusProvider.overrideWith(
              () => _FakeTorrentStatusNotifier(testStatus),
            ),
            torrentProgressOverlayEnabledProvider.overrideWith(
              () => _FakeOverlayEnabledNotifier(false),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Frieren: Beyond Journey\'s End',
                episodeTitle: 'The End of the Journey',
                videoSource: 'Torrent • [SubsPlease] Frieren - 01 (1080p).mkv',
                videoUrl: 'http://127.0.0.1:43211/api/v1/torrentstream/stream/video.mkv',
                onBack: () {},
                onOpenSettings: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('4.2 MB/s'), findsNothing);
      expect(find.text('22'), findsNothing);
    });
  });

  group('PlayerSettingsSheet Dedicated Torrent Section Tests', () {
    testWidgets('navigates to torrent section and toggles visibility and displays metrics', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      bool torrentProgressToggled = false;
      bool currentVal = false;

      const testStatus = TorrentStreamStatus(
        downloadProgress: 600000000,
        progressPercentage: 62.0,
        downloadSpeed: '5.2 MB/s',
        uploadSpeed: '80 KB/s',
        size: '1.2 GB',
        seeders: 15,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            torrentStreamStatusProvider.overrideWith(
              () => _FakeTorrentStatusNotifier(testStatus),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerSettingsSheet(
                videoSource: 'Torrent • [SubsPlease] Frieren - 01 (1080p).mkv',
                videoUrl: 'http://127.0.0.1:43211/api/v1/torrentstream/stream/video.mkv',
                isTorrentProgressVisible: false,
                onTorrentProgressVisibilityChanged: (val) {
                  torrentProgressToggled = true;
                  currentVal = val;
                },
                chapters: const [],
                onChapterSelected: (_) {},
                audioTracks: const [
                  UiTrack(
                    id: '1',
                    index: 0,
                    title: 'Japanese',
                    language: 'ja',
                    selected: true,
                  ),
                ],
                subtitleTracks: const [
                  UiTrack(
                    id: '1',
                    index: 0,
                    title: 'Spanish',
                    language: 'es',
                    selected: true,
                  ),
                ],
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: '1',
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
              ),
            ),
          ),
        ),
      );

      // Progreso del Torrent item should be rendered in the main menu with a chevron
      expect(find.text('Progreso del Torrent'), findsOneWidget);
      expect(find.text('Desactivado'), findsWidgets);

      // Tap on the torrent item to enter its dedicated section
      await tester.tap(find.text('Progreso del Torrent'));
      await tester.pumpAndSettle();

      // Now inside the section: verify header and live metrics
      expect(find.text('Progreso del Torrent'), findsWidgets);
      expect(find.text('62.0%'), findsOneWidget);
      expect(find.text('5.2 MB/s'), findsOneWidget);
      expect(find.text('80 KB/s'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Tap the toggle switch inside the section to activate
      await tester.tap(find.byIcon(Icons.remove_red_eye_outlined));
      await tester.pumpAndSettle();

      expect(torrentProgressToggled, isTrue);
      expect(currentVal, isTrue);

      // Tap back button to return to main menu
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      // Back in main menu: shows Ajustes header
      expect(find.text('Ajustes'), findsOneWidget);
    });

    testWidgets('hides Progreso del Torrent when videoSource is not torrent', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PlayerSettingsSheet(
                videoSource: 'Hianime • HD-1',
                videoUrl: 'https://cdn.example.com/hls/ep1/master.m3u8',
                chapters: const [],
                onChapterSelected: (_) {},
                audioTracks: const [
                  UiTrack(
                    id: '1',
                    index: 0,
                    title: 'Japanese',
                    language: 'ja',
                    selected: true,
                  ),
                ],
                subtitleTracks: const [
                  UiTrack(
                    id: '1',
                    index: 0,
                    title: 'Spanish',
                    language: 'es',
                    selected: true,
                  ),
                ],
                selectedAudioTrackId: '1',
                selectedSubtitleTrackId: '1',
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
              ),
            ),
          ),
        ),
      );

      // For online streams, torrent progress should not be shown
      expect(find.text('Progreso del Torrent'), findsNothing);
    });
  });
}

class _FakeTorrentStatusNotifier extends TorrentStreamStatusNotifier {
  final TorrentStreamStatus? initial;
  _FakeTorrentStatusNotifier(this.initial);

  @override
  TorrentStreamStatus? build() => initial;
}

class _FakeOverlayEnabledNotifier extends TorrentProgressOverlayEnabledNotifier {
  final bool initial;
  _FakeOverlayEnabledNotifier(this.initial);

  @override
  bool build() => initial;
}
