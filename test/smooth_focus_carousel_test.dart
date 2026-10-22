import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/widgets/feed/smooth_focus_carousel.dart';

void main() {
  group('SmoothFocusCarousel Center-Locked Offset Calculations', () {
    const itemWidth = 200.0;
    const spacing = 20.0;
    const paddingLeft = 16.0;
    const viewportWidth = 800.0;
    const maxScrollExtent = 2000.0;

    test('item at index 0 stays clamped at 0.0 scroll offset', () {
      final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: 0,
        itemWidth: itemWidth,
        spacing: spacing,
        paddingLeft: paddingLeft,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScrollExtent,
      );

      // itemCenter = 16 + 100 = 116. idealScroll = 116 - 400 = -284 -> clamped to 0.0
      expect(offset, equals(0.0));
    });

    test('item at index 1 stays clamped at 0.0 scroll offset', () {
      final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: 1,
        itemWidth: itemWidth,
        spacing: spacing,
        paddingLeft: paddingLeft,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScrollExtent,
      );

      // itemLeft = 16 + 1 * 220 = 236. itemCenter = 236 + 100 = 336. idealScroll = 336 - 400 = -64 -> clamped to 0.0
      expect(offset, equals(0.0));
    });

    test('item at index 2 reaches center and initiates center-locked scrolling', () {
      final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: 2,
        itemWidth: itemWidth,
        spacing: spacing,
        paddingLeft: paddingLeft,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScrollExtent,
      );

      // itemLeft = 16 + 2 * 220 = 456. itemCenter = 556. idealScroll = 556 - 400 = 156.0
      expect(offset, equals(156.0));
      // In viewport: 556 - 156 = 400.0 (Exactly in the middle of 800.0 viewport!)
      final onScreenPos = (paddingLeft + 2 * (itemWidth + spacing) + (itemWidth / 2)) - offset;
      expect(onScreenPos, equals(viewportWidth / 2));
    });

    test('item at index 5 maintains exact center position on screen', () {
      final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: 5,
        itemWidth: itemWidth,
        spacing: spacing,
        paddingLeft: paddingLeft,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScrollExtent,
      );

      // itemLeft = 16 + 5 * 220 = 1116. itemCenter = 1216. idealScroll = 1216 - 400 = 816.0
      expect(offset, equals(816.0));
      // In viewport: 1216 - 816 = 400.0 (Still locked at the center!)
      final onScreenPos = (paddingLeft + 5 * (itemWidth + spacing) + (itemWidth / 2)) - offset;
      expect(onScreenPos, equals(viewportWidth / 2));
    });

    test('trailing items near end clamp to maxScrollExtent and allow focus to step to edge', () {
      final offset = SmoothFocusCarousel.calculateCenterLockedOffset(
        index: 15,
        itemWidth: itemWidth,
        spacing: spacing,
        paddingLeft: paddingLeft,
        viewportWidth: viewportWidth,
        maxScrollExtent: maxScrollExtent, // 2000
      );

      // itemLeft = 16 + 15 * 220 = 3316. idealScroll = 3416 - 400 = 3016 -> clamped to maxScrollExtent (2000.0)
      expect(offset, equals(maxScrollExtent));
    });
  });

  group('SmoothFocusCarousel Widget Rendering & Focus Integration', () {
    testWidgets('renders items and responds to focus changes smoothly', (tester) async {
      int focusedIndex = -1;
      final focusNodes = List.generate(10, (_) => FocusNode());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmoothFocusCarousel(
              itemCount: 10,
              itemWidth: 150,
              spacing: 10,
              height: 200,
              onFocusedIndexChanged: (i) => focusedIndex = i,
              itemBuilder: (context, index) {
                return Focus(
                  focusNode: focusNodes[index],
                  child: SizedBox(
                    width: 150,
                    height: 200,
                    child: Text('Card $index'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Card 0'), findsOneWidget);
      expect(find.text('Card 1'), findsOneWidget);

      // Focus second card via FocusNode (simulating DPAD traversal)
      focusNodes[1].requestFocus();
      await tester.pump();
      await tester.pumpAndSettle();

      expect(focusedIndex, equals(1));

      for (final node in focusNodes) {
        node.dispose();
      }
    });
  });
}
