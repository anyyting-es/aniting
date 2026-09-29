import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/app_scroll_behavior.dart';

void main() {
  group('AppScrollBehavior Tests', () {
    test('Configures dragDevices to include mouse, touch, trackpad and stylus', () {
      const behavior = AppScrollBehavior();
      final devices = behavior.dragDevices;

      expect(devices.contains(PointerDeviceKind.mouse), isTrue);
      expect(devices.contains(PointerDeviceKind.touch), isTrue);
      expect(devices.contains(PointerDeviceKind.trackpad), isTrue);
      expect(devices.contains(PointerDeviceKind.stylus), isTrue);
    });

    testWidgets('Allows dragging with mouse on vertical scrollables', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (context, i) => SizedBox(
                height: 50,
                child: Text('Item $i'),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, 0.0);

      // Drag with mouse
      await tester.drag(find.text('Item 0'), const Offset(0, -150), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(50.0));
    });

    testWidgets('Allows dragging with mouse on horizontal scrollables', (tester) async {
      final controller = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                controller: controller,
                itemCount: 40,
                itemBuilder: (context, i) => SizedBox(
                  width: 80,
                  child: Text('Card $i'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(controller.offset, 0.0);

      // Drag with mouse horizontally
      await tester.drag(find.text('Card 0'), const Offset(-150, 0), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(50.0));
    });

    testWidgets('Clicking activates onTap, while dragging scrolls without triggering onTap', (tester) async {
      final controller = ScrollController();
      int tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          scrollBehavior: const AppScrollBehavior(),
          home: Scaffold(
            body: ListView.builder(
              controller: controller,
              itemCount: 40,
              itemBuilder: (context, i) => InkWell(
                onTap: () => tappedIndex = i,
                child: SizedBox(
                  height: 60,
                  child: Text('ClickItem $i'),
                ),
              ),
            ),
          ),
        ),
      );

      // 1. Single click on ClickItem 0
      await tester.tap(find.text('ClickItem 0'));
      await tester.pumpAndSettle();
      expect(tappedIndex, 0);

      // Reset
      tappedIndex = -1;

      // 2. Drag starting on ClickItem 1
      await tester.drag(find.text('ClickItem 1'), const Offset(0, -120), kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();

      expect(tappedIndex, -1);
      expect(controller.offset, greaterThan(50.0));
    });
  });
}
