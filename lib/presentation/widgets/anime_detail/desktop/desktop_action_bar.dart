import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

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
        // Expanded Reactive Floating Play Button
        _HoverPlayButton(
          label: playLabel,
          onTap: isTmdb
              ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded,
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
          icon: AppIcons.play(iconPack),
        ),
        const SizedBox(width: 14),

        // Edit Entry Pencil Button (GlassMenuAnchor with fluid detachment)
        GlassMenuAnchor(
          width: 210,
          items: [
            GlassMenuItem(
              label: l10n.statusWatching,
              icon: const Icon(
                Icons.play_circle_fill_rounded,
                size: 18,
                color: Color(0xFF10B981),
              ),
              onPressed: () => _updateStatus(context, ref, 'CURRENT'),
            ),
            GlassMenuItem(
              label: l10n.statusPlanning,
              icon: const Icon(
                Icons.bookmark_added_rounded,
                size: 18,
                color: Color(0xFF3B82F6),
              ),
              onPressed: () => _updateStatus(context, ref, 'PLANNING'),
            ),
            GlassMenuItem(
              label: l10n.statusCompleted,
              icon: const Icon(
                Icons.check_circle_rounded,
                size: 18,
                color: Color(0xFF8B5CF6),
              ),
              onPressed: () => _updateStatus(context, ref, 'COMPLETED'),
            ),
            GlassMenuItem(
              label: l10n.statusPaused,
              icon: const Icon(
                Icons.pause_circle_filled_rounded,
                size: 18,
                color: Color(0xFFF59E0B),
              ),
              onPressed: () => _updateStatus(context, ref, 'PAUSED'),
            ),
            GlassMenuItem(
              label: l10n.statusDropped,
              icon: const Icon(
                Icons.cancel_rounded,
                size: 18,
                color: Color(0xFFEF4444),
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
            return _HoverFloatingIconButton(
              tooltip: isTmdb ? l10n.editDetails : l10n.editInAnilist,
              icon: AppIcons.edit(iconPack),
              onTap: controller.open,
            );
          },
        ),
        const SizedBox(width: 12),

        // Share Button (Floating icon)
        _HoverFloatingIconButton(
          tooltip: l10n.share,
          icon: AppIcons.share(iconPack),
          onTap: () => _shareAnime(context, title, l10n),
        ),
        const SizedBox(width: 12),

        // Watch Trailer Button (Floating icon)
        if (hasTrailer) ...[
          _HoverFloatingIconButton(
            tooltip: l10n.watchTrailer,
            icon: AppIcons.video(iconPack),
            onTap: _launchTrailer,
          ),
          const SizedBox(width: 12),
        ],

        // Download Button (Torrents modal - Anime only)
        if (!isTmdb && onDownload != null) ...[
          _HoverFloatingIconButton(
            tooltip: l10n.downloadWithTorrentClient,
            icon: Icons.download_rounded,
            onTap: onDownload!,
          ),
          const SizedBox(width: 12),
        ],

        // External Link (TMDB)
        if (isTmdb) ...[
          _HoverFloatingIconButton(
            tooltip: 'The Movie Database (TMDB)',
            icon: Icons.open_in_new_rounded,
            onTap: () => _launchTmdb(mediaId),
          ),
          const SizedBox(width: 12),
        ] else ...[
          // AniList External Tracker Link (Rounded icon only, clean, floating, no background/borders)
          _HoverBrandIcon(
            assetPath: 'assets/icons/AniList_logo.png',
            tooltip: l10n.viewOnAnilist,
            onTap: () => _launchAnilist(mediaId),
          ),
          const SizedBox(width: 12),

          // MAL External Tracker Link (Rounded icon only, clean, floating, no background/borders)
          if (idMal != null) ...[
            _HoverBrandIcon(
              assetPath: 'assets/icons/MyAnimeList_Logo.png',
              tooltip: l10n.viewOnMal,
              onTap: () => _launchMal(idMal!),
            ),
            const SizedBox(width: 12),
          ],
        ],

        const Spacer(),

        // Source Mode Toggle (Online / Torrent) with GlassSegmentedControl (Anime only)
        if (!isTmdb && onlineEnabled && torrentEnabled) ...[
          SizedBox(
            width: 230,
            child: GlassSegmentedControl(
              selectedIndex: currentTab == AnimeDetailTab.online ? 0 : 1,
              onSelected: (index) {
                onTabChanged(index == 0 ? AnimeDetailTab.online : AnimeDetailTab.torrent);
              },
              trackColor: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              thumbColor: isDark
                  ? theme.colorScheme.surfaceContainerHighest
                  : Colors.white,
              segments: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.globe(iconPack), size: 13),
                      const SizedBox(width: 4),
                      const Text(
                        'Online',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.cloudDownload(iconPack), size: 13),
                      const SizedBox(width: 4),
                      const Text(
                        'Torrent',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HoverPlayButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  const _HoverPlayButton({
    required this.label,
    required this.onTap,
    this.icon = Icons.play_arrow_rounded,
  });

  @override
  State<_HoverPlayButton> createState() => _HoverPlayButtonState();
}

class _HoverPlayButtonState extends State<_HoverPlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(24),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (_isHovered
                            ? Colors.white.withValues(alpha: 0.22)
                            : Colors.white.withValues(alpha: 0.14))
                        : (_isHovered
                            ? theme.colorScheme.primary.withValues(alpha: 0.22)
                            : theme.colorScheme.primary.withValues(alpha: 0.14)),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark
                          ? (_isHovered
                              ? Colors.white.withValues(alpha: 0.38)
                              : Colors.white.withValues(alpha: 0.24))
                          : (_isHovered
                              ? theme.colorScheme.primary.withValues(alpha: 0.40)
                              : theme.colorScheme.primary.withValues(alpha: 0.25)),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.icon,
                        color: isDark ? Colors.white : theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                          color: isDark ? Colors.white : theme.colorScheme.primary,
                        ),
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

class _HoverFloatingIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _HoverFloatingIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HoverFloatingIconButton> createState() => _HoverFloatingIconButtonState();
}

class _HoverFloatingIconButtonState extends State<_HoverFloatingIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultIconColor = isDark
        ? (_isHovered ? Colors.white : Colors.white.withValues(alpha: 0.85))
        : (_isHovered ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: widget.onTap,
                  customBorder: const CircleBorder(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? (_isHovered
                              ? Colors.white.withValues(alpha: 0.18)
                              : Colors.white.withValues(alpha: 0.08))
                          : (_isHovered
                              ? theme.colorScheme.primary.withValues(alpha: 0.16)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45)),
                      border: Border.all(
                        color: isDark
                            ? (_isHovered
                                ? Colors.white.withValues(alpha: 0.32)
                                : Colors.white.withValues(alpha: 0.18))
                            : (_isHovered
                                ? theme.colorScheme.primary.withValues(alpha: 0.30)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25)),
                        width: 0.8,
                      ),
                    ),
                    child: Icon(
                      widget.icon,
                      color: defaultIconColor,
                      size: 20,
                    ),
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

class _HoverBrandIcon extends StatefulWidget {
  final String assetPath;
  final String tooltip;
  final VoidCallback onTap;

  const _HoverBrandIcon({
    required this.assetPath,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_HoverBrandIcon> createState() => _HoverBrandIconState();
}

class _HoverBrandIconState extends State<_HoverBrandIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              onTap: widget.onTap,
              customBorder: const CircleBorder(),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHovered
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5))
                      : Colors.transparent,
                ),
                child: ClipOval(
                  child: Image.asset(
                    widget.assetPath,
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
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

