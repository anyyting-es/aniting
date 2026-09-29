import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';

class DesktopRelationsTab extends StatelessWidget {
  final List relations;
  final bool isLoading;

  const DesktopRelationsTab({
    super.key,
    required this.relations,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && relations.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 150).floor().clamp(2, 6);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (relations.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, color: Colors.white38, size: 32),
              SizedBox(height: 10),
              Text(
                'No hay relaciones disponibles',
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
          itemCount: relations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.58,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final edge = relations[index] as Map<String, dynamic>?;
            return _DesktopRelationCard(edge: edge);
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

class _DesktopRelationCard extends StatefulWidget {
  final Map<String, dynamic>? edge;

  const _DesktopRelationCard({required this.edge});

  @override
  State<_DesktopRelationCard> createState() => _DesktopRelationCardState();
}

class _DesktopRelationCardState extends State<_DesktopRelationCard> {
  bool _isHovered = false;

  String _formatRelationLabel(String raw) {
    switch (raw.toUpperCase()) {
      case 'PREQUEL':
        return 'Precuela';
      case 'SEQUEL':
        return 'Secuela';
      case 'SIDE_STORY':
        return 'Historia paralela';
      case 'SPIN_OFF':
        return 'Spin-off';
      case 'PARENT':
        return 'Historia principal';
      case 'ALTERNATIVE':
        return 'Alternativo';
      case 'SUMMARY':
        return 'Resumen';
      case 'CHARACTER':
        return 'Personaje';
      case 'OTHER':
        return 'Relacionado';
      case 'SOURCE':
        return 'Obra original';
      case 'ADAPTATION':
        return 'Adaptación';
      default:
        if (raw.isEmpty) return '';
        final s = raw.replaceAll('_', ' ').toLowerCase();
        return s[0].toUpperCase() + s.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final relationType = widget.edge?['relationType'] as String? ?? '';
    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final relId = node?['id'] as int? ?? 0;
    final titleMap = node?['title'] as Map<String, dynamic>?;
    final relTitle = titleMap?['userPreferred'] ?? titleMap?['romaji'] ?? titleMap?['english'] ?? 'Sin título';
    final coverMap = node?['coverImage'] as Map<String, dynamic>?;
    final coverUrl = coverMap?['large'] ?? coverMap?['medium'];
    final relationLabel = _formatRelationLabel(relationType);

    return MouseRegion(
      cursor: relId > 0 ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        child: InkWell(
          onTap: relId > 0
              ? () {
                  final type = node?['type'] as String?;
                  if (type == 'MANGA') {
                    MangaEntry? manga;
                    if (node != null) {
                      try {
                        manga = MangaEntry.fromJson(node);
                      } catch (_) {}
                    }
                    MangaDetailScreen.navigate(
                      context,
                      mediaId: relId,
                      initialEntry: manga,
                    );
                  } else {
                    AnimeEntry? entry;
                    if (node != null) {
                      try {
                        entry = AnimeEntry.fromJson(node);
                      } catch (_) {}
                    }
                    AnimeDetailScreen.navigate(
                      context,
                      mediaId: relId,
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
                // Clean Poster Image (no badges on top of the image)
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

                // Details Below Poster: Relation Tag + Name
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Relation type label (e.g. "Precuela", "Secuela")
                      if (relationLabel.isNotEmpty) ...[
                        Text(
                          relationLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 3),
                      ],

                      // Relation Anime Title
                      Text(
                        relTitle as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ],
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
