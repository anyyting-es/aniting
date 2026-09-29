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
              childAspectRatio: 0.52,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (relations.isEmpty) {
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.hub_outlined, color: isDark ? Colors.white38 : theme.colorScheme.outline, size: 32),
              const SizedBox(height: 10),
              Text(
                'No hay relaciones disponibles',
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
          itemCount: relations.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.52,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
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
          height: 10,
          width: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF22262E),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
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

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Poster Container with border & shadow
              AspectRatio(
                aspectRatio: 0.70,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isHovered
                          ? theme.colorScheme.primary
                          : (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _isHovered ? 0.45 : 0.20),
                        blurRadius: _isHovered ? 12 : 6,
                        offset: Offset(0, _isHovered ? 4 : 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ClipRect(
                    child: AnimatedScale(
                      scale: _isHovered ? 1.04 : 1.0,
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeInOut,
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
              ),
              const SizedBox(height: 8),

              // 2. Relation type label outside container
              if (relationLabel.isNotEmpty) ...[
                Text(
                  relationLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
              ],

              // 3. Relation Anime Title outside container
              Text(
                relTitle as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
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
