import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../../core/i18n/i18n_provider.dart';

class DesktopMangaActionBar extends ConsumerWidget {
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

  void _shareManga(BuildContext context, String title, String message) {
    Clipboard.setData(ClipboardData(text: 'https://anilist.co/manga/$mediaId'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final label = progress > 0
        ? l10n.continueChapterNumbered(progress + 1)
        : l10n.startReading;

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
          tooltip: l10n.editInAnilist,
          icon: Icons.bookmark_border_rounded,
          onTap: () => onOpenEditEntryModal(title),
        ),
        const SizedBox(width: 8),

        // Batch Download Button
        _HoverIconButton(
          tooltip: l10n.batchDownload,
          icon: Icons.download_rounded,
          onTap: onBatchDownload,
        ),
        const SizedBox(width: 8),

        // Share Button
        _HoverIconButton(
          tooltip: l10n.share,
          icon: Icons.share_rounded,
          onTap: () => _shareManga(context, title, l10n.linkCopiedFor(title)),
        ),
        const SizedBox(width: 8),

        // AniList External Link with Official Brand Icon (Clean, no borders)
        _HoverBrandIcon(
          assetPath: 'assets/icons/AniList_logo.png',
          tooltip: l10n.viewOnAnilist,
          onTap: () => _launchAnilist(mediaId),
        ),
        const SizedBox(width: 8),

        // MAL External Link with Official Brand Icon (Clean, no borders)
        if (idMal != null) ...[
          _HoverBrandIcon(
            assetPath: 'assets/icons/MyAnimeList_Logo.png',
            tooltip: l10n.viewOnMal,
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
    final isDark = theme.brightness == Brightness.dark;

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
            minimumSize: const Size(0, 38),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: _isHovered ? 4 : 1,
            shadowColor: (isDark ? Colors.black : theme.colorScheme.primary).withValues(alpha: 0.25),
          ),
          onPressed: widget.onTap,
          icon: Icon(Icons.menu_book_rounded, size: 18, color: theme.colorScheme.onPrimary),
          label: Text(
            widget.label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.1,
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
              padding: const EdgeInsets.all(9),
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
              child: Icon(
                widget.icon,
                color: iconColor,
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
