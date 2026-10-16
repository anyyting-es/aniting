import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'desktop_episode_models.dart';

class DesktopGridEpisodeCard extends ConsumerStatefulWidget {
  final int? mediaId;
  final DesktopEpisodeItemData ep;
  final bool isLoading;
  final String formattedTitle;
  final String? fallbackCoverImage;
  final VoidCallback onTap;
  final Widget? trailingActions;

  const DesktopGridEpisodeCard({
    super.key,
    this.mediaId,
    required this.ep,
    required this.isLoading,
    required this.formattedTitle,
    required this.fallbackCoverImage,
    required this.onTap,
    this.trailingActions,
  });

  @override
  ConsumerState<DesktopGridEpisodeCard> createState() => _DesktopGridEpisodeCardState();
}

class _DesktopGridEpisodeCardState extends ConsumerState<DesktopGridEpisodeCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final double cardOpacity = widget.ep.isWatched ? (_isHovered ? 0.75 : 0.45) : 1.0;

    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${widget.mediaId}_${widget.ep.number}';
    final mediaProgress = widget.mediaId != null ? playbackMap[widget.mediaId.toString()] : null;
    final localProgress = widget.mediaId != null
        ? (playbackMap[epKey] ??
            (mediaProgress != null && mediaProgress.episodeNumber == widget.ep.number ? mediaProgress : null))
        : null;
    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : null;

    return RepaintBoundary(
      child: MouseRegion(
        cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: widget.isLoading ? null : widget.onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 16:9 Thumbnail with Box Expansion on hover (No play icon)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AnimatedScale(
                  scale: _isHovered ? 1.025 : 1.0,
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
                        width: 1.0,
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
                                memCacheWidth: 400,
                                errorWidget: (_, _, _) => _buildPlaceholder(),
                              )
                            : _buildPlaceholder(),

                        // Downloading progress badge
                        if (widget.ep.isDownloading)
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

                      // Video playback progress indicator at the bottom edge (matching Continue Watching)
                      if (progressFraction != null && progressFraction > 0.01 && progressFraction < 0.98)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: LinearProgressIndicator(
                            value: progressFraction,
                            backgroundColor: Colors.black.withValues(alpha: 0.35),
                            valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                            minHeight: 3.0,
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
            ),
            const SizedBox(height: 8),
            // Title: "EP X. Title" with clean green download icon at far right
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.formattedTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: _isHovered ? theme.colorScheme.primary : titleColor,
                      height: 1.3,
                    ),
                  ),
                ),
                if (widget.ep.isDownloaded) ...[
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(top: 1.5),
                    child: Icon(
                      AppIcons.checkCircleFilled(iconPack),
                      size: 14,
                      color: Colors.greenAccent.shade400,
                    ),
                  ),
                ],
                if (widget.trailingActions != null) ...[
                  const SizedBox(width: 4),
                  widget.trailingActions!,
                ],
              ],
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
