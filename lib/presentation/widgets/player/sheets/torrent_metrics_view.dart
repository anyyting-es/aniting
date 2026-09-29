import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';

class TorrentMetricsView extends ConsumerWidget {
  final bool isTorrentProgressVisible;
  final ValueChanged<bool>? onTorrentProgressVisibilityChanged;

  const TorrentMetricsView({
    super.key,
    required this.isTorrentProgressVisible,
    this.onTorrentProgressVisibilityChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final status = ref.watch(torrentStreamStatusProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Switch to activate/deactivate indicator in player
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Icon(AppIcons.eye(iconPack), size: 18, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.torrentDownloadProgress,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Switch(
                  value: isTorrentProgressVisible,
                  onChanged: onTorrentProgressVisibilityChanged,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),

          // Real-time metrics section
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status == null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text(
                        '--',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  // Progress % & Downloaded / Total size
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${status.progressPercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${status.formattedDownloaded} / ${status.size.isNotEmpty ? status.size : '--'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Minimal monochrome Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: (status.progressPercentage / 100.0).clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: Colors.white10,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Minimal monochrome metrics rows
                  _buildTorrentMetricRow(
                    icon: AppIcons.arrowDown(iconPack),
                    label: l10n.downloadSpeed,
                    value: status.downloadSpeed.isNotEmpty ? status.downloadSpeed : '0 B/s',
                  ),
                  const SizedBox(height: 8),
                  _buildTorrentMetricRow(
                    icon: AppIcons.arrowUp(iconPack),
                    label: l10n.uploadSpeed,
                    value: status.uploadSpeed.isNotEmpty ? status.uploadSpeed : '0 B/s',
                  ),
                  const SizedBox(height: 8),
                  _buildTorrentMetricRow(
                    icon: AppIcons.users(iconPack),
                    label: l10n.seedersPeers,
                    value: '${status.seeders}',
                  ),
                  const SizedBox(height: 8),
                  _buildTorrentMetricRow(
                    icon: AppIcons.timer(iconPack),
                    label: l10n.remainingTime,
                    value: status.isComplete ? l10n.completed : status.etaString,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTorrentMetricRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
