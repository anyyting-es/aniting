import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'desktop_episode_models.dart';

/// Envoltura para tarjetas de episodios en desktop que añade un menú contextual
/// de vidrio líquido `g1455` (GlassCard) bajo demanda al hacer clic derecho (secondary click).
/// No monta instancias persistentes de OverlayPortal dentro de GridView para evitar colisiones
/// de semántica y layouts.
class DesktopEpisodeContextMenu extends ConsumerWidget {
  final DesktopEpisodeItemData ep;
  final int mediaId;
  final AnimeDetails? details;
  final Widget child;
  final ValueChanged<DesktopEpisodeItemData> onEpisodeClicked;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  })? onOpenTorrentSelector;
  final VoidCallback? onRefreshLocal;

  const DesktopEpisodeContextMenu({
    super.key,
    required this.ep,
    required this.mediaId,
    required this.details,
    required this.child,
    required this.onEpisodeClicked,
    this.onOpenTorrentSelector,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ep.isWatched
                ? l10n.markedAsUnwatched(ep.number)
                : l10n.markedAsWatched(ep.number),
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteDownloaded(BuildContext context, WidgetRef ref) async {
    final l10n = ref.read(translationsProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteDownload),
        content: Text(l10n.deleteEpisodeDownloadConfirm(ep.number)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final repo = ref.read(repositoryProvider);
      final messenger = ScaffoldMessenger.of(context);
      final path = ep.localFilePath;
      if (path != null && path.isNotEmpty) {
        await repo.deleteLocalFiles([path]);
        try {
          final f = File(path);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      onRefreshLocal?.call();
      ref.invalidate(downloadedAnimeProvider);
      ref.read(activeDownloadsProvider.notifier).refresh();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.downloadDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showContextMenu(
    BuildContext context,
    WidgetRef ref,
    Offset position,
  ) {
    final l10n = ref.read(translationsProvider);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;

    const menuWidth = 230.0;
    final itemCount =
        2 + (ep.isDownloaded || onOpenTorrentSelector != null ? 1 : 0);
    final menuHeight = (itemCount * 44.0) + 16.0;

    final left = (position.dx + menuWidth > screenSize.width - 16)
        ? (screenSize.width - menuWidth - 16).clamp(16.0, screenSize.width)
        : position.dx.clamp(16.0, screenSize.width - menuWidth - 16);

    final top = (position.dy + menuHeight > screenSize.height - 16)
        ? (screenSize.height - menuHeight - 16).clamp(16.0, screenSize.height)
        : position.dy.clamp(16.0, screenSize.height - menuHeight - 16);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.12),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogCtx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: GlassCard(
                  borderRadius: BorderRadius.circular(16),
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                  child: SizedBox(
                    width: menuWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DesktopContextMenuItem(
                          icon: Icons.play_arrow_rounded,
                          label: l10n.playEpisode,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            onEpisodeClicked(ep);
                          },
                        ),
                        _DesktopContextMenuItem(
                          icon: ep.isWatched
                              ? Icons.remove_done_rounded
                              : Icons.check_circle_outline_rounded,
                          label: ep.isWatched
                              ? l10n.markAsUnwatched
                              : l10n.markAsWatched,
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            _toggleWatched(context, ref);
                          },
                        ),
                        if (ep.isDownloaded)
                          _DesktopContextMenuItem(
                            icon: Icons.delete_outline_rounded,
                            label: l10n.deleteDownload,
                            isDestructive: true,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              _deleteDownloaded(context, ref);
                            },
                          )
                        else if (onOpenTorrentSelector != null)
                          _DesktopContextMenuItem(
                            icon: Icons.download_rounded,
                            label: l10n.downloadEpisode,
                            onTap: () {
                              Navigator.pop(dialogCtx);
                              onOpenTorrentSelector!(
                                episodeNumber: ep.number,
                                episodeTitle: ep.title,
                                aniDBEpisode: ep.aniDBEpisode,
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            alignment: Alignment.topLeft,
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (details) =>
          _showContextMenu(context, ref, details.globalPosition),
      child: child,
    );
  }
}

class _DesktopContextMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _DesktopContextMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  State<_DesktopContextMenuItem> createState() =>
      _DesktopContextMenuItemState();
}

class _DesktopContextMenuItemState extends State<_DesktopContextMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = DefaultTextStyle.of(context).style.color ??
        (isDark ? Colors.white : Colors.black87);
    final foregroundColor = widget.isDestructive
        ? theme.colorScheme.error
        : (_isHovered ? theme.colorScheme.primary : labelColor);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDestructive
                    ? theme.colorScheme.error.withValues(alpha: 0.12)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.07)))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                widget.icon,
                size: 18,
                color: widget.isDestructive
                    ? theme.colorScheme.error
                    : (_isHovered
                        ? theme.colorScheme.primary
                        : (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black87)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                    color: foregroundColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
