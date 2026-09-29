import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/library_screen.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';

class MockRunningServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
        status: ServerStatus(
          username: 'SeanimeUser',
        ),
      );
}

class MockLastSessionNotifier extends LastSessionNotifier {
  final LastSessionItem? _initial;
  MockLastSessionNotifier([this._initial]);

  @override
  LastSessionItem? build() => _initial;
}

class MockResumeBarEnabledNotifier extends ResumeBarEnabledNotifier {
  @override
  bool build() => true;
}

void main() {
  final testItems = [
    const DesktopSidebarItem(
      icon: Icons.home_rounded,
      selectedIcon: Icons.home_rounded,
      label: 'Inicio',
      targetIndex: 0,
    ),
    const DesktopSidebarItem(
      icon: Icons.menu_book_rounded,
      selectedIcon: Icons.menu_book_rounded,
      label: 'Manga',
      targetIndex: 1,
    ),
    const DesktopSidebarItem(
      icon: Icons.person_rounded,
      selectedIcon: Icons.person_rounded,
      label: 'Perfil',
      targetIndex: 3,
    ),
  ];

  testWidgets('DesktopSidebar renders floating icons without border boxes', (tester) async {
    int selected = 0;
    bool searchClicked = false;
    bool settingsClicked = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: DesktopSidebar(
              selectedIndex: selected,
              onDestinationSelected: (idx) => selected = idx,
              onSearchPressed: () => searchClicked = true,
              onSettingsPressed: () => settingsClicked = true,
              items: testItems,
            ),
          ),
        ),
      ),
    );

    // Verify icons are rendered
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Verify tooltips exist with the labels
    final tooltipFinders = find.byType(Tooltip);
    expect(tooltipFinders, findsWidgets);

    // Verify tap triggers onDestinationSelected
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();
    expect(selected, 1);

    // Verify search tap
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(searchClicked, true);

    // Verify settings tap
    await tester.tap(find.byTooltip('Configuración'));
    await tester.pumpAndSettle();
    expect(settingsClicked, true);
  });

  testWidgets('DesktopSidebar uses bookmark icon when resuming manga session', (tester) async {
    const mangaSession = LastSessionItem(
      mediaType: 'MANGA',
      mediaId: 10,
      title: 'Berserk',
      chapterId: '1',
      mangaProvider: 'comick',
      chapterNumber: 1,
      updatedAt: 123456,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          resumeBarEnabledProvider.overrideWith(MockResumeBarEnabledNotifier.new),
          lastSessionProvider.overrideWith(() => MockLastSessionNotifier(mangaSession)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DesktopSidebar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              onSearchPressed: () {},
              items: testItems,
            ),
          ),
        ),
      ),
    );

    // Should NOT have duplicate menu_book for resume; should use bookmark
    expect(find.byIcon(AppIcons.bookmark()), findsOneWidget);
  });

  testWidgets('LibraryScreen constrains content to maxWidth 820 on wide screens', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
          animeCollectionProvider.overrideWith((ref) => Future.value([])),
          mangaCollectionProvider.overrideWith((ref) => Future.value([])),
        ],
        child: const MaterialApp(
          home: LibraryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final constrainedBoxFinder = find.ancestor(
      of: find.byType(ListView),
      matching: find.byType(ConstrainedBox),
    );
    expect(constrainedBoxFinder, findsOneWidget);

    final constrainedBox = tester.widget<ConstrainedBox>(constrainedBoxFinder);
    expect(constrainedBox.constraints.maxWidth, 820);
  });

  testWidgets('DesktopSidebar in light theme does not turn hover icons to white', (tester) async {
    final lightTheme = ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        onSurface: Color(0xFF1F2430),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: lightTheme,
          home: Scaffold(
            body: DesktopSidebar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              onSearchPressed: () {},
              items: testItems,
            ),
          ),
        ),
      ),
    );

    // Hover over Manga item (index 1, unselected)
    final mangaIconFinder = find.byIcon(Icons.menu_book_rounded);
    expect(mangaIconFinder, findsOneWidget);

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(mangaIconFinder));
    await tester.pumpAndSettle();

    final iconWidget = tester.widget<Icon>(mangaIconFinder);
    expect(iconWidget.color, isNot(Colors.white));
    expect(iconWidget.color, const Color(0xFF1F2430));
  });
}
