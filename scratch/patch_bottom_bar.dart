import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
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
  final VoidCallback onSeekBackward;
  final VoidCallback onSeekForward;
  final ValueChanged<double> onVolumeChanged;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onNextEpisode;
  final bool isFullscreen;
  final bool? isDesktopOverride;

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
    required this.onSeekBackward,
    required this.onSeekForward,
    required this.onVolumeChanged,
    this.onToggleFullscreen,
    this.onNextEpisode,
    this.isFullscreen = false,
    this.isDesktopOverride,
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

    // Compact single-line layout for mobile in portrait / mini view
    if (_isSmallMobile) {
      return SafeArea(
        top: false,
        bottom: false,
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

              // Single continuous line: [Play/Pause] [Forward 10s] [Expanded TimelineSlider] [Fullscreen]
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
                      iconSize: 24,
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                      ),
                      tooltip: 'Siguiente episodio',
                      onPressed: onNextEpisode,
                    ),
                  ],

                  const SizedBox(width: 2),

                  // Quick action button (+10s seek)
                  IconButton(
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(4),
                    ),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 24,
                    icon: Icon(
                      AppIcons.forward10(iconPack),
                      color: Colors.white,
                    ),
                    tooltip: l10n.forward10s,
                    onPressed: onSeekForward,
                  ),

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
                      iconSize: 26,
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
                      padding: const EdgeInsets.all(6),
                    ),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      isPlaying
                          ? AppIcons.pause(iconPack)
                          : AppIcons.play(iconPack),
                      color: Colors.white,
                      size: 28,
                    ),
                    tooltip: isPlaying ? l10n.pause : l10n.play,
                    onPressed: onPlayPause,
                  ),

                  // Next Episode Button (if available)
                  if (onNextEpisode != null) ...[
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                        size: 24,
                      ),
                      tooltip: 'Siguiente episodio',
                      onPressed: onNextEpisode,
                    ),
                  ],

                  // -10s Seek Button
                  if (_isDesktop)
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        AppIcons.replay10(iconPack),
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: l10n.rewind10s,
                      onPressed: onSeekBackward,
                    ),

                  // +10s Seek Button
                  if (_isDesktop)
                    IconButton(
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.all(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        AppIcons.forward10(iconPack),
                        color: Colors.white70,
                        size: 22,
                      ),
                      tooltip: l10n.forward10s,
                      onPressed: onSeekForward,
                    ),

                  // Volume Control (Hover slider on desktop, mute icon on mobile)
                  VolumeSlider(
                    volume: volume,
                    onVolumeChanged: onVolumeChanged,
                    isDesktopOverride: _isDesktop,
                  ),

                  const SizedBox(width: 8),

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
                        padding: const EdgeInsets.all(6),
                      ),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        isFullscreen
                            ? AppIcons.fullscreenExit(iconPack)
                            : AppIcons.fullscreen(iconPack),
                        color: Colors.white,
                        size: 24,
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
