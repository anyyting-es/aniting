import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
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
                                  memCacheWidth: 320, maxWidthDiskCache: 480,
                                  imageUrl: image,
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => fallbackImage != null
                                      ? CachedNetworkImage(memCacheWidth: 320, maxWidthDiskCache: 480, imageUrl: fallbackImage, fit: BoxFit.cover)
                                      : Container(color: theme.colorScheme.surfaceContainerHighest),
                                )
                              : fallbackImage != null
                                  ? CachedNetworkImage(memCacheWidth: 320, maxWidthDiskCache: 480, imageUrl: fallbackImage, fit: BoxFit.cover)
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
                                  Icon(AppIcons.clock(iconPack), size: 12, color: Colors.white70),
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
                              Icon(AppIcons.calendar(iconPack), size: 12, color: theme.colorScheme.primary),
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
                              Icon(AppIcons.star(iconPack), size: 14, color: theme.colorScheme.primary),
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
  final int? mediaId;
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
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const EpisodeListItem({
    super.key,
    this.mediaId,
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
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelection,
    this.onLongPress,
    this.onTap,
    this.onPlay,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final itemRadius = context.themeColors.borderRadius;

    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${mediaId}_$episodeNumber';
    final mediaProgress = mediaId != null ? playbackMap[mediaId.toString()] : null;
    final localProgress = mediaId != null
        ? (playbackMap[epKey] ??
            (mediaProgress != null && mediaProgress.episodeNumber == episodeNumber ? mediaProgress : null))
        : null;
    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : null;

    final showCheckbox = isSelectionMode || isSelected;

    return RepaintBoundary(
      child: AnimatedScale(
        scale: isSelected ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.28 : 0.42)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(itemRadius),
            border: isSelected
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.9),
                    width: 1.6,
                  )
                : (isSelectionMode
                    ? Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                        width: 0.8,
                      )
                    : null),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(itemRadius),
              onTap: (isLoading || isDownloading)
                  ? null
                  : (isSelectionMode
                      ? () {
                          HapticFeedback.selectionClick();
                          onToggleSelection?.call();
                        }
                      : (onTap ?? onPlay)),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                if (onLongPress != null) {
                  onLongPress!();
                } else if (onToggleSelection != null) {
                  onToggleSelection!();
                } else {
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
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Animated Selection Checkbox
                    if (showCheckbox) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 14, right: 6),
                        child: AnimatedScale(
                          scale: isSelected ? 1.0 : 0.88,
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutBack,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant,
                                width: 1.8,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ],
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
                            memCacheWidth: 320, maxWidthDiskCache: 480,
                            imageUrl: image!,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) => fallbackImage != null
                                ? CachedNetworkImage(memCacheWidth: 320, maxWidthDiskCache: 480, imageUrl: fallbackImage!, fit: BoxFit.cover)
                                : Container(color: theme.colorScheme.surfaceContainerHighest),
                          )
                        else if (fallbackImage != null)
                          CachedNetworkImage(
                            memCacheWidth: 320, maxWidthDiskCache: 480,
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
                                  Icon(AppIcons.sensors(iconPack), size: 12, color: Colors.white),
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
                              child: Icon(AppIcons.check(iconPack), size: 13, color: Colors.white70),
                            ),
                          ),
                        ],

                        // Downloading progress badge
                        if (isDownloading)
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
                              minHeight: 2.5,
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
                        const Spacer(),
                        if (isDownloaded) ...[
                          Icon(
                            AppIcons.checkCircle(iconPack),
                            size: 14,
                            color: Colors.greenAccent.shade400,
                          ),
                          const SizedBox(width: 4),
                        ],
                        if (onPlay != null || onDownload != null || onDelete != null)
                          GlassMenuAnchor(
                            width: 210,
                            items: [
                              if (onPlay != null || onTap != null)
                                GlassMenuItem(
                                  label: l10n.playEpisode,
                                  icon: Icon(AppIcons.play(iconPack), size: 18),
                                  onPressed: onPlay ?? onTap,
                                ),
                              if (onDownload != null && !isDownloaded)
                                GlassMenuItem(
                                  label: l10n.downloadEpisode,
                                  icon: Icon(AppIcons.download(iconPack), size: 18),
                                  onPressed: onDownload,
                                ),
                              if (onDelete != null && isDownloaded)
                                GlassMenuItem(
                                  label: l10n.deleteDownload,
                                  isDestructive: true,
                                  icon: Icon(AppIcons.trash(iconPack), size: 18),
                                  onPressed: onDelete,
                                ),
                              GlassMenuItem(
                                label: l10n.details,
                                icon: Icon(AppIcons.info(iconPack), size: 18),
                                onPressed: () {
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
                              ),
                            ],
                            builder: (context, controller) {
                              return InkWell(
                                onTap: controller.open,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: Icon(
                                    AppIcons.moreHoriz(iconPack),
                                    size: 18,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                  ),
                                ),
                              );
                            },
                          ),
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

              // Loading indicator only when starting playback (not downloading —
              // the thumbnail badge already shows the download state)
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(left: 8, right: 4, top: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
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
}

