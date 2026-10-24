import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

enum _DesktopSourceMode {
  local,
  online,
  torrent,
}

class DesktopActionBar extends ConsumerStatefulWidget {
  final int mediaId;
  final String title;
  final int progress;
  final int? idMal;
  final String? trailerId;
  final String? trailerSite;
  final bool hasTrailer;
  final AnimeDetailTab currentTab;
  final bool onlineEnabled;
  final bool torrentEnabled;
  final bool isTmdb;
  final bool isMovie;
  final String? userStatus;
  final int? totalEpisodes;
  final VoidCallback onPlayNext;
  final void Function(String title) onOpenEditEntryModal;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final VoidCallback? onDownload;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final VoidCallback? onToggleLocalMode;
  final void Function(String mode)? onModeChanged;

  const DesktopActionBar({
    super.key,
    required this.mediaId,
    required this.title,
    required this.progress,
    required this.idMal,
    this.trailerId,
    this.trailerSite,
    this.hasTrailer = false,
    required this.currentTab,
    required this.onlineEnabled,
    required this.torrentEnabled,
    this.isTmdb = false,
    this.isMovie = false,
    this.userStatus,
    this.totalEpisodes,
    required this.onPlayNext,
    required this.onOpenEditEntryModal,
    required this.onTabChanged,
    this.onDownload,
    this.isLocalMode = false,
    this.hasLocalFiles = false,
    this.onToggleLocalMode,
    this.onModeChanged,
  });

  @override
  ConsumerState<DesktopActionBar> createState() => _DesktopActionBarState();
}

class _DesktopActionBarState extends ConsumerState<DesktopActionBar> {
  bool _isExpanded = false;

  Future<void> _launchTmdb(int mediaId) async {
    try {
      await launchUrlString(
        'https://www.themoviedb.org/${widget.isMovie ? "movie" : "tv"}/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _shareAnime(BuildContext context, String title, AppTranslations l10n) {
    final shareUrl = widget.isTmdb
        ? 'https://www.themoviedb.org/${widget.isMovie ? "movie" : "tv"}/${widget.mediaId}'
        : 'https://anilist.co/anime/${widget.mediaId}';
    Clipboard.setData(ClipboardData(text: shareUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.linkCopiedFor(title)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _updateStatus(
    BuildContext context,
    String newStatus,
  ) async {
    final repo = ref.read(repositoryProvider);
    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final l10n = ref.read(translationsProvider);

    if (isLoggedIn && !widget.isTmdb) {
      await repo.editAnilistListEntry(
        mediaId: widget.mediaId,
        type: 'anime',
        status: newStatus,
        progress: widget.progress,
      );
    }

    await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
      mediaId: widget.mediaId,
      title: widget.title,
      status: newStatus,
      progress: widget.progress,
      totalCount: widget.totalEpisodes,
      isTmdb: widget.isTmdb,
    );

    if (context.mounted) {
      ref.invalidate(animeCollectionProvider);
      ref.invalidate(continueWatchingProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.settingsSaved),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    // Dynamic Reactive Play Label
    final String playLabel;
    if (widget.userStatus == 'COMPLETED') {
      playLabel = l10n.rewatch;
    } else if (widget.progress > 0) {
      final nextEp = (widget.progress + 1).clamp(1, widget.totalEpisodes ?? (widget.progress + 1));
      playLabel = l10n.continueEpisodeNumbered(nextEp);
    } else {
      playLabel = l10n.watchEpisodeOne;
    }

    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Reactive Play Button (Same standard height as all buttons, contracts horizontally on expand)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  constraints: BoxConstraints(
                    minWidth: _isExpanded ? 130 : 200,
                    maxWidth: _isExpanded ? 165 : 240,
                  ),
                  child: M3EButton.icon(
                    style: M3EButtonStyle.filled,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    icon: Icon(AppIcons.play(iconPack), size: 18),
                    label: Text(
                      playLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    onPressed: widget.isTmdb
                        ? () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(AppIcons.info(iconPack),
                                        color: Colors.white, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(l10n.streamingComingSoon)),
                                  ],
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        : widget.onPlayNext,
                  ),
                ),
                const SizedBox(width: 8),

        // Quick Action 1: Status / Bookmark Dropdown (Always visible)
        GlassMenuAnchor(
          width: 210,
          items: [
            GlassMenuItem(
              label: l10n.statusWatching,
              icon: Icon(
                AppIcons.playCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFF10B981),
              ),
              onPressed: () => _updateStatus(context, 'CURRENT'),
            ),
            GlassMenuItem(
              label: l10n.statusPlanning,
              icon: Icon(
                AppIcons.bookmarkAdded(iconPack),
                size: 18,
                color: const Color(0xFF3B82F6),
              ),
              onPressed: () => _updateStatus(context, 'PLANNING'),
            ),
            GlassMenuItem(
              label: l10n.statusCompleted,
              icon: Icon(
                AppIcons.checkCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFF8B5CF6),
              ),
              onPressed: () => _updateStatus(context, 'COMPLETED'),
            ),
            GlassMenuItem(
              label: l10n.statusPaused,
              icon: Icon(
                AppIcons.pauseCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFFF59E0B),
              ),
              onPressed: () => _updateStatus(context, 'PAUSED'),
            ),
            GlassMenuItem(
              label: l10n.statusDropped,
              icon: Icon(
                AppIcons.cancel(iconPack),
                size: 18,
                color: const Color(0xFFEF4444),
              ),
              onPressed: () => _updateStatus(context, 'DROPPED'),
            ),
            if (!widget.isTmdb)
              GlassMenuItem(
                label: l10n.editDetails,
                icon: Icon(
                  AppIcons.edit(iconPack),
                  size: 18,
                ),
                onPressed: () => widget.onOpenEditEntryModal(widget.title),
              ),
          ],
          builder: (context, controller) {
            return M3EIconButton(
              tooltip: widget.isTmdb ? l10n.editDetails : l10n.editInAnilist,
              icon: Icon(AppIcons.edit(iconPack), size: 18),
              variant: M3EIconButtonVariant.tonal,
              size: M3EIconButtonSize.sm,
              onPressed: controller.open,
            );
          },
        ),
        const SizedBox(width: 8),

        // Quick Action 2: Expand / Collapse Toggle Button
        Tooltip(
          message: _isExpanded ? l10n.collapse : l10n.moreOptions,
          child: M3EIconButton(
            icon: AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 220),
              child: Icon(
                _isExpanded ? AppIcons.chevronLeft(iconPack) : AppIcons.moreHoriz(iconPack),
                size: 18,
              ),
            ),
            variant: _isExpanded ? M3EIconButtonVariant.filled : M3EIconButtonVariant.tonal,
            size: M3EIconButtonSize.sm,
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
          ),
        ),

