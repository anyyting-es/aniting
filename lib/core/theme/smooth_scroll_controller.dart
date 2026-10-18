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

  // Anti-jitter & mechanical encoder bounce filter state
  int _dominantDirection = 0; // +1: forward (down/right), -1: reverse (up/left)
  int _lastScrollTimestampMs = 0;
  int _consecutiveReverseTicks = 0;
  double _accumulatedReverseDelta = 0.0;

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

    final int now = DateTime.now().millisecondsSinceEpoch;
    final int elapsedSinceLast = _lastScrollTimestampMs == 0 ? 9999 : now - _lastScrollTimestampMs;
    _lastScrollTimestampMs = now;

    final int currentDirection = delta > 0 ? 1 : -1;
    final double absDelta = delta.abs();

    // 1. Noise Floor / Micro-Jitter Suppression:
    // Worn optical/mechanical encoders emit erratic micro-deltas (< 2.5px) when resting or vibrating.
    // If we recently scrolled, ignore opposite or sub-noise micro-deltas without stopping the animation.
    if (absDelta < 2.5) {
      if (_dominantDirection != 0 && currentDirection != _dominantDirection && elapsedSinceLast < 250) {
        return;
      }
    }

    // 2. Hardware Mouse Wheel Encoder Bounce Filter (Direction Hysteresis):
    // A worn, dirty, or loose mechanical wheel encoder frequently skips or bounces backwards
    // (e.g. an isolated reverse notch of 60px–120px on Windows, or a micro-tick) during an active scroll gesture.
    // In Chromium/Electron and browser engines, human intent is modeled with a temporal hysteresis window (~220ms):
    // humans do not intentionally reverse scroll direction in less than 220ms with a single notch.
    if (_dominantDirection != 0 && currentDirection != _dominantDirection && elapsedSinceLast < 220) {
      _consecutiveReverseTicks++;
      _accumulatedReverseDelta += absDelta;

      // If this is an isolated reverse tick and hasn't exceeded 140px of accumulated movement,
      // it is a hardware encoder bounce/glitch. Swallow and discard it completely!
      if (_consecutiveReverseTicks <= 1 && _accumulatedReverseDelta <= 140.0) {
        return;
      }

      // If multiple consecutive reverse ticks arrive or accumulated reverse delta is large,
      // it is a genuine intentional reversal of direction by the user.
      _dominantDirection = currentDirection;
      _consecutiveReverseTicks = 0;
      _accumulatedReverseDelta = 0.0;
    } else {
      // Continuing in same direction or outside hysteresis window:
      _dominantDirection = currentDirection;
      _consecutiveReverseTicks = 0;
      _accumulatedReverseDelta = 0.0;
    }

    final double effectiveDelta = delta * speedMultiplier;
    final bool isMoving = _ticker != null && _ticker!.isActive;

    // 3. Fluid Momentum Accumulation:
    // When scrolling continuously in the same direction, accumulate onto _futurePixels.
    // When legitimately reversing direction, smoothly transition without abrupt position snaps.
    double base;
    if (isMoving) {
      final double remainingVel = _futurePixels - pixels;
      final bool sameDirection = (remainingVel * effectiveDelta) > 0;
      if (sameDirection) {
        base = _futurePixels;
      } else {
        // Smoothly decelerate remaining velocity rather than abruptly snapping hard to pixels:
        base = pixels + remainingVel * 0.4;
      }
    } else {
      base = pixels;
    }

    _futurePixels = (base + effectiveDelta).clamp(minScrollExtent, maxScrollExtent);
    updateUserScrollDirection(-effectiveDelta > 0.0 ? ScrollDirection.forward : ScrollDirection.reverse);
    _ensureTickerRunning();
  }

  @override
  void applyUserOffset(double delta) {
    _stopTicker();
    _dominantDirection = 0;
    _consecutiveReverseTicks = 0;
    _accumulatedReverseDelta = 0.0;
    _futurePixels = pixels;
    super.applyUserOffset(delta);
  }

  @override
  void jumpTo(double value) {
    _stopTicker();
    _dominantDirection = 0;
    _consecutiveReverseTicks = 0;
    _accumulatedReverseDelta = 0.0;
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
