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
  final double width;
  final double height;

  const ContinueWatchingCard({
    super.key,
    required this.entry,
    required this.onTap,
    this.width = 285,
    this.height = 168,
  });

  @override
  ConsumerState<ContinueWatchingCard> createState() => _ContinueWatchingCardState();
}

class _ContinueWatchingCardState extends ConsumerState<ContinueWatchingCard> {
  bool _isHovered = false;
  bool _isFocused = false;

  bool get _isActive => _isHovered || _isFocused;

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        widget.onTap();
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
    final langCode = appLang.code;

    final epNum = widget.entry.episodeNumber ?? (widget.entry.progress + 1);

    // Always watch AniZip for duration and episode metadata
    final aniZipAsync = widget.entry.mediaId > 0
        ? ref.watch(aniZipDataProvider(widget.entry.mediaId))
        : null;
    final aniZipData = aniZipAsync?.asData?.value;
    final aniZipEpisode = aniZipData?.getEpisode(epNum);

    final String? resolvedThumbnail = (aniZipEpisode?.image != null &&
            aniZipEpisode!.image!.trim().isNotEmpty)
        ? aniZipEpisode.image!.trim()
        : (widget.entry.episodeThumbnail != null &&
                widget.entry.episodeThumbnail != widget.entry.bannerImage
            ? widget.entry.episodeThumbnail
            : null);

    final imageUrl = resolvedThumbnail ?? widget.entry.bannerImage ?? widget.entry.coverImage;

    final String resolvedEpTitle = (aniZipEpisode != null &&
            aniZipEpisode.displayTitleForLang(langCode).isNotEmpty &&
            !aniZipEpisode.displayTitleForLang(langCode).toLowerCase().startsWith('episod'))
        ? aniZipEpisode.displayTitleForLang(langCode)
        : (widget.entry.episodeTitle != null &&
                widget.entry.episodeTitle!.isNotEmpty &&
                !widget.entry.episodeTitle!.toLowerCase().startsWith('episod')
            ? widget.entry.episodeTitle!
            : '');

    final String titleLine = resolvedEpTitle.isNotEmpty
        ? 'EP $epNum • $resolvedEpTitle'
        : 'EP $epNum';

    final animeTitle = widget.entry.displayTitle(titleLang);
    final String? episodeDuration = aniZipEpisode?.formattedDuration;

    // Local video playback progress (only appears if user has actually watched part of THIS episode locally)
    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${widget.entry.mediaId}_$epNum';
    final mediaProgress = playbackMap[widget.entry.mediaId.toString()];
    final localProgress = playbackMap[epKey] ??
        (mediaProgress != null && mediaProgress.episodeNumber == epNum ? mediaProgress : null);
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
            onTap: widget.onTap,
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
                                    memCacheWidth: isCompact ? 450 : 600,
                                    memCacheHeight: isCompact ? 260 : 340,
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
