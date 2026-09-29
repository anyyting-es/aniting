import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_bottom_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_top_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/timeline_slider.dart';

class _MockMaterialIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.material;
}

class _MockLucideIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.lucide;
}

void main() {
  group('PlayerBottomBar Icon Sizing and Relative Dimensions', () {
    testWidgets('Material icons on PC desktop have scaled dimensions with preserved deltas and reduced padding', (tester) async {
      bool playPaused = false;
      bool nextEpisodeCalled = false;
      bool fullscreenToggled = false;
      double currentVolume = 75.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconPackProvider.overrideWith(() => _MockMaterialIconPackNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 10, seconds: 0)),
                duration: const Duration(minutes: 24, seconds: 0),
                bufferNotifier: ValueNotifier(const Duration(minutes: 15, seconds: 0)),
                isPlaying: true,
                volume: currentVolume,
                onSeek: (_) {},
                onPlayPause: () => playPaused = true,
                onNextEpisode: () => nextEpisodeCalled = true,
                onVolumeChanged: (v) => currentVolume = v,
                onToggleFullscreen: () => fullscreenToggled = true,
                isDesktopOverride: true,
              ),
            ),
          ),
        ),
      );

      // Verify Play/Pause icon (Icons.pause_rounded) is sized to 32
      final pauseIconFinder = find.byIcon(Icons.pause_rounded);
      expect(pauseIconFinder, findsOneWidget);
      final Icon pauseIcon = tester.widget(pauseIconFinder);
      expect(pauseIcon.size, equals(32.0));

      // Verify Skip Next icon (Icons.skip_next_rounded) is sized to 34 (preserving +2 delta)
      final skipNextFinder = find.byIcon(Icons.skip_next_rounded);
      expect(skipNextFinder, findsOneWidget);
      final Icon skipNextIcon = tester.widget(skipNextFinder);
      expect(skipNextIcon.size, equals(34.0));

      // Verify Fullscreen icon (Icons.fullscreen_rounded) is sized to 32 (equal to play/pause)
      final fullscreenFinder = find.byIcon(Icons.fullscreen_rounded);
      expect(fullscreenFinder, findsOneWidget);
      final Icon fullscreenIcon = tester.widget(fullscreenFinder);
      expect(fullscreenIcon.size, equals(32.0));

      // Verify Volume icon (Icons.volume_up_rounded) is sized to 28 (preserving -4 delta)
      final volumeFinder = find.byIcon(Icons.volume_up_rounded);
      expect(volumeFinder, findsOneWidget);
      final Icon volumeIcon = tester.widget(volumeFinder);
      expect(volumeIcon.size, equals(28.0));

      // Verify mathematical delta preservation:
      // skipNext - playPause == 2
      // playPause - volume == 4
      // playPause == fullscreen
      expect(skipNextIcon.size! - pauseIcon.size!, equals(2.0));
      expect(pauseIcon.size! - volumeIcon.size!, equals(4.0));
      expect(pauseIcon.size!, equals(fullscreenIcon.size!));

      // Verify reduced padding on IconButtons (all(2))
      final iconButtons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      for (final btn in iconButtons) {
        expect(btn.style?.padding?.resolve({}), equals(const EdgeInsets.all(2)));
      }

      // Verify interactions work
      await tester.tap(pauseIconFinder);
      expect(playPaused, isTrue);

      await tester.tap(skipNextFinder);
      expect(nextEpisodeCalled, isTrue);

      await tester.tap(fullscreenFinder);
      expect(fullscreenToggled, isTrue);
    });

    testWidgets('Lucide icons on PC desktop have scaled dimensions with preserved deltas', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconPackProvider.overrideWith(() => _MockLucideIconPackNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerBottomBar(
                positionNotifier: ValueNotifier(const Duration(minutes: 10, seconds: 0)),
                duration: const Duration(minutes: 24, seconds: 0),
                bufferNotifier: ValueNotifier(const Duration(minutes: 15, seconds: 0)),
                isPlaying: false,
                volume: 85.0,
                onSeek: (_) {},
                onPlayPause: () {},
                onNextEpisode: () {},
                onVolumeChanged: (_) {},
                onToggleFullscreen: () {},
                isDesktopOverride: true,
              ),
            ),
          ),
        ),
      );

      // Play icon in Lucide
      final playIconFinder = find.byIcon(AppIcons.play(AppIconPack.lucide));
      expect(playIconFinder, findsOneWidget);
      final Icon playIcon = tester.widget(playIconFinder);
      expect(playIcon.size, equals(28.0));

      // Skip next icon in Lucide
      final skipNextFinder = find.byIcon(AppIcons.skipNext(AppIconPack.lucide));
      expect(skipNextFinder, findsOneWidget);
      final Icon skipNextIcon = tester.widget(skipNextFinder);
      expect(skipNextIcon.size, equals(26.0));

      // Fullscreen icon in Lucide
      final fullscreenFinder = find.byIcon(AppIcons.fullscreen(AppIconPack.lucide));
      expect(fullscreenFinder, findsOneWidget);
      final Icon fullscreenIcon = tester.widget(fullscreenFinder);
      expect(fullscreenIcon.size, equals(27.0));

      // Volume icon in Lucide
      final volumeFinder = find.byIcon(AppIcons.volume(AppIconPack.lucide));
      expect(volumeFinder, findsOneWidget);
      final Icon volumeIcon = tester.widget(volumeFinder);
      expect(volumeIcon.size, equals(23.0));
    });

    testWidgets('TimelineSlider has 6dp track height and black background track', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TimelineSlider(
              position: const Duration(minutes: 5),
              duration: const Duration(minutes: 24),
              buffer: const Duration(minutes: 10),
              onSeek: (_) {},
            ),
          ),
        ),
      );

      // Verify SliderTheme trackHeight is 6
      final sliderThemeFinder = find.byType(SliderTheme);
      expect(sliderThemeFinder, findsOneWidget);
      final SliderTheme sliderTheme = tester.widget(sliderThemeFinder);
      expect(sliderTheme.data.trackHeight, equals(6.0));

      // Verify thumb radius is 7
      final thumbShape = sliderTheme.data.thumbShape as RoundSliderThumbShape;
      expect(thumbShape.enabledThumbRadius, equals(7.0));
    });

    testWidgets('PlayerTopBar icons have harmonized sizes and reduced padding', (tester) async {
      bool backed = false;
      bool settingsOpened = false;
      bool sidebarToggled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            iconPackProvider.overrideWith(() => _MockMaterialIconPackNotifier()),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlayerTopBar(
                title: 'Sousou no Frieren',
                episodeTitle: 'Episodio 1',
                onBack: () => backed = true,
                onOpenSettings: () => settingsOpened = true,
                onToggleSidePanel: () => sidebarToggled = true,
                isFullscreen: true,
              ),
            ),
          ),
        ),
      );

      // Back icon
      final backIconFinder = find.byIcon(Icons.arrow_back_rounded);
      expect(backIconFinder, findsOneWidget);
      final Icon backIcon = tester.widget(backIconFinder);
      expect(backIcon.size, equals(30.0));

      // Settings icon
      final settingsIconFinder = find.byIcon(Icons.settings_rounded);
      expect(settingsIconFinder, findsOneWidget);
      final Icon settingsIcon = tester.widget(settingsIconFinder);
      expect(settingsIcon.size, equals(29.0));

      // Sidebar icon
      final sidebarIconFinder = find.byIcon(Icons.view_sidebar_rounded);
      expect(sidebarIconFinder, findsOneWidget);
      final Icon sidebarIcon = tester.widget(sidebarIconFinder);
      expect(sidebarIcon.size, equals(28.0));

      // Verify buttons have compact padding (all(2))
      final iconButtons = tester.widgetList<IconButton>(find.byType(IconButton)).toList();
      for (final btn in iconButtons) {
        expect(btn.style?.padding?.resolve({}), equals(const EdgeInsets.all(2)));
      }

      await tester.tap(backIconFinder);
      expect(backed, isTrue);

      await tester.tap(settingsIconFinder);
      expect(settingsOpened, isTrue);

      await tester.tap(sidebarIconFinder);
      expect(sidebarToggled, isTrue);
    });
  });
}
