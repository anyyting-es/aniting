import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/player/mpv_player_service.dart';
import 'package:seanime_app/core/preferences/player_gesture_provider.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/core/preferences/volume_boost_provider.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_bottom_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_gesture_overlay.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_top_bar.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/overlays/performance_stats_overlay.dart';
import 'package:seanime_app/presentation/widgets/player/overlays/seek_feedback_toast.dart';

/// The core visual viewport stack of the video player:
/// renders video frames, gesture detection, toasts, stats overlay,
/// skip chapter button, and animated top/bottom controls.
class PlayerViewport extends ConsumerWidget {
  final bool isUsingExoPlayer;
  final MpvPlayerService? mpvPlayerService;
  final PlayerFitMode fitMode;
  final String? selectedSubtitleTrackId;
  final String currentSubtitleText;

  // Controls visibility & state
  final bool areControlsVisible;
  final bool isTransitioningOrientation;
  final VoidCallback onToggleControls;

  // Playback control callbacks
  final VoidCallback onPlayOrPause;
  final void Function(int seconds) onSeekRelative;
  final void Function(Duration position) onSeekTo;
  final VoidCallback onToggleFullscreen;
  final bool isFullscreen;
  final bool isDesktop;

  // Volume & Brightness
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<bool>? onVolumeHoverChanged;
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  // Buffering & feedback
  final bool isBuffering;
  final bool isLoadingNextEpisode;
  final String? seekFeedback;
  final int seekFeedbackKey;
  final String? fallbackNotice;

  // Stats overlay
  final bool isStatsVisible;
  final ValueNotifier<PerformanceStats?> performanceStatsNotifier;
  final VoidCallback onCloseStats;

  // MKV Chapters
  final bool canSkipCurrentChapter;
  final PlayerChapter? activeChapter;
  final VoidCallback onSkipChapter;
  final List<PlayerChapter> chapters;

  // Top Bar info
  final String title;
  final String? episodeTitle;
  final String? videoSource;
  final String videoUrl;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback? onToggleSidePanel;
  final bool isSidePanelCollapsed;

  // Bottom Bar info
  final ValueNotifier<Duration> positionNotifier;
  final ValueNotifier<Duration> bufferNotifier;
  final Duration duration;
  final bool isPlaying;
  final bool hasNextEpisode;
  final VoidCallback? onNextEpisode;

