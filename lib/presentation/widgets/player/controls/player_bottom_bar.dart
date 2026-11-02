import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_track_selectors.dart';
import 'package:seanime_app/presentation/widgets/player/controls/timeline_slider.dart';
import 'package:seanime_app/presentation/widgets/player/controls/volume_slider.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Bottom controls bar for the player containing the timeline slider,
/// controls row, and in-video track selection panels.
class PlayerBottomBar extends ConsumerStatefulWidget {
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
  final List<UiTrack> audioTracks;
  final List<UiTrack> subtitleTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;
  final ValueChanged<UiTrack>? onAudioTrackSelected;
  final ValueChanged<UiTrack?>? onSubtitleTrackSelected;
  final ValueChanged<bool>? onMenuOpenChanged;

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
    this.audioTracks = const [],
    this.subtitleTracks = const [],
    this.selectedAudioTrackId,
    this.selectedSubtitleTrackId,
    this.onAudioTrackSelected,
    this.onSubtitleTrackSelected,
    this.onMenuOpenChanged,
  });

  @override
  ConsumerState<PlayerBottomBar> createState() => _PlayerBottomBarState();
}

class _PlayerBottomBarState extends ConsumerState<PlayerBottomBar> {
  final GlassMenuController _subtitlePopoverController = GlassMenuController();
  final GlassMenuController _audioPopoverController = GlassMenuController();

  bool get _isDesktop =>
      widget.isDesktopOverride ?? (!Platform.isAndroid && !Platform.isIOS);

  bool get _isSmallMobile => !widget.isFullscreen && !_isDesktop;

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
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isMaterial = iconPack == AppIconPack.material;

    final double playPauseSize = _isDesktop
        ? (isMaterial ? 24.0 : 20.0)
        : (isMaterial ? 28.0 : 25.0);
    final double skipNextSize = _isDesktop
        ? (isMaterial ? 25.0 : 19.0)
        : (isMaterial ? 30.0 : 23.0);
    final double fullscreenSize = _isDesktop
        ? (isMaterial ? 24.0 : 19.0)
        : (isMaterial ? 28.0 : 24.0);
    final double volumeSize = _isDesktop
        ? (isMaterial ? 22.0 : 17.0)
        : (isMaterial ? 24.0 : 21.0);
    final double tracksIconSize = _isDesktop
        ? (isMaterial ? 22.0 : 18.0)
        : (isMaterial ? 26.0 : 22.0);

