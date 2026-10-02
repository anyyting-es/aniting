import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

class DesktopMangaRecommendationsRow extends ConsumerWidget {
  final List recommendations;
  final bool isLoading;

  const DesktopMangaRecommendationsRow({
    super.key,
    required this.recommendations,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;

    if (isLoading && recommendations.isEmpty) {
      return SizedBox(
        height: 290,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 6,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, index) => _buildSkeletonCard(context),
        ),
      );
    }

    if (recommendations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            l10n.noSimilarWorksAvailable,
            style: TextStyle(
              color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 290,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recommendations.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final edge = recommendations[index] as Map<String, dynamic>?;
          return _DesktopMangaRecommendationCard(edge: edge);
        },
      ),
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SizedBox(
      width: 165,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.70,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1D23) : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            height: 14,
            width: 110,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF22262E) : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopMangaRecommendationCard extends ConsumerStatefulWidget {
  final Map<String, dynamic>? edge;

  const _DesktopMangaRecommendationCard({required this.edge});

  @override
  ConsumerState<_DesktopMangaRecommendationCard> createState() => _DesktopMangaRecommendationCardState();
}

class _DesktopMangaRecommendationCardState extends ConsumerState<_DesktopMangaRecommendationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final mediaRec = node?['mediaRecommendation'] as Map<String, dynamic>?;
    if (mediaRec == null) return const SizedBox.shrink();

    final l10n = ref.watch(translationsProvider);
    final recId = mediaRec['id'] as int? ?? 0;
    final titleMap = mediaRec['title'] as Map<String, dynamic>?;
    final recTitle = titleMap?['userPreferred'] ?? titleMap?['romaji'] ?? titleMap?['english'] ?? l10n.noTitle;
    final coverMap = mediaRec['coverImage'] as Map<String, dynamic>?;
    final coverUrl = coverMap?['large'] ?? coverMap?['medium'];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return SizedBox(
      width: 165,
      child: MouseRegion(
        cursor: recId > 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: InkWell(
          onTap: recId > 0
              ? () {
                  final type = mediaRec['type'] as String?;
                  if (type == 'MANGA') {
                    MangaEntry? manga;
                    try {
                      manga = MangaEntry.fromJson(mediaRec);
                    } catch (_) {}
                    MangaDetailScreen.navigate(
                      context,
                      mediaId: recId,
                      initialEntry: manga,
                    );
                  } else {
                    AnimeEntry? entry;
                    try {
                      entry = AnimeEntry.fromJson(mediaRec);
                    } catch (_) {}
                    AnimeDetailScreen.navigate(
                      context,
                      mediaId: recId,
                      initialEntry: entry,
                    );
                  }
                }
              : null,
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 0.70,
                child: AnimatedScale(
                  scale: _isHovered ? 1.03 : 1.0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isHovered
                            ? (isDark ? Colors.white.withValues(alpha: 0.35) : theme.colorScheme.primary)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: _isHovered ? 0.35 : 0.15),
                          blurRadius: _isHovered ? 12 : 6,
                          offset: Offset(0, _isHovered ? 4 : 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: coverUrl != null
                        ? CachedNetworkImage(
                            imageUrl: coverUrl as String,
                            fit: BoxFit.cover,
                            memCacheWidth: 330,
                            errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
                          )
                        : Container(color: const Color(0xFF1E2228)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                recTitle as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: _isHovered ? theme.colorScheme.primary : titleColor,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
