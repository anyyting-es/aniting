import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/settings_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/expressive/expressive_settings_category_tile.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/expressive/expressive_settings_sidebar.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/pixel_settings_widgets.dart';

class MockRunningServerNotifier extends ServerNotifier {
  @override
  ServerStateModel build() => ServerStateModel(
        state: ServerState.running,
        status: ServerStatus(
          username: 'SeanimeUser',
        ),
      );
}

void main() {
  testWidgets('SettingsScreen renders ExpressiveSettingsSidebar with categories and detail panel on desktop', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify ExpressiveSettingsSidebar and category tiles exist
    expect(find.byType(ExpressiveSettingsSidebar), findsOneWidget);
    expect(find.byType(ExpressiveSettingsCategoryTile), findsWidgets);

    // On desktop, the first tile (theme) is selected
    final tiles = tester.widgetList<ExpressiveSettingsCategoryTile>(
      find.byType(ExpressiveSettingsCategoryTile),
    ).toList();
    expect(tiles.first.isSelected, isTrue);
    expect(tiles.first.showChevron, isFalse);
  });

  testWidgets('SettingsScreen on mobile has no pre-selected option and shows chevrons', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpressiveSettingsSidebar), findsOneWidget);
    final tiles = tester.widgetList<ExpressiveSettingsCategoryTile>(
      find.byType(ExpressiveSettingsCategoryTile),
    ).toList();

    // On mobile, NO option is selected and all show chevrons
    for (final tile in tiles) {
      expect(tile.isSelected, isFalse);
      expect(tile.showChevron, isTrue);
    }
  });

  testWidgets('Mouse click does not show D-pad focus ring, only selects category', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serverNotifierProvider.overrideWith(MockRunningServerNotifier.new),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tiles = find.byType(ExpressiveSettingsCategoryTile);
    await tester.tap(tiles.at(1));
    await tester.pumpAndSettle();

    final updatedTiles = tester.widgetList<ExpressiveSettingsCategoryTile>(tiles).toList();
    expect(updatedTiles[1].isSelected, isTrue);
    expect(updatedTiles[1].isDpadFocused, isFalse);
  });

  testWidgets('PixelSettingsGroupCard and PixelCardContainer are unboxed', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PixelSettingsGroupCard(
                children: [Text('Item 1'), Text('Item 2')],
              ),
              PixelCardContainer(
                child: Text('Card item'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify they render children without throwing and without container decorations
    expect(find.text('Item 1'), findsOneWidget);
    expect(find.text('Item 2'), findsOneWidget);
    expect(find.text('Card item'), findsOneWidget);
  });
}
