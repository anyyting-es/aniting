import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Custom [ScrollPositionWithSingleContext] that intercepts discrete mouse wheel
/// pointer scroll events and smoothly interpolates towards the target offset
/// using an ease-out easing curve and momentum accumulation.
///
/// Native touch drags, stylus input, and trackpad gestures are untouched and
/// retain their direct 1:1 response.
class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  final Duration duration;
  final Curve curve;
  final double speedMultiplier;

  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.speedMultiplier = 1.0,
  });

  double? _targetPixels;

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }

    final double effectiveDelta = delta * speedMultiplier;
    final double currentPixels = pixels;

    double base = currentPixels;
    if (_targetPixels != null) {
      // If moving in the same direction, accumulate momentum
      final bool sameDirection = (_targetPixels! - currentPixels) * effectiveDelta > 0;
      if (sameDirection) {
        base = _targetPixels!;
      }
    }

    final double target = (base + effectiveDelta).clamp(
      math.min(minScrollExtent, maxScrollExtent),
      math.max(minScrollExtent, maxScrollExtent),
    );

    // If already at boundary, do nothing
    if (target == currentPixels && _targetPixels == null) {
      return;
    }

    _targetPixels = target;

    animateTo(
      target,
      duration: duration,
      curve: curve,
    ).whenComplete(() {
      if (_targetPixels == target) {
        _targetPixels = null;
      }
    });
  }

  @override
  void applyUserOffset(double delta) {
    // Immediate cancellation of smooth animation upon user touch/drag
    _targetPixels = null;
    super.applyUserOffset(delta);
  }

  @override
  void jumpTo(double value) {
    _targetPixels = null;
    super.jumpTo(value);
  }
}

/// A drop-in replacement for [ScrollController] that provides smooth, fluid
/// mouse wheel scrolling across desktop and web platforms.
class SmoothScrollController extends ScrollController {
  final Duration duration;
  final Curve curve;
  final double speedMultiplier;

  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.speedMultiplier = 1.0,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      duration: duration,
      curve: curve,
      speedMultiplier: speedMultiplier,
    );
  }
}

/// A drop-in replacement for [TrackingScrollController] that provides smooth
/// mouse wheel scrolling across desktop and web platforms.
class SmoothTrackingScrollController extends TrackingScrollController {
  final Duration duration;
  final Curve curve;
  final double speedMultiplier;

  SmoothTrackingScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.speedMultiplier = 1.0,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return SmoothScrollPosition(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
      duration: duration,
      curve: curve,
      speedMultiplier: speedMultiplier,
    );
  }
}

/// A lightweight, Riverpod-friendly builder widget mirroring dyn_mouse_scroll
/// that provides a smooth-scrolling [ScrollController] to its children.
class DynMouseScroll extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final Duration duration;
  final Curve curve;
  final double speedMultiplier;
  final ScrollController? controller;

  const DynMouseScroll({
    super.key,
    required this.builder,
    this.duration = const Duration(milliseconds: 220),
    this.curve = Curves.easeOutCubic,
    this.speedMultiplier = 1.0,
    this.controller,
  });

  @override
  State<DynMouseScroll> createState() => _DynMouseScrollState();
}

class _DynMouseScrollState extends State<DynMouseScroll> {
  ScrollController? _internalController;

  ScrollController get _effectiveController => widget.controller ?? _internalController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = SmoothScrollController(
        duration: widget.duration,
        curve: widget.curve,
        speedMultiplier: widget.speedMultiplier,
      );
    }
  }

  @override
  void didUpdateWidget(DynMouseScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != null && _internalController != null) {
      _internalController?.dispose();
      _internalController = null;
    } else if (widget.controller == null && _internalController == null) {
      _internalController = SmoothScrollController(
        duration: widget.duration,
        curve: widget.curve,
        speedMultiplier: widget.speedMultiplier,
      );
    }
  }

  @override
  void dispose() {
    _internalController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _effectiveController);
  }
}
