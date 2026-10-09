import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'desktop_episode_models.dart';

class DesktopListEpisodeCard extends ConsumerStatefulWidget {
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
  ConsumerState<DesktopListEpisodeCard> createState() => _DesktopListEpisodeCardState();
}

class _DesktopListEpisodeCardState extends ConsumerState<DesktopListEpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
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
                  width: 240,
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
                                    memCacheWidth: 480,
                                    errorWidget: (_, _, _) => _buildPlaceholder(),
                                  )
                                : _buildPlaceholder(),

                          // Local downloaded badge
                          if (widget.ep.isDownloaded)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.greenAccent.withValues(alpha: 0.6),
                                    width: 0.8,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 10),
                                    SizedBox(width: 3.5),
                                    Text(
                                      'LOCAL',
                                      style: TextStyle(
                                        color: Colors.greenAccent,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (widget.ep.isDownloading)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.7),
                                    width: 0.9,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 10,
                                      height: 10,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        value: (widget.ep.downloadProgress != null &&
                                                widget.ep.downloadProgress! > 0)
                                            ? widget.ep.downloadProgress
                                            : null,
                                        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                        backgroundColor: (widget.ep.downloadProgress != null &&
                                                widget.ep.downloadProgress! > 0)
                                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      widget.ep.downloadProgress != null &&
                                              widget.ep.downloadProgress! > 0
                                          ? '${(widget.ep.downloadProgress! * 100).toInt()}%'
                                          : '...',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
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
              ),
              const SizedBox(width: 18),

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
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: _isHovered ? theme.colorScheme.primary : titleColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.ep.synopsis != null && widget.ep.synopsis!.isNotEmpty
                              ? widget.ep.synopsis!
                              : l10n.noDescriptionAvailable,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
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
