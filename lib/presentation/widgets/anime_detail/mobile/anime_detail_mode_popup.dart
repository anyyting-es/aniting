import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

/// Compact Material Design Expressive popup for switching playback modes
/// (Online Streaming, Torrent Swarm, Local Library) with a spring/bounce animation.
class AnimeDetailModePopup extends StatelessWidget {
  final AnimeDetailTab currentTab;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final VoidCallback onToggleLocalMode;

  const AnimeDetailModePopup({
    super.key,
    required this.currentTab,
    required this.isLocalMode,
    required this.hasLocalFiles,
    required this.onTabChanged,
    required this.onToggleLocalMode,
  });

  static Future<void> show({
    required BuildContext context,
    required AnimeDetailTab currentTab,
    required bool isLocalMode,
    required bool hasLocalFiles,
    required ValueChanged<AnimeDetailTab> onTabChanged,
    required VoidCallback onToggleLocalMode,
  }) {
    final parentTheme = Theme.of(context);
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cerrar selector de modo',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 320),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final bounceCurve = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(bounceCurve),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim, secondaryAnim) => Theme(
        data: parentTheme,
        child: AnimeDetailModePopup(
          currentTab: currentTab,
          isLocalMode: isLocalMode,
          hasLocalFiles: hasLocalFiles,
          onTabChanged: onTabChanged,
          onToggleLocalMode: onToggleLocalMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogBg = theme.colorScheme.surfaceContainerHigh;
    final isTorrent = !isLocalMode && currentTab == AnimeDetailTab.torrent;
    final isOnline = !isLocalMode && currentTab == AnimeDetailTab.online;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 290,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: dialogBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        size: 18,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Modo de Reproducción',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1, thickness: 0.8),

              // Options
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                child: Column(
                  children: [
                    _buildModeTile(
                      context: context,
                      theme: theme,
                      label: 'Online Streaming',
                      subtitle: 'Servidores comunitarios',
                      icon: Icons.public_rounded,
                      color: theme.colorScheme.primary,
                      isSelected: isOnline,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        if (isLocalMode) onToggleLocalMode();
                        onTabChanged(AnimeDetailTab.online);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildModeTile(
                      context: context,
                      theme: theme,
                      label: 'Torrent Swarm',
                      subtitle: 'Descarga y streaming P2P',
                      icon: Icons.cloud_download_rounded,
                      color: theme.colorScheme.secondary,
                      isSelected: isTorrent,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        if (isLocalMode) onToggleLocalMode();
                        onTabChanged(AnimeDetailTab.torrent);
                      },
                    ),
                    if (hasLocalFiles) ...[
                      const SizedBox(height: 4),
                      _buildModeTile(
                        context: context,
                        theme: theme,
                        label: 'Archivos Locales',
                        subtitle: 'Biblioteca descargada',
                        icon: Icons.folder_rounded,
                        color: theme.colorScheme.tertiary,
                        isSelected: isLocalMode,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          if (!isLocalMode) onToggleLocalMode();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTile({
    required BuildContext context,
    required ThemeData theme,
    required String label,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected ? color : theme.colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
