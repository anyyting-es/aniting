import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';

/// Wraps the scrollable settings content once and reveals whatever control
/// gains focus (D-pad included), even when it was not wrapped with
/// [SettingsDpadFocus]. This covers plain [InkWell] / [ListTile] controls.
class SettingsFocusEnsurer extends StatefulWidget {
  final Widget child;

  const SettingsFocusEnsurer({super.key, required this.child});

  @override
  State<SettingsFocusEnsurer> createState() => _SettingsFocusEnsurerState();
}

class _SettingsFocusEnsurerState extends State<SettingsFocusEnsurer> {
  FocusNode? _lastPrimary;
  double? _lastTop;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    final node = FocusManager.instance.primaryFocus;
    if (node == null || node == _lastPrimary) return;
    _lastPrimary = node;

    // Only auto-scroll while navigating with the D-pad / keyboard.
    if (AppFocusCoordinator.inputMode.value != AppInputMode.dpad) return;

    final ctx = node.context;
    if (ctx == null || !ctx.mounted) return;

    // Ignore controls outside this subtree (dialogs, other routes) and those
    // already handled by their own SettingsDpadFocus wrapper.
    if (ctx.findAncestorStateOfType<_SettingsFocusEnsurerState>() != this) return;
    if (ctx.findAncestorStateOfType<_SettingsDpadFocusState>() != null) return;

    double? top;
    try {
      top = node.rect.top;
    } catch (_) {
      top = null;
    }
    final movingUp = _lastTop != null && top != null && top < _lastTop!;
    _lastTop = top;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignmentPolicy: movingUp
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


/// Reusable D-pad / gamepad / keyboard focus wrapper for the settings pages.
///
/// It mirrors the focus contract already used across the app
/// (`AppFocusCoordinator` + `Scrollable.ensureVisible`):
///
/// * The wrapper owns a single [FocusNode] and takes the focus itself, so inner
///   controls (which are excluded from focus) never add surprise stops.
/// * When it gains focus it scrolls itself into view, so navigating with a
///   D-pad through a long settings page always reveals the focused row.
/// * It draws a clear focus ring only while navigating with the D-pad, keeping
///   mouse hover untouched.
/// * Select / Enter / Space / Gamepad A activate it.
class SettingsDpadFocus extends StatefulWidget {
  final Widget child;

  /// Called on tap as well as D-pad / keyboard activation.
  final VoidCallback? onActivate;

  /// Radius used to clip the focus ring so it follows the control shape.
  final BorderRadius borderRadius;

  /// Outer margin applied around the focus ring.
  final EdgeInsetsGeometry margin;

  /// When false the control is skipped by focus traversal.
  final bool enabled;

  /// Alignment used when scrolling the focused control into view.
  final double ensureVisibleAlignment;

  const SettingsDpadFocus({
    super.key,
    required this.child,
    this.onActivate,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.margin = EdgeInsets.zero,
    this.enabled = true,
    this.ensureVisibleAlignment = 0.4,
  });

  @override
  State<SettingsDpadFocus> createState() => _SettingsDpadFocusState();
}

class _SettingsDpadFocusState extends State<SettingsDpadFocus> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'settings-dpad-focus');
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_isFocused == _focusNode.hasFocus) return;
    final focused = _focusNode.hasFocus;
    setState(() => _isFocused = focused);

    if (focused) {
      AppFocusCoordinator.onNodeFocused(_focusNode);
      if (mounted) {
        Scrollable.ensureVisible(
          context,
          alignment: widget.ensureVisibleAlignment,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  void _activate() {
    HapticFeedback.selectionClick();
    final onActivate = widget.onActivate;
    if (onActivate != null) {
      onActivate();
      return;
    }
    _simulateTap();
  }

  /// Dispatches a synthetic tap at the center of the control so D-pad Select
  /// reuses the exact same action as a real tap (InkWell, SwitchListTile…),
  /// without every call site having to duplicate its callback here.
  void _simulateTap() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return;
    final global = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
    const int pointer = 7;
    final binding = GestureBinding.instance;
    binding.handlePointerEvent(
      PointerDownEvent(position: global, pointer: pointer),
    );
    binding.handlePointerEvent(
      PointerUpEvent(position: global, pointer: pointer),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      _activate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Focus(
      focusNode: _focusNode,
      canRequestFocus: widget.enabled,
      skipTraversal: !widget.enabled,
      onKeyEvent: _handleKeyEvent,
      child: ValueListenableBuilder<AppInputMode>(
        valueListenable: AppFocusCoordinator.inputMode,
        builder: (context, mode, child) {
          final showRing =
              _isFocused && mode == AppInputMode.dpad && widget.enabled;

          return MouseRegion(
            cursor: widget.enabled
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            onEnter: (_) => AppFocusCoordinator.switchToMouse(_focusNode),
            // Inner controls keep their own pointer behaviour (tap, ripple,
            // hover) but must never become separate focus stops.
            child: ExcludeFocus(
              child: Padding(
                padding: widget.margin,
                child: Stack(
                  children: [
                    child!,
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            borderRadius: widget.borderRadius,
                            border: Border.all(
                              color: showRing
                                  ? colorScheme.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