/// Compact grid item for grid view mode:
/// No image, just episode number and title. Long-press opens full details.
class EpisodeGridItem extends ConsumerWidget {
  final int? mediaId;
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
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelection;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;

  const EpisodeGridItem({
    super.key,
    this.mediaId,
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
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelection,
    this.onLongPress,
    this.onTap,
    this.onPlay,
    this.onDownload,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final gridRadius = context.themeColors.borderRadius;

    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    final epKey = '${mediaId}_$episodeNumber';
    final mediaProgress = mediaId != null ? playbackMap[mediaId.toString()] : null;
    final localProgress = mediaId != null
        ? (playbackMap[epKey] ??
            (mediaProgress != null && mediaProgress.episodeNumber == episodeNumber ? mediaProgress : null))
        : null;
    final double? progressFraction = (localProgress != null &&
            localProgress.durationMs > 0 &&
            localProgress.positionMs > 0)
        ? (localProgress.positionMs / localProgress.durationMs).clamp(0.0, 1.0)
        : null;

    final baseColor = isWatched && !isPlaying
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : isDownloaded
            ? Colors.green.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45);

    return RepaintBoundary(
      child: AnimatedScale(
        scale: isSelected ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: isDark ? 0.35 : 0.5)
                : baseColor,
            borderRadius: BorderRadius.circular(gridRadius),
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : (isPlaying
                      ? theme.colorScheme.primary
                      : isDownloading
                          ? theme.colorScheme.primary.withValues(alpha: 0.6)
                          : isDownloaded
                              ? Colors.greenAccent.withValues(alpha: 0.5)
                              : isWatched
                                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                  : (isSelectionMode
                                      ? theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
                                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
              width: isSelected ? 2.0 : ((isPlaying || isDownloading) ? 1.5 : 1.0),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(gridRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(gridRadius),
              onTap: (isLoading || isDownloading)
                  ? null
                  : (isSelectionMode
                      ? () {
                          HapticFeedback.selectionClick();
                          onToggleSelection?.call();
                        }
                      : (onTap ?? onPlay)),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                if (onLongPress != null) {
                  onLongPress!();
                } else if (onToggleSelection != null) {
                  onToggleSelection!();
                } else {
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
                }
              },
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  if (isSelectionMode || isSelected)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: AnimatedScale(
                        scale: isSelected ? 1.0 : 0.85,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutBack,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            border: Border.all(
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              width: 1.8,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 13,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ),
                    ),
                  Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                    Icon(AppIcons.checkCircle(iconPack), size: 12, color: Colors.greenAccent),
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
                    Icon(AppIcons.check(iconPack), size: 14, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
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
      if (progressFraction != null && progressFraction > 0.01 && progressFraction < 0.98)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: progressFraction,
                    backgroundColor: Colors.black.withValues(alpha: 0.25),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 2.5,
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
}
