import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/server_status.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/settings/settings_screen.dart';
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
  testWidgets('SettingsScreen renders unboxed items with titles only, separated by sections', (tester) async {
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

    // Verify section headers exist
    expect(find.byType(SettingsSectionHeader), findsWidgets);

    // Verify tiles have titles rendered
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Tema y Colores')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Apariencia e Interfaz')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Extensiones')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Reproductor de Video')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Lector de Manga')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Servidor Seanime y Red')), findsOneWidget);
    expect(find.descendant(of: find.byType(SettingsTile), matching: find.text('Acerca de Aniting')), findsOneWidget);

    // Verify old descriptions are NOT present
    expect(find.text('Modo oscuro, colores de acento y tema de anime'), findsNothing);
    expect(find.text('Idioma, tipografía y estilo de visualización'), findsNothing);
    expect(find.text('Modo Webtoon, paginado, gestos y status bar'), findsNothing);

    // Verify SettingsTile is unboxed (not wrapped in heavy BoxDecoration borders)
    final tileFinders = find.byType(SettingsTile);
    expect(tileFinders, findsWidgets);

    final firstTile = tester.widget<SettingsTile>(tileFinders.first);
    expect(firstTile.subtitle, isNull);
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
