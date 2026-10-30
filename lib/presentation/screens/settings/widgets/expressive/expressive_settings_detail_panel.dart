import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/theme/app_dpad_navigator.dart';

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
  bool _isSlider(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null || !ctx.mounted) return false;
    try {
      if (ctx.widget is Slider || ctx.widget is RangeSlider) return true;
      if (ctx.findAncestorWidgetOfExactType<Slider>() != null) return true;
      if (ctx.findAncestorWidgetOfExactType<RangeSlider>() != null) return true;
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _isButtonGroup(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null || !ctx.mounted) return false;
    try {
      if (ctx.widget is M3EButtonGroup) return true;
      return ctx.findAncestorWidgetOfExactType<M3EButtonGroup>() != null;
    } catch (_) {
      return false;
    }
  }

  bool _isTextInput(FocusNode? node) {
    final ctx = node?.context;
    if (ctx == null || !ctx.mounted) return false;
    try {
      if (ctx is StatefulElement && ctx.state is EditableTextState) return true;
      return ctx.findAncestorStateOfType<EditableTextState>() != null;
    } catch (_) {
      return false;
    }
  }

  bool _canReceiveFocus(FocusNode node) {
    if (!node.canRequestFocus || node.skipTraversal) return false;
    final scope = node.enclosingScope;
    if (scope != null && !scope.canRequestFocus) return false;
    for (final ancestor in node.ancestors) {
      if (!ancestor.descendantsAreFocusable) return false;
    }
    return true;
  }

  Rect? _rectOf(FocusNode node) {
    final ctx = node.context;
    if (ctx == null || !ctx.mounted) return null;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return null;
    final size = ro.size;
    if (size.isEmpty) return null;
    try {
      final origin = ro.localToGlobal(Offset.zero);
      return origin & size;
    } catch (_) {
      return null;
    }
  }

  FocusNode? _findHorizontalCandidate(
    FocusNode primary,
    TraversalDirection direction,
  ) {
    final fromRect = _rectOf(primary);
    if (fromRect == null) return null;

    final scope = widget.focusScopeNode ?? primary.nearestScope;
    if (scope == null) return null;

    final isLeft = direction == TraversalDirection.left;
    FocusNode? bestCandidate;
    double bestDistance = double.infinity;

    for (final node in scope.traversalDescendants) {
      if (node == primary || node.hasFocus) continue;
      if (node is FocusScopeNode) continue;
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (!_canReceiveFocus(node)) continue;
      if (primary.ancestors.contains(node) || node.ancestors.contains(primary)) continue;

      final rect = _rectOf(node);
      if (rect == null) continue;

      // 1. Must be in requested direction
      if (isLeft) {
        if (rect.center.dx >= fromRect.center.dx - 1.0) continue;
      } else {
        if (rect.center.dx <= fromRect.center.dx + 1.0) continue;
      }

      // 2. Must be in the same horizontal band (same row)
      final overlapTop = math.max(rect.top, fromRect.top);
      final overlapBottom = math.min(rect.bottom, fromRect.bottom);
      final overlapHeight = overlapBottom - overlapTop;
      final minHeight = math.min(rect.height, fromRect.height);

      // Require meaningful vertical overlap to avoid jumping between separate rows
      if (overlapHeight < math.min(8.0, minHeight * 0.35)) continue;

      // 3. Find closest neighbor in that direction
      final distance = isLeft
          ? (fromRect.center.dx - rect.center.dx)
          : (rect.center.dx - fromRect.center.dx);

      if (distance < bestDistance) {
        bestDistance = distance;
        bestCandidate = node;
      }
    }

    return bestCandidate;
  }

  bool _moveVertical(FocusNode from, TraversalDirection direction) {
    // 1. Geometric vertical candidate search takes priority (bridges horizontal
    // scrollviews, M3E button groups, and adjacent rows accurately).
    final target = _findVerticalCandidate(from, direction);
    if (target != null) {
      target.requestFocus();
      return true;
    }
    // 2. Framework fallbacks
    if (from.focusInDirection(direction)) {
      return true;
    }
    if (AppDpadNavigator.moveFocus(from, direction)) {
      return true;
    }
    return false;
  }

  FocusNode? _findVerticalCandidate(
    FocusNode from,
    TraversalDirection direction,
  ) {
    final fromRect = _rectOf(from);
    if (fromRect == null) return null;

    final scope = widget.focusScopeNode ?? from.nearestScope;
    if (scope == null) return null;

    final isUp = direction == TraversalDirection.up;
    FocusNode? bestCandidate;
    double bestDistance = double.infinity;

    for (final node in scope.traversalDescendants) {
      if (node == from || node.hasFocus) continue;
      if (node is FocusScopeNode) continue;
      if (!node.canRequestFocus || node.skipTraversal) continue;
      if (!_canReceiveFocus(node)) continue;

      // Cannot navigate to ancestor or descendant
      if (from.ancestors.contains(node) || node.ancestors.contains(from)) continue;

      // Two elements inside the same M3EButtonGroup are horizontal siblings, never vertical candidates
      if (_isButtonGroup(from) && _isButtonGroup(node)) continue;

      final rect = _rectOf(node);
      if (rect == null) continue;

      // Ensure candidate is strictly in the requested vertical direction,
      // excluding sibling items in the same row (which have dy delta ~ 0).
      if (isUp) {
        if (rect.center.dy >= fromRect.center.dy - 12.0) continue;
      } else {
        if (rect.center.dy <= fromRect.center.dy + 12.0) continue;
      }

      final dy = (rect.center.dy - fromRect.center.dy).abs();
      final dx = (rect.center.dx - fromRect.center.dx).abs();
      // Heavily weigh vertical distance so the immediately adjacent row ALWAYS wins
      final distance = dy * 100.0 + dx;
      if (distance < bestDistance) {
        bestDistance = distance;
        bestCandidate = node;
      }
    }

    return bestCandidate;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final isLeft = key == LogicalKeyboardKey.arrowLeft;
    final isRight = key == LogicalKeyboardKey.arrowRight;
    final isUp = key == LogicalKeyboardKey.arrowUp;
    final isDown = key == LogicalKeyboardKey.arrowDown;

    if (!isLeft && !isRight && !isUp && !isDown) {
      return KeyEventResult.ignored;
    }

    final primary = FocusManager.instance.primaryFocus;

    // 1. M3EButtonGroup: overcomes the Tab-only traversal policy of M3E buttons.
    if (_isButtonGroup(primary)) {
      if (isLeft) {
        final target = _findHorizontalCandidate(primary!, TraversalDirection.left);
        if (target != null) {
          target.requestFocus();
          return KeyEventResult.handled;
        }
        final exit = widget.onExitToSidebar;
        if (exit != null) {
          exit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }
      if (isRight) {
        final target = _findHorizontalCandidate(primary!, TraversalDirection.right);
        if (target != null) {
          target.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.handled;
      }
      if (isDown) {
        _moveVertical(primary!, TraversalDirection.down);
        return KeyEventResult.handled;
      }
      if (isUp) {
        _moveVertical(primary!, TraversalDirection.up);
        return KeyEventResult.handled;
      }
    }

    // 2. Sliders: Left/Right adjust value (never exit to sidebar); Up/Down navigate out vertically.
    if (_isSlider(primary)) {
      if (isLeft || isRight) {
        return KeyEventResult.ignored;
      }
      if (isUp) {
        _moveVertical(primary!, TraversalDirection.up);
        return KeyEventResult.handled;
      }
      if (isDown) {
        _moveVertical(primary!, TraversalDirection.down);
        return KeyEventResult.handled;
      }
    }

    // 3. Text inputs: keep arrow keys for cursor positioning.
    if (_isTextInput(primary)) {
      return KeyEventResult.ignored;
    }

    // 4. Left navigation: move to left sibling if any; exit to sidebar ONLY when at the leftmost edge.
    if (isLeft) {
      if (primary != null && primary != node) {
        final target = _findHorizontalCandidate(primary, TraversalDirection.left);
        if (target != null) {
          target.requestFocus();
          return KeyEventResult.handled;
        }
      }

      final exit = widget.onExitToSidebar;
      if (exit != null) {
        exit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    // 5. Right navigation: move to right sibling if any.
    if (isRight) {
      if (primary != null && primary != node) {
        final target = _findHorizontalCandidate(primary, TraversalDirection.right);
        if (target != null) {
          target.requestFocus();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    // 6. Global Vertical Navigation (Up / Down):
    // Reliably connects adjacent rows, bridges horizontal scrollviews and M3E button groups.
    if (isUp) {
      if (primary != null && primary != node) {
        if (_moveVertical(primary, TraversalDirection.up)) {
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    if (isDown) {
      if (primary != null && primary != node) {
        if (_moveVertical(primary, TraversalDirection.down)) {
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      node: widget.focusScopeNode,
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: _handleKeyEvent,
        // Wraps the options panel with directional navigation mode so that all
        // child Sliders natively ignore Up/Down and reserve them for focus traversal.
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            navigationMode: NavigationMode.directional,
          ),
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
      ),
    );
  }
}
