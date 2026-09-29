import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

class DesktopActionBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // Big Pill Play Button with Gentle Scaling
        _HoverPlayButton(onTap: onPlayNext),
        const SizedBox(width: 10),

        // Bookmark Button (AniList status modal) with Gentle Hover
        _HoverIconButton(
          tooltip: 'Editar en AniList',
          icon: Icons.bookmark_border_rounded,
          onTap: () => onOpenEditEntryModal(title),
        ),
        const SizedBox(width: 8),

        // Share Button with Gentle Hover
        _HoverIconButton(
          tooltip: 'Compartir',
          icon: Icons.share_rounded,
          onTap: () => _shareAnime(context, title),
        ),
        const SizedBox(width: 8),

        // Watch Trailer Button (Clean, next to play/actions)
        if (hasTrailer) ...[
          _HoverIconButton(
            tooltip: 'Ver tráiler',
            icon: Icons.smart_display_rounded,
            iconColor: Colors.white,
            onTap: _launchTrailer,
          ),
          const SizedBox(width: 8),
        ],

        // AniList External Link Pill with Gentle Hover
        _HoverLinkPill(
          label: 'A',
          tooltip: 'Ver en AniList',
          accentColor: const Color(0xFF02A9FF),
          onTap: () => _launchAnilist(mediaId),
        ),
        const SizedBox(width: 8),

        // MAL External Link Pill with Gentle Hover
        if (idMal != null) ...[
          _HoverLinkPill(
            label: 'MAL',
            tooltip: 'Ver en MyAnimeList',
            accentColor: const Color(0xFF5D84E0),
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
              color: const Color(0xFF1B1E24),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HoverSourcePill(
                  label: 'Online',
                  icon: Icons.public_rounded,
                  isSelected: currentTab == AnimeDetailTab.online,
                  onTap: () => onTabChanged(AnimeDetailTab.online),
                ),
                _HoverSourcePill(
                  label: 'Torrent',
                  icon: Icons.cloud_download_outlined,
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
          icon: isLocalMode ? Icons.folder_rounded : Icons.folder_outlined,
          iconColor: isLocalMode ? theme.colorScheme.primary : Colors.white,
          backgroundColor: isLocalMode
              ? theme.colorScheme.primaryContainer
              : const Color(0xFF1B1E24),
          onTap: onToggleLocalMode,
        ),
      ],
    );
  }
}

class _HoverPlayButton extends StatefulWidget {
  final VoidCallback onTap;

  const _HoverPlayButton({required this.onTap});

  @override
  State<_HoverPlayButton> createState() => _HoverPlayButtonState();
}

class _HoverPlayButtonState extends State<_HoverPlayButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: _isHovered ? 12 : 6,
                  offset: Offset(0, _isHovered ? 3 : 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.black,
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
    final baseBg = widget.backgroundColor ?? const Color(0xFF1B1E24);
    final hoverBg = Color.lerp(baseBg, Colors.white, 0.09) ?? const Color(0xFF282D36);

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.035 : 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: _isHovered ? hoverBg : baseBg,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor ?? (_isHovered ? Colors.white : Colors.white70),
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverLinkPill extends StatefulWidget {
  final String label;
  final String tooltip;
  final Color accentColor;
  final VoidCallback onTap;

  const _HoverLinkPill({
    required this.label,
    required this.tooltip,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_HoverLinkPill> createState() => _HoverLinkPillState();
}

class _HoverLinkPillState extends State<_HoverLinkPill> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.03 : 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: _isHovered ? 0.30 : 0.20),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: _isHovered ? 0.55 : 0.35),
                ),
              ),
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: widget.label.length == 1 ? 12.5 : 11,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? const Color(0xFF2C323D)
                  : (_isHovered
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.transparent),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.icon,
                  size: 14,
                  color: widget.isSelected || _isHovered
                      ? Colors.white
                      : Colors.white60,
                ),
                const SizedBox(width: 5),
                Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected || _isHovered
                        ? Colors.white
                        : Colors.white60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
