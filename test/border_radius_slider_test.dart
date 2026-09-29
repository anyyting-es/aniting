import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/presentation/screens/settings/subpages/personalizacion_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PersonalizacionSettingsScreen renders and updates border radius smoothly', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PersonalizacionSettingsScreen(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify presence of slider
    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('10 px'), findsOneWidget);

    // Verify chips exist
    expect(find.text('0 px (Cuadrado)'), findsOneWidget);
    expect(find.text('16 px (Redondo)'), findsOneWidget);

    // Drag slider
    await tester.drag(find.byType(Slider), const Offset(100, 0));
    await tester.pumpAndSettle();

    // Verify badge updated
    expect(find.text('10 px'), findsNothing);

    // Tap on 16 px chip
    await tester.tap(find.text('16 px (Redondo)'));
    await tester.pumpAndSettle();

    expect(find.text('16 px'), findsOneWidget);

    // Tap on 0 px chip
    await tester.tap(find.text('0 px (Cuadrado)'));
    await tester.pumpAndSettle();

    expect(find.text('0 px'), findsOneWidget);
  });
}
