import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/desktop_sidebar.dart';
import 'package:seanime_app/presentation/widgets/mobile_floating_nav.dart';

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

  const testSession = LastSessionItem(
    mediaType: 'ANIME',
    mediaId: 12345,
    title: 'Frieren: Beyond Journey\'s End',
    subtitle: 'Episodio 12 • 14:20',
    episodeNumber: 12,
    positionMs: 860000,
    durationMs: 1440000,
    updatedAt: 1690000000,
  );

  testWidgets('MobileFloatingNav renders dock with selected item label and unselected icons', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastSessionProvider.overrideWith(() => _MockLastSessionNotifier(null)),
        ],
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileFloatingNav(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              items: testItems,
              isResumeExpanded: true,
            ),
          ),
        ),
      ),
    );

    // Selected item displays its text to the right
    expect(find.text('Inicio'), findsOneWidget);

    // Unselected items are icon-only
    expect(find.text('Manga'), findsNothing);
    expect(find.text('Explorar'), findsNothing);
    expect(find.text('Perfil'), findsNothing);

    // All icons are present
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);
    expect(find.byIcon(Icons.explore_rounded), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Verify no session title is shown
    expect(find.text('Frieren: Beyond Journey\'s End'), findsNothing);
  });

  testWidgets('MobileFloatingNav renders expanded header bar when isResumeExpanded is true', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastSessionProvider.overrideWith(() => _MockLastSessionNotifier(testSession)),
        ],
        child: MaterialApp(
          home: Scaffold(
            bottomNavigationBar: MobileFloatingNav(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              items: testItems,
              isResumeExpanded: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Selected nav item label
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Perfil'), findsNothing);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);

    // Expanded resume bar content: Episode number/title on top, Anime name below
    expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
    expect(find.text('Episodio 12'), findsOneWidget);
  });

  testWidgets('MobileFloatingNav switches to icon-only mode when collapsed into companion row', (tester) async {
    bool isExpanded = true;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastSessionProvider.overrideWith(() => _MockLastSessionNotifier(testSession)),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () => setState(() => isExpanded = false),
                  child: const Text('Collapse'),
                ),
                bottomNavigationBar: MobileFloatingNav(
                  selectedIndex: 0,
                  onDestinationSelected: (_) {},
                  items: testItems,
                  isResumeExpanded: isExpanded,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Frieren: Beyond Journey\'s End'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);

    // Tap collapse button to transition to collapsed state
    await tester.tap(find.text('Collapse'));
    await tester.pumpAndSettle();

    // In collapsed companion mode, all items switch to icon-only (zero deployed text)
    expect(find.text('Inicio'), findsNothing);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

    // Resume card text fades away in collapsed mode
    expect(find.text('Frieren: Beyond Journey\'s End'), findsNothing);
  });

  testWidgets('MobileFloatingNav navigation item selection triggers callback', (tester) async {
    int selected = 0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          lastSessionProvider.overrideWith(() => _MockLastSessionNotifier(testSession)),
        ],
        child: MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                bottomNavigationBar: MobileFloatingNav(
                  selectedIndex: selected,
                  onDestinationSelected: (idx) => setState(() => selected = idx),
                  items: testItems,
                  isResumeExpanded: false,
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(selected, 0);

    // Tap 'Manga' icon destination
    await tester.tap(find.byIcon(Icons.menu_book_rounded));
    await tester.pumpAndSettle();

    expect(selected, 1);
  });

  testWidgets('LastSessionItem prefers characterImage (MC) over coverImage for general display', (tester) async {
    const sessionWithBoth = LastSessionItem(
      mediaType: 'ANIME',
      mediaId: 999,
      title: 'Anime with MC',
      coverImage: 'https://example.com/cover.jpg',
      characterImage: 'https://example.com/mc_character.jpg',
      updatedAt: 1234567,
    );

    expect(sessionWithBoth.displayImage, 'https://example.com/mc_character.jpg');

    const sessionWithOnlyCover = LastSessionItem(
      mediaType: 'ANIME',
      mediaId: 999,
      title: 'Anime with Cover Only',
      coverImage: 'https://example.com/cover.jpg',
      updatedAt: 1234567,
    );

    expect(sessionWithOnlyCover.displayImage, 'https://example.com/cover.jpg');
  });
}

class _MockLastSessionNotifier extends LastSessionNotifier {
  final LastSessionItem? _initial;
  _MockLastSessionNotifier(this._initial);

  @override
  LastSessionItem? build() => _initial;
}
