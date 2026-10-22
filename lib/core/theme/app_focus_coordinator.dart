import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  /// Switches active mode to DPAD / Keyboard and focuses the element under the mouse or last focus.
  static void switchToDpad() {
    if (inputMode.value != AppInputMode.dpad) {
      inputMode.value = AppInputMode.dpad;
    }

    // Seamlessly transfer focus to the hovered node if available, so DPAD continues directly from where the mouse was!
    final target = (lastHoveredNode != null &&
            lastHoveredNode!.context != null &&
            lastHoveredNode!.canRequestFocus)
        ? lastHoveredNode
        : (lastFocusedNode != null &&
                lastFocusedNode!.context != null &&
                lastFocusedNode!.canRequestFocus)
            ? lastFocusedNode
            : null;

    if (target != null && !target.hasFocus) {
      target.requestFocus();
    }
  }

  /// Switches active mode to Mouse. Deactivates DPAD highlights so only the hovered card is active.
  static void switchToMouse([FocusNode? hoveredNode]) {
    if (hoveredNode != null) {
      lastHoveredNode = hoveredNode;
    }
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
