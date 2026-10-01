import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

void main() {
  group('Advanced Ticker-Based Smooth Scroll Tests', () {
    testWidgets('Glides smoothly with single-ticker exponential smoothing', (tester) async {
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
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );

      // Frame 1 (~16ms)
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.offset, greaterThan(10.0));
      expect(controller.offset, lessThan(40.0));

      // Frame 3 (~50ms)
      await tester.pump(const Duration(milliseconds: 34));
      expect(controller.offset, greaterThan(35.0));
      expect(controller.offset, lessThan(85.0));

      // Settle
      await tester.pumpAndSettle();
      expect(controller.offset, 100.0);
    });

    testWidgets('Filters out hardware mouse wheel encoder bounce glitch', (tester) async {
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

      // Forward wheel tick (+100px)
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 100),
          kind: PointerDeviceKind.mouse,
        ),
      );
      await tester.pump(const Duration(milliseconds: 16));

      // Hardware bounce: faulty wheel sends an accidental -15px reverse tick
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -15),
          kind: PointerDeviceKind.mouse,
        ),
      );

      // The glitch is filtered out: it continues smoothly toward 100px!
      await tester.pumpAndSettle();
      expect(controller.offset, 100.0);
    });

    testWidgets('Touchpad micro-deltas scroll immediately without animation lag', (tester) async {
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

      // Send trackpad micro-event (+2.5px)
      tester.binding.handlePointerEvent(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 2.5),
          kind: PointerDeviceKind.trackpad,
        ),
      );

      // It updates IMMEDIATELY without waiting for an animation cycle
      expect(controller.offset, 2.5);
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
      await tester.pump(const Duration(milliseconds: 16));
      expect(capturedController.offset, greaterThan(10.0));
      expect(capturedController.offset, lessThan(40.0));

      await tester.pumpAndSettle();
      expect(capturedController.offset, 100.0);
    });
  });
}
