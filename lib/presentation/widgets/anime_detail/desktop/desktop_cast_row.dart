import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

class DesktopCastRow extends ConsumerWidget {
  final List<dynamic> characters;
  final bool isTmdb;

  const DesktopCastRow({
    super.key,
    required this.characters,
    this.isTmdb = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (characters.isEmpty) return const SizedBox.shrink();

    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = isTmdb ? l10n.cast : l10n.characters;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: characters.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = characters[index];
              return _DesktopCastCard(item: item, isTmdb: isTmdb);
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopCastCard extends ConsumerStatefulWidget {
  final dynamic item;
  final bool isTmdb;

  const _DesktopCastCard({
    required this.item,
    required this.isTmdb,
  });

  @override
  ConsumerState<_DesktopCastCard> createState() => _DesktopCastCardState();
}

class _DesktopCastCardState extends ConsumerState<_DesktopCastCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);

    final String name;
    final String? roleOrActor;
    final String? imageUrl;

    if (widget.isTmdb) {
      final map = widget.item is Map ? widget.item as Map : {};
      name = (map['name'] ?? map['original_name'] ?? '') as String;
      roleOrActor = map['character'] as String?;
      final profilePath = map['profile_path'] as String?;
      imageUrl = profilePath != null ? 'https://image.tmdb.org/t/p/w185$profilePath' : null;
    } else {
      final edge = widget.item is Map ? widget.item as Map : {};
      final node = edge['node'] as Map?;
      final nameMap = node?['name'] as Map?;
      name = (nameMap?['userPreferred'] ?? nameMap?['full'] ?? '') as String;
      final role = (edge['role'] as String?)?.toUpperCase();
      String? vaName;
      final voiceActors = edge['voiceActors'] as List?;
      if (voiceActors != null && voiceActors.isNotEmpty) {
        final firstVa = voiceActors.first;
        if (firstVa is Map) {
          final vaNameMap = firstVa['name'];
          if (vaNameMap is Map) {
            vaName = (vaNameMap['userPreferred'] ?? vaNameMap['full'])?.toString();
          }
        }
      }
      roleOrActor = vaName ?? (role == 'MAIN' ? 'Principal' : 'Secundario');
      final imageMap = node?['image'] as Map?;
      imageUrl = imageMap?['large'] ?? imageMap?['medium'];
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 110,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 150),
                          errorWidget: (_, _, _) => Center(
                            child: Icon(AppIcons.profile(iconPack), size: 28, color: Colors.white24),
                          ),
                        )
                      : Center(
                          child: Icon(AppIcons.profile(iconPack), size: 28, color: Colors.white24),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isHovered
                    ? theme.colorScheme.primary
                    : (isDark ? Colors.white : theme.colorScheme.onSurface),
              ),
            ),
            if (roleOrActor != null && roleOrActor.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                roleOrActor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
