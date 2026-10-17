import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/widgets/dpad_navigation_scope.dart';

void main() {
  testWidgets('DpadNavigationScope moves focus down from TextField on arrowDown', (tester) async {
    final focus1 = FocusNode();
    final focus2 = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: DpadNavigationScope(
          child: Scaffold(
            body: Column(
              children: [
                TextField(
                  focusNode: focus1,
                  decoration: const InputDecoration(hintText: 'Field 1'),
                ),
                TextField(
                  focusNode: focus2,
                  decoration: const InputDecoration(hintText: 'Field 2'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Focus the first text field
    focus1.requestFocus();
    await tester.pump();
    expect(focus1.hasFocus, isTrue);
    expect(focus2.hasFocus, isFalse);

    // Send ArrowDown key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    // Focus should have moved to the second field
    expect(focus1.hasFocus, isFalse);
    expect(focus2.hasFocus, isTrue);

    // Send ArrowUp key
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();

    // Focus should have returned to the first field
    expect(focus1.hasFocus, isTrue);
    expect(focus2.hasFocus, isFalse);

    focus1.dispose();
    focus2.dispose();
  });

  testWidgets('DpadNavigationScope unfocuses on Escape key', (tester) async {
    final focus = FocusNode();

    await tester.pumpWidget(
      MaterialApp(
        home: DpadNavigationScope(
          child: Scaffold(
            body: TextField(
              focusNode: focus,
            ),
          ),
        ),
      ),
    );

    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);

    // Send Escape
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(focus.hasFocus, isFalse);
    focus.dispose();
  });
}
