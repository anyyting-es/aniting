import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/core/theme/app_dpad_navigator.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/presentation/widgets/floating_resume_bar.dart';

class DesktopSidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? targetIndex;
  final String? avatarUrl;

  const DesktopSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.targetIndex,
    this.avatarUrl,
  });
}

/// A sleek, floating Web & TV Media-Center Navigation Rail.
/// Transparent floating rail, borderless canvas, and full DPAD/keyboard focus traversal.
class DesktopSidebar extends ConsumerStatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onSearchPressed;
  final VoidCallback? onSettingsPressed;
  final bool isSearchActive;
  final List<DesktopSidebarItem> items;
  final bool? isTv;

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSearchPressed,
    this.onSettingsPressed,
    this.isSearchActive = false,
    required this.items,
    this.isTv,
  });

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  int? _hoveredIndex;
  int? _focusedIndex;
  bool _isSettingsHovered = false;
  bool _isSettingsFocused = false;
  bool _isSearchHovered = false;
  bool _isSearchFocused = false;
  bool _isResumeHovered = false;
  bool _isResumeFocused = false;

  bool get _isDpadFocused =>
      _focusedIndex != null ||
      _isSearchFocused ||
      _isSettingsFocused ||
      _isResumeFocused;

  void _resumePlayback(BuildContext context, WidgetRef ref, LastSessionItem session) {
    FloatingResumeBar.resumePlayback(context, ref, session);
  }

  KeyEventResult _handleActionKey(KeyEvent event, VoidCallback action) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter ||
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
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final resumeEnabled = ref.watch(resumeBarEnabledProvider);
    final hasSession = ref.watch(lastSessionProvider.select((s) => s != null));
    final session = hasSession ? ref.read(lastSessionProvider) : null;
    final iconPack = ref.watch(iconPackProvider);
    final isDark = theme.brightness == Brightness.dark;
    final hoverIconColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final bool isTv = widget.isTv ?? ref.watch(tvModeProvider);
    final bool isExpanded = isTv && _isDpadFocused;

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return FocusScope(
      child: FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (node, event) {
            if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
              return KeyEventResult.ignored;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              // The sidebar owns its own FocusScope. Use the global navigator
              // so the right arrow can actually reach the content area.
              final primary = FocusManager.instance.primaryFocus;
              if (primary != null) {
                AppDpadNavigator.moveFocus(primary, TraversalDirection.right);
              }
              return KeyEventResult.handled;
            }
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown) {
              // Keep vertical navigation inside the rail. At the edges the key
              // is consumed instead of jumping sideways into the content.
              final primary = FocusManager.instance.primaryFocus;
              if (primary != null) {
                if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  primary.nextFocus();
                } else {
                  primary.previousFocus();
                }
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: isTv ? (isExpanded ? 196.0 : 56.0) : 72.0,
            height: double.infinity,
            decoration: BoxDecoration(
              gradient: isExpanded
                  ? LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      stops: const [0.0, 0.40, 0.70, 0.88, 1.0],
                      colors: [
                        Colors.black.withValues(alpha: 0.85),
                        Colors.black.withValues(alpha: 0.70),
                        Colors.black.withValues(alpha: 0.42),
                        Colors.black.withValues(alpha: 0.15),
                        Colors.transparent,
                      ],
                    )
                  : null,
            ),
            padding: EdgeInsets.only(
              top: 38,
              bottom: 24 + bottomInset,
              left: 12,
              right: 12,
            ),
            child: ClipRect(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Floating Search Action Button (Focusable with DPAD)
                  _buildActionRow(
                    icon: Icon(
                      AppIcons.search(iconPack),
                      color: widget.isSearchActive
                          ? colors.accent
                          : ((_isSearchHovered || _isSearchFocused)
                              ? hoverIconColor
                              : colors.textSecondary.withValues(alpha: 0.7)),
                      size: 22,
                    ),
                    label: l10n.search,
                    isSelected: widget.isSearchActive,
                    isHovered: _isSearchHovered,
                    isFocused: _isSearchFocused,
                    onTap: widget.onSearchPressed,
                    onFocusChange: (val) => setState(() => _isSearchFocused = val),
                    onHoverChange: (val) => setState(() => _isSearchHovered = val),
                    colors: colors,
                    hoverIconColor: hoverIconColor,
                  ),

                  const Spacer(),

                  // 2. Navigation Rail Floating Destinations (Vertically Centered)
                  for (int i = 0; i < widget.items.length; i++) ...[
                    _buildNavItem(i, widget.items[i], colors, hoverIconColor),
                    if (i < widget.items.length - 1) const SizedBox(height: 10),
                  ],

                  const Spacer(),

                  // 3. Continue Watching / Reading (Floating Focusable)
                  if (resumeEnabled && session != null) ...[
                    _buildActionRow(
                      icon: Icon(
                        session.isAnime
                            ? AppIcons.play(iconPack)
                            : AppIcons.bookmark(iconPack),
                        size: 22,
                        color: (_isResumeHovered || _isResumeFocused)
                            ? hoverIconColor
                            : colors.textSecondary.withValues(alpha: 0.7),
                      ),
                      label: session.isAnime ? l10n.continueWatching : l10n.continueReading,
                      isSelected: false,
                      isHovered: _isResumeHovered,
                      isFocused: _isResumeFocused,
                      onTap: () => _resumePlayback(context, ref, session),
                      onFocusChange: (val) => setState(() => _isResumeFocused = val),
                      onHoverChange: (val) => setState(() => _isResumeHovered = val),
                      colors: colors,
                      hoverIconColor: hoverIconColor,
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 4. Floating Settings Action Button
                  if (widget.onSettingsPressed != null) ...[
                    _buildActionRow(
                      icon: Icon(
                        AppIcons.settings(iconPack),
                        size: 22,
                        color: (_isSettingsHovered || _isSettingsFocused)
                            ? hoverIconColor
                            : colors.textSecondary.withValues(alpha: 0.7),
                      ),
                      label: l10n.settingsTitle,
                      isSelected: false,
                      isHovered: _isSettingsHovered,
                      isFocused: _isSettingsFocused,
                      onTap: widget.onSettingsPressed!,
                      onFocusChange: (val) => setState(() => _isSettingsFocused = val),
                      onHoverChange: (val) => setState(() => _isSettingsHovered = val),
                      colors: colors,
                      hoverIconColor: hoverIconColor,
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

  Widget _buildNavItem(
    int index,
    DesktopSidebarItem item,
    AppThemeColors colors,
    Color hoverIconColor,
  ) {
    final isSelected = !widget.isSearchActive &&
        (item.targetIndex != null
            ? widget.selectedIndex == item.targetIndex
            : widget.selectedIndex == index);
    final isHovered = _hoveredIndex == index;
    final isFocused = _focusedIndex == index;

    final avatarUrl = item.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final theme = Theme.of(context);

    Widget iconWidget;
    if (hasAvatar) {
      final isActive = isHovered || isFocused;
      iconWidget = Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? colors.accent
                : (isActive ? hoverIconColor : colors.border.withValues(alpha: 0.6)),
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: avatarUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: theme.colorScheme.surfaceContainer,
          ),
          errorWidget: (context, url, error) => Icon(
            isSelected ? item.selectedIcon : item.icon,
            size: 20,
            color: isSelected
                ? colors.accent
                : (isActive ? hoverIconColor : colors.textSecondary.withValues(alpha: 0.7)),
          ),
        ),
      );
    } else {
      iconWidget = Icon(
        isSelected ? item.selectedIcon : item.icon,
        size: 22,
        color: isSelected
            ? colors.accent
            : ((isHovered || isFocused) ? hoverIconColor : colors.textSecondary.withValues(alpha: 0.7)),
      );
    }

    return _buildActionRow(
      icon: iconWidget,
      label: item.label,
      isSelected: isSelected,
      isHovered: isHovered,
      isFocused: isFocused,
      onTap: () => widget.onDestinationSelected(item.targetIndex ?? index),
      onFocusChange: (val) {
        setState(() {
          _focusedIndex = val ? index : (_focusedIndex == index ? null : _focusedIndex);
        });
      },
      onHoverChange: (val) {
        setState(() {
          _hoveredIndex = val ? index : (_hoveredIndex == index ? null : _hoveredIndex);
        });
      },
      colors: colors,
      hoverIconColor: hoverIconColor,
    );
  }

  Widget _buildActionRow({
    required Widget icon,
    required String label,
    required bool isSelected,
    required bool isHovered,
    required bool isFocused,
    required VoidCallback onTap,
    required ValueChanged<bool> onFocusChange,
    required ValueChanged<bool> onHoverChange,
    required AppThemeColors colors,
    required Color hoverIconColor,
  }) {
    final theme = Theme.of(context);
    final isActive = isHovered || isFocused;
    final bool isTv = widget.isTv ?? ref.watch(tvModeProvider);
    final bool isExpanded = isTv && _isDpadFocused;

    return Focus(
      onFocusChange: onFocusChange,
      onKeyEvent: (node, event) => _handleActionKey(event, onTap),
      child: Tooltip(
        message: label,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          onEnter: (_) => onHoverChange(true),
          onExit: (_) => onHoverChange(false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: isFocused
                    ? colors.accent.withValues(alpha: 0.22)
                    : (isHovered
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                        : Colors.transparent),
                border: Border.all(
                  color: isFocused
                      ? colors.accent.withValues(alpha: 0.55)
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        scale: isActive ? 1.15 : (isSelected ? 1.1 : 1.0),
                        child: icon,
                      ),
                    ),
                  ),
                  if (isExpanded)
                    Expanded(
                      child: ClipRect(
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          opacity: isExpanded ? 1.0 : 0.0,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 10),
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.fade,
                              style: TextStyle(
                                color: isSelected
                                    ? colors.accent
                                    : (isActive ? hoverIconColor : colors.textSecondary),
                                fontSize: 14,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : (isActive ? FontWeight.w600 : FontWeight.w500),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
