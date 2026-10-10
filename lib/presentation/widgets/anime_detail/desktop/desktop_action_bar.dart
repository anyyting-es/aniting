import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:url_launcher/url_launcher_string.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);

    return Row(
      children: [
        // Floating Pill Play Button with Gentle Scaling
        _HoverPlayButton(
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
        const SizedBox(width: 10),

        // Bookmark Button (AniList status modal) with Gentle Hover (Anime only)
        if (!isTmdb) ...[
          _HoverIconButton(
            tooltip: l10n.editInAnilist,
            icon: AppIcons.bookmarkOutline(iconPack),
            onTap: () => onOpenEditEntryModal(title),
          ),
          const SizedBox(width: 8),
        ],

        // Share Button with Gentle Hover
        _HoverIconButton(
          tooltip: l10n.share,
          icon: AppIcons.share(iconPack),
          onTap: () => _shareAnime(context, title, l10n),
        ),
        const SizedBox(width: 8),

        // Watch Trailer Button (Clean, next to play/actions)
        if (hasTrailer) ...[
          _HoverIconButton(
            tooltip: l10n.watchTrailer,
            icon: AppIcons.video(iconPack),
            onTap: _launchTrailer,
          ),
          const SizedBox(width: 8),
        ],

        // Download Button (Torrents modal - Anime only)
        if (!isTmdb && onDownload != null) ...[
          _HoverIconButton(
            tooltip: l10n.downloadWithTorrentClient,
            icon: Icons.download_rounded,
            onTap: onDownload!,
          ),
          const SizedBox(width: 8),
        ],

        // External Link
        if (isTmdb) ...[
          _HoverIconButton(
            tooltip: 'The Movie Database (TMDB)',
            icon: Icons.open_in_new_rounded,
            onTap: () => _launchTmdb(mediaId),
          ),
          const SizedBox(width: 8),
        ] else ...[
          // AniList External Link with Official Brand Icon
          _HoverBrandIcon(
            assetPath: 'assets/icons/AniList_logo.png',
            tooltip: l10n.viewOnAnilist,
            onTap: () => _launchAnilist(mediaId),
          ),
          const SizedBox(width: 8),

          // MAL External Link with Official Brand Icon
          if (idMal != null) ...[
            _HoverBrandIcon(
              assetPath: 'assets/icons/MyAnimeList_Logo.png',
              tooltip: l10n.viewOnMal,
              onTap: () => _launchMal(idMal!),
            ),
            const SizedBox(width: 8),
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
  final VoidCallback onTap;
  final IconData icon;

  const _HoverPlayButton({
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
        child: GlassCard(
          borderRadius: BorderRadius.circular(24),
          padding: EdgeInsets.zero,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
              decoration: BoxDecoration(
                color: isDark
                    ? (_isHovered
                        ? Colors.white.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.85))
                    : (_isHovered
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withValues(alpha: 0.9)),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : theme.colorScheme.primary)
                        .withValues(alpha: _isHovered ? 0.35 : 0.20),
                    blurRadius: _isHovered ? 12 : 6,
                    offset: Offset(0, _isHovered ? 3 : 1),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: isDark ? Colors.black : Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<_HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBaseBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85);
    final defaultHoverBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHigh;

    final baseBg = defaultBaseBg;
    final hoverBg = _isHovered ? defaultHoverBg : baseBg;

    final defaultIconColor = isDark
        ? (_isHovered ? Colors.white : Colors.white70)
        : (_isHovered ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.025 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _isHovered ? hoverBg : baseBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: _isHovered ? 0.22 : 0.08)
                        : theme.colorScheme.outlineVariant.withValues(alpha: _isHovered ? 0.6 : 0.3),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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

    final baseBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHigh;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.025 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isHovered ? hoverBg : baseBg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: _isHovered ? 0.22 : 0.08)
                        : theme.colorScheme.outlineVariant.withValues(alpha: _isHovered ? 0.6 : 0.3),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
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
