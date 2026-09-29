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
          scale: _isHovered ? 1.01 : 1.0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onTap,
            borderRadius: BorderRadius.circular(12),
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
                  // Left 16:9 Thumbnail with Inner Zoom & Play Overlay
                  SizedBox(
                    width: 220,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: _isHovered ? 0.20 : 0.08),
                          ),
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
                                        memCacheWidth: 440,
                                        errorWidget: (_, _, _) => _buildPlaceholder(),
                                      )
                                    : _buildPlaceholder(),
                              ),
                            ),

                            // Hover Play Overlay (neutral white button)
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
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
                            color: Colors.white.withValues(alpha: 0.65),
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
