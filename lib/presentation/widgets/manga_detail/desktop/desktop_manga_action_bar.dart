import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher_string.dart';

class DesktopMangaActionBar extends StatelessWidget {
  final int mediaId;
  final String title;
  final int progress;
  final int? idMal;
  final VoidCallback onContinueReading;
  final void Function(String title) onOpenEditEntryModal;
  final VoidCallback onBatchDownload;

  const DesktopMangaActionBar({
    super.key,
    required this.mediaId,
    required this.title,
    required this.progress,
    this.idMal,
    required this.onContinueReading,
    required this.onOpenEditEntryModal,
    required this.onBatchDownload,
  });

  Future<void> _launchAnilist(int mediaId) async {
    try {
      await launchUrlString(
        'https://anilist.co/manga/$mediaId',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  Future<void> _launchMal(int idMal) async {
    try {
      await launchUrlString(
        'https://myanimelist.net/manga/$idMal',
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
  }

  void _shareManga(BuildContext context, String title) {
    Clipboard.setData(ClipboardData(text: 'https://anilist.co/manga/$mediaId'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Enlace copiado para $title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final label = progress > 0
        ? 'Continuar Leyendo • Cap. ${progress + 1}'
        : 'Empezar a Leer';

    return Row(
      children: [
        // Big Pill Read Button
        _HoverReadButton(
          label: label,
          onTap: onContinueReading,
        ),
        const SizedBox(width: 10),

        // Bookmark Button (AniList status modal)
        _HoverIconButton(
          tooltip: 'Editar en AniList',
          icon: Icons.bookmark_border_rounded,
          onTap: () => onOpenEditEntryModal(title),
        ),
        const SizedBox(width: 8),

        // Batch Download Button
        _HoverIconButton(
          tooltip: 'Descargar por lote',
          icon: Icons.download_rounded,
          onTap: onBatchDownload,
        ),
        const SizedBox(width: 8),

        // Share Button
        _HoverIconButton(
          tooltip: 'Compartir',
          icon: Icons.share_rounded,
          onTap: () => _shareManga(context, title),
        ),
        const SizedBox(width: 8),

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
      ],
    );
  }
}

class _HoverReadButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const _HoverReadButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_HoverReadButton> createState() => _HoverReadButtonState();
}

class _HoverReadButtonState extends State<_HoverReadButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.primary,
            foregroundColor: theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: _isHovered ? 6 : 2,
          ),
          onPressed: widget.onTap,
          icon: Icon(Icons.menu_book_rounded, size: 20, color: theme.colorScheme.onPrimary),
          label: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: theme.colorScheme.onPrimary,
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

    final baseBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.85);
    final hoverBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHigh;

    final iconColor = isDark
        ? (_isHovered ? Colors.white : Colors.white70)
        : (_isHovered ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: IconButton(
          tooltip: widget.tooltip,
          style: IconButton.styleFrom(
            backgroundColor: _isHovered ? hoverBg : baseBg,
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            widget.icon,
            color: iconColor,
            size: 20,
          ),
          onPressed: widget.onTap,
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
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedScale(
          scale: _isHovered ? 1.14 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _isHovered ? 1.0 : 0.72,
            duration: const Duration(milliseconds: 150),
            child: InkResponse(
              onTap: widget.onTap,
              radius: 18,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
