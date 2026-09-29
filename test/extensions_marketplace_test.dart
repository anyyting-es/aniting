import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/api/api_client.dart';
import 'package:seanime_app/data/models/extension_item.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/extensions_marketplace_screen.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class FakeSeanimeRepository extends SeanimeRepository {
  FakeSeanimeRepository() : super(ApiClient());

  @override
  Future<List<ExtensionItem>> getAllExtensions({bool withUpdates = true}) async {
    return [
      const ExtensionItem(
        id: 'account-switcher',
        name: 'Account Switcher',
        version: '1.0.0',
        author: 'FracturedSora',
        description: 'Switch between AniList accounts',
        type: 'plugin',
        language: 'typescript',
        isBuiltin: false,
        disabled: false,
      ),
    ];
  }

  @override
  Future<List<ExtensionItem>> getMarketplaceExtensions(String repoUrl, {bool forceRefresh = false}) async {
    return [
      const ExtensionItem(
        id: 'aiostreams-plugin',
        name: 'AIOStreams',
        version: '0.10.1',
        author: 'Viren070',
        description: 'Stream content from AIOStreams directly in Seanime.',
        type: 'plugin',
        language: 'javascript',
        manifestUri: 'https://example.com/aiostreams/manifest.json',
      ),
      const ExtensionItem(
        id: 'acg-rip-provider',
        name: 'ACG.RIP',
        version: '1.0.2',
        author: 'Bas1874',
        description: 'Fetches torrents from acg.rip.',
        type: 'anime-torrent-provider',
        language: 'typescript',
        manifestUri: 'https://example.com/acg/manifest.json',
      ),
      const ExtensionItem(
        id: 'mangadex-provider',
        name: 'MangaDex',
        version: '1.0.0',
        author: 'Community',
        description: 'Read manga directly from MangaDex.',
        type: 'manga-provider',
        language: 'typescript',
        manifestUri: 'https://example.com/mangadex/manifest.json',
      ),
    ];
  }
}

void main() {
  group('ExtensionsMarketplaceScreen Tests', () {
    testWidgets('Renders dynamic Marketplace, filters, search, and repository dialog', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeSeanimeRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            repositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: const MaterialApp(
            home: ExtensionsMarketplaceScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Top pill navigation: verify NO emojis, clean text
      expect(find.text('Instaladas (1)'), findsOneWidget);
      expect(find.text('Marketplace'), findsWidgets);

      // Switch to Marketplace tab
      await tester.tap(find.text('Marketplace').first);
      await tester.pumpAndSettle();

      // Header info
      expect(find.text('Explora e instala extensiones desde el repositorio.'), findsOneWidget);
      expect(find.text('Actualizar'), findsOneWidget);
      expect(find.text('Cambiar Repositorio'), findsOneWidget);

      const l10n = SpanishTranslations();
      // Filter chips exist (Plugins filter chip is excluded)
      expect(find.text(l10n.allTypes), findsOneWidget);
      expect(find.text('Plugins'), findsNothing);
      expect(find.text(l10n.animeTorrents), findsWidgets);
      expect(find.text(l10n.manga), findsWidgets);
      expect(find.text(l10n.onlineStreamingTab), findsOneWidget);
      expect(find.text(l10n.customSources), findsOneWidget);

      // Dynamic extensions rendered from repository (Plugin type extensions are filtered out)
      expect(find.text('AIOStreams'), findsNothing);
      expect(find.text('aiostreams-plugin'), findsNothing);
      expect(find.text('ACG.RIP'), findsOneWidget);
      expect(find.text('mangadex-provider'), findsOneWidget);

      // Filter by type: tap 'Anime Torrents' chip
      await tester.tap(find.widgetWithText(FilterChip, l10n.animeTorrents));
      await tester.pumpAndSettle();

      // Only Anime Torrents should be visible
      expect(find.text('ACG.RIP'), findsOneWidget);
      expect(find.text('AIOStreams'), findsNothing);

      // Reset to All Types
      await tester.tap(find.widgetWithText(FilterChip, l10n.allTypes));
      await tester.pumpAndSettle();

      // Test Search
      await tester.enterText(find.byType(TextField), 'MangaDex');
      await tester.pumpAndSettle();

      expect(find.text('mangadex-provider'), findsOneWidget);
      expect(find.text('AIOStreams'), findsNothing);

      // Clear search
      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      // Open Change Repository dialog
      await tester.tap(find.text('Cambiar Repositorio'));
      await tester.pumpAndSettle();

      expect(find.text('Configuración de Repositorio'), findsOneWidget);
      expect(find.text('URL del Repositorio Marketplace (JSON)'), findsOneWidget);
      expect(find.text('Restablecer repositorio por defecto'), findsOneWidget);
      expect(find.text('Guardar y Cargar'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Switch to Installed tab
      await tester.tap(find.text('Instaladas (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Account Switcher'), findsOneWidget);
    });
  });
}
