import 'package:flutter/material.dart';

/// Geometry-based directional focus navigation for D-pad / keyboard users.
///
/// Flutter's built-in directional traversal is intentionally conservative:
/// it keeps focus inside the current scrollable and inside the nearest
/// [FocusTraversalGroup]. That works for a single list, but it makes it
/// impossible to leave a horizontal carousel towards the sidebar, or to move
/// between rows that live in different traversal groups.
///
/// This navigator is used as a fallback when the built-in traversal found no
/// target, and directly by widgets that own a separate [FocusScope] (such as
/// the desktop sidebar). It looks at every focusable widget of the current
/// route and chooses the closest one in the requested direction, so D-pad
/// navigation never gets trapped in a row or a section.
class AppDpadNavigator {
  AppDpadNavigator._();

  static const double _directionEpsilon = 1.0;
  static const double _bandOverlap = 2.0;

  /// Moves the primary focus from [from] towards [direction].
  ///
  /// Returns true when a focus request was issued. Note that Flutter applies
  /// the focus change in a microtask, so [FocusNode.hasFocus] must not be read
  /// synchronously here.
  static bool moveFocus(FocusNode from, TraversalDirection direction) {
    final fromRect = _rectOf(from);
    if (fromRect == null || !isInCurrentRoute(from)) {
      // The focused node may belong to a covered route after a transition.
      // Recover by focusing the first usable widget of the current route.
      return focusFirst();
    }

    final candidates = _sortedCandidates(from, fromRect, direction);
    for (final candidate in candidates) {
      if (!canReceiveFocus(candidate)) continue;
      _requestFocus(candidate, direction);
      return true;
    }
    return false;
  }

  /// Whether [node] is attached to the currently visible route.
  static bool isInCurrentRoute(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return false;
    try {
      final route = ModalRoute.of(context);
      return route == null || route.isCurrent;
    } catch (_) {
      return false;
    }
  }

  /// Whether [node] can actually receive focus.
  ///
  /// [FocusNode.canRequestFocus] only reflects the node itself; an ancestor
  /// [ExcludeFocus] can still make the whole subtree unreachable.
  static bool canReceiveFocus(FocusNode node) {
    if (!node.canRequestFocus || node.skipTraversal) return false;
    final scope = node.enclosingScope;
    if (scope != null && !scope.canRequestFocus) return false;
    for (final ancestor in node.ancestors) {
      if (!ancestor.descendantsAreFocusable) return false;
    }
    return true;
  }

  /// Focuses the first visible focusable widget of the current route.
  ///
  /// Used when the user starts navigating with a D-pad before anything has
  /// received focus (for example on TV / gamepad startup).
  static bool focusFirst() {
    final root = FocusManager.instance.rootScope;
    final candidates = root.traversalDescendants.where((node) {
      if (node is FocusScopeNode) return false;
      if (!_isUsable(node)) return false;
      final context = node.context;
      if (context == null) return false;
      final route = ModalRoute.of(context);
      return route == null || route.isCurrent;
    }).toList();
    if (candidates.isEmpty) return false;

    candidates.sort((a, b) {
      final byY = a.rect.top.compareTo(b.rect.top);
      if (byY != 0) return byY;
      return a.rect.left.compareTo(b.rect.left);
    });

    _requestFocus(candidates.first, TraversalDirection.down);
    return true;
  }

  static List<FocusNode> _sortedCandidates(
    FocusNode from,
    Rect fromRect,
    TraversalDirection direction,
  ) {
    final inBand = <_ScoredNode>[];
    final outOfBand = <_ScoredNode>[];

    for (final node in _collectCandidates(from)) {
      final rect = _rectOf(node);
      if (rect == null) continue;
      if (!_isInDirection(fromRect, rect, direction)) continue;

      final scored = _ScoredNode(node, _score(fromRect, rect, direction));
      if (_overlapsBand(fromRect, rect, direction)) {
        inBand.add(scored);
      } else {
        outOfBand.add(scored);
      }
    }

    inBand.sort((a, b) => a.score.compareTo(b.score));
    outOfBand.sort((a, b) => a.score.compareTo(b.score));
    // Prefer targets aligned with the current row/column, but keep the rest as
    // fallbacks in case the aligned ones cannot receive focus.
    return <FocusNode>[
      ...inBand.map((entry) => entry.node),
      ...outOfBand.map((entry) => entry.node),
    ];
  }

