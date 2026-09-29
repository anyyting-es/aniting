import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/controls/timeline_slider.dart';
import 'package:seanime_app/presentation/widgets/player/controls/volume_slider.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Bottom controls bar for the player containing the timeline slider and controls row.
class PlayerBottomBar extends ConsumerWidget {
  final ValueNotifier<Duration> positionNotifier;
  final Duration duration;
  final ValueNotifier<Duration> bufferNotifier;
  final bool isPlaying;
  final double volume;
  final List<PlayerChapter> chapters;
  final String? currentChapterTitle;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onPlayPause;
  final VoidCallback? onSeekBackward;
  final VoidCallback? onSeekForward;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onNextEpisode;
  final bool isFullscreen;
  final bool? isDesktopOverride;
  final ValueChanged<bool>? onVolumeHoverChanged;

  const PlayerBottomBar({
    super.key,
    required this.positionNotifier,
    required this.duration,
    required this.bufferNotifier,
    required this.isPlaying,
    required this.volume,
    this.chapters = const [],
    this.currentChapterTitle,
    required this.onSeek,
    required this.onPlayPause,
    this.onSeekBackward,
    this.onSeekForward,
    required this.onVolumeChanged,
    this.onToggleFullscreen,
    this.onNextEpisode,
    this.isFullscreen = false,
    this.isDesktopOverride,
    this.onVolumeHoverChanged,
  });

  bool get _isDesktop =>
      isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);

  bool get _isSmallMobile => !isFullscreen && !_isDesktop;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final isMaterial = iconPack == AppIconPack.material;

    // Optical icon sizing: Material icons have internal glyph padding
    // and need proportional optical scaling so skipNext, volume,
    // and fullscreen feel harmonious and not miniature.
    // Calibrated relative delta proportions: SkipNext +2, Volume -4, Play/Fullscreen equal.
    final double playPauseSize = _isDesktop
        ? (isMaterial ? 32.0 : 28.0)
        : (isMaterial ? 28.0 : 25.0);
    final double skipNextSize = _isDesktop
        ? (isMaterial ? 34.0 : 26.0)
        : (isMaterial ? 30.0 : 23.0);
    final double fullscreenSize = _isDesktop
        ? (isMaterial ? 32.0 : 27.0)
        : (isMaterial ? 28.0 : 24.0);
    final double volumeSize = _isDesktop
        ? (isMaterial ? 28.0 : 23.0)
        : (isMaterial ? 24.0 : 21.0);

    // Compact single-line layout for mobile in portrait / mini view
    if (_isSmallMobile) {
      final double smallSkipNextSize = isMaterial ? 28 : 24;
      final double smallFullscreenSize = isMaterial ? 28 : 24;

      return SafeArea(
        top: false,
        bottom: false,
        left: false,
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timestamp display directly above play/pause on the left
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Row(
                  children: [
                    ValueListenableBuilder<Duration>(
                      valueListenable: positionNotifier,
                      builder: (context, pos, _) {
                        return Text(
                          '${_formatDuration(pos)} / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        );
                      },
                    ),
                    if (currentChapterTitle != null &&
                        currentChapterTitle!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• $currentChapterTitle',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Single continuous line: [Play/Pause] [Next Episode] [Expanded TimelineSlider] [Fullscreen]
              Row(
                children: [
                  // Play / Pause Button
                  IconButton(
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(4),
                    ),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 28,
                    icon: Icon(
                      isPlaying
                          ? AppIcons.pause(iconPack)
                          : AppIcons.play(iconPack),
                      color: Colors.white,
                    ),
                    tooltip: isPlaying ? l10n.pause : l10n.play,
                    onPressed: onPlayPause,
                  ),

                  // Next Episode Button (if available)
                  if (onNextEpisode != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(4),
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: smallSkipNextSize,
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                      ),
                      tooltip: 'Siguiente episodio',
                      onPressed: onNextEpisode,
                    ),
                  ],

                  const SizedBox(width: 4),

                  // Continuous reproduction seek bar
                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: positionNotifier,
                      builder: (context, pos, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: bufferNotifier,
                          builder: (context, buf, _) {
                            return TimelineSlider(
                              position: pos,
                              duration: duration,
                              buffer: buf,
                              chapters: chapters,
                              onSeek: onSeek,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 4),

                  // Fullscreen toggle button
                  if (onToggleFullscreen != null)
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(4),
                      ),
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: smallFullscreenSize,
                      icon: Icon(
                        isFullscreen
                            ? AppIcons.fullscreenExit(iconPack)
                            : AppIcons.fullscreen(iconPack),
                        color: Colors.white,
                      ),
                      tooltip: isFullscreen
                          ? l10n.exitFullScreen
                          : l10n.fullScreen,
                      onPressed: onToggleFullscreen,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      bottom: isFullscreen,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Timeline Progress Bar with MKV Chapter ticks
            ValueListenableBuilder<Duration>(
              valueListenable: positionNotifier,
              builder: (context, pos, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: bufferNotifier,
                  builder: (context, buf, _) {
                    return TimelineSlider(
                      position: pos,
                      duration: duration,
                      buffer: buf,
                      chapters: chapters,
                      onSeek: onSeek,
                    );
                  },
                );
              },
            ),

            // 2. Controls Row Under Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  // Play / Pause Button
                  IconButton(
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(2),
                    ),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      isPlaying
                          ? AppIcons.pause(iconPack)
                          : AppIcons.play(iconPack),
                      color: Colors.white,
                      size: playPauseSize,
                    ),
                    tooltip: isPlaying ? l10n.pause : l10n.play,
                    onPressed: onPlayPause,
                  ),

                  // Next Episode Button (if available)
                  if (onNextEpisode != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(2),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                        size: skipNextSize,
                      ),
                      tooltip: 'Siguiente episodio',
                      onPressed: onNextEpisode,
                    ),
                  ],

                  // Volume Control (Desktop only; mobile uses hardware buttons)
                  if (_isDesktop) ...[
                    const SizedBox(width: 6),
                    VolumeSlider(
                      volume: volume,
                      onVolumeChanged: onVolumeChanged,
                      isDesktopOverride: _isDesktop,
                      onHoverChanged: onVolumeHoverChanged,
                      iconSize: volumeSize,
                    ),
                  ],

                  const SizedBox(width: 10),

                  // Timestamp Display (Standard normal font, no monospace)
                  ValueListenableBuilder<Duration>(
                    valueListenable: positionNotifier,
                    builder: (context, pos, _) {
                      return Text(
                        '${_formatDuration(pos)} / ${_formatDuration(duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),

                  // Active Chapter Label
                  if (currentChapterTitle != null &&
                      currentChapterTitle!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: _isDesktop ? 350 : 150),
                      child: Text(
                        '• $currentChapterTitle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Fullscreen toggle (Desktop and Mobile)
                  if (onToggleFullscreen != null)
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(2),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        isFullscreen
                            ? AppIcons.fullscreenExit(iconPack)
                            : AppIcons.fullscreen(iconPack),
                        color: Colors.white,
                        size: fullscreenSize,
                      ),
                      tooltip: isFullscreen
                          ? l10n.exitFullScreen
                          : l10n.fullScreen,
                      onPressed: onToggleFullscreen,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