  const PlayerViewport({
    super.key,
    required this.isUsingExoPlayer,
    required this.mpvPlayerService,
    required this.fitMode,
    required this.selectedSubtitleTrackId,
    this.currentSubtitleText = '',
    required this.areControlsVisible,
    required this.isTransitioningOrientation,
    required this.onToggleControls,
    required this.onPlayOrPause,
    required this.onSeekRelative,
    required this.onSeekTo,
    required this.onToggleFullscreen,
    required this.isFullscreen,
    required this.isDesktop,
    required this.volume,
    required this.onVolumeChanged,
    this.onVolumeHoverChanged,
    required this.brightness,
    required this.onBrightnessChanged,
    required this.isBuffering,
    this.isLoadingNextEpisode = false,
    required this.seekFeedback,
    required this.seekFeedbackKey,
    required this.fallbackNotice,
    required this.isStatsVisible,
    required this.performanceStatsNotifier,
    required this.onCloseStats,
    required this.canSkipCurrentChapter,
    required this.activeChapter,
    required this.onSkipChapter,
    required this.chapters,
    required this.title,
    required this.episodeTitle,
    required this.videoSource,
    required this.videoUrl,
    required this.onBack,
    required this.onOpenSettings,
    this.onToggleSidePanel,
    required this.isSidePanelCollapsed,
    required this.positionNotifier,
    required this.bufferNotifier,
    required this.duration,
    required this.isPlaying,
    required this.hasNextEpisode,
    this.onNextEpisode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final subStyle = ref.watch(subtitleStylePreferencesProvider);

    return ColoredBox(
      color: isUsingExoPlayer ? Colors.transparent : Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Viewport (Isolated on its own composited layer)
          Positioned.fill(
            child: (isUsingExoPlayer || isLoadingNextEpisode)
                ? const SizedBox.expand()
                : (mpvPlayerService != null
                    ? SizedBox.expand(
                        child: RepaintBoundary(
                          child: Video(
                            controller: mpvPlayerService!.videoController,
                            controls: NoVideoControls,
                            fit: fitMode.boxFit,
                            filterQuality: FilterQuality.low,
                            subtitleViewConfiguration: SubtitleViewConfiguration(
                              visible: selectedSubtitleTrackId != null &&
                                  selectedSubtitleTrackId != 'no' &&
                                  selectedSubtitleTrackId != 'none',
                              style: TextStyle(
                                height: 1.4,
                                fontFamily: subStyle.fontFamily == 'sans-serif' ? null : subStyle.fontFamily,
                                fontSize: 26.0 * subStyle.fontSizeMultiplier,
                                fontWeight: subStyle.bold ? FontWeight.bold : FontWeight.normal,
                                fontStyle: subStyle.italic ? FontStyle.italic : FontStyle.normal,
                                color: subStyle.textFlutterColor,
                                backgroundColor: subStyle.backgroundColor != 0 ? subStyle.bgFlutterColor : null,
                                shadows: const [
                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(1, 1)),
                                  Shadow(color: Colors.black, blurRadius: 4, offset: Offset(-1, -1)),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 32.0),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.expand()),
          ),

          // 2. Gesture Detection Overlay
          RepaintBoundary(
            child: PlayerGestureOverlay(
              gesturesEnabled: ref.watch(playerGesturesProvider),
              volumeBoostEnabled: ref.watch(volumeBoostProvider),
              onToggleControls: onToggleControls,
              onDoubleTapPlayPause: onPlayOrPause,
              onSeekBackward: () => onSeekRelative(-10),
              onSeekForward: () => onSeekRelative(10),
              onToggleFullscreen: onToggleFullscreen,
              volume: volume,
              onVolumeChanged: onVolumeChanged,
              brightness: brightness,
              onBrightnessChanged: onBrightnessChanged,
            ),
          ),

          // 3. Center Buffering / Next Episode Loading Indicator
          if (isBuffering || isLoadingNextEpisode)
            Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3.5,
              ),
            ),

          // 4. Seek Feedback Toast (+10s / -10s)
          if (seekFeedback != null && !isLoadingNextEpisode)
            SeekFeedbackToast(
              key: ValueKey('$seekFeedback$seekFeedbackKey'),
              text: seekFeedback!,
            ),

          // 5. Fallback Notification Toast
          if (fallbackNotice != null)
            Positioned(
              top: 60,
              left: 32,
              right: 32,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.6)),
                ),
                child: Row(
                  children: [
                    Icon(AppIcons.info(iconPack), color: primaryColor, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fallbackNotice!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Real-time Performance Stats Overlay
          if (isStatsVisible)
            PerformanceStatsOverlay(
              statsNotifier: performanceStatsNotifier,
              onClose: onCloseStats,
            ),

          // 7. Floating Skip Opening / Intro / Ending Button
          if (areControlsVisible && canSkipCurrentChapter && activeChapter != null)
            Positioned(
              bottom: 95,
              right: 20,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  elevation: 6,
                ),
                icon: Icon(AppIcons.fastForward(iconPack), size: 18),
                label: Text(
                  activeChapter!.localizedSkipButtonLabel(l10n),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: onSkipChapter,
              ),
            ),

          // 8. ExoPlayer Subtitles Overlay (for SRT / WebVTT / standard text cues)
          if (isUsingExoPlayer &&
              currentSubtitleText.isNotEmpty &&
              selectedSubtitleTrackId != null &&
              selectedSubtitleTrackId != 'no' &&
              selectedSubtitleTrackId != 'none')
            Positioned(
              left: 20,
              right: 20,
              bottom: areControlsVisible
                  ? (isFullscreen ? 96.0 : 56.0)
                  : (isFullscreen ? 36.0 : 18.0),
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: subStyle.bgFlutterColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentSubtitleText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: subStyle.textFlutterColor,
                        fontFamily: subStyle.fontFamily == 'sans-serif' ? null : subStyle.fontFamily,
                        fontSize: (isFullscreen ? 20.0 : 15.0) * subStyle.fontSizeMultiplier,
                        fontWeight: subStyle.bold ? FontWeight.bold : FontWeight.normal,
                        fontStyle: subStyle.italic ? FontStyle.italic : FontStyle.normal,
                        height: 1.3,
                        shadows: _buildViewportSubtitleShadows(subStyle),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 9. Modern Material Design 3 Controls Overlay
          RepaintBoundary(
            child: _ControlsOverlay(
              areControlsVisible: areControlsVisible,
              isTransitioningOrientation: isTransitioningOrientation,
              topBar: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.85),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.65, 1.0],
                      ),
                    ),
                    child: PlayerTopBar(
                      title: title,
                      episodeTitle: episodeTitle,
                      videoSource: videoSource,
                      videoUrl: videoUrl,
                      onBack: onBack,
                      onOpenSettings: onOpenSettings,
                      onToggleSidePanel: onToggleSidePanel,
                      isSidePanelCollapsed: isSidePanelCollapsed,
                      isFullscreen: isFullscreen,
                      showTitle: isFullscreen || (isDesktop && isSidePanelCollapsed),
                    ),
                  ),
                ),
              ),
              bottomBar: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RepaintBoundary(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.9),
                          Colors.black.withValues(alpha: 0.45),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                    child: PlayerBottomBar(
                      positionNotifier: positionNotifier,
                      duration: duration,
                      bufferNotifier: bufferNotifier,
                      isPlaying: isPlaying,
                      volume: volume,
                      chapters: chapters,
                      currentChapterTitle: activeChapter?.title,
                      onSeek: onSeekTo,
                      onPlayPause: onPlayOrPause,
                      onSeekBackward: () => onSeekRelative(-10),
                      onSeekForward: () => onSeekRelative(10),
                      onVolumeChanged: onVolumeChanged,
                      onVolumeHoverChanged: onVolumeHoverChanged,
                      onToggleFullscreen: onToggleFullscreen,
                      onNextEpisode: onNextEpisode,
                      isFullscreen: isFullscreen,
                      isDesktopOverride: isDesktop,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Shadow>? _buildViewportSubtitleShadows(SubtitleStylePrefs prefs) {
    final borderCol = prefs.borderFlutterColor;
    final bSize = prefs.borderSize;

    switch (prefs.borderStyle) {
      case SubtitleBorderStyle.none:
        return null;
      case SubtitleBorderStyle.outline:
        // Adding a subtle blurRadius softens discrete directional shadow steps into smooth anti-aliased outlines.
        final blur = math.max(1.0, bSize * 0.5);
        return [
          Shadow(offset: Offset(-bSize, -bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(bSize, -bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(-bSize, bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(bSize, bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(0, -bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(0, bSize), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(-bSize, 0), blurRadius: blur, color: borderCol),
          Shadow(offset: Offset(bSize, 0), blurRadius: blur, color: borderCol),
        ];
      case SubtitleBorderStyle.dropShadow:
        return [
          Shadow(offset: Offset(bSize, bSize), blurRadius: bSize * 1.5, color: borderCol),
        ];
      case SubtitleBorderStyle.raised:
        return [
          Shadow(offset: Offset(-bSize * 0.7, -bSize * 0.7), color: Colors.white54),
          Shadow(offset: Offset(bSize * 0.7, bSize * 0.7), color: borderCol),
        ];
      case SubtitleBorderStyle.depressed:
        return [
          Shadow(offset: Offset(bSize * 0.7, bSize * 0.7), color: Colors.white54),
          Shadow(offset: Offset(-bSize * 0.7, -bSize * 0.7), color: borderCol),
        ];
    }
  }
}

class _ControlsOverlay extends StatefulWidget {
  final bool areControlsVisible;
  final bool isTransitioningOrientation;
  final Widget topBar;
  final Widget bottomBar;

  const _ControlsOverlay({
    required this.areControlsVisible,
    required this.isTransitioningOrientation,
    required this.topBar,
    required this.bottomBar,
  });

  @override
  State<_ControlsOverlay> createState() => _ControlsOverlayState();
}

class _ControlsOverlayState extends State<_ControlsOverlay> {
  bool _controlsMounted = true;

  @override
  void initState() {
    super.initState();
    _controlsMounted = widget.areControlsVisible;
  }

  @override
  void didUpdateWidget(_ControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.areControlsVisible && !oldWidget.areControlsVisible) {
      _controlsMounted = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: (widget.areControlsVisible && !widget.isTransitioningOrientation) ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      onEnd: () {
        if (!widget.areControlsVisible && mounted) {
          setState(() => _controlsMounted = false);
        }
      },
      child: IgnorePointer(
        ignoring: !widget.areControlsVisible || widget.isTransitioningOrientation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_controlsMounted) widget.topBar,
            if (_controlsMounted) widget.bottomBar,
          ],
        ),
      ),
    );
  }
}
