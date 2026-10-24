import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/theme/app_dpad_navigator.dart';

enum AppInputMode {
  dpad,
  mouse,
}

/// Coordinates mutual exclusion between DPAD / keyboard navigation and mouse pointer interactions.
///
/// Ensures:
/// 1. When the user uses the mouse, DPAD focus highlights are deactivated and the mouse takes exclusive precedence.
/// 2. When the user presses ANY DPAD or arrow key, DPAD mode takes control immediately, ignoring the mouse cursor,
///    and naturally continuing navigation from the element the mouse was hovering or the last focused element.
class AppFocusCoordinator {
  AppFocusCoordinator._();

  static final ValueNotifier<AppInputMode> inputMode = ValueNotifier<AppInputMode>(AppInputMode.dpad);

  static FocusNode? lastFocusedNode;
  static FocusNode? lastHoveredNode;
  static bool _handlerInstalled = false;

  /// Ensures keyboard events update the active input mode.
  static void initialize() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  static bool _onKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final key = event.logicalKey;
      final isNavKey = key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.arrowUp ||
          key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.tab ||
          key == LogicalKeyboardKey.select ||
          key == LogicalKeyboardKey.gameButtonA ||
          key == LogicalKeyboardKey.gameButtonB ||
          key == LogicalKeyboardKey.gameButtonSelect;

      if (isNavKey) {
        switchToDpad();
      }
    }
    return false; // Passive observer: never consumes the key event
  }

  /// Switches active mode to DPAD / Keyboard.
  ///
  /// The hovered node is used only on the mouse -> D-pad transition. Re-using
  /// it on every arrow key would keep stealing focus back to whatever card the
  /// mouse cursor happens to be resting on, trapping the user in that card.
  static void switchToDpad() {
    final wasDpad = inputMode.value == AppInputMode.dpad;
    if (!wasDpad) {
      inputMode.value = AppInputMode.dpad;
    }

    // Already navigating with the D-pad: never move focus on our own.
    if (wasDpad) return;

    // While typing, arrows belong to the text field. DpadNavigationScope is in
    // charge of leaving it once the caret reaches an edge.
    final primary = FocusManager.instance.primaryFocus;
    if (primary != null && _isTextInput(primary)) {
      lastHoveredNode = null;
      return;
    }

    final hovered = lastHoveredNode;
    // Consume the hovered node so it cannot steal focus again on the next key.
    lastHoveredNode = null;

    if (hovered != null) {
      // Already on the hovered card: let the key navigate from it instead of
      // falling back to a different previously focused card.
      if (hovered.hasFocus) return;
      if (_canFocus(hovered)) {
        hovered.requestFocus();
        return;
      }
    }

    final last = lastFocusedNode;
    if (last != null && _canFocus(last)) {
      last.requestFocus();
    }
  }

  static bool _isTextInput(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    try {
      if (context is StatefulElement && context.state is EditableTextState) {
        return true;
      }
      return context.findAncestorStateOfType<EditableTextState>() != null;
    } catch (_) {
      return false;
    }
  }

  /// Whether [node] belongs to the current route and can take focus.
  ///
  /// A stale hover/focus target from a covered route (detail screen, dialog,
  /// bottom sheet) must never pull the D-pad focus back to a hidden page.
  static bool _canFocus(FocusNode node) {
    if (node.hasFocus || !AppDpadNavigator.canReceiveFocus(node)) return false;
    final context = node.context;
    if (context == null || !context.mounted) return false;
    try {
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return false;
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Switches active mode to Mouse. Deactivates DPAD highlights so only the hovered card is active.
  static void switchToMouse([FocusNode? hoveredNode]) {
    // Keep the hover target in sync even when the caller does not expose its
    // node; a stale target would steal focus on the next D-pad key.
    lastHoveredNode = hoveredNode;
    if (inputMode.value != AppInputMode.mouse) {
      inputMode.value = AppInputMode.mouse;
    }
  }

  /// Alias for switchToMouse for backwards-compatible call sites.
  static void onPointerEntered([FocusNode? ownFocusNode]) => switchToMouse(ownFocusNode);

  /// Registers when a node gains focus.
  static void onNodeFocused(FocusNode node) {
    lastFocusedNode = node;
    if (inputMode.value != AppInputMode.dpad) {
      inputMode.value = AppInputMode.dpad;
    }
  }
}
