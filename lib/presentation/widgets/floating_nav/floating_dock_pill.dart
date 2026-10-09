import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';

/// A Material Design 3 floating navigation dock with fluid animated pill expansion
/// and enhanced Liquid Glass frosted refraction.
class FloatingDockPill extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopSidebarItem> items;
  final double labelProgress; // 0.0 = icon-only, 1.0 = label fully deployed
  final double? width;
  final double height;
  final BorderRadius borderRadius;

  const FloatingDockPill({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    this.labelProgress = 1.0,
    this.width,
    this.height = 68.0,
    required this.borderRadius,
  });

  static double measureTextWidth(String text, TextStyle style) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  /// Calculates the exact intrinsic width of the dock pill given current items,
  /// selected tab, and label deployment progress.
  static double calculateWidth({
    required List<DesktopSidebarItem> items,
    required int selectedIndex,
    double labelProgress = 1.0,
  }) {
    const baseButtonWidth = 52.0;
    const itemGap = 8.0;
    const horizontalPadding = 16.0; // 8.0 left + 8.0 right
    const borderWidth = 2.0; // 1.0 left border + 1.0 right border
    const labelStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );

    double total = horizontalPadding + borderWidth;
    if (items.isNotEmpty) {
      total += (items.length - 1) * itemGap;
      for (int i = 0; i < items.length; i++) {
        final isSelected = selectedIndex == (items[i].targetIndex ?? i);
        if (isSelected && labelProgress > 0.05) {
          final textWidth = measureTextWidth(items[i].label, labelStyle);
          final expandedButtonWidth = baseButtonWidth + textWidth + 18.0;
          total += lerpDouble(baseButtonWidth, expandedButtonWidth, labelProgress.clamp(0.0, 1.0))!;
        } else {
          total += baseButtonWidth;
        }
      }
    }
    return total;
  }

  @override
  ConsumerState<FloatingDockPill> createState() => _FloatingDockPillState();
}

class _FloatingDockPillState extends ConsumerState<FloatingDockPill> {
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
    final glassEnabled = ref.watch(glassEffectsEnabledProvider);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
          if (glassEnabled)
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: GlassCard(
          borderRadius: widget.borderRadius,
          padding: EdgeInsets.zero,
          child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                color: glassEnabled
                    ? (isDark
                        ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.35)
                        : theme.colorScheme.surfaceContainer.withValues(alpha: 0.48))
                    : theme.colorScheme.surfaceContainer,
                borderRadius: widget.borderRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: glassEnabled ? 0.20 : 0.12)
                      : theme.colorScheme.outlineVariant.withValues(alpha: glassEnabled ? 0.45 : 0.25),
                  width: 1.0,
                ),
              ),
              child: Center(
                widthFactor: widget.width == null ? 1.0 : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (int i = 0; i < widget.items.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8.0),
                          _buildNavItem(
                            index: i,
                            item: widget.items[i],
                            isSelected: widget.selectedIndex == (widget.items[i].targetIndex ?? i),
                            theme: theme,
                          ),
                        ],
                      ],
                    ),
                  ),
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
      fontSize: 14.5,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
    );

    final textWidth = FloatingDockPill.measureTextWidth(item.label, labelStyle);
    const baseButtonWidth = 52.0;
    const buttonHeight = 50.0;
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
                  // Width smoothly animates between 52.0 (compact icon) and expandedButtonWidth (pill with text)
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
                        // Icon or Avatar
                        if (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                          Container(
                            width: 26.5,
                            height: 26.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectValue > 0.5
                                    ? theme.colorScheme.primary
                                    : (isActive
                                        ? (iconColor ?? theme.colorScheme.onSurface)
                                        : Colors.white.withValues(alpha: 0.25)),
                                width: selectValue > 0.5 ? 1.8 : 1.2,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: item.avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: theme.colorScheme.surfaceContainerHighest,
                              ),
                              errorWidget: (context, url, error) => Icon(
                                selectValue > 0.5 ? item.selectedIcon : item.icon,
                                size: 20,
                                color: iconColor,
                              ),
                            ),
                          )
                        else
                          Icon(
                            selectValue > 0.5 ? item.selectedIcon : item.icon,
                            size: 26.5,
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
