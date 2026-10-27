import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/aspect_ratio_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/audio_tracks_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/chapters_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/playback_speed_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/shaders_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/source_info_view.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/subtitle_style_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/subtitle_tracks_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/sync_offset_view.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/torrent_metrics_view.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';

enum _SettingsSection {
  menu,
  chapters,
  audioTracks,
  subtitleTracks,
  subtitleStyle,
  subtitleSync,
  audioSync,
  speed,
  shaders,
  aspectRatio,
  source,
  torrent,
}

/// Unified Player Settings Sheet opening as a right-to-left slide-in modal.
/// Houses all playback configurations cleanly categorized with smooth in-sheet navigation.
class PlayerSettingsSheet extends ConsumerStatefulWidget {
  final List<PlayerChapter> chapters;
  final Duration currentPosition;
  final ValueChanged<PlayerChapter> onChapterSelected;

  final List<UiTrack> audioTracks;
  final List<UiTrack> subtitleTracks;
  final String? selectedAudioTrackId;
  final String? selectedSubtitleTrackId;
  final ValueChanged<UiTrack> onAudioTrackSelected;
  final ValueChanged<UiTrack?> onSubtitleTrackSelected;

  final int subtitleDelayMs;
  final ValueChanged<int> onSubtitleDelayChanged;
  final int audioDelayMs;
  final ValueChanged<int> onAudioDelayChanged;

  final double playbackRate;
  final ValueChanged<double> onPlaybackRateChanged;

  final ShaderPreset activeShaderPreset;
  final ValueChanged<ShaderPreset> onShaderPresetSelected;

  final bool isStatsVisible;
  final ValueChanged<bool> onStatsVisibilityChanged;

  final PlayerFitMode fitMode;
  final ValueChanged<PlayerFitMode> onFitModeChanged;

  final bool isUsingExoPlayer;

  final bool gesturesEnabled;
  final ValueChanged<bool>? onGesturesChanged;

  final bool volumeBoostEnabled;
  final ValueChanged<bool>? onVolumeBoostChanged;

  final bool isTorrentProgressVisible;
  final ValueChanged<bool>? onTorrentProgressVisibilityChanged;

  final String? videoSource;
  final String? videoUrl;

  final bool isBottomSheet;
  final double rightOffset;

  const PlayerSettingsSheet({
    super.key,
    this.chapters = const [],
    this.currentPosition = Duration.zero,
    required this.onChapterSelected,
    required this.audioTracks,
    required this.subtitleTracks,
    required this.selectedAudioTrackId,
    required this.selectedSubtitleTrackId,
    required this.onAudioTrackSelected,
    required this.onSubtitleTrackSelected,
    required this.subtitleDelayMs,
    required this.onSubtitleDelayChanged,
    required this.audioDelayMs,
    required this.onAudioDelayChanged,
    required this.playbackRate,
    required this.onPlaybackRateChanged,
    required this.activeShaderPreset,
    required this.onShaderPresetSelected,
    required this.isStatsVisible,
    required this.onStatsVisibilityChanged,
    required this.fitMode,
    required this.onFitModeChanged,
    this.isUsingExoPlayer = false,
    this.gesturesEnabled = true,
    this.onGesturesChanged,
    this.volumeBoostEnabled = false,
    this.onVolumeBoostChanged,
    this.isTorrentProgressVisible = false,
    this.onTorrentProgressVisibilityChanged,
    this.videoSource,
    this.videoUrl,
    this.isBottomSheet = false,
    this.rightOffset = 0.0,
  });

