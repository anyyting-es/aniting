import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/theme/app_palette.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';

void main() {
  group('Web-Style Page Transitions Tests', () {
    test('WebPageRoute and aliases have snappy web timings and curves', () {
      final webRoute = WebPageRoute<void>(child: const SizedBox());
      final smoothRoute = SmoothPageRoute<void>(child: const SizedBox());
      final slideRoute = SlideRightToLeftPageRoute<void>(child: const SizedBox());

      expect(webRoute.transitionDuration, const Duration(milliseconds: 240));
      expect(webRoute.reverseTransitionDuration, const Duration(milliseconds: 200));

      expect(smoothRoute.transitionDuration, const Duration(milliseconds: 240));
      expect(smoothRoute.reverseTransitionDuration, const Duration(milliseconds: 200));

      expect(slideRoute.transitionDuration, const Duration(milliseconds: 240));
      expect(slideRoute.reverseTransitionDuration, const Duration(milliseconds: 200));

      expect(kWebDecelCurve.a, 0.16);
      expect(kWebDecelCurve.b, 1.0);
      expect(kWebDecelCurve.c, 0.3);
      expect(kWebDecelCurve.d, 1.0);
    });

    testWidgets('SmoothPageRoute produces pure fade and micro-slide without ScaleTransition', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  SmoothPageRoute(
                    child: const Scaffold(
                      body: Text('Target Screen'),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump(); // Start transition

      // During animation: verify FadeTransition and SlideTransition are present
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);

      // Verify NO ScaleTransition is used (eliminates blurry/jelly screen scaling)
      expect(find.byType(ScaleTransition), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Target Screen'), findsOneWidget);
    });

    testWidgets('AppThemeBuilder configures WebPageTransitionsBuilder across all platforms', (tester) async {
      final theme = AppThemeBuilder.buildTheme(
        palette: AppPalettes.getDarkPresets().first,
        isDark: true,
      );

      final transitionsTheme = theme.pageTransitionsTheme;
      for (final platform in [
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.windows,
      ]) {
        expect(
          transitionsTheme.builders[platform],
          isA<WebPageTransitionsBuilder>(),
          reason: 'Platform $platform must use WebPageTransitionsBuilder',
        );
      }
    });

    testWidgets('MaterialPageRoute inherits web transition from ThemeData', (tester) async {
      final theme = AppThemeBuilder.buildTheme(
        palette: AppPalettes.getDarkPresets().first,
        isDark: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('Material Target')),
                  ),
                );
              },
              child: const Text('Go'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Go'));
      await tester.pump();

      // Verify web-style transitions are used for MaterialPageRoute
      expect(find.byType(FadeTransition), findsWidgets);
      expect(find.byType(SlideTransition), findsWidgets);
      expect(find.byType(ScaleTransition), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('Material Target'), findsOneWidget);
    });
  });
}
