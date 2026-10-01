import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'desktop_episode_models.dart';

class DesktopListEpisodeCard extends StatefulWidget {
  final DesktopEpisodeItemData ep;
  final bool isLoading;
  final String formattedTitle;
  final String? fallbackCoverImage;
  final VoidCallback onTap;

  const DesktopListEpisodeCard({
    super.key,
    required this.ep,
    required this.isLoading,
    required this.formattedTitle,
    required this.fallbackCoverImage,
    required this.onTap,
  });

  @override
  State<DesktopListEpisodeCard> createState() => _DesktopListEpisodeCardState();
}

class _DesktopListEpisodeCardState extends State<DesktopListEpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final descColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : theme.colorScheme.onSurfaceVariant;
    final double cardOpacity = widget.ep.isWatched ? (_isHovered ? 0.75 : 0.45) : 1.0;

    return MouseRegion(
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onTap,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _isHovered
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isHovered
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Left 16:9 Thumbnail with Box Expansion on hover (No play icon)
                SizedBox(
                  width: 220,
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AnimatedScale(
                      scale: _isHovered ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isHovered
                                ? Colors.white.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.25),
                              blurRadius: _isHovered ? 10 : 6,
                              offset: Offset(0, _isHovered ? 3 : 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            widget.ep.image != null && widget.ep.image!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.ep.image!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 440,
                                    errorWidget: (_, _, _) => _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),

                          if (widget.isLoading)
                            Container(
                              color: Colors.black45,
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

                  // Right Title & Synopsis
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.formattedTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isHovered ? theme.colorScheme.primary : titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.ep.synopsis != null && widget.ep.synopsis!.isNotEmpty
                              ? widget.ep.synopsis!
                              : 'Sin descripción.',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: descColor,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  Widget _buildPlaceholder() {
    if (widget.fallbackCoverImage != null) {
      return CachedNetworkImage(
        imageUrl: widget.fallbackCoverImage!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
      );
    }
    return Container(color: const Color(0xFF1E2228));
  }
}