  /// Displays the player settings modal.
  /// On mobile in portrait embedded mode, renders as a bottom sheet with drag handle.
  /// On desktop, supports rightOffset to display adjacent to the info panel rather than covering it.
  static Future<void> show({
    required BuildContext context,
    bool isBottomSheet = false,
    double rightOffset = 0.0,
    List<PlayerChapter> chapters = const [],
    Duration currentPosition = Duration.zero,
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
    required PlayerFitMode fitMode,
    required ValueChanged<PlayerFitMode> onFitModeChanged,
    bool isUsingExoPlayer = false,
    bool gesturesEnabled = true,
    ValueChanged<bool>? onGesturesChanged,
    bool volumeBoostEnabled = false,
    ValueChanged<bool>? onVolumeBoostChanged,
    bool isTorrentProgressVisible = false,
    ValueChanged<bool>? onTorrentProgressVisibilityChanged,
    String? videoSource,
    String? videoUrl,
  }) {
    if (isBottomSheet) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) {
          return PlayerSettingsSheet(
            isBottomSheet: true,
            rightOffset: 0.0,
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
            fitMode: fitMode,
            onFitModeChanged: onFitModeChanged,
            isUsingExoPlayer: isUsingExoPlayer,
            gesturesEnabled: gesturesEnabled,
            onGesturesChanged: onGesturesChanged,
            volumeBoostEnabled: volumeBoostEnabled,
            onVolumeBoostChanged: onVolumeBoostChanged,
            isTorrentProgressVisible: isTorrentProgressVisible,
            onTorrentProgressVisibilityChanged: onTorrentProgressVisibilityChanged,
            videoSource: videoSource,
            videoUrl: videoUrl,
          );
        },
      );
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: rightOffset),
            child: RepaintBoundary(
              child: Material(
                color: Colors.transparent,
                child: PlayerSettingsSheet(
                  isBottomSheet: false,
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
                  fitMode: fitMode,
                  onFitModeChanged: onFitModeChanged,
                  isUsingExoPlayer: isUsingExoPlayer,
                  gesturesEnabled: gesturesEnabled,
                  onGesturesChanged: onGesturesChanged,
                  volumeBoostEnabled: volumeBoostEnabled,
                  onVolumeBoostChanged: onVolumeBoostChanged,
                  isTorrentProgressVisible: isTorrentProgressVisible,
                  onTorrentProgressVisibilityChanged: onTorrentProgressVisibilityChanged,
                  videoSource: videoSource,
                  videoUrl: videoUrl,
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  ConsumerState<PlayerSettingsSheet> createState() => _PlayerSettingsSheetState();
}

class _PlayerSettingsSheetState extends ConsumerState<PlayerSettingsSheet> {
  _SettingsSection _currentSection = _SettingsSection.menu;
  late bool _isStatsVisible;
  late ShaderPreset _activeShaderPreset;
  late double _playbackRate;
  late int _subtitleDelayMs;
  late int _audioDelayMs;
  late PlayerFitMode _fitMode;
  late bool _gesturesEnabled;
  late bool _volumeBoostEnabled;
  late bool _isTorrentProgressVisible;
  String? _selectedAudioTrackId;
  String? _selectedSubtitleTrackId;

  @override
  void initState() {
    super.initState();
    _isStatsVisible = widget.isStatsVisible;
    _activeShaderPreset = widget.activeShaderPreset;
    _playbackRate = widget.playbackRate;
    _subtitleDelayMs = widget.subtitleDelayMs;
    _audioDelayMs = widget.audioDelayMs;
    _fitMode = widget.fitMode;
    _gesturesEnabled = widget.gesturesEnabled;
    _volumeBoostEnabled = widget.volumeBoostEnabled;
    _isTorrentProgressVisible = widget.isTorrentProgressVisible;
    _selectedAudioTrackId = widget.selectedAudioTrackId;
    _selectedSubtitleTrackId = widget.selectedSubtitleTrackId;
  }

  String _getActiveAudioTitle(AppTranslations l10n) {
    for (final t in widget.audioTracks) {
      if (t.id == _selectedAudioTrackId) return t.title;
    }
    return widget.audioTracks.isNotEmpty
        ? widget.audioTracks.first.title
        : l10n.defaultOption;
  }

  String _getActiveSubtitleTitle(AppTranslations l10n) {
    if (_selectedSubtitleTrackId == null ||
        _selectedSubtitleTrackId == 'no' ||
        _selectedSubtitleTrackId == 'none') {
      return l10n.disabled;
    }
    for (final t in widget.subtitleTracks) {
      if (t.id == _selectedSubtitleTrackId) return t.title;
    }
    return l10n.embedded;
  }

  String _getHeaderTitle(AppTranslations l10n) {
    switch (_currentSection) {
      case _SettingsSection.menu:
        return l10n.playerSettings;
      case _SettingsSection.chapters:
        return l10n.chapters;
      case _SettingsSection.audioTracks:
        return l10n.audioTracks;
      case _SettingsSection.subtitleTracks:
        return l10n.subtitleTracks;
      case _SettingsSection.subtitleStyle:
        return l10n.subtitleStyle;
      case _SettingsSection.subtitleSync:
        return l10n.subtitleSync;
      case _SettingsSection.audioSync:
        return l10n.audioSync;
      case _SettingsSection.speed:
        return l10n.playbackSpeed;
      case _SettingsSection.shaders:
        return l10n.shaders;
      case _SettingsSection.aspectRatio:
        return l10n.aspectRatio;
      case _SettingsSection.source:
        return l10n.videoSource;
      case _SettingsSection.torrent:
        return l10n.torrentDownloadProgress;
    }
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  value,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronRight(iconPack),
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required AppTranslations l10n,
  }) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: theme.colorScheme.onSurfaceVariant, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Text(
                value ? l10n.onBadge : l10n.offBadge,
                style: TextStyle(
                  color: value ? accentColor : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainMenu(AppTranslations l10n) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTorrent = (widget.videoSource?.toLowerCase().contains('torrent') ?? false) ||
        (widget.videoUrl?.contains('torrentstream') ?? false) ||
        ref.watch(torrentStreamStatusProvider) != null;

    final iconPack = ref.watch(iconPackProvider);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Chapters & Editions (if available)
            if (widget.chapters.isNotEmpty) ...[
              _buildMenuItem(
                icon: AppIcons.bookmarks(iconPack),
                title: l10n.chapters,
                value: '${widget.chapters.length} ${l10n.parts}',
                onTap: () =>
                    setState(() => _currentSection = _SettingsSection.chapters),
              ),
              Divider(color: dividerColor, height: 1),
            ],

            // 2. Audio Tracks
            _buildMenuItem(
              icon: AppIcons.audio(iconPack),
              title: l10n.audioTracks,
              value: _getActiveAudioTitle(l10n),
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.audioTracks),
            ),
            Divider(color: dividerColor, height: 1),

            // 3. Subtitles
            _buildMenuItem(
              icon: AppIcons.subtitles(iconPack),
              title: l10n.subtitleTracks,
              value: _getActiveSubtitleTitle(l10n),
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.subtitleTracks),
            ),
            Divider(color: dividerColor, height: 1),

            // 3.1 Subtitle Style
            _buildMenuItem(
              icon: AppIcons.palette(iconPack),
              title: l10n.subtitleStyle,
              value: '${ref.watch(subtitleStylePreferencesProvider).fontFamily} • ${(ref.watch(subtitleStylePreferencesProvider).fontSizeMultiplier * 100).round()}%',
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.subtitleStyle),
            ),
            Divider(color: dividerColor, height: 1),

            // 4. Playback Speed
            _buildMenuItem(
              icon: AppIcons.speed(iconPack),
              title: l10n.playbackSpeed,
              value: _playbackRate == 1.0 ? l10n.normal : '${_playbackRate}x',
              onTap: () => setState(() => _currentSection = _SettingsSection.speed),
            ),
            Divider(color: dividerColor, height: 1),

            // 5. Aspect Ratio
            _buildMenuItem(
              icon: _fitMode.getIcon(iconPack),
              title: l10n.aspectRatio,
              value: _fitMode.localizedLabel(l10n),
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.aspectRatio),
            ),
            Divider(color: dividerColor, height: 1),

            // 6. Subtitle Sync
            _buildMenuItem(
              icon: AppIcons.sync(iconPack),
              title: l10n.subtitleSync,
              value: _subtitleDelayMs == 0
                  ? '0 ms'
                  : '${_subtitleDelayMs > 0 ? '+' : ''}$_subtitleDelayMs ms',
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.subtitleSync),
            ),
            Divider(color: dividerColor, height: 1),

            // 7. Audio Sync
            _buildMenuItem(
              icon: AppIcons.syncAlt(iconPack),
              title: l10n.audioSync,
              value: _audioDelayMs == 0
                  ? '0 ms'
                  : '${_audioDelayMs > 0 ? '+' : ''}$_audioDelayMs ms',
              onTap: () =>
                  setState(() => _currentSection = _SettingsSection.audioSync),
            ),
            Divider(color: dividerColor, height: 1),

            // 8. Shader presets remain visible for compatibility, but are
            // not applied by the direct media_kit backend.
            if (!widget.isUsingExoPlayer) ...[
              _buildMenuItem(
                icon: AppIcons.sparkles(iconPack),
                title: l10n.shaders,
                value: _activeShaderPreset.localizedName(l10n),
                onTap: () =>
                    setState(() => _currentSection = _SettingsSection.shaders),
              ),
              Divider(color: dividerColor, height: 1),
            ],

            // 9. Fuente del video
            if (widget.videoSource != null && widget.videoSource!.isNotEmpty) ...[
              _buildMenuItem(
                icon: AppIcons.stream(iconPack),
                title: l10n.source,
                value: widget.videoSource!,
                onTap: () => setState(() => _currentSection = _SettingsSection.source),
              ),
              Divider(color: dividerColor, height: 1),
            ],

            // 10. Progreso del Torrent
            if (isTorrent) ...[
              _buildMenuItem(
                icon: AppIcons.download(iconPack),
                title: l10n.torrentDownloadProgress,
                value: _isTorrentProgressVisible ? l10n.onBadge : l10n.offBadge,
                onTap: () => setState(() => _currentSection = _SettingsSection.torrent),
              ),
              Divider(color: dividerColor, height: 1),
            ],

            // 11. Gestos en pantalla Toggle (On / Off)
            _buildToggleItem(
              icon: AppIcons.touchApp(iconPack),
              title: l10n.gestures,
              value: _gesturesEnabled,
              l10n: l10n,
              onChanged: (val) {
                setState(() => _gesturesEnabled = val);
                widget.onGesturesChanged?.call(val);
              },
            ),
            Divider(color: dividerColor, height: 1),

            // 12. Amplificación de volumen (>100%)
            _buildToggleItem(
              icon: AppIcons.volume(iconPack),
              title: l10n.volumeBoost,
              value: _volumeBoostEnabled,
              l10n: l10n,
              onChanged: (val) {
                setState(() => _volumeBoostEnabled = val);
                widget.onVolumeBoostChanged?.call(val);
              },
            ),
            Divider(color: dividerColor, height: 1),

            // 13. Performance Stats Toggle (On / Off)
            _buildToggleItem(
              icon: AppIcons.analytics(iconPack),
              title: l10n.performanceStats,
              value: _isStatsVisible,
              l10n: l10n,
              onChanged: (val) {
                setState(() => _isStatsVisible = val);
                widget.onStatsVisibilityChanged(val);
              },
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final screenSize = MediaQuery.of(context).size;
    final isMobile = Platform.isAndroid || Platform.isIOS;

    if (widget.isBottomSheet) {
      final sheetHeight = math.min(screenSize.height * 0.70, 560.0);
      final borderRad = const BorderRadius.vertical(top: Radius.circular(22));

      return Material(
        color: Colors.transparent,
        child: SizedBox(
          width: double.infinity,
          height: sheetHeight,
          child: ClipRRect(
            borderRadius: borderRad,
            child: GlassCard(
              borderRadius: borderRad,
              padding: EdgeInsets.zero,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0C0D12).withValues(alpha: 0.65)
                      : theme.colorScheme.surface.withValues(alpha: 0.75),
                  borderRadius: borderRad,
                  border: Border(
                    top: BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  left: true,
                  right: true,
                  bottom: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modal Drag Handle Indicator (deslizamiento de arriba pa abajo)
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 38,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Header Bar (Title on left, Close button on right)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      if (_currentSection != _SettingsSection.menu) ...[
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                          style: IconButton.styleFrom(
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                          ),
                          icon: Icon(
                            AppIcons.arrowLeft(iconPack),
                            color: theme.colorScheme.onSurface,
                            size: 20,
                          ),
                          tooltip: l10n.back,
                          onPressed: () => setState(
                            () => _currentSection = _SettingsSection.menu,
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],

                      Expanded(
                        child: Text(
                          _getHeaderTitle(l10n),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                        ),
                        icon: Icon(
                          AppIcons.close(iconPack),
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                        tooltip: l10n.close,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content in scrollable area
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 16),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      layoutBuilder: (currentChild, previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: [
                            ...previousChildren,
                            ?currentChild,
                          ],
                        );
                      },
                      child: _buildCurrentContent(l10n),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
);
    }

    final sheetWidth = isMobile
        ? math.min(screenSize.width * 0.40, 320.0)
        : math.min(screenSize.width * 0.35, 350.0);
    final finalWidth = math.max(sheetWidth, 280.0);
    final hasRightOffset = widget.rightOffset > 0;
    final drawerRadius = hasRightOffset
        ? BorderRadius.circular(16)
        : const BorderRadius.horizontal(
            left: Radius.circular(16),
          );

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: finalWidth,
        height: double.infinity,
        child: ClipRRect(
          borderRadius: drawerRadius,
          child: GlassCard(
            borderRadius: drawerRadius,
            padding: EdgeInsets.zero,
            child: Container(
              margin: EdgeInsets.zero,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0C0D12).withValues(alpha: 0.65)
                    : theme.colorScheme.surface.withValues(alpha: 0.75),
                borderRadius: drawerRadius,
                border: Border(
                  left: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.15)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    width: 1,
                  ),
                  right: hasRightOffset
                      ? BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                          width: 1,
                        )
                      : BorderSide.none,
                ),
              ),
              child: SafeArea(
                left: false,
                top: false,
                bottom: false,
                right: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
              // Header Bar (Title on left, Close button on right)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (_currentSection != _SettingsSection.menu) ...[
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        style: IconButton.styleFrom(
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(36, 36),
                        ),
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: theme.colorScheme.onSurface,
                          size: 20,
                        ),
                        tooltip: l10n.back,
                        onPressed: () => setState(
                          () => _currentSection = _SettingsSection.menu,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],

                    Expanded(
                      child: Text(
                        _getHeaderTitle(l10n),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                      ),
                      icon: Icon(
                        AppIcons.close(iconPack),
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                      tooltip: l10n.close,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Content in scrollable area
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          ?currentChild,
                        ],
                      );
                    },
                    child: _buildCurrentContent(l10n),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
  }

  Widget _buildCurrentContent(AppTranslations l10n) {
    return KeyedSubtree(
      key: ValueKey(_currentSection),
      child: switch (_currentSection) {
        _SettingsSection.menu => _buildMainMenu(l10n),
        _SettingsSection.chapters => ChaptersView(
          chapters: widget.chapters,
          currentPosition: widget.currentPosition,
          onChapterSelected: (c) {
            widget.onChapterSelected(c);
            Navigator.of(context).pop();
          },
        ),
        _SettingsSection.audioTracks => AudioTracksView(
          tracks: widget.audioTracks,
          selectedTrackId: _selectedAudioTrackId,
          onTrackSelected: (track) {
            setState(() => _selectedAudioTrackId = track.id);
            widget.onAudioTrackSelected(track);
          },
        ),
        _SettingsSection.subtitleTracks => SubtitleTracksView(
          tracks: widget.subtitleTracks,
          selectedTrackId: _selectedSubtitleTrackId,
          onTrackSelected: (track) {
            setState(() => _selectedSubtitleTrackId = track?.id);
            widget.onSubtitleTrackSelected(track);
          },
        ),
        _SettingsSection.subtitleStyle => const SubtitleStyleView(),
        _SettingsSection.subtitleSync => SyncOffsetView(
          title: l10n.subtitleSyncTitle,
          description: l10n.subtitleSyncDesc,
          offsetMs: _subtitleDelayMs,
          onOffsetChanged: (ms) {
            setState(() => _subtitleDelayMs = ms);
            widget.onSubtitleDelayChanged(ms);
          },
          onReset: () {
            setState(() => _subtitleDelayMs = 0);
            widget.onSubtitleDelayChanged(0);
          },
        ),
        _SettingsSection.audioSync => SyncOffsetView(
          title: l10n.audioSyncTitle,
          description: l10n.audioSyncDesc,
          offsetMs: _audioDelayMs,
          onOffsetChanged: (ms) {
            setState(() => _audioDelayMs = ms);
            widget.onAudioDelayChanged(ms);
          },
          onReset: () {
            setState(() => _audioDelayMs = 0);
            widget.onAudioDelayChanged(0);
          },
        ),
        _SettingsSection.speed => PlaybackSpeedView(
          currentSpeed: _playbackRate,
          onSpeedSelected: (speed) {
            setState(() {
              _playbackRate = speed;
            });
            widget.onPlaybackRateChanged(speed);
          },
        ),
        _SettingsSection.shaders => ShadersView(
          activePreset: _activeShaderPreset,
          isMpvActive: !widget.isUsingExoPlayer,
          onPresetSelected: (preset) {
            setState(() {
              _activeShaderPreset = preset;
            });
            widget.onShaderPresetSelected(preset);
          },
        ),
        _SettingsSection.aspectRatio => AspectRatioView(
          currentFitMode: _fitMode,
          onFitModeChanged: (mode) {
            setState(() => _fitMode = mode);
            widget.onFitModeChanged(mode);
          },
        ),
        _SettingsSection.source => SourceInfoView(
          videoSource: widget.videoSource,
          videoUrl: widget.videoUrl,
          isUsingExoPlayer: widget.isUsingExoPlayer,
        ),
        _SettingsSection.torrent => TorrentMetricsView(
          isTorrentProgressVisible: _isTorrentProgressVisible,
          onTorrentProgressVisibilityChanged: (val) {
            setState(() => _isTorrentProgressVisible = val);
            widget.onTorrentProgressVisibilityChanged?.call(val);
          },
        ),
      },
    );
  }
}
