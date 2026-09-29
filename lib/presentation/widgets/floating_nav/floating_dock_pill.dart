import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';

/// A solid Material Design 3 floating navigation dock.
///
/// Features:
/// - 100% solid background (zero transparency/blur) using `theme.colorScheme.surfaceContainer`.
/// - Material 3 elevation shadow and crisp subtle outline.
/// - Active item display:
///   - When [labelProgress] > 0: shows an active pill with `[Icon]  [Label]` smoothly expanded to the right.
///   - When [labelProgress] == 0 (e.g. when resume companion shares the row): icon-only mode with active indicator.
/// - Unselected items: clean monochrome icon.
class FloatingDockPill extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopSidebarItem> items;
  final double labelProgress; // 0.0 = icon-only, 1.0 = label fully deployed
  final double height;
  final BorderRadius borderRadius;

  const FloatingDockPill({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.labelProgress = 1.0,
    this.height = 64.0,
    required this.borderRadius,
  });

  @override
  State<FloatingDockPill> createState() => _FloatingDockPillState();
}

class _FloatingDockPillState extends State<FloatingDockPill> {
  int? _hoveredIndex;
  int? _focusedIndex;

  KeyEventResult _handleActionKey(KeyEvent event, VoidCallback action) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA) {
        action();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        // Solid M3 surface container - 100% opaque, zero transparency
        color: theme.colorScheme.surfaceContainer,
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: isDark ? 0.25 : 0.15,
          ),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.06 : 0.03),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0),
          child: Row(
            children: [
              for (int i = 0; i < widget.items.length; i++)
                _buildNavItem(
                  index: i,
                  item: widget.items[i],
                  isSelected: widget.selectedIndex == i,
                  theme: theme,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required DesktopSidebarItem item,
    required bool isSelected,
    required ThemeData theme,
  }) {
    final isHovered = _hoveredIndex == index;
    final isFocused = _focusedIndex == index;
    final isActive = isHovered || isFocused;
    final progress = widget.labelProgress.clamp(0.0, 1.0);

    // Flex weight: when selected and label is expanding, allocate more flex space
    // 100 flex points base, plus up to 90 additional points for selected item when expanded
    final flex = isSelected ? (100 + (90 * progress).round()) : 100;

    return Expanded(
      flex: flex,
      child: Focus(
        onFocusChange: (val) {
          setState(() {
            _focusedIndex = val ? index : (_focusedIndex == index ? null : _focusedIndex);
          });
        },
        onKeyEvent: (node, event) => _handleActionKey(event, () {
          if (widget.selectedIndex != index) {
            HapticFeedback.lightImpact();
            widget.onDestinationSelected(index);
          }
        }),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) {
            if (_hoveredIndex == index) setState(() => _hoveredIndex = null);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (widget.selectedIndex != index) {
                HapticFeedback.lightImpact();
                widget.onDestinationSelected(index);
              }
            },
            child: Center(
              child: isSelected
                  ? _buildSelectedPill(
                      item: item,
                      theme: theme,
                      progress: progress,
                      isActive: isActive,
                    )
                  : _buildUnselectedItem(
                      item: item,
                      theme: theme,
                      isActive: isActive,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  /// Active pill container showing [Icon] and optionally [Label] to the right
  Widget _buildSelectedPill({
    required DesktopSidebarItem item,
    required ThemeData theme,
    required double progress,
    required bool isActive,
  }) {
    final showText = progress > 0.05;

    return Container(
      height: 40,
      padding: EdgeInsets.symmetric(
        horizontal: showText ? (10 + (4 * progress)) : 14,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.selectedIcon,
            size: 22,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          if (showText) ...[
            SizedBox(width: 6 * progress),
            Flexible(
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Opacity(
                    opacity: progress,
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSecondaryContainer,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Unselected item showing only icon
  Widget _buildUnselectedItem({
    required DesktopSidebarItem item,
    required ThemeData theme,
    required bool isActive,
  }) {
    return Container(
      width: 44,
      height: 38,
      decoration: BoxDecoration(
        color: isActive
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(19),
      ),
      child: Center(
        child: Icon(
          item.icon,
          size: 22,
          color: isActive
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
