import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:seanime_app/presentation/widgets/snapping_scroll_physics.dart';

void main() {
  group('SnappingListScrollPhysics Tests', () {
    const itemExtent = 300.0;
    const physics = SnappingListScrollPhysics(
      itemExtent: itemExtent,
      parent: BouncingScrollPhysics(),
    );

    test('gentle forward swipe locks to the next card', () {
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 50,
        viewportDimension: 360,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final sim = physics.createBallisticSimulation(position, 200);
      expect(sim, isNotNull);
      expect(sim is ScrollSpringSimulation, isTrue);
      final springSim = sim as ScrollSpringSimulation;
      // Should target next item (300.0)
      expect(springSim.x(10.0), closeTo(300.0, 1.0));
    });

    test('gentle backward swipe locks to the previous card', () {
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 250,
        viewportDimension: 360,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final sim = physics.createBallisticSimulation(position, -200);
      expect(sim, isNotNull);
      final springSim = sim as ScrollSpringSimulation;
      // Should target previous item (0.0)
      expect(springSim.x(10.0), closeTo(0.0, 1.0));
    });

    test('high velocity fling travels multiple cards fluidly and locks to exact item', () {
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 0,
        viewportDimension: 360,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      // Fast fling
      final sim = physics.createBallisticSimulation(position, 2500);
      expect(sim, isNotNull);
      final springSim = sim as ScrollSpringSimulation;
      // 2500 * 0.24 = 600 -> round(600 / 300) = 2 items -> 600.0
      expect(springSim.x(10.0), closeTo(600.0, 1.0));
    });

    test('stationary release locks to nearest card', () {
      final position = FixedScrollMetrics(
        minScrollExtent: 0,
        maxScrollExtent: 3000,
        pixels: 160, // slightly more than half of 300
        viewportDimension: 360,
        axisDirection: AxisDirection.right,
        devicePixelRatio: 1.0,
      );

      final sim = physics.createBallisticSimulation(position, 0);
      expect(sim, isNotNull);
      final springSim = sim as ScrollSpringSimulation;
      expect(springSim.x(10.0), closeTo(300.0, 1.0));
    });
  });
}
