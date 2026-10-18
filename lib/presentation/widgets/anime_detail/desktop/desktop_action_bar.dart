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

class DesktopActionBar extends ConsumerWidget {
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

  Future<void> _launchTmdb(int mediaId) async {
    try {
      await launchUrlString(
        'https://www.themoviedb.org/${isMovie ? "movie" : "tv"}/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchAnilist(int mediaId) async {
    try {
      await launchUrlString(
        'https://anilist.co/anime/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchMal(int idMal) async {
    try {
      await launchUrlString(
        'https://myanimelist.net/anime/$idMal',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchTrailer() async {
    if (trailerId == null || trailerId!.isEmpty) return;
    String url = '';
    final site = trailerSite?.toLowerCase();
    if (site == 'youtube' || site == null) {
      url = 'https://www.youtube.com/watch?v=$trailerId';
    } else if (site == 'dailymotion') {
      url = 'https://www.dailymotion.com/video/$trailerId';
    }
    if (url.isNotEmpty) {
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  void _shareAnime(BuildContext context, String title, AppTranslations l10n) {
    final shareUrl = isTmdb
        ? 'https://www.themoviedb.org/${isMovie ? "movie" : "tv"}/$mediaId'
        : 'https://anilist.co/anime/$mediaId';
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
    WidgetRef ref,
    String newStatus,
  ) async {
    final repo = ref.read(repositoryProvider);
    final serverState = ref.read(serverNotifierProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final l10n = ref.read(translationsProvider);

    if (isLoggedIn && !isTmdb) {
      await repo.editAnilistListEntry(
        mediaId: mediaId,
        type: 'anime',
        status: newStatus,
        progress: progress,
      );
    }

    await OfflineLibraryService.instance.saveAnimeEntryFromEdit(
      mediaId: mediaId,
      title: title,
      status: newStatus,
      progress: progress,
      totalCount: totalEpisodes,
      isTmdb: isTmdb,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    // Dynamic Reactive Play Label
    final String playLabel;
    if (userStatus == 'COMPLETED') {
      playLabel = l10n.rewatch;
    } else if (progress > 0) {
      final nextEp = (progress + 1).clamp(1, totalEpisodes ?? (progress + 1));
      playLabel = l10n.continueEpisodeNumbered(nextEp);
    } else {
      playLabel = l10n.watchEpisodeOne;
    }

    return Row(
      children: [
        // Expanded Reactive Play Button with M3 Expressive motion & morphing
        M3EButton.icon(
          style: M3EButtonStyle.filled,
          size: M3EButtonSize.sm,
          shape: M3EButtonShape.round,
          icon: Icon(AppIcons.play(iconPack), size: 18),
          label: Text(
            playLabel,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          onPressed: isTmdb
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
              : onPlayNext,
        ),
        const SizedBox(width: 10),

        // Edit Entry Pencil Button (GlassMenuAnchor with fluid detachment)
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
              onPressed: () => _updateStatus(context, ref, 'CURRENT'),
            ),
            GlassMenuItem(
              label: l10n.statusPlanning,
              icon: Icon(
                AppIcons.bookmarkAdded(iconPack),
                size: 18,
                color: const Color(0xFF3B82F6),
              ),
              onPressed: () => _updateStatus(context, ref, 'PLANNING'),
            ),
            GlassMenuItem(
              label: l10n.statusCompleted,
              icon: Icon(
                AppIcons.checkCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFF8B5CF6),
              ),
              onPressed: () => _updateStatus(context, ref, 'COMPLETED'),
            ),
            GlassMenuItem(
              label: l10n.statusPaused,
              icon: Icon(
                AppIcons.pauseCircleFilled(iconPack),
                size: 18,
                color: const Color(0xFFF59E0B),
              ),
              onPressed: () => _updateStatus(context, ref, 'PAUSED'),
            ),
            GlassMenuItem(
              label: l10n.statusDropped,
              icon: Icon(
                AppIcons.cancel(iconPack),
                size: 18,
                color: const Color(0xFFEF4444),
              ),
              onPressed: () => _updateStatus(context, ref, 'DROPPED'),
            ),
            if (!isTmdb)
              GlassMenuItem(
                label: l10n.editDetails,
                icon: Icon(
                  AppIcons.edit(iconPack),
                  size: 18,
                ),
                onPressed: () => onOpenEditEntryModal(title),
              ),
          ],
          builder: (context, controller) {
            return M3EIconButton(
              tooltip: isTmdb ? l10n.editDetails : l10n.editInAnilist,
              icon: Icon(AppIcons.edit(iconPack), size: 18),
              variant: M3EIconButtonVariant.standard,
              size: M3EIconButtonSize.sm,
              onPressed: controller.open,
            );
          },
        ),
        const SizedBox(width: 6),

        // Share Button (M3E Icon Button)
        M3EIconButton(
          tooltip: l10n.share,
          icon: Icon(AppIcons.share(iconPack), size: 18),
          variant: M3EIconButtonVariant.standard,
          size: M3EIconButtonSize.sm,
          onPressed: () => _shareAnime(context, title, l10n),
        ),
        const SizedBox(width: 6),

        // Watch Trailer Button (M3E Icon Button)
        if (hasTrailer) ...[
          M3EIconButton(
            tooltip: l10n.watchTrailer,
            icon: Icon(AppIcons.video(iconPack), size: 18),
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.sm,
            onPressed: _launchTrailer,
          ),
          const SizedBox(width: 6),
        ],

        // Download Button (Torrents modal - Anime only)
        if (!isTmdb && onDownload != null) ...[
          M3EIconButton(
            tooltip: l10n.downloadWithTorrentClient,
            icon: Icon(AppIcons.download(iconPack), size: 20),
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.sm,
            onPressed: onDownload!,
          ),
          const SizedBox(width: 6),
        ],

        // External Link (TMDB)
        if (isTmdb) ...[
          Tooltip(
            message: 'The Movie Database (TMDB)',
            child: M3EIconButton(
              icon: Icon(AppIcons.openInNew(iconPack), size: 18),
              variant: M3EIconButtonVariant.standard,
              size: M3EIconButtonSize.sm,
              onPressed: () => _launchTmdb(mediaId),
            ),
          ),
          const SizedBox(width: 6),
        ] else ...[
          // AniList External Tracker Link (M3E Icon Button)
          Tooltip(
            message: l10n.viewOnAnilist,
            child: M3EIconButton(
              icon: ClipOval(
                child: Image.asset(
                  'assets/icons/AniList_logo.png',
                  width: 20,
                  height: 20,
                  fit: BoxFit.contain,
                ),
              ),
              variant: M3EIconButtonVariant.standard,
              size: M3EIconButtonSize.sm,
              onPressed: () => _launchAnilist(mediaId),
            ),
          ),
          const SizedBox(width: 6),

          // MAL External Tracker Link (M3E Icon Button)
          if (idMal != null) ...[
            Tooltip(
              message: l10n.viewOnMal,
              child: M3EIconButton(
                icon: ClipOval(
                  child: Image.asset(
                    'assets/icons/MyAnimeList_Logo.png',
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
                variant: M3EIconButtonVariant.standard,
                size: M3EIconButtonSize.sm,
                onPressed: () => _launchMal(idMal!),
              ),
            ),
            const SizedBox(width: 6),
          ],
        ],

        const Spacer(),

        // Source Mode Toggle (Local / Online / Torrent) with GlassSegmentedControl (Anime only)
        if (!isTmdb) ...[
          () {
            final availableModes = <_DesktopSourceMode>[
              if (hasLocalFiles) _DesktopSourceMode.local,
              if (onlineEnabled) _DesktopSourceMode.online,
              if (torrentEnabled) _DesktopSourceMode.torrent,
            ];

            if (availableModes.length < 2) return const SizedBox.shrink();

            final _DesktopSourceMode activeMode = isLocalMode
                ? _DesktopSourceMode.local
                : (currentTab == AnimeDetailTab.online
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
                  if (onModeChanged != null) {
                    onModeChanged!(mode.name);
                  } else {
                    switch (mode) {
                      case _DesktopSourceMode.local:
                        if (!isLocalMode) onToggleLocalMode?.call();
                        break;
                      case _DesktopSourceMode.online:
                        if (isLocalMode) onToggleLocalMode?.call();
                        onTabChanged(AnimeDetailTab.online);
                        break;
                      case _DesktopSourceMode.torrent:
                        if (isLocalMode) onToggleLocalMode?.call();
                        onTabChanged(AnimeDetailTab.torrent);
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

