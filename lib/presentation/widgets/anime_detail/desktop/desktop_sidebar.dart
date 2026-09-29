import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DesktopSidebar extends StatelessWidget {
  final String? coverUrl;
  final String format;
  final String? status;
  final String airedStr;
  final String seasonYearStr;
  final num? score;
  final String studio;

  const DesktopSidebar({
    super.key,
    required this.coverUrl,
    required this.format,
    required this.status,
    required this.airedStr,
    required this.seasonYearStr,
    required this.score,
    required this.studio,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 260,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded Vertical Poster with Smooth Hover Animation
          Center(
            child: _DesktopSidebarPoster(
              coverUrl: coverUrl,
              fallbackColor: theme.colorScheme.surfaceContainer,
            ),
          ),
          const SizedBox(height: 24),

          // Metadata Sidebar items
          _buildMetaItem(theme, 'Format', format == 'TV' ? 'TV Show' : format.replaceAll('_', ' ')),
          if (status != null && status!.isNotEmpty)
            _buildMetaItem(theme, 'Status', status!.replaceAll('_', ' ')),
          if (airedStr.isNotEmpty)
            _buildMetaItem(theme, 'Aired', airedStr),
          if (seasonYearStr.isNotEmpty)
            _buildMetaItem(theme, 'Season', seasonYearStr),
          if (score != null && score! > 0)
            _buildMetaItem(theme, 'Average score', '${score!.round()}%'),
          if (studio.isNotEmpty)
            _buildMetaItem(theme, 'Studio', studio),
        ],
      ),
    );
  }

  Widget _buildMetaItem(ThemeData theme, String label, String value) {
    final isDark = theme.brightness == Brightness.dark;
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final valueColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebarPoster extends StatefulWidget {
  final String? coverUrl;
  final Color fallbackColor;

  const _DesktopSidebarPoster({
    required this.coverUrl,
    required this.fallbackColor,
  });

  @override
  State<_DesktopSidebarPoster> createState() => _DesktopSidebarPosterState();
}

class _DesktopSidebarPosterState extends State<_DesktopSidebarPoster> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: 250,
          height: 360,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.08),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.65 : 0.45),
                blurRadius: _isHovered ? 24 : 16,
                offset: Offset(0, _isHovered ? 8 : 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: widget.coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: widget.coverUrl!,
                  fit: BoxFit.cover,
                  memCacheWidth: 500,
                  memCacheHeight: 720,
                  errorWidget: (_, _, _) => Container(color: widget.fallbackColor),
                )
              : Container(color: widget.fallbackColor),
        ),
      ),
    );
  }
}
