import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

/// Custom [ScrollPositionWithSingleContext] that delivers a browser-grade
/// smooth scrolling experience (inspired by Chromium, Firefox, and Lenis).
///
/// Key advantages:
/// 1. **Single Ticker with Exponential Smoothing**: Runs a continuous per-frame
///    Ticker with frame-rate independent exponential decay (`1 - exp(-k * dt)`),
///    eliminating the jerky animation-restart hitches of repeated `animateTo()` calls.
/// 2. **Hardware Bounce Filter**: Absorbs and discards accidental micro-reverse ticks
///    caused by worn/faulty mouse wheel mechanical encoders, preventing jitter.
/// 3. **Trackpad & Touchpad Heuristic**: Sub-4px continuous deltas bypass the ticker
///    and apply direct 1:1 displacement instantly, ensuring laptop trackpads feel
///    completely natural, crisp, and lag-free.
/// 4. **Direct Interruption**: User touch drags and scrollbar manipulations
///    immediately take direct 1:1 control with zero resistance.
class SmoothScrollPosition extends ScrollPositionWithSingleContext {
  final double smoothingFactor;
  final double speedMultiplier;

  SmoothScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
    this.smoothingFactor = 14.0,
    this.speedMultiplier = 1.0,
  }) : _futurePixels = initialPixels ?? 0.0;

  late double _futurePixels;
  Ticker? _ticker;
  Duration _lastElapsed = Duration.zero;

  void _onTick(Duration elapsed) {
    if (!hasContentDimensions) {
      _stopTicker();
      return;
    }

    final double dt = _lastElapsed == Duration.zero
        ? 1.0 / 60.0
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    // Guard against abnormal frame steps (e.g. window pause or debugger)
    if (dt <= 0 || dt > 0.1) return;

    final double current = pixels;
    final double target = _futurePixels;
    final double diff = target - current;

    if (diff.abs() < 0.5) {
      if (current != target) {
        forcePixels(target);
        didUpdateScrollPositionBy(target - current);
      }
      _stopTicker();
      didEndScroll();
      goBallistic(0.0);
      return;
    }

    // Frame-rate independent exponential smoothing
    final double factor = 1.0 - math.exp(-smoothingFactor * dt);
    final double next = (current + diff * factor).clamp(minScrollExtent, maxScrollExtent);
    final double step = next - current;

    if (step.abs() > 0.001) {
      forcePixels(next);
      didUpdateScrollPositionBy(step);
    }
  }

  void _ensureTickerRunning() {
    _ticker ??= context.vsync.createTicker(_onTick);
    if (!_ticker!.isActive) {
      _lastElapsed = Duration.zero;
      isScrollingNotifier.value = true;
      didStartScroll();
      _ticker!.start();
    }
  }

  void _stopTicker() {
    if (_ticker != null && _ticker!.isActive) {
      _ticker!.stop();
      isScrollingNotifier.value = false;
    }
  }

  @override
  void pointerScroll(double delta) {
    if (delta == 0.0) {
      goBallistic(0.0);
      return;
    }

    // 1. Trackpad & Touchpad Heuristic:
    // Precision touchpads emit continuous micro-deltas (< 4px per event).
    // Apply immediate 1:1 direct scrolling to keep trackpads 100% responsive and natural.
    if (delta.abs() < 4.0) {
      _stopTicker();
      final double targetPixels = (pixels + delta).clamp(minScrollExtent, maxScrollExtent);
      if (targetPixels != pixels) {
        final double oldPixels = pixels;
        forcePixels(targetPixels);
        didStartScroll();
        didUpdateScrollPositionBy(targetPixels - oldPixels);
        didEndScroll();
      }
      _futurePixels = pixels;
      return;
    }

    // 2. Hardware Mouse Wheel Encoder Bounce Filter:
    // Worn or loose mouse wheels often bounce and emit a momentary reverse tick (< 35px).
    // If the scroll is already moving in one direction, ignore the hardware bounce glitch.
    final double effectiveDelta = delta * speedMultiplier;
    final bool isMoving = _ticker != null && _ticker!.isActive;
    if (isMoving) {
      final double currentVel = _futurePixels - pixels;
      final bool oppositeDirection = (currentVel * effectiveDelta) < 0;
      if (oppositeDirection && effectiveDelta.abs() < 35.0) {
        // Discard hardware glitch
        return;
      }
    }

    // 3. Fluid Momentum Accumulation:
    double base = pixels;
    if (isMoving) {
      final bool sameDirection = (_futurePixels - pixels) * effectiveDelta > 0;
      if (sameDirection) {
        base = _futurePixels;
      }
    }

    _futurePixels = (base + effectiveDelta).clamp(minScrollExtent, maxScrollExtent);
    updateUserScrollDirection(-effectiveDelta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse);
    _ensureTickerRunning();
  }

  @override
  void applyUserOffset(double delta) {
    _stopTicker();
    _futurePixels = pixels;
    super.applyUserOffset(delta);
  }

  @override
  void jumpTo(double value) {
    _stopTicker();
    _futurePixels = value;
    super.jumpTo(value);
  }

  @override
  void dispose() {
    _stopTicker();
    _ticker?.dispose();
    _ticker = null;
    super.dispose();
  }
}

/// A drop-in replacement for [ScrollController] that provides smooth, fluid,
/// browser-grade mouse wheel scrolling with hardware bounce filtering.
class SmoothScrollController extends ScrollController {
  final double smoothingFactor;
  final double speedMultiplier;

  SmoothScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.smoothingFactor = 14.0,
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
      smoothingFactor: smoothingFactor,
      speedMultiplier: speedMultiplier,
    );
  }
}

/// A drop-in replacement for [TrackingScrollController] that provides smooth,
/// browser-grade mouse wheel scrolling with hardware bounce filtering.
class SmoothTrackingScrollController extends TrackingScrollController {
  final double smoothingFactor;
  final double speedMultiplier;

  SmoothTrackingScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
    super.onAttach,
    super.onDetach,
    this.smoothingFactor = 14.0,
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
      smoothingFactor: smoothingFactor,
      speedMultiplier: speedMultiplier,
    );
  }
}

/// A lightweight, Riverpod-friendly builder widget mirroring dyn_mouse_scroll
/// that provides a smooth-scrolling [ScrollController] to its children.
class DynMouseScroll extends StatefulWidget {
  final Widget Function(BuildContext context, ScrollController controller) builder;
  final double smoothingFactor;
  final double speedMultiplier;
  final ScrollController? controller;

  const DynMouseScroll({
    super.key,
    required this.builder,
    this.smoothingFactor = 14.0,
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
        smoothingFactor: widget.smoothingFactor,
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
        smoothingFactor: widget.smoothingFactor,
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
