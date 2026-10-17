import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/downloads/online_stream_download_task.dart';
import 'package:seanime_app/core/downloads/online_stream_downloader.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/providers/online_stream_download_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';

/// Lists the online stream downloads (in progress, paused and failed) inside the
/// download manager, sharing the same flow as torrent downloads.
class OnlineStreamDownloadsSection extends ConsumerWidget {
  final bool showHeader;

  const OnlineStreamDownloadsSection({super.key, this.showHeader = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final onlineState = ref.watch(onlineStreamDownloadProvider);
    final tasks = onlineState.visibleTasks;

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          SettingsSectionHeader(title: l10n.onlineDownloads),
          const SizedBox(height: 8),
        ],
        ...tasks.map(
          (task) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OnlineStreamDownloadCard(task: task),
          ),
        ),
      ],
    );
  }
}

/// Single online stream download card (progress, cancel and failure state).
class OnlineStreamDownloadCard extends ConsumerWidget {
  final OnlineStreamDownloadTask task;

  const OnlineStreamDownloadCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final isFailed = task.status == OnlineStreamDownloadStatus.failed;
    final progress = task.progress.clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: isFailed
              ? theme.colorScheme.errorContainer.withValues(alpha: 0.16)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFailed
                ? theme.colorScheme.error.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (task.thumbnail != null && task.thumbnail!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: CachedNetworkImage(
                        imageUrl: task.thumbnail!,
                        fit: BoxFit.cover,
                        memCacheWidth: 160,
                        errorWidget: (_, _, _) => _buildThumbPlaceholder(theme, iconPack),
                      ),
                    ),
                  )
                else
                  _buildThumbPlaceholder(theme, iconPack, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${task.animeTitle} - ${l10n.episodeNumber(task.episodeNumber)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${task.providerName} • ${task.server.toUpperCase()} (${task.quality})',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFailed ? Icons.close_rounded : Icons.cancel_outlined,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  tooltip: isFailed ? l10n.close : l10n.cancelDownload,
                  onPressed: () {
                    final notifier = ref.read(onlineStreamDownloadProvider.notifier);
                    if (isFailed) {
                      notifier.removeTask(task.id);
                    } else {
                      notifier.cancelDownload(task.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isFailed) ...[
              Row(
                children: [
                  Icon(
                    AppIcons.error(iconPack),
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _failureMessage(l10n),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$percentage%',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    task.speed.isNotEmpty
                        ? '↓ ${task.speed}'
                        : OnlineStreamDownloader.formatBytes(task.downloadedBytes),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildThumbPlaceholder(ThemeData theme, AppIconPack iconPack, {double size = 52}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        AppIcons.stream(iconPack),
        color: theme.colorScheme.primary,
        size: 22,
      ),
    );
  }

  String _failureMessage(AppTranslations l10n) {
    if (task.error != null && task.error!.isNotEmpty) {
      return task.error!;
    }
    return switch (task.errorCode) {
      'protected' => l10n.downloadFailedProtected,
      'invalid' => l10n.downloadFailedInvalid,
      _ => l10n.downloadFailedGeneric,
    };
  }
}
