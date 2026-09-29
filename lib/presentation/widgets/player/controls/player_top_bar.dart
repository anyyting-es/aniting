import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';

/// Clean, modern top bar for the video player displaying back button, titles,
/// video source badge (extension, torrent, local file or stream),
/// minimal floating torrent indicators, and settings button on the top right.
class PlayerTopBar extends ConsumerWidget {
  final String title;
  final String? episodeTitle;
  final String? videoSource;
  final String? videoUrl;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final VoidCallback? onToggleSidePanel;
  final bool isSidePanelCollapsed;
  final bool isFullscreen;
  final bool showTitle;

  const PlayerTopBar({
    super.key,
    required this.title,
    this.episodeTitle,
    this.videoSource,
    this.videoUrl,
    required this.onBack,
    required this.onOpenSettings,
    this.onToggleSidePanel,
    this.isSidePanelCollapsed = false,
    this.isFullscreen = true,
    this.showTitle = true,
  });

  Widget _buildTorrentIndicator(TorrentStreamStatus? status, AppIconPack iconPack) {
    const textShadows = [
      Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 1)),
      Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(-0.5, -0.5)),
    ];

    if (status == null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Torrent...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              shadows: textShadows,
            ),
          ),
        ],
      );
    }

    if (status.isComplete) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.checkCircle(iconPack), size: 14, color: Colors.white70),
          const SizedBox(width: 4),
          const Text(
            '100% Completado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: textShadows,
            ),
          ),
        ],
      );
    }

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Velocidad de descarga
          Icon(AppIcons.arrowDown(iconPack), size: 13, color: Colors.white70),
          const SizedBox(width: 3),
          Text(
            status.downloadSpeed.isNotEmpty ? status.downloadSpeed : '0 B/s',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: textShadows,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white38, fontSize: 10, shadows: textShadows),
            ),
          ),

          // Peers
          Icon(AppIcons.users(iconPack), size: 13, color: Colors.white70),
          const SizedBox(width: 3),
          Text(
            '${status.seeders}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: textShadows,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '•',
              style: TextStyle(color: Colors.white38, fontSize: 10, shadows: textShadows),
            ),
          ),

          // Porcentaje y Tiempo restante (ETA)
          Text(
            '${status.progressPercentage.toStringAsFixed(0)}% (${status.etaString})',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: textShadows,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isTorrentProgressEnabled = ref.watch(torrentProgressOverlayEnabledProvider);
    final torrentStatus = ref.watch(torrentStreamStatusProvider);
    final isTorrent = (videoSource?.toLowerCase().contains('torrent') ?? false) ||
        (videoUrl?.contains('torrentstream') ?? false) ||
        torrentStatus != null;

    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isMaterial = iconPack == AppIconPack.material;

    // Optical icon sizing: harmonized with bottom bar controls
    final double backIconSize = isDesktop
        ? (isMaterial ? 30.0 : 26.0)
        : (isMaterial ? 26.0 : 23.0);
    final double settingsIconSize = isDesktop
        ? (isMaterial ? 29.0 : 25.0)
        : (isMaterial ? 26.0 : 23.0);
    final double sidebarIconSize = isDesktop
        ? (isMaterial ? 28.0 : 24.0)
        : (isMaterial ? 24.0 : 21.0);

    return SafeArea(
      top: isFullscreen,
      bottom: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isFullscreen ? 16 : 8,
          vertical: 4,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Left and Right controls Row
            Row(
              children: [
                // Back button
                IconButton(
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(2),
                  ),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(AppIcons.arrowLeft(iconPack), color: Colors.white, size: backIconSize),
                  tooltip: l10n.back,
                  onPressed: onBack,
                ),

                // Title, Episode Title & Source Badge (only when showTitle is true)
                if (showTitle) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (episodeTitle != null && episodeTitle!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              episodeTitle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),

                // Side panel collapse / expand toggle (PC / Desktop)
                if (onToggleSidePanel != null) ...[
                  IconButton(
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.all(2),
                    ),
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    icon: Icon(
                      isSidePanelCollapsed
                          ? AppIcons.sidebarOutline(iconPack)
                          : AppIcons.sidebar(iconPack),
                      color: Colors.white,
                      size: sidebarIconSize,
                    ),
                    tooltip: isSidePanelCollapsed ? 'Mostrar información' : 'Colapsar panel',
                    onPressed: onToggleSidePanel,
                  ),
                  const SizedBox(width: 8),
                ],

                // Settings button (always pinned to the far right!)
                IconButton(
                  style: IconButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.all(2),
                  ),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  icon: Icon(AppIcons.settings(iconPack), color: Colors.white, size: settingsIconSize),
                  tooltip: l10n.settingsTitle,
                  onPressed: onOpenSettings,
                ),
              ],
            ),

            // Layer 2: Torrent indicator centered in the middle of the screen
            if (isTorrent && isTorrentProgressEnabled)
              IgnorePointer(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 96),
                    child: _buildTorrentIndicator(torrentStatus, iconPack),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

