import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'desktop_episode_models.dart';

class DesktopGridEpisodeCard extends StatefulWidget {
  final DesktopEpisodeItemData ep;
  final bool isLoading;
  final String formattedTitle;
  final String? fallbackCoverImage;
  final VoidCallback onTap;

  const DesktopGridEpisodeCard({
    super.key,
    required this.ep,
    required this.isLoading,
    required this.formattedTitle,
    required this.fallbackCoverImage,
    required this.onTap,
  });

  @override
  State<DesktopGridEpisodeCard> createState() => _DesktopGridEpisodeCardState();
}

class _DesktopGridEpisodeCardState extends State<DesktopGridEpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final double cardOpacity = widget.ep.isWatched ? (_isHovered ? 0.75 : 0.45) : 1.0;

    return MouseRegion(
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        child: AnimatedScale(
          scale: _isHovered ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 16:9 Thumbnail with Inner Zoom & Hover Play Icon
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: _isHovered ? 0.22 : 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _isHovered ? 0.45 : 0.25),
                          blurRadius: _isHovered ? 12 : 6,
                          offset: Offset(0, _isHovered ? 4 : 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRect(
                          child: AnimatedScale(
                            scale: _isHovered ? 1.04 : 1.0,
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeInOut,
                            child: widget.ep.image != null && widget.ep.image!.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: widget.ep.image!,
                                    fit: BoxFit.cover,
                                    memCacheWidth: 400,
                                    errorWidget: (_, _, _) => _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),
                          ),
                        ),

                        // Hover Play Icon Overlay (Neutral dark glass with white play icon)
                        AnimatedOpacity(
                          opacity: _isHovered && !widget.isLoading ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 220),
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.35),
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Loading indicator
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
                const SizedBox(height: 8),

                // Title: "EP X. Title" (Theme-aware)
                Text(
                  widget.formattedTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                    height: 1.25,
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
