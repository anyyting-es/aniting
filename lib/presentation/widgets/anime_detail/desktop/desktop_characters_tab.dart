import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class DesktopCharactersTab extends StatelessWidget {
  final List characters;
  final bool isLoading;

  const DesktopCharactersTab({
    super.key,
    required this.characters,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && characters.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 0.72,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemBuilder: (context, index) => _buildSkeletonCard(),
          );
        },
      );
    }

    if (characters.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined, color: Colors.white38, size: 32),
              SizedBox(height: 10),
              Text(
                'No hay personajes disponibles',
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
        final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: characters.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final edge = characters[index] as Map<String, dynamic>?;
            return _DesktopCharacterCard(edge: edge);
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
              width: 90,
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

class _DesktopCharacterCard extends StatefulWidget {
  final Map<String, dynamic>? edge;

  const _DesktopCharacterCard({required this.edge});

  @override
  State<_DesktopCharacterCard> createState() => _DesktopCharacterCardState();
}

class _DesktopCharacterCardState extends State<_DesktopCharacterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final role = widget.edge?['role'] as String? ?? 'SUPPORTING';
    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final nameMap = node?['name'] as Map<String, dynamic>?;
    final charName = nameMap?['userPreferred'] ?? nameMap?['full'] ?? 'Personaje';
    final imageMap = node?['image'] as Map<String, dynamic>?;
    final imgUrl = imageMap?['large'] ?? imageMap?['medium'];
    final isMain = role.toUpperCase() == 'MAIN';

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedScale(
        scale: _isHovered ? 1.025 : 1.0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
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
              // Character Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imgUrl != null)
                      ClipRect(
                        child: CachedNetworkImage(
                          imageUrl: imgUrl as String,
                          fit: BoxFit.cover,
                          memCacheWidth: 320,
                          errorWidget: (_, _, _) => Container(color: const Color(0xFF1E2228)),
                        ),
                      )
                    else
                      Container(color: const Color(0xFF1E2228)),

                    // Subtle neutral role badge
                    Positioned(
                      top: 7,
                      left: 7,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: isMain ? 0.85 : 0.70),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: isMain ? 0.25 : 0.12),
                          ),
                        ),
                        child: Text(
                          isMain ? 'PRINCIPAL' : 'SECUNDARIO',
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: isMain ? FontWeight.w700 : FontWeight.w500,
                            letterSpacing: 0.3,
                            color: Colors.white.withValues(alpha: isMain ? 0.95 : 0.75),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Character Name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  charName as String,
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
    );
  }
}
