import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/presentation/widgets/player/controls/volume_slider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VolumeSlider Desktop Tests', () {
    testWidgets('VolumeSlider renders mobile icon button when isDesktop is false', (tester) async {
      double currentVolume = 75.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VolumeSlider(
                volume: currentVolume,
                onVolumeChanged: (v) => currentVolume = v,
                isDesktopOverride: false,
              ),
            ),
          ),
        ),
      );

      // Finds the mobile icon button
      expect(find.byType(IconButton), findsOneWidget);

      // Tapping toggles mute
      await tester.tap(find.byType(IconButton));
      expect(currentVolume, 0.0);
    });

    testWidgets('VolumeSlider opens vertical popup on hover and triggers onHoverChanged(true)', (tester) async {
      double currentVolume = 50.0;
      bool isHovered = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: VolumeSlider(
                  volume: currentVolume,
                  onVolumeChanged: (v) => currentVolume = v,
                  isDesktopOverride: true,
                  onHoverChanged: (val) => isHovered = val,
                ),
              ),
            ),
          ),
        ),
      );

      // Initially popup is not open (no volume text)
      expect(find.text('50'), findsNothing);
      expect(isHovered, isFalse);

      // Hover over volume button
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer(location: Offset.zero);
      addTearDown(gesture.removePointer);

      final center = tester.getCenter(find.byType(VolumeSlider));
      await gesture.moveTo(center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Popover is now showing with volume number
      expect(find.text('50'), findsOneWidget);
      expect(isHovered, isTrue);

      // Moving mouse away triggers grace period then closes
      await gesture.moveTo(const Offset(900, 900));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(isHovered, isFalse);
    });

    testWidgets('VolumeSlider handles mouse wheel scroll signal directly on target', (tester) async {
      double currentVolume = 50.0;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    return VolumeSlider(
                      volume: currentVolume,
                      onVolumeChanged: (v) {
                        setState(() {
                          currentVolume = v;
                        });
                      },
                      isDesktopOverride: true,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      final center = tester.getCenter(find.byType(VolumeSlider));

      // Scroll up (negative dy) should increase volume
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, -20),
        ),
      );
      await tester.pump();

      expect(currentVolume, 55.0);

      // Scroll down (positive dy) should decrease volume
      await tester.sendEventToBinding(
        PointerScrollEvent(
          position: center,
          scrollDelta: const Offset(0, 20),
        ),
      );
      await tester.pump();

      expect(currentVolume, 50.0);
    });
  });
}
