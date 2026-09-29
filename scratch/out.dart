import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/player/mpv_player_service.dart';
import 'package:seanime_app/core/preferences/player_gesture_provider.dart';
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
class PlayerViewport extends ConsumerStatefulWidget {
  @override
  ConsumerState<PlayerViewport> createState() => _PlayerViewportState();
}

class _PlayerViewportState extends ConsumerState<PlayerViewport> {
  final bool isUsingExoPlayer;
  final MpvPlayerService? mpvPlayerService;
  final PlayerFitMode fitMode;
  final String? selectedSubtitleTrackId;

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
  final double brightness;
  final ValueChanged<double> onBrightnessChanged;

  // Buffering & feedback
  final bool isBuffering;
  final String? seekFeedback;
  final int seekFeedbackKey;
  final String? fallbackNotice;

  // Stats overlay
  final bool isStatsVisible;
  final PerformanceStats performanceStats;
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
    required this.brightness,
    required this.onBrightnessChanged,
    required this.isBuffering,
    required this.seekFeedback,
    required this.seekFeedbackKey,
    required this.fallbackNotice,
    required this.isStatsVisible,
    required this.performanceStats,
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
  
  bool _controlsMounted = true;

  @override
  void initState() {
    super.initState();
    _controlsMounted = widget.areControlsVisible;
  }

  @override
  void didUpdateWidget(PlayerViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.areControlsVisible && !oldWidget.areControlsVisible) {
      setState(() => _controlsMounted = true);
    }
  }

Widget build(BuildContext context) {
    final ref = this.ref;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return ColoredBox(
      color: widget.isUsingExoPlayer ? Colors.transparent : Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Viewport (Isolated on its own composited layer)
          Positioned.fill(
            child: widget.isUsingExoPlayer
                ? const SizedBox.expand()
                : (widget.mpvPlayerService != null
                    ? SizedBox.expand(
                        child: RepaintBoundary(
                          child: Video(
                            controller: widget.mpvPlayerService!.videoController,
                            controls: NoVideoControls,
                            fit: widget.fitMode.boxFit,
                            filterQuality: FilterQuality.low,
                            subtitleViewConfiguration: SubtitleViewConfiguration(
                              visible: widget.selectedSubtitleTrackId != null &&
                                  widget.selectedSubtitleTrackId != 'no' &&
                                  widget.selectedSubtitleTrackId != 'none',
                              style: const TextStyle(
                                height: 1.4,
                                fontSize: 26.0,
                                color: Colors.white,
                                shadows: [
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
              widget.onToggleControls: widget.onToggleControls,
              onDoubleTapPlayPause: widget.onPlayOrPause,
              onSeekBackward: () => widget.onSeekRelative(-10),
              onSeekForward: () => widget.onSeekRelative(10),
              widget.onToggleFullscreen: widget.onToggleFullscreen,
              widget.volume: widget.volume,
              widget.onVolumeChanged: widget.onVolumeChanged,
              widget.brightness: widget.brightness,
              widget.onBrightnessChanged: widget.onBrightnessChanged,
            ),
          ),

          // 3. Center Buffering Indicator
          if (widget.isBuffering)
            Center(
              child: CircularProgressIndicator(
                color: primaryColor,
                strokeWidth: 3.5,
              ),
            ),

          // 4. Seek Feedback Toast (+10s / -10s)
          if (widget.seekFeedback != null)
            SeekFeedbackToast(
              key: ValueKey('$widget.seekFeedback$widget.seekFeedbackKey'),
              text: widget.seekFeedback!,
            ),

          // 5. Fallback Notification Toast
          if (widget.fallbackNotice != null)
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
                        widget.fallbackNotice!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 6. Real-time Performance Stats Overlay
          if (widget.isStatsVisible)
            PerformanceStatsOverlay(
              stats: widget.performanceStats,
              onClose: widget.onCloseStats,
            ),

          // 7. Floating Skip Opening / Intro / Ending Button
          if (widget.areControlsVisible && widget.canSkipCurrentChapter && widget.activeChapter != null)
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
                  widget.activeChapter!.localizedSkipButtonLabel(l10n),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: widget.onSkipChapter,
              ),
            ),

          // 8. Modern Material Design 3 Controls Overlay
          RepaintBoundary(
            child: AnimatedOpacity(
              opacity: (widget.areControlsVisible && !widget.isTransitioningOrientation) ? 1.0 : 0.0,
              widget.duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !widget.areControlsVisible || widget.isTransitioningOrientation,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Top Bar with gradient
                    if (_controlsMounted) Positioned(
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
                            widget.title: widget.title,
                            widget.episodeTitle: widget.episodeTitle,
                            widget.videoSource: widget.videoSource,
                            widget.videoUrl: widget.videoUrl,
                            widget.onBack: widget.onBack,
                            widget.onOpenSettings: widget.onOpenSettings,
                            widget.onToggleSidePanel: widget.onToggleSidePanel,
                            widget.isSidePanelCollapsed: widget.isSidePanelCollapsed,
                            widget.isFullscreen: widget.isFullscreen,
                            showTitle: widget.isFullscreen || (widget.isDesktop && widget.isSidePanelCollapsed),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Bar with gradient
                    if (_controlsMounted) Positioned(
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
                          child: ValueListenableBuilder<Duration>(
                            valueListenable: widget.positionNotifier,
                            builder: (context, currentPos, _) {
                              return ValueListenableBuilder<Duration>(
                                valueListenable: widget.bufferNotifier,
                                builder: (context, currentBuf, _) {
                                  return PlayerBottomBar(
                                    position: currentPos,
                                    widget.duration: widget.duration,
                                    buffer: currentBuf,
                                    widget.isPlaying: widget.isPlaying,
                                    widget.volume: widget.volume,
                                    widget.chapters: widget.chapters,
                                    currentChapterTitle: widget.activeChapter?.title,
                                    onSeek: widget.onSeekTo,
                                    onPlayPause: widget.onPlayOrPause,
                                    onSeekBackward: () => widget.onSeekRelative(-10),
                                    onSeekForward: () => widget.onSeekRelative(10),
                                    widget.onVolumeChanged: widget.onVolumeChanged,
                                    widget.onToggleFullscreen: widget.onToggleFullscreen,
                                    widget.onNextEpisode: widget.onNextEpisode,
                                    widget.isFullscreen: widget.isFullscreen,
                                    isDesktopOverride: widget.isDesktop,
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
