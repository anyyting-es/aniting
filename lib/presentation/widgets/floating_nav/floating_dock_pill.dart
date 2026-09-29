import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';

/// A solid Material Design 3 floating navigation dock with fluid animated pill expansion.
///
/// Features:
/// - 100% solid background (zero transparency/blur) using `theme.colorScheme.surfaceContainer`.
/// - Material 3 elevation shadow and crisp subtle outline.
/// - Cohesive centered layout ("todo más junto, más acomodado") instead of stretching across the screen.
/// - Prominent, larger icons (25dp) and comfortable pill height (46dp).
/// - Fluid animated pill expansion on tab selection:
///   - When tapping a destination, the pill smoothly expands horizontally, pushing adjacent icons aside
///     with organic, physics-based easing (`Curves.easeOutCubic`).
///   - The previous active pill smoothly contracts back to a circular icon button.
///   - When [labelProgress] == 0 (e.g. sharing row with resume companion), operates in icon-only mode.
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

  double _measureTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
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
            blurRadius: 16,
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
        child: Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8.0),
                    _buildNavItem(
                      index: i,
                      item: widget.items[i],
                      isSelected: widget.selectedIndex == i,
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ),
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

    // Target values for animations:
    // 1. selectionTarget: 1.0 if selected, 0.0 if not (controls background pill highlight and colors)
    final selectionTarget = isSelected ? 1.0 : 0.0;
    // 2. labelTarget: 1.0 if selected AND dock is in label mode; 0.0 if unselected or icon-only mode
    final labelTarget = (isSelected && widget.labelProgress > 0.05)
        ? widget.labelProgress.clamp(0.0, 1.0)
        : 0.0;

    const labelStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );

    final textWidth = _measureTextWidth(item.label, labelStyle);
    const baseButtonWidth = 48.0;
    const buttonHeight = 46.0;
    // Expanded width = base button + gap (8) + text width + right margin (14)
    final expandedButtonWidth = baseButtonWidth + textWidth + 18.0;

    return Focus(
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
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(end: labelTarget),
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            builder: (context, labelValue, _) {
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: selectionTarget),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (context, selectValue, _) {
                  // Width smoothly animates between 48.0 (compact icon) and expandedButtonWidth (pill with text)
                  final currentWidth = lerpDouble(
                    baseButtonWidth,
                    expandedButtonWidth,
                    labelValue,
                  )!;

                  final pillBgColor = Color.lerp(
                    isActive
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                        : Colors.transparent,
                    theme.colorScheme.secondaryContainer,
                    selectValue,
                  );

                  final iconColor = Color.lerp(
                    isActive
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                    theme.colorScheme.onSecondaryContainer,
                    selectValue,
                  );

                  return Container(
                    width: currentWidth,
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: pillBgColor,
                      borderRadius: BorderRadius.circular(buttonHeight / 2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon (prominent 25dp)
                        Icon(
                          selectValue > 0.5 ? item.selectedIcon : item.icon,
                          size: 25,
                          color: iconColor,
                        ),

                        // Animated expanding text label
                        if (labelValue > 0.01) ...[
                          SizedBox(width: 8.0 * labelValue),
                          ClipRect(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              widthFactor: labelValue,
                              child: Opacity(
                                opacity: labelValue.clamp(0.0, 1.0),
                                child: Text(
                                  item.label,
                                  style: labelStyle.copyWith(
                                    color: theme.colorScheme.onSecondaryContainer,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 4.0 * labelValue),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
