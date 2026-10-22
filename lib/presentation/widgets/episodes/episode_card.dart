import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/data/models/episode_item.dart';

/// Universal canonical episode card supporting both Grid (16:9) and List (compact row) modes.
/// Works identically for Anime, TMDB TV Shows, and Movies.
class EpisodeCard extends ConsumerStatefulWidget {
  final int? mediaId;
  final EpisodeItem episode;
  final String? fallbackImageUrl;
  final String? coverColor;
  final bool isGridView;
  final VoidCallback? onTap;
  final VoidCallback? onOpenTorrent;
  final bool isLoading;

  const EpisodeCard({
    super.key,
    this.mediaId,
    required this.episode,
    this.fallbackImageUrl,
    this.coverColor,
    this.isGridView = true,
    this.onTap,
    this.onOpenTorrent,
    this.isLoading = false,
  });

  @override
  ConsumerState<EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends ConsumerState<EpisodeCard> {
  bool _isHovered = false;

  String _formatTitle() {
    final ep = widget.episode;
    final cleanT = ep.title.trim();
    final prefix = (ep.seasonNumber != null && ep.seasonNumber! > 1)
        ? 'S${ep.seasonNumber}E${ep.number}'
        : 'EP ${ep.number}';

    if (cleanT.isEmpty ||
        cleanT.toLowerCase() == 'episodio ${ep.number}' ||
        cleanT.toLowerCase() == 'episode ${ep.number}' ||
        cleanT == prefix) {
      return prefix;
    }
    return '$prefix. $cleanT';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    // Watch playback progress map for real-time continuity bar
    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${widget.mediaId}_${widget.episode.number}';
    final mediaProgress = widget.mediaId != null ? playbackMap[widget.mediaId.toString()] : null;
    final localProgress = widget.mediaId != null
        ? (playbackMap[epKey] ??
            (mediaProgress != null && mediaProgress.episodeNumber == widget.episode.number ? mediaProgress : null))
        : null;

    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : (widget.episode.progress > 0 ? widget.episode.progress : null);

    final imageUrl = widget.episode.image ?? widget.fallbackImageUrl;
    final formattedTitle = _formatTitle();
    final double cardOpacity = widget.episode.isWatched ? (_isHovered ? 0.80 : 0.50) : 1.0;

    final iconPack = ref.watch(iconPackProvider);

    return RepaintBoundary(
      child: AnimatedOpacity(
        opacity: cardOpacity,
        duration: const Duration(milliseconds: 200),
        child: widget.isGridView
            ? _buildGridCard(context, theme, isDark, l10n, iconPack, imageUrl, formattedTitle, progressFraction)
            : _buildListCard(context, theme, isDark, l10n, iconPack, imageUrl, formattedTitle, progressFraction),
      ),
    );
  }

  Widget _buildGridCard(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    dynamic l10n,
    AppIconPack iconPack,
    String? imageUrl,
    String formattedTitle,
    double? progressFraction,
  ) {
    final dynamicColor = parseHexColor(widget.coverColor) ?? theme.colorScheme.primary;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return MouseRegion(
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        AppFocusCoordinator.onPointerEntered();
        setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Stack(
          children: [
            // Ambient color background with inside-out expansion animation (No borders)
            Positioned.fill(
              child: AnimatedScale(
                scale: _isHovered ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 220),
                curve: _isHovered ? Curves.easeOutCubic : Curves.easeInCubic,
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: dynamicColor.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 16:9 Thumbnail
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AnimatedScale(
                      scale: _isHovered ? 1.015 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.20),
                              blurRadius: _isHovered ? 10 : 6,
                              offset: Offset(0, _isHovered ? 3 : 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnailImage(imageUrl, theme, iconPack),
                        if (widget.isLoading)
                          Container(
                            color: Colors.black.withValues(alpha: 0.65),
                            child: const Center(
                              child: SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2.5),
                              ),
                            ),
                          ),
                        _buildBadges(l10n, iconPack),
                        if (progressFraction != null && progressFraction > 0)
                          _buildProgressBar(theme, progressFraction),
                        if (widget.onOpenTorrent != null && _isHovered)
                          _buildTorrentHoverButton(l10n, iconPack),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Title only: enlarged, clean and white
              Text(
                formattedTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.0,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  height: 1.25,
                ),
              ),
            ],
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
    AppIconPack iconPack,
    String? imageUrl,
    String formattedTitle,
    double? progressFraction,
  ) {
    final dynamicColor = parseHexColor(widget.coverColor) ?? theme.colorScheme.primary;

    return MouseRegion(
      cursor: widget.isLoading ? SystemMouseCursors.basic : SystemMouseCursors.click,
      onEnter: (_) {
        AppFocusCoordinator.onPointerEntered();
        setState(() => _isHovered = true);
      },
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.isLoading ? null : widget.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: [
            // Ambient color background with inside-out expansion animation (No borders)
            Positioned.fill(
              child: AnimatedScale(
                scale: _isHovered ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 220),
                curve: _isHovered ? Curves.easeOutCubic : Curves.easeInCubic,
                alignment: Alignment.center,
                child: AnimatedOpacity(
                  opacity: _isHovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: dynamicColor.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Foreground Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 16:9 Left Thumbnail
                  SizedBox(
                    width: 130,
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                            width: 1.0,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildThumbnailImage(imageUrl, theme, iconPack),
                            if (progressFraction != null && progressFraction > 0)
                              _buildProgressBar(theme, progressFraction),
                            if (widget.episode.isDownloaded)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: _buildLocalBadge(l10n, iconPack),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Right: Title, synopsis, and duration
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formattedTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        if (widget.episode.synopsis != null && widget.episode.synopsis!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Text(
                              widget.episode.synopsis!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                height: 1.3,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  if (widget.onOpenTorrent != null)
                    IconButton(
                      icon: Icon(AppIcons.download(iconPack), size: 20),
                      tooltip: l10n.torrents,
                      onPressed: widget.onOpenTorrent,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailImage(String? imageUrl, ThemeData theme, AppIconPack iconPack) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: 400,
        memCacheHeight: 225,
        placeholder: (_, _) => Container(color: theme.colorScheme.surfaceContainerHighest),
        errorWidget: (_, _, _) => Container(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Icon(AppIcons.movie(iconPack), color: theme.colorScheme.outline),
        ),
      );
    }
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(AppIcons.movie(iconPack), color: theme.colorScheme.outline),
    );
  }

  Widget _buildBadges(dynamic l10n, AppIconPack iconPack) {
    return Positioned(
      top: 6,
      left: 6,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.episode.isDownloaded)
            _buildLocalBadge(l10n, iconPack),
          if (widget.episode.isFiller) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Filler',
                style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocalBadge(dynamic l10n, AppIconPack iconPack) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.folderFilled(iconPack), color: Colors.white, size: 10),
          const SizedBox(width: 3),
          const Text(
            'Local',
            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(ThemeData theme, double fraction) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: LinearProgressIndicator(
        value: fraction,
        minHeight: 3.5,
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
      ),
    );
  }

  Widget _buildTorrentHoverButton(dynamic l10n, AppIconPack iconPack) {
    return Positioned(
      top: 6,
      right: 6,
      child: Material(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: widget.onOpenTorrent,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(
              AppIcons.download(iconPack),
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
    );
  }
}
