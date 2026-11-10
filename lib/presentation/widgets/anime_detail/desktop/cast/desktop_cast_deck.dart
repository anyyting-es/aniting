import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'desktop_cast_models.dart';

/// Deck-of-cards carousel for characters with expressive 3D perspective animations.
/// Displays the active character card prominently in front and center,
/// while previous and next cards peek out on the left and right with subtle opacity.
class DesktopCastDeck extends ConsumerStatefulWidget {
  final List<DesktopCastItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final int? mediaId;
  final double cardWidth;
  final double cardHeight;

  const DesktopCastDeck({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelectIndex,
    this.mediaId,
    this.cardWidth = 265,
    this.cardHeight = 390,
  });

  @override
  ConsumerState<DesktopCastDeck> createState() => _DesktopCastDeckState();
}

class _DesktopCastDeckState extends ConsumerState<DesktopCastDeck> {
  double _direction = 1.0;
  bool _hoverLeft = false;
  bool _hoverRight = false;

  @override
  void didUpdateWidget(covariant DesktopCastDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _direction = widget.currentIndex >= oldWidget.currentIndex ? 1.0 : -1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final iconPack = ref.watch(iconPackProvider);
    final isDark = theme.brightness == Brightness.dark;

    final hasPrev = widget.currentIndex > 0;
    final hasNext = widget.currentIndex < widget.items.length - 1;

    // Deck footprint: cardWidth + 64 for subtle peeking side cards (at most 3 items)
    final deckWidth = widget.cardWidth + 64;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: deckWidth,
          height: widget.cardHeight + 10,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // ── 1. Previous Character Peeking Card (i - 1) ──
              if (hasPrev)
                _buildInteractiveSideCard(
                  item: widget.items[widget.currentIndex - 1],
                  deckWidth: deckWidth,
                  dx: _hoverLeft ? -28 : -22,
                  scale: _hoverLeft ? 0.94 : 0.91,
                  opacity: _hoverLeft ? 0.50 : 0.30,
                  tiltAngle: -0.035,
                  isDark: isDark,
                  iconPack: iconPack,
                  theme: theme,
                  onHoverChange: (v) => setState(() => _hoverLeft = v),
                  onTap: () => widget.onSelectIndex(widget.currentIndex - 1),
                ),

              // ── 2. Next Character Peeking Card (i + 1) ──
              if (hasNext)
                _buildInteractiveSideCard(
                  item: widget.items[widget.currentIndex + 1],
                  deckWidth: deckWidth,
                  dx: _hoverRight ? 28 : 22,
                  scale: _hoverRight ? 0.94 : 0.91,
                  opacity: _hoverRight ? 0.50 : 0.30,
                  tiltAngle: 0.035,
                  isDark: isDark,
                  iconPack: iconPack,
                  theme: theme,
                  onHoverChange: (v) => setState(() => _hoverRight = v),
                  onTap: () => widget.onSelectIndex(widget.currentIndex + 1),
                ),

              // ── 3. Active Center Card with Dynamic 3D Perspective Transition ──
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 340),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isEntering = child.key == ValueKey('center_${widget.items[widget.currentIndex].id}');
                    return AnimatedBuilder(
                      animation: animation,
                      builder: (context, _) {
                        final progress = animation.value;
                        final double offset;
                        final double rotation;

                        if (isEntering) {
                          offset = _direction * 65.0 * (1.0 - progress);
                          rotation = _direction * -0.16 * (1.0 - progress);
                        } else {
                          offset = -_direction * 65.0 * (1.0 - progress);
                          rotation = -_direction * 0.16 * (1.0 - progress);
                        }

                        return Transform(
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)
                            ..translate(offset, 0.0)
                            ..rotateY(rotation),
                          alignment: Alignment.center,
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey('center_${widget.items[widget.currentIndex].id}'),
                    child: _buildCenterCard(
                      item: widget.items[widget.currentIndex],
                      isDark: isDark,
                      iconPack: iconPack,
                      theme: theme,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── 6. Minimalist Steppers ──
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            M3EIconButton(
              onPressed: hasPrev ? () => widget.onSelectIndex(widget.currentIndex - 1) : null,
              icon: Icon(AppIcons.arrowLeft(iconPack), size: 18),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                  width: 1,
                ),
              ),
              child: Text(
                '${widget.currentIndex + 1} / ${widget.items.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white.withValues(alpha: 0.85) : theme.colorScheme.onSurface,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            M3EIconButton(
              onPressed: hasNext ? () => widget.onSelectIndex(widget.currentIndex + 1) : null,
              icon: Icon(AppIcons.arrowRight(iconPack), size: 18),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInteractiveSideCard({
    required DesktopCastItem item,
    required double deckWidth,
    required double dx,
    required double scale,
    required double opacity,
    required double tiltAngle,
    required bool isDark,
    required AppIconPack iconPack,
    required ThemeData theme,
    required ValueChanged<bool> onHoverChange,
    required VoidCallback onTap,
  }) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      left: (deckWidth - widget.cardWidth) / 2 + dx,
      top: ((widget.cardHeight + 10) - (widget.cardHeight * scale)) / 2,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        opacity: opacity,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHoverChange(true),
          onExit: (_) => onHoverChange(false),
          child: GestureDetector(
            onTap: onTap,
            child: Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(tiltAngle)
                ..scale(scale),
              alignment: Alignment.center,
              child: Container(
                width: widget.cardWidth,
                height: widget.cardHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? Colors.white24 : Colors.black26,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.40),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: item.imageUrl != null && item.imageUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 400,
                        errorWidget: (_, _, _) => Container(
                          color: isDark ? const Color(0xFF16191F) : Colors.black12,
                          child: Icon(AppIcons.profile(iconPack), size: 40, color: Colors.white24),
                        ),
                      )
                    : Container(
                        color: isDark ? const Color(0xFF16191F) : Colors.black12,
                        child: Icon(AppIcons.profile(iconPack), size: 40, color: Colors.white24),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterCard({
    required DesktopCastItem item,
    required bool isDark,
    required AppIconPack iconPack,
    required ThemeData theme,
  }) {
    final heroTag = 'cast_hero_${widget.mediaId ?? 0}_${item.id}';

    return Hero(
      tag: heroTag,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: widget.cardWidth,
          height: widget.cardHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.22)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.65 : 0.32),
                blurRadius: 36,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                color: isDark ? const Color(0xFF14171B) : theme.colorScheme.surfaceContainerHighest,
              ),
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  memCacheWidth: 600,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, _) => Container(
                    color: isDark ? const Color(0xFF1A1D24) : theme.colorScheme.surfaceContainerHigh,
                    child: Center(
                      child: SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: theme.colorScheme.primary.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (_, _, _) => Center(
                    child: Icon(
                      AppIcons.profile(iconPack),
                      size: 54,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                )
              else
                Center(
                  child: Icon(
                    AppIcons.profile(iconPack),
                    size: 54,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              // Subtle bottom gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.25),
                      ],
                      stops: const [0.75, 1.0],
                    ),
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
