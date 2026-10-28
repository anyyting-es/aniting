import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/player/media_kit_player_service.dart';
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
  final MediaKitPlayerService? mediaKitPlayerService;
  final PlayerFitMode fitMode;
  final String? selectedSubtitleTrackId;
  final String currentSubtitleText;

  // Controls visibility & state
  final bool areControlsVisible;
  final bool isTransitioningOrientation;
  final bool isExiting;
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
  final bool showLoadingOverlay;
  final String loadingMessage;
  final String loadingTitle;
  final String? loadingBackgroundImage;
  final String? loadingLogoImage;
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
  final VoidCallback? onToggleTheaterMode;
  final bool isTheaterMode;
  final GlobalKey? captureKey;

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
    required this.mediaKitPlayerService,
    required this.fitMode,
    required this.selectedSubtitleTrackId,
    this.currentSubtitleText = '',
    required this.areControlsVisible,
    required this.isTransitioningOrientation,
    this.isExiting = false,
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
    this.showLoadingOverlay = false,
    this.loadingMessage = '',
    this.loadingTitle = '',
    this.loadingBackgroundImage,
    this.loadingLogoImage,
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
    this.onToggleTheaterMode,
    this.isTheaterMode = false,
    this.captureKey,
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
    final showLoadingArtwork =
        showLoadingOverlay && loadingBackgroundImage != null;

    return ColoredBox(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Video Viewport (Isolated on its own composited layer)
          Positioned.fill(
            child: (isUsingExoPlayer || isLoadingNextEpisode || isExiting)
                ? const SizedBox.expand()
                : (mediaKitPlayerService != null
                      ? SizedBox.expand(
                          child: RepaintBoundary(
                            key: captureKey,
                            child: Video(
                              controller:
                                  mediaKitPlayerService!.videoController,
                              fill: Colors.black,
                              fit: _toBoxFit(fitMode),
                              controls: NoVideoControls,
                            ),
                          ),
                        )
                      : const SizedBox.expand()),
          ),

          if (showLoadingOverlay)
            Positioned.fill(
              child: _LoadingArtwork(
                backgroundImage: loadingBackgroundImage,
                logoImage: loadingLogoImage,
                title: loadingTitle,
                message: loadingMessage,
                showArtwork: showLoadingArtwork,
              ),
            ),

          // 2. Gesture Detection Overlay
          if (!showLoadingOverlay)
            RepaintBoundary(
              child: ValueListenableBuilder<Duration>(
                valueListenable: positionNotifier,
                builder: (context, pos, _) {
                  return PlayerGestureOverlay(
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
                    position: pos,
                    duration: duration,
                    onSeek: onSeekTo,
                  );
                },
              ),
            ),

          // 3. Center Buffering / Next Episode Loading Indicator (Material 3 Expressive Morphing Indicator)
          if ((isBuffering || isLoadingNextEpisode) && !showLoadingOverlay)
            Center(
              child: M3ELoadingIndicator(
                variant: M3ELoadingIndicatorVariant.contained,
                size: 52,
                color: theme.colorScheme.tertiary,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.6),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.info(iconPack),
                      color: primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fallbackNotice!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
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
          if (areControlsVisible &&
              canSkipCurrentChapter &&
              activeChapter != null)
            Positioned(
              bottom: 95,
              right: 20,
              child: FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.92),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 6,
                ),
                icon: Icon(AppIcons.fastForward(iconPack), size: 18),
                label: Text(
                  activeChapter!.localizedSkipButtonLabel(l10n),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                onPressed: onSkipChapter,
              ),
            ),

          // 8. ExoPlayer Non-ASS Subtitles Overlay (Crisp vector outline, scalable and clean)
          if (isUsingExoPlayer &&
              currentSubtitleText.isNotEmpty &&
              selectedSubtitleTrackId != 'no' &&
              selectedSubtitleTrackId != 'none')
            Positioned(
              left: 24,
              right: 24,
              bottom: areControlsVisible
                  ? (isFullscreen ? 96.0 : 56.0)
                  : (isFullscreen ? 36.0 : 20.0),
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    padding: subStyle.backgroundColor != 0
                        ? const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          )
                        : EdgeInsets.zero,
                    decoration: subStyle.backgroundColor != 0
                        ? BoxDecoration(
                            color: subStyle.bgFlutterColor,
                            borderRadius: BorderRadius.circular(6),
                          )
                        : null,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Vector stroke outline (renders crisp border without blurry shadows)
                        if (subStyle.borderStyle != SubtitleBorderStyle.none &&
                            subStyle.borderSize > 0)
                          Text(
                            currentSubtitleText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: subStyle.fontFamily == 'sans-serif'
                                  ? null
                                  : subStyle.fontFamily,
                              fontSize:
                                  (isFullscreen ? 28.0 : 20.0) *
                                  subStyle.fontSizeMultiplier,
                              fontWeight: subStyle.bold
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              fontStyle: subStyle.italic
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                              height: 1.35,
                              foreground: Paint()
                                ..style = PaintingStyle.stroke
                                ..strokeWidth =
                                    (isFullscreen ? 3.5 : 2.5) *
                                    (subStyle.borderSize / 3.0).clamp(0.5, 2.5)
                                ..strokeJoin = StrokeJoin.round
                                ..strokeCap = StrokeCap.round
                                ..color = subStyle.borderFlutterColor,
                            ),
                          ),
                        // Foreground fill text
                        Text(
                          currentSubtitleText,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: subStyle.textFlutterColor,
                            fontFamily: subStyle.fontFamily == 'sans-serif'
                                ? null
                                : subStyle.fontFamily,
                            fontSize:
                                (isFullscreen ? 28.0 : 20.0) *
                                subStyle.fontSizeMultiplier,
                            fontWeight: subStyle.bold
                                ? FontWeight.bold
                                : FontWeight.w600,
                            fontStyle: subStyle.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 9. Modern Material Design 3 Controls Overlay
          if (!showLoadingOverlay)
            RepaintBoundary(
              child: _ControlsOverlay(
                areControlsVisible: areControlsVisible,
                isTransitioningOrientation: isTransitioningOrientation,
                topBar: Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
                    child: PlayerTopBar(
                      title: title,
                      episodeTitle: episodeTitle,
                      videoSource: videoSource,
                      videoUrl: videoUrl,
                      onBack: onBack,
                      onOpenSettings: onOpenSettings,
                      isFullscreen: isFullscreen,
                      onToggleTheaterMode: onToggleTheaterMode,
                      isTheaterMode: isTheaterMode,
                      showBackButton: isTheaterMode || !(isDesktop && !isFullscreen),
                      showTitle: isFullscreen,
                    ),
                  ),
                ),
                bottomBar: Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
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
        ],
      ),
    );
  }

  static BoxFit _toBoxFit(PlayerFitMode mode) {
    switch (mode) {
      case PlayerFitMode.contain:
        return BoxFit.contain;
      case PlayerFitMode.cover:
        return BoxFit.cover;
      case PlayerFitMode.fill:
        return BoxFit.fill;
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

class _LoadingArtwork extends StatefulWidget {
  final String? backgroundImage;
  final String? logoImage;
  final String title;
  final String message;
  final bool showArtwork;

  const _LoadingArtwork({
    required this.backgroundImage,
    required this.logoImage,
    required this.title,
    required this.message,
    required this.showArtwork,
  });

  @override
  State<_LoadingArtwork> createState() => _LoadingArtworkState();
}

class _LoadingArtworkState extends State<_LoadingArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
    lowerBound: 0.45,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.showArtwork)
            CachedNetworkImage(
              imageUrl: widget.backgroundImage!,
              fit: BoxFit.cover,
              errorWidget: (_, _, _) => const SizedBox.shrink(),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.3),
                  Colors.black.withValues(alpha: 0.78),
                ],
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.logoImage != null && widget.logoImage!.isNotEmpty)
                  FadeTransition(
                    opacity: _pulseController,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = (constraints.maxWidth * 0.62).clamp(
                          260.0,
                          460.0,
                        );
                        return CachedNetworkImage(
                          imageUrl: widget.logoImage!,
                          width: width,
                          height: width * 0.42,
                          fit: BoxFit.contain,
                          errorWidget: (_, _, _) => const SizedBox.shrink(),
                        );
                      },
                    ),
                  )
                else
                  Icon(
                    Icons.movie_outlined,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
    final isVisible =
        widget.areControlsVisible && !widget.isTransitioningOrientation;
    return AnimatedOpacity(
      opacity: isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (!widget.areControlsVisible && mounted) {
          setState(() => _controlsMounted = false);
        }
      },
      child: IgnorePointer(
        ignoring: !isVisible,
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
