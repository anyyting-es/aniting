import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';

bool _isGenericTitle(String? title, int epNum) {
  if (title == null || title.trim().isEmpty) return true;
  final clean = title.trim().toLowerCase();
  if (clean == 'episodio $epNum' ||
      clean == 'episode $epNum' ||
      clean == 'ep. $epNum' ||
      clean == 'ep $epNum' ||
      clean == 'ep.$epNum' ||
      clean == '$epNum') {
    return true;
  }
  return RegExp(r'^(episode|episodio|ep\.?|e)\s*\d+$', caseSensitive: false).hasMatch(clean);
}

/// Clean episode item displaying the next episode thumbnail, title, and metadata
/// loosely without heavy card/box containers, mirroring the anime details EpisodeListItem style.
class NextEpisodeCard extends ConsumerWidget {
  final AnimeEpisode episode;
  final String? animeTitle;
  final String? episodeTitle;
  final String? imageUrl;
  final String? fallbackImageUrl;
  final String? synopsis;
  final String? duration;
  final VoidCallback? onTap;

  const NextEpisodeCard({
    super.key,
    required this.episode,
    this.animeTitle,
    this.episodeTitle,
    this.imageUrl,
    this.fallbackImageUrl,
    this.synopsis,
    this.duration,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    const double imageWidth = 148;
    const double imageHeight = 84;

    final effectiveImage = (imageUrl != null && imageUrl!.isNotEmpty)
        ? imageUrl
        : ((episode.image != null && episode.image!.isNotEmpty)
            ? episode.image
            : fallbackImageUrl);

    final rawTitle = (episodeTitle != null && episodeTitle!.trim().isNotEmpty)
        ? episodeTitle!.trim()
        : episode.title;

    final String displayEpTitle;
    if (_isGenericTitle(rawTitle, episode.episodeNumber)) {
      displayEpTitle = l10n.episodeNumber(episode.episodeNumber);
    } else {
      displayEpTitle = rawTitle;
    }

    final effectiveSynopsis = (synopsis != null && synopsis!.trim().isNotEmpty)
        ? synopsis!.trim()
        : (episode.description != null && episode.description!.trim().isNotEmpty
            ? episode.description!.trim()
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean enlarged thumbnail loose on background (no overlay text or badges inside)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: imageWidth,
                  height: imageHeight,
                  child: effectiveImage != null && effectiveImage.isNotEmpty
                      ? CachedNetworkImage(
                          memCacheWidth: 300, memCacheHeight: 170, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                          imageUrl: effectiveImage,
                          fit: BoxFit.cover,
                          placeholder: (ctx, url) => Container(
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (ctx, url, err) => fallbackImageUrl != null &&
                                  fallbackImageUrl != effectiveImage
                              ? CachedNetworkImage(
                                  memCacheWidth: 300, memCacheHeight: 170, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                                  imageUrl: fallbackImageUrl!,
                                  fit: BoxFit.cover,
                                  errorWidget: (c, u, e) => Container(
                                    color: theme.colorScheme.surfaceContainerHighest,
                                  ),
                                )
                              : Container(
                                  color: theme.colorScheme.surfaceContainerHighest,
                                ),
                        )
                      : (fallbackImageUrl != null && fallbackImageUrl!.isNotEmpty
                          ? CachedNetworkImage(
                              memCacheWidth: 300, memCacheHeight: 170, maxWidthDiskCache: 480, maxHeightDiskCache: 270,
                              imageUrl: fallbackImageUrl!,
                              fit: BoxFit.cover,
                              errorWidget: (c, u, e) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                            )),
                ),
              ),
              const SizedBox(width: 12),

              // Info Column: strictly constrained to the image height so text never spills out
              Expanded(
                child: SizedBox(
                  height: imageHeight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Row 1: EP number + duration
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            'EP ${episode.episodeNumber}',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (duration != null && duration!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              duration!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Row 2: Title of the episode
                      Text(
                        displayEpTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Row 3: Synopsis snippet (without anime title)
                      if (effectiveSynopsis != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          effectiveSynopsis,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                            fontSize: 11,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
