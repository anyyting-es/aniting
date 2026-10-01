import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final bool isLocalMode;
  final bool onlineEnabled;
  final bool torrentEnabled;
  final VoidCallback onPlayNext;
  final void Function(String title) onOpenEditEntryModal;
  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;

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
    required this.isLocalMode,
    required this.onlineEnabled,
    required this.torrentEnabled,
    required this.onPlayNext,
    required this.onOpenEditEntryModal,
    required this.onToggleLocalMode,
    required this.onTabChanged,
  });

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

  void _shareAnime(BuildContext context, String title) {
    Clipboard.setData(ClipboardData(text: 'https://anilist.co/anime/$mediaId'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enlace copiado para $title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);

    return Row(
      children: [
        // Big Pill Play Button with Gentle Scaling
        _HoverPlayButton(
          onTap: onPlayNext,
          icon: AppIcons.play(iconPack),
        ),
        const SizedBox(width: 10),

        // Bookmark Button (AniList status modal) with Gentle Hover
        _HoverIconButton(
          tooltip: 'Editar en AniList',
          icon: AppIcons.bookmarkOutline(iconPack),
          onTap: () => onOpenEditEntryModal(title),
        ),
        const SizedBox(width: 8),

        // Share Button with Gentle Hover
        _HoverIconButton(
          tooltip: 'Compartir',
          icon: AppIcons.share(iconPack),
          onTap: () => _shareAnime(context, title),
        ),
        const SizedBox(width: 8),

        // Watch Trailer Button (Clean, next to play/actions)
        if (hasTrailer) ...[
          _HoverIconButton(
            tooltip: 'Ver tráiler',
            icon: AppIcons.video(iconPack),
            onTap: _launchTrailer,
          ),
          const SizedBox(width: 8),
        ],

        // AniList External Link with Official Brand Icon (Clean, no borders)
        _HoverBrandIcon(
          assetPath: 'assets/icons/AniList_logo.png',
          tooltip: 'Ver en AniList',
          onTap: () => _launchAnilist(mediaId),
        ),
        const SizedBox(width: 8),

        // MAL External Link with Official Brand Icon (Clean, no borders)
        if (idMal != null) ...[
          _HoverBrandIcon(
            assetPath: 'assets/icons/MyAnimeList_Logo.png',
            tooltip: 'Ver en MyAnimeList',
            onTap: () => _launchMal(idMal!),
          ),
          const SizedBox(width: 8),
        ],

        const Spacer(),

        // Source Mode Toggle (Online / Torrent)
        if (!isLocalMode && onlineEnabled && torrentEnabled) ...[
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HoverSourcePill(
                  label: 'Online',
                  icon: AppIcons.globe(iconPack),
                  isSelected: currentTab == AnimeDetailTab.online,
                  onTap: () => onTabChanged(AnimeDetailTab.online),
                ),
                _HoverSourcePill(
                  label: 'Torrent',
                  icon: AppIcons.cloudDownload(iconPack),
                  isSelected: currentTab == AnimeDetailTab.torrent,
                  onTap: () => onTabChanged(AnimeDetailTab.torrent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],

        // Local library toggle
        _HoverIconButton(
          tooltip: isLocalMode ? 'Salir de modo local' : 'Biblioteca local',
          icon: isLocalMode ? AppIcons.folderFilled(iconPack) : AppIcons.folder(iconPack),
          iconColor: isLocalMode
              ? theme.colorScheme.primary
              : (isDark ? Colors.white : theme.colorScheme.onSurfaceVariant),
          backgroundColor: isLocalMode
              ? theme.colorScheme.primaryContainer
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : theme.colorScheme.surfaceContainerHighest),
          onTap: onToggleLocalMode,
        ),
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
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
            decoration: BoxDecoration(
              color: isDark ? Colors.white : theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : theme.colorScheme.primary).withValues(alpha: _isHovered ? 0.35 : 0.20),
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
    );
  }
}

class _HoverIconButton extends StatefulWidget {
  final String tooltip;
  final IconData icon;
  final Color? iconColor;
  final Color? backgroundColor;
  final VoidCallback onTap;

  const _HoverIconButton({
    required this.tooltip,
    required this.icon,
    this.iconColor,
    this.backgroundColor,
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

    final baseBg = widget.backgroundColor ?? defaultBaseBg;
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
                      ? Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: _isHovered ? 0.6 : 0.3),
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
                color: widget.iconColor ?? defaultIconColor,
                size: 20,
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
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _isHovered ? hoverBg : baseBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08)
                      : theme.colorScheme.outlineVariant.withValues(alpha: _isHovered ? 0.6 : 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.25 : 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
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
    );
  }
}

class _HoverSourcePill extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _HoverSourcePill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_HoverSourcePill> createState() => _HoverSourcePillState();
}

class _HoverSourcePillState extends State<_HoverSourcePill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedBg = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.surface;
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surface.withValues(alpha: 0.5);

    final selectedColor = isDark ? Colors.white : theme.colorScheme.primary;
    final unselectedColor = isDark
        ? (_isHovered ? Colors.white : Colors.white60)
        : (_isHovered ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? selectedBg
                : (_isHovered ? hoverBg : Colors.transparent),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isSelected && !isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: widget.isSelected ? selectedColor : unselectedColor,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected ? selectedColor : unselectedColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
