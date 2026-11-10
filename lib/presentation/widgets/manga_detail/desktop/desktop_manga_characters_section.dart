import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import '../../anime_detail/desktop/cast/desktop_cast_detail_view.dart';
import '../../anime_detail/desktop/cast/desktop_cast_models.dart';

class DesktopMangaCharactersSection extends ConsumerWidget {
  final List characters;
  final bool isLoading;
  final int? mediaId;
  final String? bannerUrl;

  const DesktopMangaCharactersSection({
    super.key,
    required this.characters,
    this.isLoading = false,
    this.mediaId,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    if (isLoading && characters.isEmpty) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) => _buildSkeletonCard(context),
      );
    }

    // Filter valid cast items
    final validItems = <DesktopCastItem>[];
    for (int i = 0; i < characters.length; i++) {
      final raw = characters[i];
      if (DesktopCastItem.hasValidImage(raw, isTmdb: false)) {
        validItems.add(DesktopCastItem.fromEdge(raw, isTmdb: false, index: i));
      }
    }

    if (validItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Text(
          l10n.noCharactersAvailable,
          style: TextStyle(
            color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: validItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 68,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final item = validItems[index];
        return _DesktopMangaCharacterCard(
          item: item,
          index: index,
          l10n: l10n,
          onTap: () {
            DesktopCastDetailView.open(
              context,
              items: validItems,
              initialIndex: index,
              mediaId: mediaId,
              bannerUrl: bannerUrl,
              isTmdb: false,
            );
          },
        );
      },
    );
  }

  Widget _buildSkeletonCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
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
                  height: 13,
                  width: 90,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF22262E) : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 50,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(4),
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

class _DesktopMangaCharacterCard extends StatefulWidget {
  final DesktopCastItem item;
  final int index;
  final AppTranslations l10n;
  final VoidCallback? onTap;

  const _DesktopMangaCharacterCard({
    required this.item,
    required this.index,
    required this.l10n,
    this.onTap,
  });

  @override
  State<_DesktopMangaCharacterCard> createState() => _DesktopMangaCharacterCardState();
}

class _DesktopMangaCharacterCardState extends State<_DesktopMangaCharacterCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final roleLabel = widget.item.isMain ? widget.l10n.mainRole : widget.l10n.supportingRole;
    final age = widget.item.age;
    final ageLabel = (age != null && age.isNotEmpty)
        ? (age.contains('year') ? age : '$age years old')
        : null;

    final tileBg = _isHovered
        ? (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.6));

    final tileBorder = _isHovered
        ? (isDark ? Colors.white.withValues(alpha: 0.24) : theme.colorScheme.primary.withValues(alpha: 0.4))
        : (isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35));

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: tileBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tileBorder, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? (_isHovered ? 0.28 : 0.10) : 0.04),
                blurRadius: _isHovered ? 10 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Character Avatar (Square 50x50 with rounded 10px)
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: widget.item.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: widget.item.imageUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 120,
                        placeholder: (_, _) => Container(
                          color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.person,
                            size: 22,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                        child: Icon(
                          Icons.person,
                          size: 22,
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                      ),
              ),

              const SizedBox(width: 12),

              // Character details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _isHovered ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                      ),
                    ),
                    if (ageLabel != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        ageLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isDark ? Colors.white54 : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: widget.item.isMain
                                ? (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.primaryContainer)
                                : (isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            roleLabel.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                              color: widget.item.isMain
                                  ? (isDark ? Colors.white : theme.colorScheme.onPrimaryContainer)
                                  : (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
