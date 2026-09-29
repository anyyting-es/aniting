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

        // AniList External Link Pill
        _HoverLinkPill(
          label: 'A',
          tooltip: 'Ver en AniList',
          accentColor: const Color(0xFF02A9FF),
          onTap: () => _launchAnilist(mediaId),
        ),
        const SizedBox(width: 8),

        // MAL External Link Pill
        if (idMal != null) ...[
          _HoverLinkPill(
            label: 'MAL',
            tooltip: 'Ver en MyAnimeList',
            accentColor: const Color(0xFF5D84E0),
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF00C7FF),
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: _isHovered ? 6 : 2,
          ),
          onPressed: widget.onTap,
          icon: const Icon(Icons.menu_book_rounded, size: 20, color: Colors.black),
          label: Text(
            widget.label,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.black,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: IconButton(
          tooltip: widget.tooltip,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08),
            padding: const EdgeInsets.all(12),
          ),
          icon: Icon(
            widget.icon,
            color: _isHovered ? Colors.white : Colors.white70,
            size: 20,
          ),
          onPressed: widget.onTap,
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
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Tooltip(
            message: widget.tooltip,
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08),
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: widget.accentColor.withValues(alpha: _isHovered ? 0.8 : 0.4),
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _isHovered ? Colors.white : widget.accentColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
