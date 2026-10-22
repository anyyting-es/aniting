import 'package:flutter/widgets.dart';

/// A [ScrollPhysics] that snaps to items of fixed extent ([itemExtent]).
///
/// Provides a gentle "mini-lock" on the adjacent item for subtle swipes,
/// while allowing continuous, fluid momentum scrolling across multiple items
/// during fast flings.
class SnappingListScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const SnappingListScrollPhysics({
    required this.itemExtent,
    super.parent,
  });

  @override
  SnappingListScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingListScrollPhysics(
      itemExtent: itemExtent,
      parent: buildParent(ancestor),
    );
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    // If out of bounds (overscrolling), let parent (e.g. BouncingScrollPhysics) handle it.
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double step = itemExtent;
    if (step <= 0) return super.createBallisticSimulation(position, velocity);

    final double currentItem = position.pixels / step;
    double targetItem;

    // Subtle swipe / drag release: mini-lock to adjacent item.
    if (velocity.abs() < 650) {
      if (velocity > tolerance.velocity) {
        targetItem = currentItem.floorToDouble() + 1.0;
      } else if (velocity < -tolerance.velocity) {
        targetItem = currentItem.ceilToDouble() - 1.0;
      } else {
        targetItem = currentItem.roundToDouble();
      }
    } else {
      // Faster fling: project destination based on momentum, allowing fluid
      // multi-item scrolling, and snap neatly to the nearest card on settle.
      final double projectedPixels = position.pixels + (velocity * 0.24);
      targetItem = (projectedPixels / step).roundToDouble();

      // Ensure directional progress on fling
      if (velocity > 0 && targetItem <= currentItem) {
        targetItem = currentItem.floorToDouble() + 1.0;
      } else if (velocity < 0 && targetItem >= currentItem) {
        targetItem = currentItem.ceilToDouble() - 1.0;
      }
    }

    final double target = (targetItem * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    if ((target - position.pixels).abs() > tolerance.distance || velocity.abs() > tolerance.velocity) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }

    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
