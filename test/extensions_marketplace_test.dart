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
        id: 'aniting-universal',
        name: 'Aniting Universal',
        version: '1.0.0',
        author: 'Aniting',
        description: 'Proveedor único oficial de streaming',
        type: 'onlinestream-provider',
        language: 'javascript',
        disabled: false,
      ),
      const ExtensionItem(
        id: 'animetosho-new',
        name: 'AnimeTosho (NEW)',
        version: '2.5.1',
        author: 'Faddix',
        description: 'Torrents oficiales',
        type: 'anime-torrent-provider',
        language: 'typescript',
        disabled: false,
      ),
    ];
  }

  @override
  Future<List<ExtensionItem>> getMarketplaceExtensions(String repoUrl, {bool forceRefresh = false}) async {
    return [
      const ExtensionItem(
        id: 'aniting-universal',
        name: 'Aniting Universal',
        version: '1.0.0',
        author: 'Aniting',
        description: 'Proveedor único oficial: Transmisiones 1080p, Multi-Audio y Multi-Subtítulos.',
        type: 'onlinestream-provider',
        language: 'javascript',
        manifestUri: 'https://example.com/universal/manifest.json',
      ),
      const ExtensionItem(
        id: 'animetosho-new',
        name: 'AnimeTosho (NEW)',
        version: '2.5.1',
        author: 'Faddix',
        description: 'Integrates Anime Tosho (NEW) as a torrent streaming provider for Seanime.',
        type: 'anime-torrent-provider',
        language: 'typescript',
        manifestUri: 'https://example.com/animetosho/manifest.json',
      ),
      const ExtensionItem(
        id: 'mangadex',
        name: 'MangaDex',
        version: '1.0.0',
        author: 'kiko',
        description: 'Read manga directly from MangaDex.',
        type: 'manga-provider',
        language: 'typescript',
        manifestUri: 'https://example.com/mangadex/manifest.json',
      ),
    ];
  }

  @override
  Future<bool> setExtensionDisabled(String id, bool disabled) async {
    return true;
  }
}

void main() {
  group('ExtensionsMarketplaceScreen Tests', () {
    testWidgets('Renders simplified categories (Online, Torrents, Manga) and strict Aniting Universal',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(1400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = FakeSeanimeRepository();
      const l10n = SpanishTranslations();

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

      // Top segmented categories: Online, Torrents, Manga
      expect(find.text(l10n.onlineStreamingTab), findsWidgets);
      expect(find.text(l10n.animeTorrents), findsWidgets);
      expect(find.text(l10n.manga), findsWidgets);

      // Verify NO repository configuration or raw URL changer exists
      expect(find.text('Cambiar Repositorio'), findsNothing);
      expect(find.text('Configuración de Repositorio'), findsNothing);

      // Online category (default active): Native online providers
      expect(find.text('Aniting Universal'), findsOneWidget);
      expect(find.text('Kawaii Animes'), findsOneWidget);
      expect(find.text('JKAnime'), findsOneWidget);
      expect(find.text('MangaDex'), findsNothing);

      // Switch to Torrents category
      await tester.tap(find.text(l10n.animeTorrents).first);
      await tester.pumpAndSettle();

      expect(find.text('AnimeTosho (NEW)'), findsOneWidget);
      expect(find.text('Aniting Universal'), findsNothing);

      // Switch to Manga category
      await tester.tap(find.text(l10n.manga).first);
      await tester.pumpAndSettle();

      expect(find.text('MangaDex'), findsOneWidget);
      expect(find.text('AnimeTosho (NEW)'), findsNothing);
    });
  });
}
