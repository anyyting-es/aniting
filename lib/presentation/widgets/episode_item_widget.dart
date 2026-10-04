import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';

/// Shows the full details modal when an episode is long-pressed
void showEpisodeDetailModal({
  required BuildContext context,
  required int episodeNumber,
  required String title,
  String? originalTitle,
  String? synopsis,
  String? image,
  String? fallbackImage,
  String? duration,
  String? airDate,
  String? rating,
  String? badgeText,
  VoidCallback? onPlay,
  VoidCallback? onDownload,
  VoidCallback? onDelete,
}) {
  final theme = Theme.of(context);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Consumer(
        builder: (ctx, ref, _) {
          final l10n = ref.watch(translationsProvider);
          final iconPack = ref.watch(iconPackProvider);
          final modalRadius = context.themeColors.borderRadius;
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Screencap
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(modalRadius),
                          child: image != null && image.isNotEmpty
                              ? CachedNetworkImage(
                                  memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                                  imageUrl: image,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => fallbackImage != null
                                      ? CachedNetworkImage(memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270, imageUrl: fallbackImage, fit: BoxFit.cover)
                                      : Container(color: theme.colorScheme.surfaceContainerHighest),
                                )
                              : fallbackImage != null
                                  ? CachedNetworkImage(memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270, imageUrl: fallbackImage, fit: BoxFit.cover)
                                  : Container(color: theme.colorScheme.surfaceContainerHighest),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(modalRadius),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'EP $episodeNumber',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        if (duration != null)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.access_time_rounded, size: 12, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Text(
                                    duration,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Episode Title
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),

                  // Original / Romaji title
                  if (originalTitle != null && originalTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      originalTitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Metadata Badges (AirDate, Rating, Duration, Tag)
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (airDate != null && airDate.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 12, color: theme.colorScheme.primary),
                              const SizedBox(width: 5),
                              Text(
                                airDate,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (rating != null && rating.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, size: 14, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                rating,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (badgeText != null && badgeText.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Synopsis
                  if (synopsis != null && synopsis.isNotEmpty) ...[
                    Text(
                      l10n.episodeSynopsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      synopsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Text(
                      l10n.noDescriptionAvailable,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Action Buttons
                  Row(
                    children: [
                      if (onPlay != null)
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              onPlay();
                            },
                            icon: Icon(AppIcons.play(iconPack), size: 22),
                            label: Text(l10n.play),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((modalRadius * 0.75).clamp(0.0, 16.0))),
                            ),
                          ),
                        ),
                      if (onDownload != null) ...[
                        if (onPlay != null) const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: l10n.downloadWithTorrentClient,
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDownload();
                          },
                          icon: Icon(AppIcons.download(iconPack), size: 20),
                          style: IconButton.styleFrom(
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((modalRadius * 0.75).clamp(0.0, 16.0))),
                          ),
                        ),
                      ],
                      if (onDelete != null) ...[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: l10n.deleteDownload,
                          onPressed: () {
                            Navigator.pop(ctx);
                            onDelete();
                          },
                          icon: Icon(AppIcons.delete(iconPack), size: 20, color: theme.colorScheme.error),
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                            padding: const EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((modalRadius * 0.75).clamp(0.0, 16.0))),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((modalRadius * 0.75).clamp(0.0, 16.0))),
                        ),
                        child: Text(l10n.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
        },
      );
    },
  );
}

