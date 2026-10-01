import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

class DesktopRecommendationsTab extends StatelessWidget {
  final List recommendations;
  final bool isLoading;

  const DesktopRecommendationsTab({
    super.key,
    required this.recommendations,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && recommendations.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 6);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.54,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (recommendations.isEmpty) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, color: isDark ? Colors.white38 : theme.colorScheme.outline, size: 32),
              const SizedBox(height: 10),
              Text(
                'No hay recomendaciones disponibles',
                style: TextStyle(
                  color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recommendations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.54,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemBuilder: (context, index) {
            final edge = recommendations[index] as Map<String, dynamic>?;
            return _DesktopRecommendationCard(edge: edge);
          },
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 0.70,
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1D23),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 12,
          width: 90,
          decoration: BoxDecoration(
            color: const Color(0xFF22262E),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}

class _DesktopRecommendationCard extends StatefulWidget {
  final Map<String, dynamic>? edge;

  const _DesktopRecommendationCard({required this.edge});

  @override
  State<_DesktopRecommendationCard> createState() => _DesktopRecommendationCardState();
}

class _DesktopRecommendationCardState extends State<_DesktopRecommendationCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final mediaRec = node?['mediaRecommendation'] as Map<String, dynamic>?;
    if (mediaRec == null) return const SizedBox.shrink();

    final recId = mediaRec['id'] as int? ?? 0;
    final titleMap = mediaRec['title'] as Map<String, dynamic>?;
    final recTitle = titleMap?['userPreferred'] ?? titleMap?['romaji'] ?? titleMap?['english'] ?? 'Sin título';
    final coverMap = mediaRec['coverImage'] as Map<String, dynamic>?;
    final coverUrl = coverMap?['large'] ?? coverMap?['medium'];

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    return MouseRegion(
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
        borderRadius: BorderRadius.circular(10),
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Poster Art Container (whole box expands smoothly on hover)
            AspectRatio(
              aspectRatio: 0.70,
              child: AnimatedScale(
                scale: _isHovered ? 1.025 : 1.0,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isHovered
                          ? Colors.white.withValues(alpha: 0.35)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
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
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl as String,
                          fit: BoxFit.cover,
                          memCacheWidth: 320,
                          errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
                        )
                      : Container(color: const Color(0xFF1E2228)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Anime Title OUTSIDE container
            Text(
              recTitle as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _isHovered ? theme.colorScheme.primary : titleColor,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
