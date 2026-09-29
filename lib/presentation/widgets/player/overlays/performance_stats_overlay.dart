import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Real-time on-screen performance overlay displaying video/audio metrics.
class PerformanceStatsOverlay extends ConsumerWidget {
  final ValueNotifier<PerformanceStats?> statsNotifier;
  final VoidCallback onClose;

  const PerformanceStatsOverlay({
    super.key,
    required this.statsNotifier,
    required this.onClose,
  });

  Widget _buildMetric(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    return Positioned(
      top: 64,
      left: 16,
      child: ValueListenableBuilder<PerformanceStats?>(
        valueListenable: statsNotifier,
        builder: (context, stats, child) {
          if (stats == null) return const SizedBox();
          return Container(
            width: 280,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(AppIcons.analytics(iconPack), size: 16, color: accentColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.playbackStats,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                      icon: Icon(AppIcons.close(iconPack), size: 16, color: Colors.white70),
                      tooltip: l10n.close,
                      onPressed: onClose,
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 12),
                _buildMetric(l10n.engine, stats.engine, valueColor: accentColor),
                if (stats.videoCodec != null)
                  _buildMetric(
                    l10n.videoCodec,
                    '${stats.videoCodec}${stats.pixelFormat != null ? ' [${stats.pixelFormat}]' : ''}',
                  ),
                if (stats.resolution != null)
                  _buildMetric(
                    l10n.resolution,
                    '${stats.resolution}${stats.aspectRatio != null ? ' (${stats.aspectRatio})' : ''}',
                  ),
                if (stats.fps != null)
                  _buildMetric(
                    'FPS',
                    '${stats.fps!.toStringAsFixed(2)} fps${stats.containerFps != null && (stats.fps! - stats.containerFps!).abs() > 0.1 ? ' (orig: ${stats.containerFps!.toStringAsFixed(2)})' : ''}',
                  ),
                if (stats.droppedFrames != null)
                  _buildMetric(
                    l10n.droppedFrames,
                    '${stats.droppedFrames} VO / ${stats.decoderDroppedFrames ?? 0} dec',
                    valueColor: (stats.droppedFrames ?? 0) > 10 ? Colors.amber : null,
                  ),
                if (stats.hwdec != null)
                  _buildMetric(
                    l10n.hwDecoder,
                    stats.hwdec!,
                    valueColor: stats.hwdec != 'no' ? Colors.greenAccent : Colors.orangeAccent,
                  ),
                if (stats.bitrate != null && stats.bitrate! > 0)
                  _buildMetric(l10n.videoBitrate, '${(stats.bitrate! / 1000).round()} kbps'),
                if (stats.audioCodec != null)
                  _buildMetric(
                    'Audio',
                    '${stats.audioCodec}${stats.audioChannels != null ? ' (${stats.audioChannels} ch' : ''}${stats.audioSampleRate != null ? ' @ ${(stats.audioSampleRate! / 1000).toStringAsFixed(1)} kHz)' : (stats.audioChannels != null ? ')' : '')}',
                  ),
                if (stats.audioBitrate != null && stats.audioBitrate! > 0)
                  _buildMetric(l10n.audioBitrate, '${(stats.audioBitrate! / 1000).round()} kbps'),
                if (stats.avsync != null)
                  _buildMetric(
                    'A/V Sync',
                    '${(stats.avsync! * 1000).toStringAsFixed(1)} ms',
                  ),
                if (stats.cacheDuration != null && stats.cacheDuration! > 0)
                  _buildMetric(
                    l10n.demuxerCache,
                    '${stats.cacheDuration!.toStringAsFixed(1)} s',
                  ),
                if (stats.subtitleFormat != null)
                  _buildMetric(l10n.subtitles, stats.subtitleFormat!),
              ],
            ),
          );
        },
      ),
    );
  }
}