/// Unified episode list tile: clean, loose (not boxed in heavy cards),
/// larger thumbnail without play icon inside, episode number with small duration on right,
/// title below, and synopsis below. Long-press opens full details modal.
class EpisodeListItem extends ConsumerWidget {
  final int episodeNumber;
  final String title;
  final String? originalTitle;
  final String? duration;
  final String? synopsis;
  final String? image;
  final String? fallbackImage;
  final String? airDate;
  final String? rating;
  final String? badgeText;
  final bool isPlaying;
  final bool isLoading;
  final bool isWatched;
  final bool isDownloading;
  final double? downloadProgress;
  final bool isDownloaded;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const EpisodeListItem({
    super.key,
    required this.episodeNumber,
    required this.title,
    this.originalTitle,
    this.duration,
    this.synopsis,
    this.image,
    this.fallbackImage,
    this.airDate,
    this.rating,
    this.badgeText,
    this.isPlaying = false,
    this.isLoading = false,
    this.isWatched = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.isDownloaded = false,
    this.onTap,
    this.onPlay,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final itemRadius = context.themeColors.borderRadius;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(itemRadius),
        onTap: isLoading ? null : (onTap ?? onPlay),
        onLongPress: () {
          showEpisodeDetailModal(
            context: context,
            episodeNumber: episodeNumber,
            title: title,
            originalTitle: originalTitle,
            synopsis: synopsis,
            image: image,
            fallbackImage: fallbackImage,
            duration: duration,
            airDate: airDate,
            rating: rating,
            badgeText: badgeText,
            onPlay: onPlay ?? onTap,
            onDownload: onDownload,
            onDelete: onDelete,
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Larger, squarer 4:3 Thumbnail without play icon inside or on side
              SizedBox(
                width: 132,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(itemRadius),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image != null && image!.isNotEmpty)
                          CachedNetworkImage(
                            memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                            imageUrl: image!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => fallbackImage != null
                                ? CachedNetworkImage(memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270, imageUrl: fallbackImage!, fit: BoxFit.cover)
                                : Container(color: theme.colorScheme.surfaceContainerHighest),
                          )
                        else if (fallbackImage != null)
                          CachedNetworkImage(
                            memCacheWidth: 320, memCacheHeight: 180, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                            imageUrl: fallbackImage!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                Container(color: theme.colorScheme.surfaceContainerHighest),
                          )
                        else
                          Container(color: theme.colorScheme.surfaceContainerHighest),
                        // Subtle gradient overlay for polish
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.1),
                                Colors.black.withValues(alpha: 0.4),
                              ],
                            ),
                          ),
                        ),
                        // Small badge if provided (e.g. SP or RELLENO)
                        if (badgeText != null && badgeText!.isNotEmpty)
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                badgeText!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8.5,
                                ),
                              ),
                            ),
                          ),
                        if (isPlaying)
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.graphic_eq_rounded, size: 12, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    l10n.watching,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        // Watched overlay: semi-transparent dark film + check icon
                        if (isWatched && !isPlaying) ...[
                          Container(
                            color: Colors.black.withValues(alpha: 0.45),
                          ),
                          Positioned(
                            bottom: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.check_rounded, size: 13, color: Colors.white70),
                            ),
                          ),
                        ],

                        // Local downloaded badge on thumbnail
                        if (isDownloaded)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.82),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: Colors.greenAccent.withValues(alpha: 0.7),
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
                        else if (isDownloading)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.75),
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
                                      value: (downloadProgress != null && downloadProgress! > 0)
                                          ? downloadProgress
                                          : null,
                                      valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                                      backgroundColor: (downloadProgress != null && downloadProgress! > 0)
                                          ? theme.colorScheme.primary.withValues(alpha: 0.25)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    downloadProgress != null && downloadProgress! > 0
                                        ? '${(downloadProgress! * 100).toInt()}%'
                                        : l10n.downloading,
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
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info Column
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Episode Number + Duration
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          'EP $episodeNumber',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: isWatched
                                ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)
                                : theme.colorScheme.primary,
                          ),
                        ),
                        if (duration != null && duration!.isNotEmpty) ...[
                          const SizedBox(width: 7),
                          Text(
                            duration!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: isWatched ? 0.4 : 0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Row 2: Title
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        height: 1.25,
                        color: isWatched
                            ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55)
                            : null,
                      ),
                    ),

                    // Row 3: Synopsis
                    if (synopsis != null && synopsis!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        synopsis!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: isWatched ? 0.4 : 0.8),
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Loading indicator if starting playback or downloading
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8, right: 4, top: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else if (isDownloading)
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 4, top: 10),
                  child: Tooltip(
                    message: downloadProgress != null
                        ? '${l10n.downloading}: ${(downloadProgress! * 100).toInt()}%'
                        : l10n.downloading,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: (downloadProgress != null && downloadProgress! > 0)
                                ? downloadProgress
                                : null,
                            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                            backgroundColor: (downloadProgress != null && downloadProgress! > 0)
                                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                : null,
                          ),
                        ),
                        if (downloadProgress != null && downloadProgress! > 0) ...[
                          const SizedBox(height: 3),
                          Text(
                            '${(downloadProgress! * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact grid item for grid view mode:
/// No image, just episode number and title. Long-press opens full details.
class EpisodeGridItem extends StatelessWidget {
  final int episodeNumber;
  final String title;
  final String? originalTitle;
  final String? duration;
  final String? synopsis;
  final String? image;
  final String? fallbackImage;
  final String? airDate;
  final String? rating;
  final String? badgeText;
  final bool isPlaying;
  final bool isLoading;
  final bool isWatched;
  final bool isDownloading;
  final double? downloadProgress;
  final bool isDownloaded;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const EpisodeGridItem({
    super.key,
    required this.episodeNumber,
    required this.title,
    this.originalTitle,
    this.duration,
    this.synopsis,
    this.image,
    this.fallbackImage,
    this.airDate,
    this.rating,
    this.badgeText,
    this.isPlaying = false,
    this.isLoading = false,
    this.isWatched = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.isDownloaded = false,
    this.onTap,
    this.onPlay,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gridRadius = context.themeColors.borderRadius;

    return Material(
      color: isWatched && !isPlaying
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : isDownloaded
              ? Colors.green.withValues(alpha: 0.08)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(gridRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(gridRadius),
        onTap: (isLoading || isDownloading) ? null : onTap,
        onLongPress: () {
          showEpisodeDetailModal(
            context: context,
            episodeNumber: episodeNumber,
            title: title,
            originalTitle: originalTitle,
            synopsis: synopsis,
            image: image,
            fallbackImage: fallbackImage,
            duration: duration,
            airDate: airDate,
            rating: rating,
            badgeText: badgeText,
            onPlay: onPlay ?? onTap,
            onDownload: onDownload,
            onDelete: onDelete,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(gridRadius),
            border: Border.all(
              color: isPlaying
                  ? theme.colorScheme.primary
                  : isDownloading
                      ? theme.colorScheme.primary.withValues(alpha: 0.6)
                      : isDownloaded
                          ? Colors.greenAccent.withValues(alpha: 0.5)
                          : isWatched
                              ? theme.colorScheme.primary.withValues(alpha: 0.2)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: (isPlaying || isDownloading) ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isLoading || isDownloading)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        value: isDownloading &&
                                (downloadProgress != null && downloadProgress! > 0)
                            ? downloadProgress
                            : null,
                        valueColor: isDownloading
                            ? AlwaysStoppedAnimation(theme.colorScheme.primary)
                            : null,
                        backgroundColor: isDownloading &&
                                (downloadProgress != null && downloadProgress! > 0)
                            ? theme.colorScheme.primary.withValues(alpha: 0.25)
                            : null,
                      ),
                    ),
                    if (isDownloading &&
                        downloadProgress != null &&
                        downloadProgress! > 0) ...[
                      const SizedBox(height: 2.5),
                      Text(
                        '${(downloadProgress! * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ],
                )
              else if (isDownloaded)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 12, color: Colors.greenAccent),
                    const SizedBox(width: 3),
                    Text(
                      'EP $episodeNumber',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                )
              else if (isWatched && !isPlaying)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                    const SizedBox(width: 3),
                    Text(
                      'EP $episodeNumber',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                )
              else
                Text(
                  'EP $episodeNumber',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isPlaying ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: isWatched && !isPlaying
                      ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45)
                      : theme.colorScheme.onSurfaceVariant,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
