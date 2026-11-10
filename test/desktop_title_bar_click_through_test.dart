import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/desktop_title_bar.dart';
import 'package:window_manager/window_manager.dart';

class _TestVideoPlayerActiveNotifier extends VideoPlayerActiveNotifier {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'DesktopTitleBar does not render logo/title and allows click-through on left in player mode',
      (tester) async {
    bool underlyingButtonClicked = false;

    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isVideoPlayerActiveProvider
              .overrideWith(_TestVideoPlayerActiveNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                // Layer 0: Page underneath (e.g. Player page header with back button)
                Positioned(
                  top: 0,
                  left: 80,
                  child: IconButton(
                    key: const ValueKey('underlying_back_button'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      underlyingButtonClicked = true;
                    },
                  ),
                ),
                // Layer 1: DesktopTitleBar positioned on top
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: DesktopTitleBar(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify logo and 'Aniting' are NOT rendered in the title bar
    expect(find.text('Aniting'), findsNothing);

    // Click the underlying back button at (x: 100, y: 15)
    // The titlebar must ignore clicks in this left clearance zone and hit the button
    await tester.tap(find.byKey(const ValueKey('underlying_back_button')));
    await tester.pumpAndSettle();

    expect(underlyingButtonClicked, isTrue);
  });

  testWidgets(
      'caption controls come back after native fullscreen is exited',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) {
              return Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      key: const ValueKey('enter_fullscreen'),
                      onPressed: () => ref
                          .read(desktopNativeFullscreenProvider.notifier)
                          .setFullscreen(true),
                      child: const Text('enter'),
                    ),
                    TextButton(
                      key: const ValueKey('exit_fullscreen'),
                      onPressed: () => ref
                          .read(desktopNativeFullscreenProvider.notifier)
                          .setFullscreen(false),
                      child: const Text('exit'),
                    ),
                    const SizedBox(
                      height: 40,
                      child: DesktopTitleBar(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(DragToMoveArea), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('enter_fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byType(DragToMoveArea), findsNothing);

    await tester.tap(find.byKey(const ValueKey('exit_fullscreen')));
    await tester.pumpAndSettle();
    expect(find.byType(DragToMoveArea), findsOneWidget);
  });
}
