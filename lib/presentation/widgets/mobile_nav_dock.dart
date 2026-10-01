import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';

/// A floating mobile navigation bar that includes both icons and text labels,
/// styled with rounded corners, elevated glassmorphism, and smooth active transitions,
/// completely detached from screen edges so it floats gracefully in the air.
class MobileNavDock extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<DesktopSidebarItem> items;

  const MobileNavDock({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
  });

  @override
  ConsumerState<MobileNavDock> createState() => _MobileNavDockState();
}

class _MobileNavDockState extends ConsumerState<MobileNavDock> {
  static const double _kDockHeight = 74.0;
  int? _hoveredIndex;
  int? _focusedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTopResumeBar = ref.watch(resumeBarEnabledProvider) && ref.watch(lastSessionProvider.select((s) => s != null));

    final borderRadius = hasTopResumeBar
        ? const BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(6),
            bottomLeft: Radius.circular(26),
            bottomRight: Radius.circular(26),
          )
        : BorderRadius.circular(26);

    return RepaintBoundary(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          top: hasTopResumeBar ? 0 : 8,
          bottom: 8,
        ),
        height: _kDockHeight,
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
              blurRadius: 12,
              spreadRadius: 0,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.90)
                  : theme.colorScheme.surface.withValues(alpha: 0.95),
              borderRadius: borderRadius,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                for (int i = 0; i < widget.items.length; i++)
                  Expanded(
                    child: _buildNavItem(
                      index: i,
                      item: widget.items[i],
                      isSelected: widget.selectedIndex == i,
                      theme: theme,
                    ),
                  ),
              ],
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

    return Focus(
      onFocusChange: (val) {
        setState(() {
          _focusedIndex = val ? index : (_focusedIndex == index ? null : _focusedIndex);
        });
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          if (widget.selectedIndex != index) {
            HapticFeedback.lightImpact();
            widget.onDestinationSelected(index);
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Active / Hover indicator capsule with icon (hover only surrounds this capsule)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 58,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.secondaryContainer
                      : (isActive
                          ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.70)
                          : Colors.transparent),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 200),
                    scale: isSelected ? 1.06 : (isActive ? 1.04 : 1.0),
                    child: (item.avatarUrl != null && item.avatarUrl!.isNotEmpty)
                        ? Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.onSecondaryContainer
                                    : (isActive
                                        ? theme.colorScheme.onSurface
                                        : Colors.white.withValues(alpha: 0.25)),
                                width: isSelected ? 1.8 : 1.2,
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
                                isSelected ? item.selectedIcon : item.icon,
                                size: 20,
                                color: isSelected
                                    ? theme.colorScheme.onSecondaryContainer
                                    : (isActive
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )
                        : Icon(
                            isSelected ? item.selectedIcon : item.icon,
                            size: 23,
                            color: isSelected
                                ? theme.colorScheme.onSecondaryContainer
                                : (isActive
                                    ? theme.colorScheme.onSurface
                                    : theme.colorScheme.onSurfaceVariant),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              // Text Label
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 12.0,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onSurface
                      : (isActive
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurfaceVariant),
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
