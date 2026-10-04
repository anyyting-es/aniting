import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/storage/app_storage_paths.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_subpage_scaffold.dart';

class DownloadManagerScreen extends ConsumerWidget {
  final bool isEmbedded;

  const DownloadManagerScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    final streamStatus = ref.watch(torrentStreamStatusProvider);
    final activeState = ref.watch(activeDownloadsProvider);
    final historyItems = ref.watch(downloadHistoryProvider);
    final activeNotifier = ref.read(activeDownloadsProvider.notifier);
    final historyNotifier = ref.read(downloadHistoryProvider.notifier);

    // Separate truly in-progress torrents from completed / seeding torrents
    final inProgressTorrents = <Map<String, dynamic>>[];
    final completedTorrents = <Map<String, dynamic>>[];

    for (final t in activeState.activeTorrents) {
      final rawProgress = t['progress'];
      double p = 0.0;
      if (rawProgress is num) {
        p = rawProgress.toDouble();
      } else if (rawProgress is String) {
        p = double.tryParse(rawProgress.replaceAll('%', '').trim()) ?? 0.0;
      }
      if (p > 1.0) p /= 100.0;

      final status = (t['status']?.toString() ?? '').toLowerCase();
      final isDone = p >= 0.999 || status == 'completed' || status == 'seeding';
      if (isDone) {
        completedTorrents.add(t);
      } else {
        inProgressTorrents.add(t);
      }
    }

    final isStreamFinished = streamStatus == null ||
        streamStatus.isComplete ||
        streamStatus.progressPercentage >= 99.9;

    final hasActiveTorrentStream = streamStatus != null &&
        streamStatus.downloadProgress > 0 &&
        !isStreamFinished;

    final hasClientTorrents = inProgressTorrents.isNotEmpty;
    final hasMangaQueue = activeState.mangaQueue.isNotEmpty;
    final hasAnyActive = hasActiveTorrentStream || hasClientTorrents || hasMangaQueue;

    final activeCount = (hasActiveTorrentStream ? 1 : 0) +
        inProgressTorrents.length +
        activeState.mangaQueue.length;