    final buttonStyle = IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.all(2),
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      hoverColor: Colors.white.withValues(alpha: 0.12),
      highlightColor: Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
    );

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
              // Timestamp display directly above play/pause on the left with shadow badge
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: Row(
                  children: [
                    ValueListenableBuilder<Duration>(
                      valueListenable: widget.positionNotifier,
                      builder: (context, pos, _) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Text(
                            '${_formatDuration(pos)} / ${_formatDuration(widget.duration)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black87,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (widget.currentChapterTitle != null &&
                        widget.currentChapterTitle!.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '• ${widget.currentChapterTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                            ],
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
                  IconButton(
                    style: buttonStyle,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    iconSize: 28,
                    icon: Icon(
                      widget.isPlaying
                          ? AppIcons.pause(iconPack)
                          : AppIcons.play(iconPack),
                      color: Colors.white,
                    ),
                    tooltip: widget.isPlaying ? l10n.pause : l10n.play,
                    onPressed: widget.onPlayPause,
                  ),

                  if (widget.onNextEpisode != null) ...[
                    const SizedBox(width: 2),
                    IconButton(
                      style: buttonStyle,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: smallSkipNextSize,
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                      ),
                      tooltip: l10n.nextEpisode,
                      onPressed: widget.onNextEpisode,
                    ),
                  ],

                  const SizedBox(width: 4),

                  Expanded(
                    child: ValueListenableBuilder<Duration>(
                      valueListenable: widget.positionNotifier,
                      builder: (context, pos, _) {
                        return ValueListenableBuilder<Duration>(
                          valueListenable: widget.bufferNotifier,
                          builder: (context, buf, _) {
                            return TimelineSlider(
                              position: pos,
                              duration: widget.duration,
                              buffer: buf,
                              chapters: widget.chapters,
                              onSeek: widget.onSeek,
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 4),

                  if (widget.onToggleFullscreen != null)
                    IconButton(
                      style: buttonStyle,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      iconSize: smallFullscreenSize,
                      icon: Icon(
                        widget.isFullscreen
                            ? AppIcons.fullscreenExit(iconPack)
                            : AppIcons.fullscreen(iconPack),
                        color: Colors.white,
                      ),
                      tooltip: widget.isFullscreen
                          ? l10n.exitFullScreen
                          : l10n.fullScreen,
                      onPressed: widget.onToggleFullscreen,
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
      bottom: widget.isFullscreen,
      left: false,
      right: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Controls Row (encima)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  // Play / Pause Button
                  IconButton(
                    style: buttonStyle,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      widget.isPlaying
                          ? AppIcons.pause(iconPack)
                          : AppIcons.play(iconPack),
                      color: Colors.white,
                      size: playPauseSize,
                    ),
                    tooltip: widget.isPlaying ? l10n.pause : l10n.play,
                    onPressed: widget.onPlayPause,
                  ),

                  // Next Episode Button (if available)
                  if (widget.onNextEpisode != null) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      style: buttonStyle,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: Icon(
                        AppIcons.skipNext(iconPack),
                        color: Colors.white,
                        size: skipNextSize,
                      ),
                      tooltip: l10n.nextEpisode,
                      onPressed: widget.onNextEpisode,
                    ),
                  ],

                  // Volume Control (Desktop only; mobile uses hardware buttons)
                  if (_isDesktop) ...[
                    const SizedBox(width: 6),
                    VolumeSlider(
                      volume: widget.volume,
                      onVolumeChanged: widget.onVolumeChanged,
                      isDesktopOverride: _isDesktop,
                      onHoverChanged: widget.onVolumeHoverChanged,
                      iconSize: volumeSize,
                    ),
                  ],

                  const SizedBox(width: 10),

                  // Timestamp Display: rounded pill badge matching other button backgrounds
                  ValueListenableBuilder<Duration>(
                    valueListenable: widget.positionNotifier,
                    builder: (context, pos, _) {
                      return Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '${_formatDuration(pos)} / ${_formatDuration(widget.duration)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                            shadows: [
                              Shadow(
                                color: Colors.black87,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Active Chapter Label: rounded pill badge matching other button backgrounds
                  if (widget.currentChapterTitle != null &&
                      widget.currentChapterTitle!.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: _isDesktop ? 340 : 150),
                        child: Text(
                          '• ${widget.currentChapterTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Desktop subtitle & audio selectors with g1455 GlassPopoverAnchor
                  if (_isDesktop) ...[
                    if (widget.subtitleTracks.isNotEmpty && widget.onSubtitleTrackSelected != null) ...[
                      PlayerSubtitleMenuButton(
                        controller: _subtitlePopoverController,
                        isSubDisabled: widget.selectedSubtitleTrackId == null ||
                            widget.selectedSubtitleTrackId == 'no' ||
                            widget.selectedSubtitleTrackId == 'none',
                        iconSize: tracksIconSize,
                        buttonStyle: buttonStyle,
                        iconPack: iconPack,
                        tooltip: l10n.subtitleTracks,
                        tracks: widget.subtitleTracks,
                        selectedTrackId: widget.selectedSubtitleTrackId,
                        onTrackSelected: widget.onSubtitleTrackSelected,
                        disableOptionLabel: l10n.disableSubtitles,
                        title: l10n.subtitleTracks,
                        onOpen: () {
                          _audioPopoverController.close();
                          widget.onMenuOpenChanged?.call(true);
                        },
                        onClose: () {
                          widget.onMenuOpenChanged?.call(false);
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (widget.audioTracks.isNotEmpty && widget.onAudioTrackSelected != null) ...[
                      PlayerAudioMenuButton(
                        controller: _audioPopoverController,
                        iconSize: tracksIconSize,
                        buttonStyle: buttonStyle,
                        iconPack: iconPack,
                        tooltip: l10n.audioTracks,
                        tracks: widget.audioTracks,
                        selectedTrackId: widget.selectedAudioTrackId,
                        onTrackSelected: widget.onAudioTrackSelected!,
                        title: l10n.audioTracks,
                        onOpen: () {
                          _subtitlePopoverController.close();
                          widget.onMenuOpenChanged?.call(true);
                        },
                        onClose: () {
                          widget.onMenuOpenChanged?.call(false);
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],

                  // Fullscreen toggle (Desktop and Mobile)
                  if (widget.onToggleFullscreen != null)
                    IconButton(
                      style: buttonStyle,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: Icon(
                          widget.isFullscreen
                              ? AppIcons.fullscreenExit(iconPack)
                              : AppIcons.fullscreen(iconPack),
                          key: ValueKey<bool>(widget.isFullscreen),
                          color: Colors.white,
                          size: fullscreenSize,
                        ),
                      ),
                      tooltip: _isDesktop
                          ? (widget.isFullscreen
                              ? '${l10n.exitFullScreen} (Esc / F)'
                              : '${l10n.fullScreen} (F)')
                          : (widget.isFullscreen ? l10n.exitFullScreen : l10n.fullScreen),
                      onPressed: widget.onToggleFullscreen,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // 2. Timeline Progress Bar with MKV Chapter ticks (debajo)
            ValueListenableBuilder<Duration>(
              valueListenable: widget.positionNotifier,
              builder: (context, pos, _) {
                return ValueListenableBuilder<Duration>(
                  valueListenable: widget.bufferNotifier,
                  builder: (context, buf, _) {
                    return TimelineSlider(
                      position: pos,
                      duration: widget.duration,
                      buffer: buf,
                      chapters: widget.chapters,
                      onSeek: widget.onSeek,
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
