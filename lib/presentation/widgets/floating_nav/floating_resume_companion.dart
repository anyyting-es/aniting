import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';

/// A solid Material Design 3 resume playback companion card.
///
/// Features:
/// - 100% solid background (zero transparency/blur) using `surfaceContainer`.
/// - Material 3 elevation shadow and crisp outline.
/// - Cover: Displays STRICTLY the cover poster of the anime or manga.
/// - Title hierarchy:
///   - Top line: Episode title (anime) or manga title (manga).
///   - Bottom line: Anime title (anime) or chapter info (manga) in smaller font.
/// - Full-width linear progress bar along the entire bottom edge.
/// - Distinctive Material 3 play action button on the far right.
/// - Seamless morphing between the expanded card and the compact 64x64 square.
class FloatingResumeCompanion extends StatefulWidget {
  final LastSessionItem session;
  final double tWidth; // 0.0 = compact 64px square, 1.0 = expanded full-width card
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final AppTranslations l10n;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const FloatingResumeCompanion({
    super.key,
    required this.session,
    required this.tWidth,
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.l10n,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<FloatingResumeCompanion> createState() => _FloatingResumeCompanionState();
}

class _FloatingResumeCompanionState extends State<FloatingResumeCompanion> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final t = widget.tWidth.clamp(0.0, 1.0);

    // Text & right button opacity fade out quickly when contracting
    final contentOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);

    // Strictly anime/manga cover poster - NO character art
    final coverUrl = widget.session.coverImage ?? widget.session.displayImage;

    // Title & subtitle resolution
    final String mainTitle;
    final String subTitle;

    if (widget.session.isAnime) {
      if (widget.session.episodeTitle != null &&
          widget.session.episodeTitle!.trim().isNotEmpty) {
        mainTitle = widget.session.episodeNumber != null
            ? 'Ep. ${widget.session.episodeNumber}: ${widget.session.episodeTitle}'
            : widget.session.episodeTitle!;
      } else if (widget.session.episodeNumber != null) {
        mainTitle = '${widget.l10n.episode} ${widget.session.episodeNumber}';
      } else {
        mainTitle = widget.session.title;
      }
      subTitle = widget.session.title;
    } else {
      mainTitle = widget.session.title;
      if (widget.session.subtitle != null &&
          widget.session.subtitle!.trim().isNotEmpty) {
        subTitle = widget.session.subtitle!;
      } else if (widget.session.chapterNumber != null) {
        final chNum = widget.session.chapterNumber! % 1 == 0
            ? widget.session.chapterNumber!.toInt().toString()
            : widget.session.chapterNumber!.toString();
        subTitle = '${widget.l10n.chapter} $chNum';
      } else {
        subTitle = '';
      }
    }

    return Tooltip(
      message: widget.session.isAnime
          ? '${widget.l10n.continueWatching}: ${widget.session.title}'
          : '${widget.l10n.continueReading}: ${widget.session.title}',
      waitDuration: const Duration(milliseconds: 500),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
            // Swipe DOWN -> Dismiss session
            HapticFeedback.lightImpact();
            widget.onDismiss();
          }
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 140),
            scale: _isHovered ? 1.02 : 1.0,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                // Solid M3 surface container - 100% opaque, zero transparency
                color: theme.colorScheme.surfaceContainer,
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: isDark ? 0.25 : 0.15,
                  ),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 14,
                    spreadRadius: 0,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                child: Stack(
                  children: [
                    // Main content: either compact square or full card
                    if (t < 0.1)
                      // Compact 64x64 square layout
                      _buildCompactSquare(
                        theme: theme,
                        coverUrl: coverUrl,
                      )
                    else
                      // Expanded card layout
                      _buildExpandedCard(
                        theme: theme,
                        coverUrl: coverUrl,
                        mainTitle: mainTitle,
                        subTitle: subTitle,
                        contentOpacity: contentOpacity,
                      ),

                    // Full-width Bottom Progress Bar (spans entire card width)
                    if (widget.session.progressRatio > 0.0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 3.0,
                        child: LinearProgressIndicator(
                          value: widget.session.progressRatio,
                          backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            theme.colorScheme.primary,
                          ),
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
    );
  }

  /// Compact 64x64 companion square layout
  Widget _buildCompactSquare({
    required ThemeData theme,
    required String? coverUrl,
  }) {
    const ringDiameter = 50.0;
    const coverDiameter = 44.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular progress ring
          if (widget.session.progressRatio > 0.0)
            SizedBox(
              width: ringDiameter,
              height: ringDiameter,
              child: CircularProgressIndicator(
                value: widget.session.progressRatio,
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.primary,
                ),
                backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),

          // Cover poster thumbnail
          Container(
            width: coverDiameter,
            height: coverDiameter,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(11),
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (coverUrl != null && coverUrl.isNotEmpty)
                  CachedNetworkImage(
                    memCacheWidth: 100,
                    memCacheHeight: 100,
                    maxWidthDiskCache: 160,
                    maxHeightDiskCache: 160,
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Icon(
                      widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                    errorWidget: (_, _, _) => Icon(
                      widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  )
                else
                  Icon(
                    widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),

                // Tiny subtle play indicator badge
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Expanded full-width card layout
  Widget _buildExpandedCard({
    required ThemeData theme,
    required String? coverUrl,
    required String mainTitle,
    required String subTitle,
    required double contentOpacity,
  }) {
    // 40w x 52h vertical poster
    const posterWidth = 40.0;
    const posterHeight = 52.0;

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 3.0),
      child: Row(
        children: [
          // 1. Poster Cover Thumbnail (Left edge)
          Container(
            width: posterWidth,
            height: posterHeight,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              color: theme.colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: coverUrl != null && coverUrl.isNotEmpty
                ? CachedNetworkImage(
                    memCacheWidth: 100,
                    memCacheHeight: 130,
                    maxWidthDiskCache: 160,
                    maxHeightDiskCache: 200,
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Icon(
                      widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                    errorWidget: (_, _, _) => Icon(
                      widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    widget.session.isAnime ? Icons.movie_rounded : Icons.menu_book_rounded,
                    size: 19,
                    color: theme.colorScheme.primary,
                  ),
          ),

          const SizedBox(width: 12),

          // 2. Titles Column (Episode/Manga title on top, Anime name below)
          Expanded(
            child: Opacity(
              opacity: contentOpacity,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainTitle,
                    style: TextStyle(
                      fontSize: 13.8,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subTitle.isNotEmpty) ...[
                    const SizedBox(height: 2.5),
                    Text(
                      subTitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 3. Play action button (Far right edge)
          Opacity(
            opacity: contentOpacity,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  widget.session.isAnime
                      ? Icons.play_arrow_rounded
                      : Icons.menu_book_rounded,
                  size: 24,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