    return PixelSubpageScaffold(
      title: l10n.downloadManager,
      isEmbedded: isEmbedded,
      children: [
        // ─── 1. TOP HEADER SUMMARY & REFRESH ───────────────────────────
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
                    color: hasAnyActive
                        ? theme.colorScheme.primary.withValues(alpha: 0.16)
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    hasAnyActive ? AppIcons.downloading(iconPack) : AppIcons.downloadOffline(iconPack),
                    size: 20,
                    color: hasAnyActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadManager,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasAnyActive
                            ? '$activeCount ${l10n.activeDownloadsCount.toLowerCase()}'
                            : l10n.noActiveDownloads,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasAnyActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          fontWeight: hasAnyActive ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.openDownloadsFolder,
                  icon: Icon(AppIcons.folderOpen(iconPack), size: 20),
                  onPressed: () async {
                    final dir = await AppStoragePaths.getDownloadsDirectory();
                    await AppStoragePaths.openDirectoryInFileManager(dir.path);
                  },
                ),
                IconButton(
                  tooltip: l10n.refreshDownloadsTooltip,
                  icon: Icon(AppIcons.refresh(iconPack), size: 20),
                  onPressed: () => activeNotifier.refresh(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ─── 2. ACTIVE DOWNLOADS SECTION (VIBRANT FULL-COLOR) ──────────
        SettingsSectionHeader(title: l10n.activeDownloads),
        const SizedBox(height: 8),

        if (!hasAnyActive)
          _buildEmptyActiveState(context, l10n, iconPack, theme)
        else ...[
          // 2.1 Torrent Stream (P2P Direct Stream)
          if (hasActiveTorrentStream) ...[
            _buildActiveTorrentStreamCard(context, streamStatus, l10n, iconPack, theme, activeNotifier),
            const SizedBox(height: 10),
          ],

          // 2.2 Client Torrents (qBittorrent / Seanime Client)
          if (hasClientTorrents) ...[
            ...inProgressTorrents.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildActiveClientTorrentCard(context, t, l10n, iconPack, theme, activeNotifier),
              ),
            ),
          ],

          // 2.3 Manga Download Queue
          if (hasMangaQueue) ...[
            _buildMangaQueueHeader(context, l10n, iconPack, activeNotifier),
            const SizedBox(height: 6),
            ...activeState.mangaQueue.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildActiveMangaQueueCard(context, item, l10n, iconPack, theme),
              ),
            ),
          ],
        ],

        // ─── 2.5 COMPLETED / SEEDING CLIENT TORRENTS ─────────────────
        if (completedTorrents.isNotEmpty) ...[
          const SizedBox(height: 20),
          SettingsSectionHeader(title: l10n.completedDownloads),
          const SizedBox(height: 8),
          ...completedTorrents.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildCompletedClientTorrentCard(context, t, l10n, iconPack, theme, activeNotifier),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // ─── 3. DOWNLOAD HISTORY SECTION (SEMI-OPAQUE / SUBTLE) ────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SettingsSectionHeader(title: l10n.downloadHistory),
            if (historyItems.isNotEmpty)
              TextButton.icon(
                onPressed: () => _confirmClearHistory(context, l10n, historyNotifier),
                icon: Icon(AppIcons.deleteSweep(iconPack), size: 16),
                label: Text(l10n.clearHistory, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurfaceVariant,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        if (historyItems.isEmpty)
          _buildEmptyHistoryState(context, l10n, iconPack, theme)
        else
          ...historyItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildDimmedHistoryCard(context, item, l10n, iconPack, theme, historyNotifier),
            ),
          ),

        const SizedBox(height: 40),
      ],
    );
  }

  // ─── EMPTY ACTIVE STATE ───────────────────────────────────────────
  Widget _buildEmptyActiveState(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
  ) {
    return PixelCardContainer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.cloudDone(iconPack),
              size: 28,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.noActiveDownloads,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.noActiveDownloadsDesc,
                    style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── ACTIVE TORRENT STREAM CARD (FULL VIBRANT COLOR & METRICS) ─────
  Widget _buildActiveTorrentStreamCard(
    BuildContext context,
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

    final etaText = status.etaString;

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.4),
            width: 1.2,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
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
                    isPaused ? AppIcons.play(iconPack) : AppIcons.pause(iconPack),
                    color: theme.colorScheme.primary,
                    size: 24,
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
                    AppIcons.close(iconPack),
                    color: theme.colorScheme.error,
                    size: 22,
                  ),
                  tooltip: l10n.cancelOrDeleteDownload,
                  onPressed: () => notifier.dropTorrentStream(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 8),

            // Metrics Row: Percentage, Download/Total, Speed, ETA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${status.progressPercentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${status.formattedDownloaded} / ${status.size})',
                      style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
                Text(
                  '↓ ${status.downloadSpeed.isEmpty ? "0 B/s" : status.downloadSpeed}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Secondary metrics row: Upload speed & ETA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (etaText != '--')
                  Text(
                    l10n.etaLabel(etaText),
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.primary.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  '↑ ${status.uploadSpeed.isEmpty ? "0 B/s" : status.uploadSpeed}',
                  style: TextStyle(
                    fontSize: 11,
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

  // ─── ACTIVE CLIENT TORRENT CARD ───────────────────────────────────
  Widget _buildActiveClientTorrentCard(
    BuildContext context,
    Map<String, dynamic> item,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    ActiveDownloadsNotifier notifier,
  ) {
    final name = item['name']?.toString() ?? 'Torrent';
    final hash = item['hash']?.toString() ?? '';

    // Safe progress parsing (handles num or String, 0..1.0 or 0..100)
    final rawProgress = item['progress'];
    double progressVal = 0.0;
    if (rawProgress is num) {
      progressVal = rawProgress.toDouble();
    } else if (rawProgress is String) {
      progressVal = double.tryParse(rawProgress.replaceAll('%', '').trim()) ?? 0.0;
    }
    final progress = (progressVal > 1.0 ? progressVal / 100.0 : progressVal).clamp(0.0, 1.0);

    // Safe download speed parsing (handles downSpeed, downloadSpeed, dlspeed as String or num)
    final rawSpeed = item['downSpeed'] ?? item['downloadSpeed'] ?? item['dlspeed'];
    String downSpeed = '';
    if (rawSpeed is String) {
      downSpeed = rawSpeed.trim();
    } else if (rawSpeed is num && rawSpeed > 0) {
      downSpeed = '${_formatBytesLocal(rawSpeed.toInt())}/s';
    }

    final status = item['status']?.toString() ?? '';
    final isPaused = status.toLowerCase().contains('pause');

    // Safe size & downloaded computation (handles String like "1.5 GiB" or num in bytes)
    final rawSize = item['size'];
    final rawDownloaded = item['downloaded'];
    String sizeLabel = '';

    if (rawSize is String && rawSize.trim().isNotEmpty) {
      final s = rawSize.trim();
      if (rawDownloaded is String && rawDownloaded.trim().isNotEmpty) {
        sizeLabel = '(${rawDownloaded.trim()} / $s)';
      } else {
        sizeLabel = '($s)';
      }
    } else if (rawSize is num && rawSize > 0) {
      final totalBytes = rawSize.toInt();
      final downloadedBytes = (rawDownloaded is num)
          ? rawDownloaded.toInt()
          : (totalBytes * progress).round();
      sizeLabel = '(${_formatBytesLocal(downloadedBytes)} / ${_formatBytesLocal(totalBytes)})';
    }

    // Safe ETA computation (handles String like "12m 30s" or num in seconds)
    final rawEta = item['eta'];
    String etaStr = '';
    if (rawEta is String) {
      final e = rawEta.trim();
      if (e.isNotEmpty && e != '8640000' && e != '0s' && e != '0' && e != '∞') {
        etaStr = e;
      }
    } else if (rawEta is num) {
      final etaSecs = rawEta.toInt();
      if (etaSecs > 0 && etaSecs < 86400 * 7) {
        if (etaSecs < 60) {
          etaStr = '${etaSecs}s';
        } else if (etaSecs < 3600) {
          etaStr = '${etaSecs ~/ 60}m ${etaSecs % 60}s';
        } else {
          etaStr = '${etaSecs ~/ 3600}h ${(etaSecs % 3600) ~/ 60}m';
        }
      }
    }

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.1,
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
                      isPaused ? AppIcons.play(iconPack) : AppIcons.pause(iconPack),
                      size: 22,
                      color: theme.colorScheme.primary,
                    ),
                    tooltip: isPaused ? l10n.resumeDownload : l10n.pauseDownload,
                    onPressed: () => notifier.performTorrentClientAction(
                      hash,
                      isPaused ? 'resume' : 'pause',
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      AppIcons.close(iconPack),
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                    tooltip: l10n.cancelOrDeleteDownload,
                    onPressed: () => notifier.performTorrentClientAction(hash, 'remove'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(height: 6),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(progress * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (sizeLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(
                        sizeLabel,
                        style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ],
                ),
                if (downSpeed.isNotEmpty)
                  Text(
                    '↓ $downSpeed',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
              ],
            ),

            if (etaStr.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                l10n.etaLabel(etaStr),
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.primary.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── COMPLETED / SEEDING CLIENT TORRENT CARD ─────────────────────
  Widget _buildCompletedClientTorrentCard(
    BuildContext context,
    Map<String, dynamic> item,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    ActiveDownloadsNotifier notifier,
  ) {
    final name = item['name']?.toString() ?? 'Torrent';
    final hash = item['hash']?.toString() ?? '';
    final status = item['status']?.toString() ?? '';
    final isPaused = status.toLowerCase().contains('pause');

    final rawSize = item['size'];
    String sizeLabel = '';
    if (rawSize is String && rawSize.trim().isNotEmpty) {
      sizeLabel = rawSize.trim();
    } else if (rawSize is num && rawSize > 0) {
      sizeLabel = _formatBytesLocal(rawSize.toInt());
    }

    final rawUpSpeed = item['upSpeed'] ?? item['uploadSpeed'] ?? item['upspeed'];
    String upSpeed = '';
    if (rawUpSpeed is String) {
      upSpeed = rawUpSpeed.trim();
    } else if (rawUpSpeed is num && rawUpSpeed > 0) {
      upSpeed = '${_formatBytesLocal(rawUpSpeed.toInt())}/s';
    }

    return PixelCardContainer(
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.green.withValues(alpha: 0.3),
            width: 1.0,
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                AppIcons.checkCircle(iconPack),
                size: 20,
                color: Colors.greenAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isPaused ? 'Pausado' : 'Seeding',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.greenAccent,
                          ),
                        ),
                      ),
                      if (sizeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          sizeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (upSpeed.isNotEmpty && upSpeed != '0 B/s' && upSpeed != '0 KiB/s') ...[
                        const SizedBox(width: 8),
                        Text(
                          '↑ $upSpeed',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (hash.isNotEmpty) ...[
              IconButton(
                icon: Icon(
                  isPaused ? AppIcons.play(iconPack) : AppIcons.pause(iconPack),
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
                tooltip: isPaused ? l10n.resumeDownload : l10n.pauseDownload,
                onPressed: () => notifier.performTorrentClientAction(
                  hash,
                  isPaused ? 'resume' : 'pause',
                ),
              ),
              IconButton(
                icon: Icon(
                  AppIcons.close(iconPack),
                  size: 20,
                  color: theme.colorScheme.error,
                ),
                tooltip: l10n.cancelOrDeleteDownload,
                onPressed: () => notifier.performTorrentClientAction(hash, 'remove'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─── ACTIVE MANGA QUEUE CARD ──────────────────────────────────────
  Widget _buildMangaQueueHeader(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    ActiveDownloadsNotifier notifier,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SettingsSectionHeader(title: l10n.mangaDownloadQueueTitle),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(AppIcons.pauseCircle(iconPack), size: 20),
              tooltip: l10n.pauseQueue,
              onPressed: () => notifier.pauseMangaQueue(),
            ),
            IconButton(
              icon: Icon(AppIcons.playCircle(iconPack), size: 20),
              tooltip: l10n.resumeQueue,
              onPressed: () => notifier.resumeMangaQueue(),
            ),
            IconButton(
              icon: Icon(AppIcons.clearAll(iconPack), size: 20),
              tooltip: l10n.clearQueue,
              onPressed: () => notifier.clearMangaQueue(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveMangaQueueCard(
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
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDownloading
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              isDownloading ? AppIcons.downloading(iconPack) : AppIcons.clock(iconPack),
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

  // ─── DIMMED DOWNLOAD HISTORY CARD (MEDIAS OPACAS / HISTORIAL) ─────
  Widget _buildDimmedHistoryCard(
    BuildContext context,
    DownloadHistoryItem item,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
    DownloadHistoryNotifier historyNotifier,
  ) {
    final timeStr = _formatRelativeDate(item.completedAt);

    return Opacity(
      opacity: 0.76, // Semiopaco como solicitado en requerimientos
      child: PixelCardContainer(
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              // Checkmark completed badge
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  AppIcons.checkCircle(iconPack),
                  size: 20,
                  color: Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 12),

              // Title and metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                          Text(
                            item.subtitle!,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('•', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (item.size.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text('•', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant)),
                          const SizedBox(width: 6),
                          Text(
                            item.size,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Remove from history button
              IconButton(
                icon: Icon(
                  AppIcons.close(iconPack),
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                tooltip: l10n.clearHistory,
                onPressed: () => historyNotifier.removeItem(item.id),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryState(
    BuildContext context,
    AppTranslations l10n,
    AppIconPack iconPack,
    ThemeData theme,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Center(
        child: Column(
          children: [
            Icon(
              AppIcons.history(iconPack),
              size: 32,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noDownloadHistory,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.noDownloadHistoryDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmClearHistory(
    BuildContext context,
    AppTranslations l10n,
    DownloadHistoryNotifier historyNotifier,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistory),
        content: Text(l10n.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              historyNotifier.clearHistory();
              Navigator.pop(ctx);
            },
            child: Text(l10n.clear),
          ),
        ],
      ),
    );
  }

  static String _formatBytesLocal(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = bytes.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
  }

  static String _formatRelativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays}d';
    return '${dt.day.toString().padLeft(2, "0")}/${dt.month.toString().padLeft(2, "0")}/${dt.year}';
  }
}
