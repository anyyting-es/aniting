import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

class LandscapeAnimeCard extends StatelessWidget {
  final AnimeEntry entry;
  final VoidCallback? onTap;
  final double width;
  final double height;

  const LandscapeAnimeCard({
    super.key,
    required this.entry,
    this.onTap,
    this.width = 240,
    this.height = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final imageUrl = entry.bannerImage ?? entry.coverImage;

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap ??
            () => AnimeDetailScreen.navigate(
                  context,
                  mediaId: entry.mediaId,
                  initialEntry: entry,
                ),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: theme.colorScheme.surfaceContainerHigh,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Backdrop image
              if (imageUrl != null)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 550,
                  memCacheHeight: 320,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: Icon(
                      Icons.movie_rounded,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              else
                Container(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Icon(Icons.movie_rounded, color: theme.colorScheme.outline),
                ),

            // Top-right Score pill
            if (entry.score != null && entry.score! > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 12),
                      const SizedBox(width: 2),
                      Text(
                        '${entry.score!.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Bottom Gradient & Title
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.only(left: 12, right: 12, bottom: 10, top: 28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    if (entry.format != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        entry.format!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
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
