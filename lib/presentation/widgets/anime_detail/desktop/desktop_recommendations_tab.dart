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
              childAspectRatio: 0.62,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (recommendations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_outlined, color: Colors.white38, size: 32),
              SizedBox(height: 10),
              Text(
                'No hay recomendaciones disponibles',
                style: TextStyle(
                  color: Colors.white70,
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
            childAspectRatio: 0.62,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF14171B),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              color: const Color(0xFF1A1D23),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Container(
              height: 12,
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF22262E),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
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

    return MouseRegion(
      cursor: recId > 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              color: const Color(0xFF14171B),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: _isHovered ? 0.18 : 0.07),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isHovered ? 0.45 : 0.25),
                  blurRadius: _isHovered ? 12 : 6,
                  offset: Offset(0, _isHovered ? 4 : 2),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Clean Poster Image (nothing on top of it)
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                    child: SizedBox.expand(
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

                // Name below poster
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                  child: Text(
                    recTitle as String,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
