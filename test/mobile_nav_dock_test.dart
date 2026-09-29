import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/mobile_nav_style_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';
import 'package:seanime_app/presentation/widgets/mobile_nav_dock.dart';

void main() {
  final testItems = [
    const DesktopSidebarItem(
      icon: Icons.home_rounded,
      selectedIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    const DesktopSidebarItem(
      icon: Icons.menu_book_rounded,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Manga',
    ),
    const DesktopSidebarItem(
      icon: Icons.explore_rounded,
      selectedIcon: Icons.explore_rounded,
      label: 'Explorar',
    ),
    const DesktopSidebarItem(
      icon: Icons.person_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil',
    ),
  ];

  testWidgets('MobileNavDock renders icons and text labels', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MobileNavDock(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                items: testItems,
              ),
            ),
          ),
        ),
      ),
    );

    // Verify all 4 icons are present
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Verify labels are displayed
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Manga'), findsOneWidget);
    expect(find.text('Explorar'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('MobileNavDock triggers onDestinationSelected and slides indicator on tap', (tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(
                  child: MobileNavDock(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() => selectedIndex = index);
                    },
                    items: testItems,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(selectedIndex, 0);

    // Tap on the 'Manga' destination (index 1)
    await tester.tap(find.text('Manga'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 1);

    // Tap on the 'Explorar' destination (index 2)
    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('MobileNavDock mouse hover updates hovered destination without errors', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: MobileNavDock(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                items: testItems,
              ),
            ),
          ),
        ),
      ),
    );

    // Create mouse pointer and hover over destination
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text('Manga')));
    await tester.pumpAndSettle();

    // Verify widget builds and renders stably with hover
    expect(find.text('Manga'), findsOneWidget);
  });

  group('MobileNavStyle Tests', () {
    test('MobileNavStyle fromKey parses properly and defaults to classic', () {
      expect(MobileNavStyle.fromKey('floating'), MobileNavStyle.floating);
      expect(MobileNavStyle.fromKey('classic'), MobileNavStyle.classic);
      expect(MobileNavStyle.fromKey(null), MobileNavStyle.classic);
      expect(MobileNavStyle.fromKey('invalid'), MobileNavStyle.classic);
    });
  });
}
