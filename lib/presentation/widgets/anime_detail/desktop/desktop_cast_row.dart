import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'cast/desktop_cast_detail_view.dart';
import 'cast/desktop_cast_models.dart';

class DesktopCastRow extends ConsumerWidget {
  final List<dynamic> characters;
  final bool isTmdb;
  final int? mediaId;
  final String? bannerUrl;

  const DesktopCastRow({
    super.key,
    required this.characters,
    this.isTmdb = false,
    this.mediaId,
    this.bannerUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (characters.isEmpty) return const SizedBox.shrink();

    // 1. Filter out items without an image (default placeholder / null)
    final validItems = <DesktopCastItem>[];
    for (int i = 0; i < characters.length; i++) {
      final raw = characters[i];
      if (DesktopCastItem.hasValidImage(raw, isTmdb: isTmdb)) {
        validItems.add(DesktopCastItem.fromEdge(raw, isTmdb: isTmdb, index: i));
      }
    }

    if (validItems.isEmpty) return const SizedBox.shrink();

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
          height: 245,
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 12),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: validItems.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final item = validItems[index];
              final heroTag = 'cast_hero_${mediaId ?? 0}_${item.id}';

              return _DesktopCastCard(
                item: item,
                heroTag: heroTag,
                isTmdb: isTmdb,
                isFirst: index == 0,
                isLast: index == validItems.length - 1,
                onTap: () {
                  DesktopCastDetailView.open(
                    context,
                    items: validItems,
                    initialIndex: index,
                    mediaId: mediaId,
                    bannerUrl: bannerUrl,
                    isTmdb: isTmdb,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DesktopCastCard extends ConsumerStatefulWidget {
  final DesktopCastItem item;
  final String heroTag;
  final bool isTmdb;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const _DesktopCastCard({
    required this.item,
    required this.heroTag,
    required this.isTmdb,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  ConsumerState<_DesktopCastCard> createState() => _DesktopCastCardState();
}

class _DesktopCastCardState extends ConsumerState<_DesktopCastCard> {
  late final FocusNode _focusNode;
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'desktop_cast');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final item = widget.item;

    final roleOrActor = item.vaName ?? (item.isMain ? 'Principal' : 'Secundario');

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final key = event.logicalKey;
          // Lock focus at the horizontal boundaries
          if (widget.isFirst && key == LogicalKeyboardKey.arrowLeft) {
            return KeyEventResult.handled;
          }
          if (widget.isLast && key == LogicalKeyboardKey.arrowRight) {
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.select ||
              key == LogicalKeyboardKey.space) {
            widget.onTap();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      onFocusChange: (val) {
        if (val) {
          AppFocusCoordinator.onNodeFocused(_focusNode);
          if (mounted) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.35,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
            );
          }
        }
        setState(() => _isFocused = val);
      },
      child: ValueListenableBuilder<AppInputMode>(
        valueListenable: AppFocusCoordinator.inputMode,
        builder: (context, inputMode, _) {
          final isDpad = inputMode == AppInputMode.dpad;
          final isActive = (inputMode == AppInputMode.mouse && _isHovered) || (isDpad && _isFocused);

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) {
              AppFocusCoordinator.switchToMouse(_focusNode);
              setState(() => _isHovered = true);
            },
            onExit: (_) {
              if (AppFocusCoordinator.lastHoveredNode == _focusNode) {
                AppFocusCoordinator.lastHoveredNode = null;
              }
              setState(() => _isHovered = false);
            },
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedScale(
                scale: _isHovered ? 1.04 : 1.0,
                alignment: Alignment.bottomCenter,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                child: SizedBox(
                  width: 110,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 0.72,
                        child: Hero(
                          tag: widget.heroTag,
                          child: Material(
                            type: MaterialType.transparency,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: (isDpad && _isFocused)
                                      ? Colors.white
                                      : (_isHovered
                                          ? theme.colorScheme.primary.withValues(alpha: 0.6)
                                          : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black12)),
                                  width: (isDpad && _isFocused) ? 2.0 : (_isHovered ? 1.5 : 1.0),
                                ),
                                boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: (isDpad && _isFocused)
                                              ? Colors.white.withValues(alpha: 0.30)
                                              : (_isHovered
                                                  ? theme.colorScheme.primary.withValues(alpha: 0.22)
                                                  : Colors.black.withValues(alpha: 0.25)),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        )
                                      ]
                                    : null,
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Container(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05),
                                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: item.imageUrl!,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        memCacheWidth: 260,
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
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
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
                      if (roleOrActor.isNotEmpty) ...[
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
              ),
            ),
          );
        },
      ),
    );
  }
}
