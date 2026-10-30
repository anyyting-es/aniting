import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../settings_screen.dart';
import '../settings_dpad_focus.dart';

/// Content detail panel for the settings pages.
///
/// It is intentionally background-less: the pages sit directly on the app
/// background (wallpaper / scaffold) per the transparency contract in
/// docs/WALLPAPER_VISUAL_FIX_PLAN.md. Only a smooth page transition, the focus
/// scope and D-pad auto-scroll remain.
class ExpressiveSettingsDetailPanel extends StatefulWidget {
  final SettingsCategory selectedCategory;
  final Widget Function(SettingsCategory category) detailViewBuilder;
  final FocusScopeNode? focusScopeNode;

  /// Called when Left is pressed while the focus is inside the panel, so the
  /// screen can hand the focus back to the categories sidebar.
  final VoidCallback? onExitToSidebar;

  const ExpressiveSettingsDetailPanel({
    super.key,
    required this.selectedCategory,
    required this.detailViewBuilder,
    this.focusScopeNode,
    this.onExitToSidebar,
  });

  @override
  State<ExpressiveSettingsDetailPanel> createState() =>
      _ExpressiveSettingsDetailPanelState();
}

class _ExpressiveSettingsDetailPanelState
    extends State<ExpressiveSettingsDetailPanel> {
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft) {
      return KeyEventResult.ignored;
    }

    // Let Left move inside the current row first (icon pack cards, radius
    // chips, side-by-side controls). Only leave the panel when there is no
    // focusable target to the left.
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null &&
        primary != node &&
        primary.focusInDirection(TraversalDirection.left)) {
      return KeyEventResult.ignored;
    }

    final exit = widget.onExitToSidebar;
    if (exit == null) {
      return KeyEventResult.ignored;
    }
    exit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: widget.focusScopeNode,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        // No opaque island: the settings pages sit directly on the app
        // background (wallpaper / scaffold), per the transparency contract in
        // docs/WALLPAPER_VISUAL_FIX_PLAN.md.
        child: SettingsFocusEnsurer(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slideAnimation = Tween<Offset>(
                begin: const Offset(0.03, 0.0),
                end: Offset.zero,
              ).animate(animation);

              return SlideTransition(
                position: slideAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            // While a page fades out it is no longer the active page: keeping
            // its controls out of the focus tree ensures the focus always
            // lands on the newly selected page.
            layoutBuilder: (currentChild, previousChildren) => Stack(
              alignment: Alignment.center,
              children: [
                for (final child in previousChildren)
                  ExcludeFocus(child: child),
                ?currentChild,
              ],
            ),
            child: KeyedSubtree(
              key: ValueKey(widget.selectedCategory),
              child: widget.detailViewBuilder(widget.selectedCategory),
            ),
          ),
        ),
      ),
    );
  }
}
