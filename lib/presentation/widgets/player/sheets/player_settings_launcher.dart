import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/player_settings_sheet.dart';

/// Helper launcher to open the unified PlayerSettingsSheet with responsive layout
/// calculations (bottom sheet in mobile portrait, docked slide-in drawer on desktop/fullscreen).
class PlayerSettingsLauncher {
  static Future<void> show({
    required BuildContext context,
    required bool isFullscreen,
    required bool isSidePanelCollapsed,
    required List<PlayerChapter> chapters,
    required Duration currentPosition,
    required ValueChanged<PlayerChapter> onChapterSelected,
    required List<UiTrack> audioTracks,
    required List<UiTrack> subtitleTracks,
    required String? selectedAudioTrackId,
    required String? selectedSubtitleTrackId,
    required ValueChanged<UiTrack> onAudioTrackSelected,
    required ValueChanged<UiTrack?> onSubtitleTrackSelected,
    required int subtitleDelayMs,
    required ValueChanged<int> onSubtitleDelayChanged,
    required int audioDelayMs,
    required ValueChanged<int> onAudioDelayChanged,
    required double playbackRate,
    required ValueChanged<double> onPlaybackRateChanged,
    required ShaderPreset activeShaderPreset,
    required ValueChanged<ShaderPreset> onShaderPresetSelected,
    required bool isStatsVisible,
    required ValueChanged<bool> onStatsVisibilityChanged,
    required bool isTorrentProgressVisible,
    required ValueChanged<bool> onTorrentProgressVisibilityChanged,
    required PlayerFitMode fitMode,
    required ValueChanged<PlayerFitMode> onFitModeChanged,
    required bool isUsingExoPlayer,
    required bool gesturesEnabled,
    required ValueChanged<bool> onGesturesChanged,
    required String? videoSource,
    required String videoUrl,
    required bool volumeBoostEnabled,
    required ValueChanged<bool> onVolumeBoostChanged,
  }) {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isMobilePortrait = !isDesktop && !isFullscreen;
    final rightOffset = (isDesktop && !isFullscreen && !isSidePanelCollapsed) ? 380.0 : 0.0;

    return PlayerSettingsSheet.show(
      context: context,
      isBottomSheet: isMobilePortrait,
      rightOffset: rightOffset,
      chapters: chapters,
      currentPosition: currentPosition,
      onChapterSelected: onChapterSelected,
      audioTracks: audioTracks,
      subtitleTracks: subtitleTracks,
      selectedAudioTrackId: selectedAudioTrackId,
      selectedSubtitleTrackId: selectedSubtitleTrackId,
      onAudioTrackSelected: onAudioTrackSelected,
      onSubtitleTrackSelected: onSubtitleTrackSelected,
      subtitleDelayMs: subtitleDelayMs,
      onSubtitleDelayChanged: onSubtitleDelayChanged,
      audioDelayMs: audioDelayMs,
      onAudioDelayChanged: onAudioDelayChanged,
      playbackRate: playbackRate,
      onPlaybackRateChanged: onPlaybackRateChanged,
      activeShaderPreset: activeShaderPreset,
      onShaderPresetSelected: onShaderPresetSelected,
      isStatsVisible: isStatsVisible,
      onStatsVisibilityChanged: onStatsVisibilityChanged,
      isTorrentProgressVisible: isTorrentProgressVisible,
      onTorrentProgressVisibilityChanged: onTorrentProgressVisibilityChanged,
      fitMode: fitMode,
      onFitModeChanged: onFitModeChanged,
      isUsingExoPlayer: isUsingExoPlayer,
      gesturesEnabled: gesturesEnabled,
      onGesturesChanged: onGesturesChanged,
      videoSource: videoSource,
      videoUrl: videoUrl,
      volumeBoostEnabled: volumeBoostEnabled,
      onVolumeBoostChanged: onVolumeBoostChanged,
    );
  }
}
