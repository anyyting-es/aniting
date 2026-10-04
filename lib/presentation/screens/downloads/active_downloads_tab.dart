import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';

class ActiveDownloadsTab extends ConsumerWidget {
  const ActiveDownloadsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final streamStatus = ref.watch(torrentStreamStatusProvider);
    final activeState = ref.watch(activeDownloadsProvider);
    final notifier = ref.read(activeDownloadsProvider.notifier);

    final hasTorrentStream = streamStatus != null && streamStatus.downloadProgress > 0;
    final hasMangaQueue = activeState.mangaQueue.isNotEmpty;
    final hasClientTorrents = activeState.activeTorrents.isNotEmpty;
    final hasAnyActive = hasTorrentStream || hasMangaQueue || hasClientTorrents;

    if (!hasAnyActive && !activeState.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.downloadOffline(iconPack),
                  size: 36,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noActiveDownloads,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.noActiveDownloadsDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: () => notifier.refresh(),
                icon: Icon(AppIcons.refresh(iconPack), size: 18),
                label: Text(l10n.refreshDownloadsTooltip),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── RESUMEN DE DESCARGAS ACTIVAS ────────────────────────────
        PixelCardContainer(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    AppIcons.downloadOffline(iconPack),
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.activeDownloads,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ),
                IconButton(
                  tooltip: l10n.refreshDownloadsTooltip,
                  icon: Icon(AppIcons.refresh(iconPack), size: 20),
                  onPressed: () => notifier.refresh(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ─── 1. TORRENT STREAMING ACTIVO ─────────────────────────────
        if (hasTorrentStream) ...[
          SettingsSectionHeader(title: l10n.torrentStreamDownload),
          const SizedBox(height: 8),
          _buildTorrentStreamCard(context, ref, streamStatus, l10n, iconPack, theme, notifier),
          const SizedBox(height: 20),
        ],

        // ─── 2. TORRENTS DE CLIENTE (QBITTORRENT / SEANIME) ──────────
        if (hasClientTorrents) ...[
          SettingsSectionHeader(title: l10n.animeTorrents),
          const SizedBox(height: 8),
          ...activeState.activeTorrents.map(
            (t) => _buildClientTorrentCard(context, t, l10n, iconPack, theme, notifier),
          ),
          const SizedBox(height: 20),
        ],

        // ─── 3. COLA DE DESCARGA DE MANGA ───────────────────────────
        if (hasMangaQueue) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SettingsSectionHeader(title: l10n.mangaDownloadQueueTitle),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.pause_circle_outline_rounded, size: 20),
                    tooltip: l10n.pauseQueue,
                    onPressed: () => notifier.pauseMangaQueue(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                    tooltip: l10n.resumeQueue,
                    onPressed: () => notifier.resumeMangaQueue(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear_all_rounded, size: 20),
                    tooltip: l10n.clearQueue,
                    onPressed: () => notifier.clearMangaQueue(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...activeState.mangaQueue.map(
            (item) => _buildMangaQueueCard(context, item, l10n, iconPack, theme),
          ),
        ],
      ],
    );
  }

  Widget _buildTorrentStreamCard(
    BuildContext context,
    WidgetRef ref,
    TorrentStreamStatus status,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    ActiveDownloadsNotifier notifier,
  ) {
    final progress = (status.progressPercentage / 100.0).clamp(0.0, 1.0);
    final isPaused = status.downloadSpeed.isEmpty ||
        status.downloadSpeed == '0 B/s' ||
        status.downloadSpeed == '0.0 B/s';

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppIcons.stream(iconPack),
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.torrentStreamDownload,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${status.size} • ${status.seeders} seeders',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
                  tooltip: isPaused ? l10n.resumeDownload : l10n.pauseDownload,
                  onPressed: () {
                    if (isPaused) {
                      notifier.resumeTorrentStream();
                    } else {
                      notifier.pauseTorrentStream();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  tooltip: l10n.cancelOrDeleteDownload,
                  onPressed: () => notifier.dropTorrentStream(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
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
                  '${status.progressPercentage.toStringAsFixed(1)}%',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  '↓ ${status.downloadSpeed.isEmpty ? "0 B/s" : status.downloadSpeed}   ↑ ${status.uploadSpeed.isEmpty ? "0 B/s" : status.uploadSpeed}',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientTorrentCard(
    BuildContext context,
    Map<String, dynamic> item,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    ActiveDownloadsNotifier notifier,
  ) {
    final name = (item['name'] as String?) ?? 'Torrent';
    final hash = (item['hash'] as String?) ?? '';
    final progressVal = ((item['progress'] as num?)?.toDouble() ?? 0.0);
    final progress = (progressVal > 1.0 ? progressVal / 100.0 : progressVal).clamp(0.0, 1.0);
    final downSpeed = (item['downloadSpeed'] as String?) ?? '';
    final status = (item['status'] as String?) ?? '';
    final isPaused = status.toLowerCase().contains('pause');

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hash.isNotEmpty) ...[
                  IconButton(
                    icon: Icon(
                      isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: () => notifier.performTorrentClientAction(
                      hash,
                      isPaused ? 'resume' : 'pause',
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    onPressed: () => notifier.performTorrentClientAction(hash, 'remove'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                ),
                if (downSpeed.isNotEmpty)
                  Text(
                    '↓ $downSpeed',
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
            ],
          ),
        ],
      ),
    ));
  }

  Widget _buildMangaQueueCard(
    BuildContext context,
    dynamic item,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
  ) {
    String title = 'Manga Chapter';
    String status = 'queued';

    if (item is Map<String, dynamic>) {
      final chNum = item['chapterNumber']?.toString() ?? '';
      final provider = item['provider']?.toString() ?? '';
      title = '${l10n.chapter} $chNum ($provider)';
      status = item['status']?.toString() ?? 'queued';
    }

    final isDownloading = status == 'downloading';

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isDownloading ? Icons.downloading_rounded : Icons.schedule_rounded,
              size: 20,
              color: isDownloading ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDownloading
                    ? theme.colorScheme.primary.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDownloading
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
