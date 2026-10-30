import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/theme/app_focus_coordinator.dart';
import 'package:seanime_app/presentation/screens/settings/settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/expressive/expressive_settings_detail_panel.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/settings_dpad_focus.dart';

void main() {
  setUp(() {
    AppFocusCoordinator.inputMode.value = AppInputMode.dpad;
  });

  group('Settings D-pad Navigation Tests', () {
    testWidgets(
      'Left arrow moves between horizontal siblings (B -> A) and only exits to sidebar from A',
      (tester) async {
        bool exitedToSidebar = false;
        final detailScope = FocusScopeNode(debugLabel: 'test-detail-scope');
        final nodeA = FocusNode(debugLabel: 'option-A');
        final nodeB = FocusNode(debugLabel: 'option-B');

        addTearDown(() {
          detailScope.dispose();
          nodeA.dispose();
          nodeB.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExpressiveSettingsDetailPanel(
                selectedCategory: SettingsCategory.theme,
                focusScopeNode: detailScope,
                onExitToSidebar: () => exitedToSidebar = true,
                detailViewBuilder: (_) => Row(
                  children: [
                    Focus(
                      focusNode: nodeA,
                      child: const SizedBox(width: 100, height: 48, child: Text('A')),
                    ),
                    const SizedBox(width: 16),
                    Focus(
                      focusNode: nodeB,
                      child: const SizedBox(width: 100, height: 48, child: Text('B')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Focus option A
        nodeA.requestFocus();
        await tester.pumpAndSettle();
        expect(nodeA.hasFocus, isTrue);

        // 2. Press Right -> moves to B
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(nodeB.hasFocus, isTrue);
        expect(exitedToSidebar, isFalse);

        // 3. Press Left -> moves BACK to A, must NOT exit to sidebar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(nodeA.hasFocus, isTrue);
        expect(exitedToSidebar, isFalse);

        // 4. Press Left on A -> nothing to the left, must exit to sidebar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(exitedToSidebar, isTrue);
      },
    );

    testWidgets(
      'Slider adjusts only with Left/Right and navigates out with Up/Down',
      (tester) async {
        bool exitedToSidebar = false;
        double sliderValue = 10.0;
        final detailScope = FocusScopeNode(debugLabel: 'test-slider-scope');
        final topNode = FocusNode(debugLabel: 'top-item');
        final bottomNode = FocusNode(debugLabel: 'bottom-item');
        final sliderNode = FocusNode(debugLabel: 'slider-node');

        addTearDown(() {
          detailScope.dispose();
          topNode.dispose();
          bottomNode.dispose();
          sliderNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ExpressiveSettingsDetailPanel(
                    selectedCategory: SettingsCategory.theme,
                    focusScopeNode: detailScope,
                    onExitToSidebar: () => exitedToSidebar = true,
                    detailViewBuilder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Focus(
                          focusNode: topNode,
                          child: const SizedBox(width: 200, height: 40, child: Text('Top')),
                        ),
                        SettingsDpadSlider(
                          child: Slider(
                            focusNode: sliderNode,
                            value: sliderValue,
                            min: 0.0,
                            max: 20.0,
                            divisions: 20,
                            onChanged: (val) => setState(() => sliderValue = val),
                          ),
                        ),
                        Focus(
                          focusNode: bottomNode,
                          child: const SizedBox(width: 200, height: 40, child: Text('Bottom')),
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

        // 1. Focus the slider
        sliderNode.requestFocus();
        await tester.pumpAndSettle();
        expect(sliderNode.hasFocus, isTrue);

        // 2. Press Left -> decreases slider value, does NOT exit to sidebar
        final initialValue = sliderValue;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(sliderValue, lessThan(initialValue));
        expect(exitedToSidebar, isFalse);
        expect(sliderNode.hasFocus, isTrue);

        // 3. Press Right -> increases slider value
        final decreasedValue = sliderValue;
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(sliderValue, greaterThan(decreasedValue));
        expect(exitedToSidebar, isFalse);
        expect(sliderNode.hasFocus, isTrue);

        // 4. Press Up -> moves focus to top item
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(topNode.hasFocus, isTrue);

        // 5. Press Down -> moves focus back to slider
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(sliderNode.hasFocus, isTrue);

        // 6. Press Down -> moves focus to bottom item
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(bottomNode.hasFocus, isTrue);
      },
    );

    testWidgets(
      'M3EButtonGroup allows horizontal DPAD navigation between actions and moves down vertically',
      (tester) async {
        bool exitedToSidebar = false;
        final detailScope = FocusScopeNode(debugLabel: 'test-group-scope');
        final itemBelowNode = FocusNode(debugLabel: 'item-below');
        final action0Node = FocusNode(debugLabel: 'action-0');
        final action1Node = FocusNode(debugLabel: 'action-1');
        final action2Node = FocusNode(debugLabel: 'action-2');

        addTearDown(() {
          detailScope.dispose();
          itemBelowNode.dispose();
          action0Node.dispose();
          action1Node.dispose();
          action2Node.dispose();
        });

        int selectedIndex = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return ExpressiveSettingsDetailPanel(
                    selectedCategory: SettingsCategory.theme,
                    focusScopeNode: detailScope,
                    onExitToSidebar: () => exitedToSidebar = true,
                    detailViewBuilder: (_) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        M3EButtonGroup(
                          type: M3EButtonGroupType.connected,
                          direction: Axis.horizontal,
                          shape: M3EButtonShape.round,
                          size: M3EButtonSize.sm,
                          style: M3EButtonStyle.filled,
                          selectionRequired: true,
                          selectedIndex: selectedIndex,
                          onSelectedIndexChanged: (i) {
                            if (i != null) setState(() => selectedIndex = i);
                          },
                          actions: [
                            M3EButtonGroupAction(
                              focusNode: action0Node,
                              label: const Text('Light'),
                            ),
                            M3EButtonGroupAction(
                              focusNode: action1Node,
                              label: const Text('Dark'),
                            ),
                            M3EButtonGroupAction(
                              focusNode: action2Node,
                              label: const Text('System'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Focus(
                          focusNode: itemBelowNode,
                          child: const SizedBox(width: 200, height: 40, child: Text('OLED switch')),
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

        // 1. Focus the middle button (action 1: Dark)
        action1Node.requestFocus();
        await tester.pumpAndSettle();
        expect(action1Node.hasFocus, isTrue);

        // 2. Press Left -> moves to action 0 (Light), does NOT exit to sidebar
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(action0Node.hasFocus, isTrue);
        expect(exitedToSidebar, isFalse);

        // 3. Press Right -> moves back to action 1 (Dark)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(action1Node.hasFocus, isTrue);

        // 4. Press Right -> moves to action 2 (System)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(action2Node.hasFocus, isTrue);

        // 5. Press Down -> moves directly to itemBelowNode (OLED switch)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(itemBelowNode.hasFocus, isTrue);

        // 6. Press Up -> moves back into M3EButtonGroup
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        final primary = FocusManager.instance.primaryFocus;
        expect(
          primary != null &&
              (action0Node.hasFocus ||
                  action1Node.hasFocus ||
                  action2Node.hasFocus ||
                  primary.context?.findAncestorWidgetOfExactType<M3EButtonGroup>() != null),
          isTrue,
        );

        // 7. From action 0 (Light), pressing Left exits to sidebar
        action0Node.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(exitedToSidebar, isTrue);
      },
    );

    testWidgets(
      'OLED switch, horizontal palettes scrollview, and exit to sidebar test',
      (tester) async {
        bool exitedToSidebar = false;
        final detailScope = FocusScopeNode(debugLabel: 'test-oled-scope');
        final oledNode = FocusNode(debugLabel: 'oled-switch');
        final palette1Node = FocusNode(debugLabel: 'palette-1');
        final palette2Node = FocusNode(debugLabel: 'palette-2');
        final iconPackNode = FocusNode(debugLabel: 'icon-pack');

        addTearDown(() {
          detailScope.dispose();
          oledNode.dispose();
          palette1Node.dispose();
          palette2Node.dispose();
          iconPackNode.dispose();
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ExpressiveSettingsDetailPanel(
                selectedCategory: SettingsCategory.theme,
                focusScopeNode: detailScope,
                onExitToSidebar: () => exitedToSidebar = true,
                detailViewBuilder: (_) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // OLED switch tile
                    Focus(
                      focusNode: oledNode,
                      child: const SizedBox(width: 400, height: 50, child: Text('OLED')),
                    ),
                    const SizedBox(height: 16),
                    // Horizontal scrollable Palettes row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Focus(
                            focusNode: palette1Node,
                            child: const SizedBox(width: 120, height: 44, child: Text('Palette 1')),
                          ),
                          const SizedBox(width: 8),
                          Focus(
                            focusNode: palette2Node,
                            child: const SizedBox(width: 120, height: 44, child: Text('Palette 2')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Icon pack section below
                    Focus(
                      focusNode: iconPackNode,
                      child: const SizedBox(width: 400, height: 60, child: Text('Icon Pack')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Focus OLED switch
        oledNode.requestFocus();
        await tester.pumpAndSettle();
        expect(oledNode.hasFocus, isTrue);

        // 2. Press Left -> must exit to sidebar ON FIRST CLICK (no double click!)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(exitedToSidebar, isTrue);

        // 3. Reset and refocus OLED switch
        exitedToSidebar = false;
        oledNode.requestFocus();
        await tester.pumpAndSettle();

        // 4. Press Down -> MUST land on Palettes (never jump over to Icon Pack!)
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(palette1Node.hasFocus || palette2Node.hasFocus, isTrue);
        expect(iconPackNode.hasFocus, isFalse);

        // 5. From palette, pressing Right moves to next palette
        if (palette1Node.hasFocus) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pumpAndSettle();
          expect(palette2Node.hasFocus, isTrue);
        }

        // 6. From palette, pressing Up moves back to OLED switch
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(oledNode.hasFocus, isTrue);

        // 7. From palette, pressing Down moves to Icon Pack
        palette1Node.requestFocus();
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(iconPackNode.hasFocus, isTrue);

        // 8. From Icon Pack, pressing Up moves back to Palettes
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
        await tester.pumpAndSettle();
        expect(palette1Node.hasFocus || palette2Node.hasFocus, isTrue);
      },
    );
  });
}
