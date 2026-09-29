import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/presentation/widgets/floating_resume_bar.dart';

class DesktopSidebarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int? targetIndex;

  const DesktopSidebarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.targetIndex,
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

  const DesktopSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onSearchPressed,
    this.onSettingsPressed,
    this.isSearchActive = false,
    required this.items,
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

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      width: 72,
      height: double.infinity,
      color: Colors.transparent,
      padding: EdgeInsets.only(
        top: 24,
        bottom: 24 + bottomInset,
        left: 8,
        right: 8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Floating Search Action Button (Focusable with DPAD)
          Focus(
            onFocusChange: (val) => setState(() => _isSearchFocused = val),
            onKeyEvent: (node, event) => _handleActionKey(event, widget.onSearchPressed),
            child: Tooltip(
              message: l10n.search,
              waitDuration: const Duration(milliseconds: 400),
              child: MouseRegion(
                onEnter: (_) => setState(() => _isSearchHovered = true),
                onExit: (_) => setState(() => _isSearchHovered = false),
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onSearchPressed,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 140),
                        curve: Curves.easeOutCubic,
                        scale: (_isSearchHovered || _isSearchFocused)
                            ? 1.15
                            : (widget.isSearchActive ? 1.1 : 1.0),
                        child: Icon(
                          AppIcons.search(iconPack),
                          color: widget.isSearchActive
                              ? colors.accent
                              : ((_isSearchHovered || _isSearchFocused)
                                  ? hoverIconColor
                                  : colors.textSecondary.withValues(alpha: 0.7)),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 2. Navigation Rail Floating Destinations
          for (int i = 0; i < widget.items.length; i++) ...[
            _buildNavItem(i, widget.items[i], colors),
            const SizedBox(height: 12),
          ],

          const Spacer(),

          // 3. Continue Watching / Reading (Floating Focusable)
          if (resumeEnabled && session != null) ...[
            Focus(
              onFocusChange: (val) => setState(() => _isResumeFocused = val),
              onKeyEvent: (node, event) =>
                  _handleActionKey(event, () => _resumePlayback(context, ref, session)),
              child: Tooltip(
                message: session.isAnime ? l10n.continueWatching : l10n.continueReading,
                waitDuration: const Duration(milliseconds: 400),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isResumeHovered = true),
                  onExit: (_) => setState(() => _isResumeHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _resumePlayback(context, ref, session),
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          scale: (_isResumeHovered || _isResumeFocused) ? 1.15 : 1.0,
                          child: Icon(
                            session.isAnime
                                ? AppIcons.play(iconPack)
                                : AppIcons.bookmark(iconPack),
                            size: 22,
                            color: (_isResumeHovered || _isResumeFocused)
                                ? hoverIconColor
                                : colors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // 4. Floating Settings Action Button
          if (widget.onSettingsPressed != null) ...[
            Focus(
              onFocusChange: (val) => setState(() => _isSettingsFocused = val),
              onKeyEvent: (node, event) =>
                  _handleActionKey(event, widget.onSettingsPressed!),
              child: Tooltip(
                message: l10n.settingsTitle,
                waitDuration: const Duration(milliseconds: 400),
                child: MouseRegion(
                  onEnter: (_) => setState(() => _isSettingsHovered = true),
                  onExit: (_) => setState(() => _isSettingsHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onSettingsPressed,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: Center(
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 140),
                          curve: Curves.easeOutCubic,
                          scale: (_isSettingsHovered || _isSettingsFocused) ? 1.15 : 1.0,
                          child: Icon(
                            AppIcons.settings(iconPack),
                            size: 22,
                            color: (_isSettingsHovered || _isSettingsFocused)
                                ? hoverIconColor
                                : colors.textSecondary.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
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

  Widget _buildNavItem(
    int index,
    DesktopSidebarItem item,
    AppThemeColors colors,
  ) {
    final isSelected = !widget.isSearchActive &&
        (item.targetIndex != null
            ? widget.selectedIndex == item.targetIndex
            : widget.selectedIndex == index);
    final isHovered = _hoveredIndex == index;
    final isFocused = _focusedIndex == index;
    final isActive = isHovered || isFocused;
    final theme = Theme.of(context);
    final hoverIconColor = theme.brightness == Brightness.dark ? Colors.white : theme.colorScheme.onSurface;

    void onSelect() => widget.onDestinationSelected(item.targetIndex ?? index);

    return Focus(
      onFocusChange: (val) {
        setState(() {
          _focusedIndex = val ? index : (_focusedIndex == index ? null : _focusedIndex);
        });
      },
      onKeyEvent: (node, event) => _handleActionKey(event, onSelect),
      child: Tooltip(
        message: item.label,
        waitDuration: const Duration(milliseconds: 400),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoveredIndex = index),
          onExit: (_) {
            if (_hoveredIndex == index) setState(() => _hoveredIndex = null);
          },
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onSelect,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 140),
                  curve: Curves.easeOutCubic,
                  scale: isActive ? 1.15 : (isSelected ? 1.1 : 1.0),
                  child: Icon(
                    isSelected ? item.selectedIcon : item.icon,
                    size: 22,
                    color: isSelected
                        ? colors.accent
                        : (isActive ? hoverIconColor : colors.textSecondary.withValues(alpha: 0.7)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
