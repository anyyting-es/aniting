import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class ContinueWatchingCard extends ConsumerStatefulWidget {
  final AnimeEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onOpenDetails;
  final double width;
  final double height;

  const ContinueWatchingCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.onOpenDetails,
    this.width = 285,
    this.height = 168,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;
  bool _isLaunching = false;

  bool get _isActive => _isHovered || _isFocused;

  Future<void> _handleTap() async {
    if (_isLaunching) return;
    setState(() => _isLaunching = true);
    try {
      widget.onTap();
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        _handleTap();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final titleLang = ref.watch(titleLanguageProvider);
    final appLang = ref.watch(appLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final langCode = appLang.code;

    final isMovie = widget.entry.format?.toUpperCase() == 'MOVIE' ||
        (widget.entry.totalEpisodes == 1 && widget.entry.format?.toUpperCase() != 'TV');

    final epNum = widget.entry.episodeNumber ?? (widget.entry.progress + 1);

    // Always watch AniZip for duration and episode metadata
    final aniZipAsync = widget.entry.mediaId > 0
        ? ref.watch(aniZipDataProvider(widget.entry.mediaId))
        : null;
    final aniZipData = aniZipAsync?.asData?.value;
    final aniZipEpisode = aniZipData?.getEpisode(epNum);

    // Check if the server's episodeThumbnail is merely a fallback to the vertical cover poster
    final bool isEpisodeThumbCoverPoster = widget.entry.episodeThumbnail != null &&
        (widget.entry.episodeThumbnail == widget.entry.coverImage ||
            (widget.entry.coverImage != null &&
                widget.entry.coverImage!.isNotEmpty &&
                widget.entry.episodeThumbnail!.contains(widget.entry.coverImage!)));

    String? imageUrl;
    if (isMovie) {
      // For movies, AniList's bannerImage is the native high-res 16:9 cinematic artwork.
      // Seanime's episodeThumbnail for movies defaults to the vertical cover poster.
      if (widget.entry.bannerImage != null && widget.entry.bannerImage!.trim().isNotEmpty) {
        imageUrl = widget.entry.bannerImage!.trim();
      } else if (aniZipEpisode?.image != null && aniZipEpisode!.image!.trim().isNotEmpty) {
        imageUrl = aniZipEpisode.image!.trim();
      } else if (widget.entry.episodeThumbnail != null && !isEpisodeThumbCoverPoster) {
        imageUrl = widget.entry.episodeThumbnail;
      } else {
        imageUrl = widget.entry.coverImage;
      }
    } else {
      // For series, prefer AniZip 16:9 episode screencap, then server episodeThumbnail, then bannerImage
      if (aniZipEpisode?.image != null && aniZipEpisode!.image!.trim().isNotEmpty) {
        imageUrl = aniZipEpisode.image!.trim();
      } else if (widget.entry.episodeThumbnail != null &&
          !isEpisodeThumbCoverPoster &&
          widget.entry.episodeThumbnail != widget.entry.bannerImage) {
        imageUrl = widget.entry.episodeThumbnail;
      } else if (widget.entry.bannerImage != null && widget.entry.bannerImage!.trim().isNotEmpty) {
        imageUrl = widget.entry.bannerImage!.trim();
      } else {
        imageUrl = widget.entry.coverImage;
      }
    }

    final bool isCoverFallback = imageUrl != null && imageUrl == widget.entry.coverImage;

    final String resolvedEpTitle = (aniZipEpisode != null &&
            aniZipEpisode.displayTitleForLang(langCode).isNotEmpty &&
            !aniZipEpisode.displayTitleForLang(langCode).toLowerCase().startsWith('episod'))
        ? aniZipEpisode.displayTitleForLang(langCode)
        : (widget.entry.episodeTitle != null &&
                widget.entry.episodeTitle!.isNotEmpty &&
                !widget.entry.episodeTitle!.toLowerCase().startsWith('episod')
            ? widget.entry.episodeTitle!
            : '');

    final String titleLine;
    if (isMovie) {
      titleLine = resolvedEpTitle.isNotEmpty ? resolvedEpTitle : l10n.formatMovie;
    } else {
      titleLine = resolvedEpTitle.isNotEmpty
          ? 'EP $epNum • $resolvedEpTitle'
          : 'EP $epNum';
    }

    final animeTitle = widget.entry.displayTitle(titleLang);
    final String? episodeDuration = aniZipEpisode?.formattedDuration;

    // Local video playback progress (only appears if user has actually watched part of THIS episode locally)
    final epKey = '${widget.entry.mediaId}_$epNum';
    final mediaIdStr = widget.entry.mediaId.toString();
    final localProgress = ref.watch(
      playbackProgressPreferencesProvider.select((map) {
        final direct = map[epKey];
        if (direct != null) return direct;
        final mediaProgress = map[mediaIdStr];
        return (mediaProgress != null && mediaProgress.episodeNumber == epNum) ? mediaProgress : null;
      }),
    );
    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : null;

    final isCompact = widget.width < 270;

    return RepaintBoundary(
      child: Focus(
        onFocusChange: (val) => setState(() => _isFocused = val),
        onKeyEvent: _handleKeyEvent,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleTap,
            onLongPress: widget.onOpenDetails,
            onSecondaryTap: widget.onOpenDetails,
            child: SizedBox(
              width: widget.width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Clean Cover Image Container (whole box expands on hover)
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: AnimatedScale(
                      scale: _isHovered ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(isCompact ? (colors.borderRadius * 0.8).clamp(0.0, 16.0) : colors.borderRadius),
                          border: Border.all(
                            color: _isFocused
                                ? Colors.white
                                : (_isHovered
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : colors.border.withValues(alpha: 0.5)),
                            width: _isFocused ? 2.0 : 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: _isHovered ? 0.30 : 0.15),
                              blurRadius: _isHovered ? 8 : 4,
                              offset: Offset(0, _isHovered ? 3 : 2),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            imageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    alignment: isCoverFallback ? Alignment.topCenter : Alignment.center,
                                    memCacheWidth: isCompact ? 450 : 600,
                                    placeholder: (context, url) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                    ),
                                    errorWidget: (context, url, error) => Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Icon(Icons.movie_rounded, color: theme.colorScheme.outline, size: isCompact ? 28 : 36),
                                    ),
                                  )
                                : Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                    child: Icon(Icons.movie_rounded, color: theme.colorScheme.outline, size: isCompact ? 28 : 36),
                                  ),
                            // Expressive Play Badge on hover / focus
                            if (_isActive && !_isLaunching)
                              Center(
                                child: Container(
                                  width: isCompact ? 36 : 44,
                                  height: isCompact ? 36 : 44,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.5),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.35),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: isCompact ? 22 : 28,
                                  ),
                                ),
                              ),
                            // Launching spinner overlay
                            if (_isLaunching)
                              Container(
                                color: Colors.black.withValues(alpha: 0.55),
                                child: const Center(
                                  child: SizedBox(
                                    width: 26,
                                    height: 26,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            // Subtle video playback progress indicator at the bottom edge (only if watched locally)
                            if (progressFraction != null && progressFraction > 0.01 && progressFraction < 0.98)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(
                                  value: progressFraction,
                                  backgroundColor: Colors.black.withValues(alpha: 0.35),
                                  valueColor: AlwaysStoppedAnimation<Color>(colors.accent),
                                  minHeight: isCompact ? 2.5 : 3.0,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: isCompact ? 6 : 8),
                  // 2. Info Below the Cover
                  Text(
                    titleLine,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: (_isActive || _isHovered)
                          ? theme.colorScheme.primary
                          : (theme.brightness == Brightness.dark
                              ? colors.textPrimary
                              : const Color(0xFF111418)),
                      fontSize: isCompact ? 12.0 : 13.0,
                      fontWeight: FontWeight.bold,
                      height: 1.25,
                      fontFamilyFallback: kJapaneseFontFallbacks,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: widget.onOpenDetails ?? _handleTap,
                          child: Text(
                            animeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: isCompact ? 10.5 : 11.5,
                              fontWeight: FontWeight.w500,
                              fontFamilyFallback: kJapaneseFontFallbacks,
                            ),
                          ),
                        ),
                      ),
                      if (episodeDuration != null && episodeDuration.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          episodeDuration,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: isCompact ? 9.5 : 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
