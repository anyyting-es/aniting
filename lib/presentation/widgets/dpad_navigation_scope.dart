import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/theme/app_dpad_navigator.dart';

/// Global scope that enables directional navigation (D-pad, arrow keys)
/// to seamlessly exit and traverse out of text fields ([TextField], [TextFormField], [EditableText]).
///
/// In standard Flutter, [EditableText] intercepts directional keys (up, down, left, right)
/// and traps focus inside the input field. This scope intercepts these keys when focused
/// on an [EditableText] and forwards them to [FocusTraversalGroup] / [FocusNode.focusInDirection],
/// allowing gamepads, Android TV remotes, and keyboard navigation to work naturally.
class DpadNavigationScope extends StatefulWidget {
  final Widget child;

  const DpadNavigationScope({
    super.key,
    required this.child,
  });

  @override
  State<DpadNavigationScope> createState() => _DpadNavigationScopeState();
}

class _DpadNavigationScopeState extends State<DpadNavigationScope> {
  final AppDirectionalFocusAction _directionalFocusAction =
      AppDirectionalFocusAction();

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return false;
    }

    // Preserve text editing shortcuts when modifier keys are held (Shift, Ctrl, Alt, Meta)
    final keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }

    final key = event.logicalKey;
    final isArrowUp = key == LogicalKeyboardKey.arrowUp;
    final isArrowDown = key == LogicalKeyboardKey.arrowDown;
    final isArrowLeft = key == LogicalKeyboardKey.arrowLeft;
    final isArrowRight = key == LogicalKeyboardKey.arrowRight;
    final isEscape = key == LogicalKeyboardKey.escape;

    if (!isArrowUp && !isArrowDown && !isArrowLeft && !isArrowRight && !isEscape) {
      return false;
    }

    final currentFocus = FocusManager.instance.primaryFocus;
    if (currentFocus == null) {
      // D-pad pressed before anything received focus (TV / gamepad startup).
      if (isEscape) return false;
      return AppDpadNavigator.focusFirst();
    }

    final context = currentFocus.context;
    if (context == null || !context.mounted) return false;

    final editableState = _findEditableTextState(context);
    // Only intercept when the currently focused element is an EditableText
    if (editableState == null) return false;

    if (isEscape) {
      currentFocus.unfocus();
      return true;
    }

    final textValue = editableState.textEditingValue;
    final text = textValue.text;
    final selection = textValue.selection;
    final isSingleLine = editableState.widget.maxLines == 1;
    final hasCollapsedCursor = selection.isValid && selection.isCollapsed;
    final cursor = hasCollapsedCursor
        ? selection.baseOffset.clamp(0, text.length).toInt()
        : 0;

    if (isArrowDown) {
      // In single-line inputs or when on the bottom-most line, navigate down
      if (isSingleLine ||
          text.isEmpty ||
          (hasCollapsedCursor && !text.substring(cursor).contains('\n'))) {
        return _moveFocus(currentFocus, TraversalDirection.down);
      }
    } else if (isArrowUp) {
      // In single-line inputs or when on the top-most line, navigate up
      if (isSingleLine ||
          text.isEmpty ||
          (hasCollapsedCursor && !text.substring(0, cursor).contains('\n'))) {
        return _moveFocus(currentFocus, TraversalDirection.up);
      }
    } else if (isArrowLeft) {
      // When cursor is at the very beginning (offset 0) or empty, navigate left
      if (text.isEmpty || (hasCollapsedCursor && cursor <= 0)) {
        return _moveFocus(currentFocus, TraversalDirection.left);
      }
    } else if (isArrowRight) {
      // When cursor is at the very end or empty, navigate right
      if (text.isEmpty || (hasCollapsedCursor && cursor >= text.length)) {
        return _moveFocus(currentFocus, TraversalDirection.right);
      }
    }

    return false;
  }

  bool _moveFocus(FocusNode focusNode, TraversalDirection direction) {
    if (focusNode.focusInDirection(direction)) return true;

    // Cross carousels, scrollables, focus scopes and traversal groups.
    if (AppDpadNavigator.moveFocus(focusNode, direction)) return true;

    // Last resort: sequential traversal if geometric direction has no direct neighbor
    if (direction == TraversalDirection.down || direction == TraversalDirection.right) {
      focusNode.nextFocus();
    } else if (direction == TraversalDirection.up || direction == TraversalDirection.left) {
      focusNode.previousFocus();
    }
    return true;
  }

  EditableTextState? _findEditableTextState(BuildContext context) {
    if (context is StatefulElement && context.state is EditableTextState) {
      return context.state as EditableTextState;
    }
    return context.findAncestorStateOfType<EditableTextState>();
  }

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: <Type, Action<Intent>>{
        DirectionalFocusIntent: _directionalFocusAction,
      },
      child: widget.child,
    );
  }
}
