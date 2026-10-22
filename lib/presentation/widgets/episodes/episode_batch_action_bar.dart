import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/providers/episode_selection_provider.dart';
import 'package:seanime_app/presentation/widgets/online_stream_download_dialog.dart';
import 'package:seanime_app/presentation/widgets/online_stream_batch_download_dialog.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast.dart';

class EpisodeBatchActionBar extends ConsumerWidget {
  final int mediaId;
  final AnimeDetails? details;
  final List<int> allEpisodeNumbers;
  final Map<int, String?> downloadedMap;
  final bool isOnlineMode;
  final OnlinestreamProvider? onlineProvider;
  final bool isDubbed;
  final VoidCallback? onRefreshLocal;
  final void Function(List<int> toDownload)? onDownloadTorrents;

  const EpisodeBatchActionBar({
    super.key,
    required this.mediaId,
    this.details,
    required this.allEpisodeNumbers,
    required this.downloadedMap,
    this.isOnlineMode = false,
    this.onlineProvider,
    this.isDubbed = false,
    this.onRefreshLocal,
    this.onDownloadTorrents,
  });

  Future<void> _handleDeleteDownloaded(
    BuildContext context,
    WidgetRef ref,
    List<int> selectedNumbers,
  ) async {
    final l10n = ref.read(translationsProvider);
    final downloadedSelected = selectedNumbers
        .where((n) => downloadedMap.containsKey(n) && downloadedMap[n] != null)
        .toList();

    if (downloadedSelected.isEmpty) return;

    final confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => GlassAlert(
        title: Text(l10n.deleteDownload, textAlign: TextAlign.center),
        message: Text(
          l10n.deleteSelectedEpisodesConfirm(downloadedSelected.length),
          textAlign: TextAlign.center,
        ),
        actions: <GlassAlertAction>[
          GlassAlertAction(
            label: l10n.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GlassAlertAction(
            label: l10n.delete,
            isDestructive: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(repositoryProvider);
      final paths = downloadedSelected
          .map((n) => downloadedMap[n])
          .whereType<String>()
          .toList();

      if (paths.isNotEmpty) {
        try {
          await repo.deleteLocalFiles(paths);
        } catch (_) {}
        for (final p in paths) {
          try {
            final f = File(p);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {}
        }
      }

      final historyNotifier = ref.read(downloadHistoryProvider.notifier);
      for (final epNum in downloadedSelected) {
        historyNotifier.removeItem('${mediaId}_$epNum');
        historyNotifier.removeItem('$epNum');
      }

      onRefreshLocal?.call();
      ref.invalidate(downloadedAnimeProvider);
      ref.invalidate(animeLibraryEntryProvider(mediaId));
      ref.invalidate(animeCollectionProvider);
      ref.read(activeDownloadsProvider.notifier).refresh();
      ref.read(episodeSelectionProvider(mediaId).notifier).clear();

      if (context.mounted) {
        AppToast.success(l10n.downloadDeleted, context: context);
      }
    }
  }

  Future<void> _handleBatchDownload(
    BuildContext context,
    WidgetRef ref,
    List<int> selectedNumbers,
  ) async {
    final l10n = ref.read(translationsProvider);
    final toDownload =
        selectedNumbers.where((n) => !downloadedMap.containsKey(n)).toList()
          ..sort();

    if (toDownload.isEmpty) return;

    if (!isOnlineMode) {
      if (onDownloadTorrents != null) {
        onDownloadTorrents!(toDownload);
        ref.read(episodeSelectionProvider(mediaId).notifier).clear();
        return;
      }
    }

    if (toDownload.length == 1) {
      final epNum = toDownload.first;
      final epThumb = details?.aniZipData?.episodes
          .where((e) => e.episodeNumber == epNum)
          .firstOrNull
          ?.image;
      showOnlineStreamDownloadDialog(
        context,
        mediaId: mediaId,
        episodeNumber: epNum,
        animeTitle: details?.title ?? 'Anime',
        episodeTitle: l10n.episodeNumber(epNum),
        thumbnail: epThumb,
        provider: onlineProvider,
        isDubbed: isDubbed,
      );
      ref.read(episodeSelectionProvider(mediaId).notifier).clear();
      return;
    }

    // Open batch download dialog with multi-source color assignments
    showOnlineStreamBatchDownloadDialog(
      context,
      mediaId: mediaId,
      animeTitle: details?.title ?? 'Anime',
      episodeNumbers: toDownload,
      aniZipData: details?.aniZipData,
      initialProvider: onlineProvider,
      isDubbed: isDubbed,
    );
    ref.read(episodeSelectionProvider(mediaId).notifier).clear();
  }

  Future<void> _handleBatchMarkWatched(
    BuildContext context,
    WidgetRef ref,
    List<int> selectedNumbers, {
    required bool markAsWatched,
  }) async {
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    final targetEpisode = markAsWatched
        ? (selectedNumbers.isEmpty
              ? 0
              : selectedNumbers.reduce((a, b) => a > b ? a : b))
        : (selectedNumbers.isEmpty
                  ? 0
                  : selectedNumbers.reduce((a, b) => a < b ? a : b) - 1)
              .clamp(0, 9999);

    final ok = await repo.updateAnimeProgress(
      mediaId: mediaId,
      episodeNumber: targetEpisode,
      totalEpisodes: details?.totalEpisodes ?? 0,
    );

    if (ok && context.mounted) {
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(animeLibraryEntryProvider(mediaId));
      ref.read(episodeSelectionProvider(mediaId).notifier).clear();
      AppToast.info(
        markAsWatched
            ? l10n.markedAsWatched(targetEpisode)
            : l10n.markedAsUnwatched(targetEpisode + 1),
        context: context,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(episodeSelectionProvider(mediaId));
    final notifier = ref.read(episodeSelectionProvider(mediaId).notifier);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassEnabled = ref.watch(glassEffectsEnabledProvider);

    final isVisible = selection.isSelectionMode;
    final selectedList = selection.selectedNumbers.toList();
    final downloadedCount = selectedList
        .where((n) => downloadedMap.containsKey(n) && downloadedMap[n] != null)
        .length;
    final notDownloadedCount = selectedList
        .where((n) => !downloadedMap.containsKey(n) || downloadedMap[n] == null)
        .length;

    final isAllSelected =
        allEpisodeNumbers.isNotEmpty &&
        selection.selectedNumbers.length >= allEpisodeNumbers.length;

    return IgnorePointer(
      ignoring: !isVisible,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 1.4),
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: isVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeInOut,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
                if (glassEnabled)
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: GlassCard(
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: glassEnabled
                        ? (isDark
                            ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.38)
                            : theme.colorScheme.surfaceContainer.withValues(alpha: 0.52))
                        : theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: glassEnabled ? 0.20 : 0.12)
                          : theme.colorScheme.outlineVariant.withValues(alpha: glassEnabled ? 0.45 : 0.25),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Cancel / Close selection button
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        tooltip: l10n.close,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          notifier.clear();
                        },
                      ),
                      const SizedBox(width: 4),

                      // Selected count pill badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          l10n.selectedEpisodesCount(selection.count),
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Select all / Deselect toggle
                      IconButton(
                        icon: Icon(
                          isAllSelected
                              ? AppIcons.removeDone(iconPack)
                              : Icons.select_all_rounded,
                          size: 20,
                        ),
                        tooltip: isAllSelected ? l10n.deselectAll : l10n.selectAll,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          if (isAllSelected) {
                            notifier.clear();
                          } else {
                            notifier.selectAll(allEpisodeNumbers);
                          }
                        },
                      ),

                      const Spacer(),

                      // Action: Download
                      if (notDownloadedCount > 0) ...[
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                          ),
                          icon: Icon(AppIcons.download(iconPack), size: 16),
                          label: Text(
                            l10n.downloadCount(notDownloadedCount),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _handleBatchDownload(context, ref, selectedList);
                          },
                        ),
                        const SizedBox(width: 6),
                      ],

                      // Action: Delete downloaded
                      if (downloadedCount > 0) ...[
                        IconButton(
                          icon: Icon(
                            AppIcons.trash(iconPack),
                            size: 20,
                            color: theme.colorScheme.error,
                          ),
                          tooltip: l10n.deleteCount(downloadedCount),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _handleDeleteDownloaded(context, ref, selectedList);
                          },
                        ),
                        const SizedBox(width: 4),
                      ],

                      // Action: Mark as watched
                      IconButton(
                        icon: Icon(AppIcons.checkCircle(iconPack), size: 20),
                        tooltip: l10n.markWatched,
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _handleBatchMarkWatched(
                            context,
                            ref,
                            selectedList,
                            markAsWatched: true,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

