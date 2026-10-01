import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class DesktopMangaCharactersSection extends ConsumerWidget {
  final List characters;
  final bool isLoading;

  const DesktopMangaCharactersSection({
    super.key,
    required this.characters,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentLanguage = ref.watch(appLanguageProvider);
    final isEn = currentLanguage == AppLanguage.en;

    if (isLoading && characters.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 84,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemBuilder: (context, index) => _buildSkeletonCard(context),
      );
    }

    if (characters.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            isEn ? 'No characters available' : 'No hay personajes disponibles',
            style: TextStyle(
              color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: characters.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 84,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemBuilder: (context, index) {
        final edge = characters[index] as Map<String, dynamic>?;
        return _DesktopMangaCharacterCard(edge: edge, isEn: isEn);
      },
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          width: 60,
          height: 84,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 14,
                width: 90,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22262E) : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 12,
                width: 60,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopMangaCharacterCard extends StatefulWidget {
  final Map<String, dynamic>? edge;
  final bool isEn;

  const _DesktopMangaCharacterCard({
    required this.edge,
    required this.isEn,
  });

  @override
  State<_DesktopMangaCharacterCard> createState() => _DesktopMangaCharacterCardState();
}

class _DesktopMangaCharacterCardState extends State<_DesktopMangaCharacterCard> {
  bool _isHovered = false;

  String _formatRole(String role, bool isEn) {
    switch (role.toUpperCase()) {
      case 'MAIN':
        return isEn ? 'Main' : 'Principal';
      case 'SUPPORTING':
        return isEn ? 'Supporting' : 'Secundario';
      case 'BACKGROUND':
        return isEn ? 'Background' : 'Fondo';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final node = widget.edge?['node'] as Map<String, dynamic>?;
    final role = widget.edge?['role'] as String? ?? 'MAIN';
    final nameMap = node?['name'] as Map<String, dynamic>?;
    final characterName = nameMap?['userPreferred'] ?? nameMap?['full'] ?? 'Personaje';
    final imageMap = node?['image'] as Map<String, dynamic>?;
    final imageUrl = imageMap?['large'] ?? imageMap?['medium'];

    // Check for voice actor info if present
    final voiceActors = widget.edge?['voiceActors'] as List?;
    final va = voiceActors?.isNotEmpty == true ? voiceActors!.first as Map<String, dynamic>? : null;
    final vaName = va?['name']?['userPreferred'] ?? va?['name']?['full'];

    final roleLabel = _formatRole(role, widget.isEn);
    final subtitle = vaName != null && vaName.isNotEmpty
        ? '$roleLabel • $vaName'
        : roleLabel;

    return MouseRegion(
      cursor: SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Larger Character Photo with gentle hover scale ──
          AnimatedScale(
            scale: _isHovered ? 1.04 : 1.0,
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            child: Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                    blurRadius: _isHovered ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl as String,
                      fit: BoxFit.cover,
                      memCacheWidth: 160,
                      placeholder: (_, _) => Container(
                        color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                      ),
                      errorWidget: (_, _, _) => Container(
                        color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.person,
                          size: 24,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : Container(
                      color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                      child: Icon(
                        Icons.person,
                        size: 24,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                      ),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // ── Unboxed Info (Larger Title & Role / CV) ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  characterName as String,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: _isHovered ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