        // ─── Collapsible Secondary Actions (Smoothly reveals on expand) ───
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          child: _isExpanded
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8),

                    // Share Button
                    M3EIconButton(
                      tooltip: l10n.share,
                      icon: Icon(AppIcons.share(iconPack), size: 18),
                      variant: M3EIconButtonVariant.tonal,
                      size: M3EIconButtonSize.sm,
                      onPressed: () => _shareAnime(context, widget.title, l10n),
                    ),

                    // Download Button (Torrents modal - Anime only)
                    if (!widget.isTmdb && widget.onDownload != null) ...[
                      const SizedBox(width: 8),
                      M3EIconButton(
                        tooltip: l10n.downloadWithTorrentClient,
                        icon: Icon(AppIcons.download(iconPack), size: 18),
                        variant: M3EIconButtonVariant.tonal,
                        size: M3EIconButtonSize.sm,
                        onPressed: widget.onDownload!,
                      ),
                    ],

                    // External Link (TMDB)
                    if (widget.isTmdb) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'The Movie Database (TMDB)',
                        child: M3EIconButton(
                          icon: Icon(AppIcons.openInNew(iconPack), size: 18),
                          variant: M3EIconButtonVariant.tonal,
                          size: M3EIconButtonSize.sm,
                          onPressed: () => _launchTmdb(widget.mediaId),
                        ),
                      ),
                    ],
                  ],
                )
              : const SizedBox.shrink(),
        ),
              ],
            ),
          ),
        ),

        // Source Mode Toggle (Local / Online / Torrent) with GlassSegmentedControl (Anime only)
        if (!widget.isTmdb) ...[
          const SizedBox(width: 12),
          () {
            final availableModes = <_DesktopSourceMode>[
              if (widget.hasLocalFiles) _DesktopSourceMode.local,
              if (widget.onlineEnabled) _DesktopSourceMode.online,
              if (widget.torrentEnabled) _DesktopSourceMode.torrent,
            ];

            if (availableModes.length < 2) return const SizedBox.shrink();

            final _DesktopSourceMode activeMode = widget.isLocalMode
                ? _DesktopSourceMode.local
                : (widget.currentTab == AnimeDetailTab.online
                    ? _DesktopSourceMode.online
                    : _DesktopSourceMode.torrent);
            final rawIndex = availableModes.indexOf(activeMode);
            final selectedIndex = rawIndex >= 0 ? rawIndex : 0;

            final totalWidth = availableModes.length >= 3 ? 310.0 : 220.0;

            return SizedBox(
              width: totalWidth,
              child: GlassSegmentedControl(
                selectedIndex: selectedIndex,
                onSelected: (index) {
                  final mode = availableModes[index];
                  if (widget.onModeChanged != null) {
                    widget.onModeChanged!(mode.name);
                  } else {
                    switch (mode) {
                      case _DesktopSourceMode.local:
                        if (!widget.isLocalMode) widget.onToggleLocalMode?.call();
                        break;
                      case _DesktopSourceMode.online:
                        if (widget.isLocalMode) widget.onToggleLocalMode?.call();
                        widget.onTabChanged(AnimeDetailTab.online);
                        break;
                      case _DesktopSourceMode.torrent:
                        if (widget.isLocalMode) widget.onToggleLocalMode?.call();
                        widget.onTabChanged(AnimeDetailTab.torrent);
                        break;
                    }
                  }
                },
                trackColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                thumbColor: isDark
                    ? theme.colorScheme.surfaceContainerHighest
                    : Colors.white,
                segments: [
                  for (final mode in availableModes)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            mode == _DesktopSourceMode.local
                                ? AppIcons.folderFilled(iconPack)
                                : (mode == _DesktopSourceMode.online
                                    ? AppIcons.globe(iconPack)
                                    : AppIcons.cloudDownload(iconPack)),
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            mode == _DesktopSourceMode.local
                                ? l10n.localLibrary
                                : (mode == _DesktopSourceMode.online ? 'Online' : 'Torrent'),
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          }(),
        ],
      ],
    );
  }
}

