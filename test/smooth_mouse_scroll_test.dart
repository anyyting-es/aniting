import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

void main() {
  group('SmoothScrollController Tests', () {
    testWidgets('Interpolates mouse wheel scrolling smoothly', (tester) async {
      final controller = SmoothScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (context, i) => SizedBox(
                height: 60,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, 0.0);

      // Single mouse wheel scroll event (+100px)
      final center = tester.getCenter(find.text('Item 0'));
      final pointerSignal = PointerScrollEvent(
        position: center,
        scrollDelta: const Offset(0, 100),
        kind: PointerDeviceKind.mouse,
      );

      tester.binding.handlePointerEvent(pointerSignal);

      // Immediately after event, it should not have jumped to 100 yet
      expect(controller.offset, 0.0);

      // Step forward: first pump initiates the ticker, second advances animation
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 60));
      expect(controller.offset, greaterThan(20.0));
      expect(controller.offset, lessThan(100.0));

      // Settle animation
      await tester.pumpAndSettle();
      expect(controller.offset, 100.0);
    });

    testWidgets('Accumulates target when scrolled repeatedly in same direction', (tester) async {
      final controller = SmoothScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (context, i) => SizedBox(
                height: 60,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Item 0'));

      // Event 1 (+100px)
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Event 2 (+100px) while first is still moving
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));

      // Settle animation
      await tester.pumpAndSettle();
      expect(controller.offset, 200.0);
    });

    testWidgets('Reverses direction smoothly without lagging', (tester) async {
      final controller = SmoothScrollController(initialScrollOffset: 300);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (context, i) => SizedBox(
                height: 60,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.text('Item 5'));

      // Scroll up (-100px)
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -100),
          kind: PointerDeviceKind.mouse,
        ),
      );

      await tester.pumpAndSettle();
      expect(controller.offset, 200.0);
    });

    testWidgets('Touch drag still works smoothly and directly without interference', (tester) async {
      final controller = SmoothScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 50,
              itemBuilder: (context, i) => SizedBox(
                height: 60,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      // Drag up with touch
      await tester.drag(find.text('Item 0'), const Offset(0, -150), kind: PointerDeviceKind.touch);
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(50.0));
    });

    testWidgets('DynMouseScroll builder widget provides smooth mouse scrolling', (tester) async {
      late ScrollController capturedController;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DynMouseScroll(
              builder: (context, controller) {
                capturedController = controller;
                return ListView.builder(
                  controller: controller,
                  itemCount: 50,
                  itemBuilder: (context, i) => SizedBox(
                    height: 60,
                    child: Text('DynItem $i'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(capturedController.offset, 0.0);

      final center = tester.getCenter(find.text('DynItem 0'));
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );

      // Step forward
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 60));
      expect(capturedController.offset, greaterThan(20.0));
      expect(capturedController.offset, lessThan(100.0));

      await tester.pumpAndSettle();
      expect(capturedController.offset, 100.0);
    });
  });
}
