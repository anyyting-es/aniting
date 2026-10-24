import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/presentation/widgets/dpad_navigation_scope.dart';
import 'package:seanime_app/presentation/widgets/feed/smooth_focus_carousel.dart';

void main() {
  setUp(() {
    AppFocusCoordinator.inputMode.value = AppInputMode.dpad;
    AppFocusCoordinator.lastFocusedNode = null;
    AppFocusCoordinator.lastHoveredNode = null;
  });

  testWidgets(
    'left arrow escapes a horizontal carousel towards the sidebar',
    (tester) async {
      final sidebarNode = FocusNode(debugLabel: 'sidebar');
      final itemNode = FocusNode(debugLabel: 'carousel-item');
      addTearDown(sidebarNode.dispose);
      addTearDown(itemNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: DpadNavigationScope(
            child: Scaffold(
              body: Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: FocusScope(
                      child: FocusTraversalGroup(
                        policy: WidgetOrderTraversalPolicy(),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Focus(
                            focusNode: sidebarNode,
                            child: const SizedBox(
                              width: 48,
                              height: 48,
                              child: Text('sidebar'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Focus(
                          focusNode: itemNode,
                          child: const SizedBox(
                            width: 200,
                            height: 120,
                            child: Text('card'),
                          ),
                        ),
                        const SizedBox(width: 200, height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      itemNode.requestFocus();
      await tester.pump();
      expect(itemNode.hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pumpAndSettle();

      expect(sidebarNode.hasPrimaryFocus, isTrue);

      // And back into the content area from the sidebar's own FocusScope.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();

      expect(itemNode.hasPrimaryFocus, isTrue);
    },
  );

  testWidgets(
    'vertical carousel navigation preserves the column and skips hidden rows',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firstRow = List.generate(3, (i) => FocusNode(debugLabel: 'first-$i'));
      final hiddenRow = List.generate(3, (i) => FocusNode(debugLabel: 'hidden-$i'));
      final lastRow = List.generate(3, (i) => FocusNode(debugLabel: 'last-$i'));
      for (final node in [...firstRow, ...hiddenRow, ...lastRow]) {
        addTearDown(node.dispose);
      }

      Widget buildRow(List<FocusNode> nodes) {
        return SmoothFocusCarousel(
          itemCount: nodes.length,
          itemWidth: 100,
          spacing: 10,
          height: 140,
          itemBuilder: (context, index) {
            return Focus(
              focusNode: nodes[index],
              child: const SizedBox(width: 100, height: 140),
            );
          },
        );
      }

      await tester.pumpWidget(
        MaterialApp(
          home: DpadNavigationScope(
            child: Scaffold(
              body: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: buildRow(firstRow)),
                  SliverToBoxAdapter(
                    child: Visibility(
                      visible: false,
                      maintainState: true,
                      child: buildRow(hiddenRow),
                    ),
                  ),
                  SliverToBoxAdapter(child: buildRow(lastRow)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      firstRow[1].requestFocus();
      await tester.pump();
      expect(firstRow[1].hasPrimaryFocus, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pumpAndSettle();

      // Same column in the next *visible* row, never the hidden one.
      expect(lastRow[1].hasPrimaryFocus, isTrue);
      expect(hiddenRow.any((node) => node.hasFocus), isFalse);
    },
  );

  testWidgets('dpad does not keep stealing focus from the hovered card', (
    tester,
  ) async {
    final hovered = FocusNode(debugLabel: 'hovered');
    final current = FocusNode(debugLabel: 'current');
    addTearDown(hovered.dispose);
    addTearDown(current.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Column(
          children: [
            Focus(
              focusNode: hovered,
              child: const SizedBox(width: 50, height: 50),
            ),
            Focus(
              focusNode: current,
              child: const SizedBox(width: 50, height: 50),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Mouse is resting on `hovered`; the first D-pad key transfers focus there.
    AppFocusCoordinator.inputMode.value = AppInputMode.mouse;
    AppFocusCoordinator.lastHoveredNode = hovered;
    AppFocusCoordinator.switchToDpad();
    await tester.pump();
    expect(hovered.hasPrimaryFocus, isTrue);

    // If the hovered node already owns focus, do not fall back to another card.
    AppFocusCoordinator.inputMode.value = AppInputMode.mouse;
    AppFocusCoordinator.lastHoveredNode = hovered;
    AppFocusCoordinator.lastFocusedNode = current;
    AppFocusCoordinator.switchToDpad();
    await tester.pump();
    expect(hovered.hasPrimaryFocus, isTrue);

    // Subsequent D-pad navigation must not pull focus back to the hovered node.
    current.requestFocus();
    await tester.pump();
    AppFocusCoordinator.switchToDpad();
    await tester.pump();

    expect(current.hasPrimaryFocus, isTrue);
    expect(hovered.hasFocus, isFalse);
  });

  testWidgets('mouse hover does not steal focus from a text field', (
    tester,
  ) async {
    final field = FocusNode(debugLabel: 'field');
    final hovered = FocusNode(debugLabel: 'hovered');
    addTearDown(field.dispose);
    addTearDown(hovered.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: field),
              Focus(
                focusNode: hovered,
                child: const SizedBox(width: 50, height: 50),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    field.requestFocus();
    await tester.pump();
    expect(field.hasPrimaryFocus, isTrue);

    // A card is hovered, but arrows must keep editing the focused field.
    AppFocusCoordinator.inputMode.value = AppInputMode.mouse;
    AppFocusCoordinator.lastHoveredNode = hovered;
    AppFocusCoordinator.switchToDpad();
    await tester.pump();

    expect(field.hasPrimaryFocus, isTrue);
    expect(hovered.hasFocus, isFalse);
    expect(AppFocusCoordinator.lastHoveredNode, isNull);
  });
}