  /// Collects focusable nodes from the current focus scope and its enclosing
  /// scopes, stopping at the current route boundary.
  ///
  /// This is what allows the sidebar (its own [FocusScope]) and the content
  /// area to see each other during directional navigation.
  static List<FocusNode> _collectCandidates(FocusNode from) {
    final fromContext = from.context;
    final route = fromContext != null ? ModalRoute.of(fromContext) : null;

    final scopes = <FocusScopeNode>[];
    FocusScopeNode? scope = from.nearestScope;
    while (scope != null) {
      if (route != null && scope.context != null) {
        final scopeRoute = ModalRoute.of(scope.context!);
        if (scopeRoute != null && scopeRoute != route) break;
      }
      scopes.add(scope);

      final parent = scope.enclosingScope;
      if (parent == null || parent == scope) break;

      if (route != null && parent.context != null) {
        final parentRoute = ModalRoute.of(parent.context!);
        if (parentRoute == null || parentRoute != route) break;
      }
      scope = parent;
    }

    final result = <FocusNode>[];
    final seen = <FocusNode>{};
    for (final currentScope in scopes) {
      for (final node in currentScope.traversalDescendants) {
        if (node is FocusScopeNode) continue;
        if (!seen.add(node)) continue;
        // Skip the currently focused node and its focus ancestors.
        if (node == from || node.hasFocus) continue;
        if (!_isUsable(node)) continue;

        if (route != null && node.context != null) {
          final nodeRoute = ModalRoute.of(node.context!);
          if (nodeRoute != null && nodeRoute != route) continue;
        }
        result.add(node);
      }
    }
    return result;
  }

  static bool _isUsable(FocusNode node) {
    if (!canReceiveFocus(node)) return false;

    final context = node.context;
    if (context == null || !context.mounted) return false;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return false;
    }

    // Hidden IndexedStack pages, offstage routes and hidden Visibility
    // subtrees must never steal the D-pad focus.
    Size? screenSize;
    try {
      if (!TickerMode.of(context)) return false;
      if (!Visibility.of(context)) return false;
      screenSize = MediaQuery.maybeOf(context)?.size;
    } catch (_) {
      return false;
    }

    final rect = _rectOf(node);
    if (rect == null || rect.isEmpty) return false;

    // Ignore widgets parked outside the horizontal viewport (for example the
    // adjacent pages of a PageView). Vertically off-screen widgets are kept
    // because focusing them should scroll the feed.
    if (screenSize != null &&
        (rect.right <= 0.0 || rect.left >= screenSize.width)) {
      return false;
    }
    return true;
  }

  static Rect? _rectOf(FocusNode node) {
    final context = node.context;
    if (context == null || !context.mounted) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return null;
    }
    try {
      final rect = node.rect;
      return rect.isEmpty ? null : rect;
    } catch (_) {
      return null;
    }
  }

  static bool _isInDirection(
    Rect from,
    Rect to,
    TraversalDirection direction,
  ) {
    switch (direction) {
      case TraversalDirection.left:
        return to.center.dx < from.center.dx - _directionEpsilon;
      case TraversalDirection.right:
        return to.center.dx > from.center.dx + _directionEpsilon;
      case TraversalDirection.up:
        return to.center.dy < from.center.dy - _directionEpsilon;
      case TraversalDirection.down:
        return to.center.dy > from.center.dy + _directionEpsilon;
    }
  }

  static bool _overlapsBand(
    Rect from,
    Rect to,
    TraversalDirection direction,
  ) {
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        return to.bottom > from.top + _bandOverlap &&
            to.top < from.bottom - _bandOverlap;
      case TraversalDirection.up:
      case TraversalDirection.down:
        return to.right > from.left + _bandOverlap &&
            to.left < from.right - _bandOverlap;
    }
  }

  static double _score(
    Rect from,
    Rect to,
    TraversalDirection direction,
  ) {
    final dx = (to.center.dx - from.center.dx).abs();
    final dy = (to.center.dy - from.center.dy).abs();
    switch (direction) {
      case TraversalDirection.left:
      case TraversalDirection.right:
        return dx + dy * 2;
      case TraversalDirection.up:
      case TraversalDirection.down:
        return dy + dx * 2;
    }
  }

  static void _requestFocus(
    FocusNode node,
    TraversalDirection direction,
  ) {
    final context = node.context;
    node.requestFocus();
    if (context == null || !context.mounted) return;

    // SmoothFocusCarousel already animates both axes around the focused card.
    // Calling ensureVisible here would fight its center-locked animation.
    if (Scrollable.maybeOf(context, axis: Axis.horizontal) != null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy:
            direction == TraversalDirection.up ||
                direction == TraversalDirection.left
            ? ScrollPositionAlignmentPolicy.keepVisibleAtStart
            : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    });
  }
}

class _ScoredNode {
  const _ScoredNode(this.node, this.score);

  final FocusNode node;
  final double score;
}

/// [DirectionalFocusAction] with a global geometric fallback.
///
/// The built-in action is tried first so local widgets (menus, sliders, text
/// fields, custom traversal groups) keep their own arrow-key behavior. Only
/// when it cannot move focus do we search the whole route.
class AppDirectionalFocusAction extends DirectionalFocusAction {
  AppDirectionalFocusAction();

  @override
  void invoke(DirectionalFocusIntent intent) {
    final before = FocusManager.instance.primaryFocus;
    if (before == null || !AppDpadNavigator.isInCurrentRoute(before)) {
      AppDpadNavigator.focusFirst();
      return;
    }

    // Unlike super.invoke(), focusInDirection reports whether it actually
    // found a target. Focus changes are applied asynchronously, so we cannot
    // compare primaryFocus before/after.
    if (before.focusInDirection(intent.direction)) return;

    AppDpadNavigator.moveFocus(before, intent.direction);
  }
}
