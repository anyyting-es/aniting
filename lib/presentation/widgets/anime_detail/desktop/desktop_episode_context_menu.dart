import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast.dart';
import 'desktop_episode_models.dart';

/// Menú de tres puntitos con Liquid Glass `g1455` (GlassMenuAnchor)
/// que se desprende suavemente del botón con la animación fluida de iOS 26.
class DesktopEpisodeMenuButton extends ConsumerWidget {
  final DesktopEpisodeItemData ep;
  final int mediaId;
  final AnimeDetails? details;
  final ValueChanged<DesktopEpisodeItemData> onEpisodeClicked;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  })? onOpenTorrentSelector;
  final VoidCallback? onDownloadOnline;
  final VoidCallback? onRefreshLocal;

  const DesktopEpisodeMenuButton({
    super.key,
    required this.ep,
    required this.mediaId,
    required this.details,
    required this.onEpisodeClicked,
    this.onOpenTorrentSelector,
    this.onDownloadOnline,
    this.onRefreshLocal,
  });

  Future<void> _toggleWatched(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final targetNumber =
        ep.isWatched ? (ep.number > 1 ? ep.number - 1 : 0) : ep.number;
    final success = await repo.updateAnimeProgress(
      mediaId: mediaId,
      episodeNumber: targetNumber,
      totalEpisodes: details?.totalEpisodes ?? 0,
    );
    if (success && context.mounted) {
      ref.invalidate(animeCollectionProvider);
      AppToast.info(
        ep.isWatched
            ? l10n.markedAsUnwatched(ep.number)
            : l10n.markedAsWatched(ep.number),
        context: context,
      );
    }
  }

  Future<void> _deleteDownloaded(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(translationsProvider);
    final confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => GlassAlert(
        title: Text(l10n.deleteDownload, textAlign: TextAlign.center),
        message: Text(
          l10n.deleteEpisodeDownloadConfirm(ep.number),
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
      var path = ep.localFilePath;
      if (path == null || path.isEmpty) {
        final history = ref.read(downloadHistoryProvider);
        for (final item in history) {
          if (item.mediaId == mediaId && (item.id == '${mediaId}_${ep.number}' || item.id == '${ep.number}')) {
            path = item.filePath;
            break;
          }
        }
      }
      if (path != null && path.isNotEmpty) {
        await repo.deleteLocalFiles([path]);
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      ref.read(downloadHistoryProvider.notifier).removeItem('${mediaId}_${ep.number}');
      onRefreshLocal?.call();
      ref.invalidate(downloadedAnimeProvider);
      ref.invalidate(animeLibraryEntryProvider(mediaId));
      ref.read(activeDownloadsProvider.notifier).refresh();
      AppToast.success(l10n.downloadDeleted);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final items = <GlassMenuItem>[
      GlassMenuItem(
        label: l10n.playEpisode,
        icon: Icon(AppIcons.play(iconPack), size: 18),
        onPressed: () => onEpisodeClicked(ep),
      ),
      GlassMenuItem(
        label: ep.isWatched ? l10n.markAsUnwatched : l10n.markAsWatched,
        icon: Icon(
          ep.isWatched
              ? AppIcons.removeDone(iconPack)
              : AppIcons.checkCircle(iconPack),
          size: 18,
        ),
        onPressed: () => _toggleWatched(context, ref),
      ),
      if (ep.isDownloaded)
        GlassMenuItem(
          label: l10n.deleteDownload,
          isDestructive: true,
          icon: Icon(AppIcons.trash(iconPack), size: 18),
          onPressed: () => _deleteDownloaded(context, ref),
        )
      else if (onDownloadOnline != null)
        GlassMenuItem(
          label: l10n.downloadEpisode,
          icon: Icon(AppIcons.download(iconPack), size: 18),
          onPressed: onDownloadOnline!,
        )
      else if (onOpenTorrentSelector != null)
        GlassMenuItem(
          label: l10n.downloadEpisode,
          icon: Icon(AppIcons.download(iconPack), size: 18),
          onPressed: () => onOpenTorrentSelector!(
            episodeNumber: ep.number,
            episodeTitle: ep.title,
            aniDBEpisode: ep.aniDBEpisode,
          ),
        ),
    ];

    return GlassMenuAnchor(
      width: 220,
      items: items,
      builder: (context, controller) {
        return _EpisodeThreeDotsButton(
          isOpen: controller.isOpen,
          onTap: controller.open,
          isDark: isDark,
          icon: AppIcons.moreHoriz(iconPack),
        );
      },
    );
  }
}

class _EpisodeThreeDotsButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;
  final bool isDark;
  final IconData icon;

  const _EpisodeThreeDotsButton({
    required this.isOpen,
    required this.onTap,
    required this.isDark,
    required this.icon,
  });

  @override
  State<_EpisodeThreeDotsButton> createState() =>
      _EpisodeThreeDotsButtonState();
}

class _EpisodeThreeDotsButtonState extends State<_EpisodeThreeDotsButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHoveredOrOpen = _isHovered || widget.isOpen;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: isHoveredOrOpen
                  ? (widget.isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.icon,
              size: 19,
              color: isHoveredOrOpen
                  ? theme.colorScheme.primary
                  : (widget.isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ),
      ),
    );
  }
}
