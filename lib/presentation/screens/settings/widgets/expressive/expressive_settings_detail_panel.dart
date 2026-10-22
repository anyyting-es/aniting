import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../settings_screen.dart';

/// Floating content detail panel matching the M3 Expressive dotfiles look.
/// Renders a solid elevated island with rounded corners and smooth animated transitions.
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
    final exit = widget.onExitToSidebar;
    if (exit == null) {
      return KeyEventResult.ignored;
    }
    exit();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FocusScope(
      node: widget.focusScopeNode,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
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
