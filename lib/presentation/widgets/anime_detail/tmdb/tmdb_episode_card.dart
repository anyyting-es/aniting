import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbEpisodeCard extends ConsumerStatefulWidget {
  final int? tmdbId;
  final TmdbEpisode episode;
  final String? fallbackImageUrl;
  final bool isGridView;
  final bool isLocalFile;
  final VoidCallback? onTap;

  const TmdbEpisodeCard({
    super.key,
    this.tmdbId,
    required this.episode,
    this.fallbackImageUrl,
    this.isGridView = true,
    this.isLocalFile = false,
    this.onTap,
  });

  @override
  ConsumerState<TmdbEpisodeCard> createState() => _TmdbEpisodeCardState();
}

class _TmdbEpisodeCardState extends ConsumerState<TmdbEpisodeCard> {
  bool _isHovered = false;

  String _formatEpisodeTitle(TmdbEpisode ep) {
    final t = ep.name.trim();
    if (t.toLowerCase() == 'episodio ${ep.episodeNumber}' ||
        t.toLowerCase() == 'episode ${ep.episodeNumber}' ||
        t.isEmpty) {
      return 'EP ${ep.episodeNumber}';
    }
    final cleanT = t.replaceFirst(
        RegExp(r'^(episodio|episode)\s*\d+\s*[:.-]?\s*', caseSensitive: false),
        '');
    if (cleanT.isNotEmpty) {
      return 'EP ${ep.episodeNumber}. $cleanT';
    }
    return 'EP ${ep.episodeNumber}. $t';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    final imageUrl = widget.episode.stillUrl ?? widget.fallbackImageUrl;
    final formattedTitle = _formatEpisodeTitle(widget.episode);

    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${widget.tmdbId}_${widget.episode.episodeNumber}';
    final mediaProgress = widget.tmdbId != null ? playbackMap[widget.tmdbId.toString()] : null;
    final localProgress = widget.tmdbId != null
        ? (playbackMap[epKey] ??
            (mediaProgress != null && mediaProgress.episodeNumber == widget.episode.episodeNumber ? mediaProgress : null))
        : null;
    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : null;

    return RepaintBoundary(
      child: widget.isGridView
          ? _buildGridCard(context, theme, isDark, l10n, imageUrl, formattedTitle, progressFraction)
          : _buildListCard(context, theme, isDark, l10n, imageUrl, formattedTitle, progressFraction),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    dynamic l10n,
    String? imageUrl,
    String formattedTitle,
    double? progressFraction,
  ) {
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 16:9 Thumbnail with Box Expansion on hover
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                      if (imageUrl != null && imageUrl.isNotEmpty)
                        CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          memCacheWidth: 400,
                          placeholder: (context, url) => _buildPlaceholder(),
                          errorWidget: (context, url, error) => _buildPlaceholder(),
                        )
                      else
                        _buildPlaceholder(),

                      // Top Left: Local File Badge
                      if (widget.isLocalFile)
                        Positioned(
                          top: 6,
                          left: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.download_done_rounded, size: 10, color: Colors.white),
                                const SizedBox(width: 3),
                                Text(
                                  l10n.localFileBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Bottom Right: Duration Pill
                      if (widget.episode.runtime != null && widget.episode.runtime! > 0)
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${widget.episode.runtime}m',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                              ),
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
                    ],
                  ),
                ),
              ),
            ),
            ),
            const SizedBox(height: 8),

            // Title: "EP X. Title" (Exact AniList Desktop Card look)
            Text(
              formattedTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _isHovered ? theme.colorScheme.primary : titleColor,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    dynamic l10n,
    String? imageUrl,
    String formattedTitle,
    double? progressFraction,
  ) {
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final descColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : theme.colorScheme.onSurfaceVariant;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
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
              // Left 16:9 Thumbnail with Box Expansion on hover
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
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (imageUrl != null && imageUrl.isNotEmpty)
                              CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                memCacheWidth: 480,
                                placeholder: (context, url) => _buildPlaceholder(),
                                errorWidget: (context, url, error) => _buildPlaceholder(),
                              )
                            else
                              _buildPlaceholder(),

                            // Top Left: Local File Badge
                            if (widget.isLocalFile)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 4,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.download_done_rounded, size: 10, color: Colors.white),
                                      const SizedBox(width: 3),
                                      Text(
                                        l10n.localFileBadge,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            // Bottom Right Duration Pill
                            if (widget.episode.runtime != null && widget.episode.runtime! > 0)
                              Positioned(
                                bottom: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.75),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    '${widget.episode.runtime}m',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                    ),
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
                          ],
                        ),
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
                      formattedTitle,
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
                      widget.episode.overview != null && widget.episode.overview!.trim().isNotEmpty
                          ? widget.episode.overview!.trim()
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
    );
  }

  Widget _buildPlaceholder() {
    if (widget.fallbackImageUrl != null) {
      return CachedNetworkImage(
        imageUrl: widget.fallbackImageUrl!,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
      );
    }
    return Container(color: const Color(0xFF1E2228));
  }
}
