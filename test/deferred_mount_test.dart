import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/common/deferred_mount.dart';

void main() {
  testWidgets('mounts the child only after the delay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeferredMount(
          delay: Duration(milliseconds: 300),
          placeholder: Text('waiting'),
          child: Text('late'),
        ),
      ),
    );

    expect(find.text('waiting'), findsOneWidget);
    expect(find.text('late'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('late'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('late'), findsOneWidget);
    expect(find.text('waiting'), findsNothing);
  });

  testWidgets('does not fire after being disposed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeferredMount(
          delay: Duration(milliseconds: 300),
          child: Text('late'),
        ),
      ),
    );

    // Replace the widget before the timer fires: the timer must be cancelled.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('late'), findsNothing);
  });
}
