import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

class TmdbEpisodeCard extends ConsumerStatefulWidget {
  final TmdbEpisode episode;
  final String? fallbackImageUrl;
  final bool isGridView;
  final VoidCallback? onTap;

  const TmdbEpisodeCard({
    super.key,
    required this.episode,
    this.fallbackImageUrl,
    this.isGridView = true,
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

    if (widget.isGridView) {
      return _buildGridCard(context, theme, isDark, l10n, imageUrl, formattedTitle);
    } else {
      return _buildListCard(context, theme, isDark, l10n, imageUrl, formattedTitle);
    }
  }

  Widget _buildGridCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    dynamic l10n,
    String? imageUrl,
    String formattedTitle,
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
                  clipBehavior: Clip.antiAlias,
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

                      // Top Right: Score / Rating Pill
                      if (widget.episode.voteAverage != null && widget.episode.voteAverage! > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: Colors.amber.withValues(alpha: 0.5),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                                const SizedBox(width: 3),
                                Text(
                                  widget.episode.voteAverage!.toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
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
                    ],
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
                      clipBehavior: Clip.antiAlias,
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

                          // Top Right Score Pill
                          if (widget.episode.voteAverage != null && widget.episode.voteAverage! > 0)
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.75),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.5),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 11, color: Colors.amber),
                                    const SizedBox(width: 3),
                                    Text(
                                      widget.episode.voteAverage!.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
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
