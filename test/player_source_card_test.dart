import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/presentation/widgets/player/panels/player_source_card.dart';

import 'package:aniting/presentation/providers/app_providers.dart';

import 'package:g1455/g1455.dart';

class _MaterialIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.material;
}

Widget _buildWrapper({required Widget child, List<dynamic>? overrides}) {
  return ProviderScope(
    overrides: [
      iconPackProvider.overrideWith(_MaterialIconPackNotifier.new),
      ...?overrides?.cast(),
    ],
    child: MaterialApp(
      builder: (context, childWidget) => GlassHost(child: childWidget!),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  const sampleSources = [
    OnlinestreamVideoSource(
      server: 'gogoanime',
      url: 'https://example.com/stream1.m3u8',
      quality: '1080p',
      type: 'm3u8',
    ),
    OnlinestreamVideoSource(
      server: 'vidstreaming',
      url: 'https://example.com/stream2.m3u8',
      quality: '720p',
      type: 'm3u8',
    ),
    OnlinestreamVideoSource(
      server: 'streamwish',
      url: 'https://example.com/stream3.mp4',
      quality: 'auto',
    ),
  ];

  testWidgets('PlayerSourceCard renders searching state while resolving', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildWrapper(
        child: const PlayerSourceCard(
          isResolvingSources: true,
          episodeNumber: 1,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Buscando opciones...'), findsOneWidget);
    expect(find.textContaining('Toca para cambiar proveedor'), findsOneWidget);
  });

  testWidgets('PlayerSourceCard renders active source info and allows reload', (
    tester,
  ) async {
    bool reloaded = false;

    await tester.pumpWidget(
      _buildWrapper(
        child: PlayerSourceCard(
          isResolvingSources: false,
          availableSources: sampleSources,
          activeSource: sampleSources.first,
          providerName: 'Gogoanime',
          episodeNumber: 3,
          onReloadSources: () {
            reloaded = true;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GOGOANIME'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('• Gogoanime'), findsOneWidget);
    expect(find.textContaining('3 opciones disponibles'), findsOneWidget);

    // Tap reload
    final reloadButton = find.byTooltip('Recargar fuentes');
    expect(reloadButton, findsOneWidget);
    await tester.tap(reloadButton);
    expect(reloaded, isTrue);
  });

  testWidgets(
    'Tapping PlayerSourceCard opens the source dropdown and selects a different source',
    (tester) async {
      OnlinestreamVideoSource? selectedSource;

      await tester.pumpWidget(
        _buildWrapper(
          child: PlayerSourceCard(
            isResolvingSources: false,
            availableSources: sampleSources,
            activeSource: sampleSources.first,
            episodeNumber: 5,
            onSelectSource: (src) {
              selectedSource = src;
            },
          ),
        ),
      );
      await tester.pump();

      // Tap the card to open the dropdown
      await tester.tap(find.byType(PlayerSourceCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Dropdown lists the available servers
      expect(find.textContaining('vidstreaming'), findsOneWidget);
      expect(find.textContaining('streamwish'), findsOneWidget);

      // Select the second source (vidstreaming)
      await tester.tap(find.textContaining('vidstreaming'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(selectedSource, isNotNull);
      expect(selectedSource!.server, 'vidstreaming');
      expect(selectedSource!.quality, '720p');
    },
  );

  testWidgets(
    'PlayerSourceCard displays error state and reloads when tapped without sources',
    (tester) async {
      bool reloaded = false;

      await tester.pumpWidget(
        _buildWrapper(
          child: PlayerSourceCard(
            isResolvingSources: false,
            availableSources: const [],
            sourceResolutionError: 'Error de conexión con el proveedor',
            onReloadSources: () {
              reloaded = true;
            },
          ),
        ),
      );
      await tester.pump();

      // With no sources the card acts as a retry surface
      await tester.tap(find.byType(PlayerSourceCard));
      await tester.pump();
      expect(reloaded, isTrue);
    },
  );

  testWidgets(
    'PlayerSourceCard allows changing provider from the provider chip',
    (tester) async {
      String? switchedProvider;

      await tester.pumpWidget(
        _buildWrapper(
          overrides: [
            onlinestreamProvidersProvider.overrideWith(
              (ref) async => const [
                OnlinestreamProvider(id: 'gogoanime', name: 'Gogoanime'),
                OnlinestreamProvider(id: 'animeflv', name: 'AnimeFLV'),
              ],
            ),
          ],
          child: PlayerSourceCard(
            isResolvingSources: false,
            availableSources: sampleSources,
            providerName: 'gogoanime',
            episodeNumber: 1,
            onSelectProvider: (newProv) {
              switchedProvider = newProv;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Provider switching lives on its own chip, not inside the server menu.
      await tester.tap(find.text('• Gogoanime'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('AnimeFLV'), findsOneWidget);
      // The server menu must not open behind the provider menu.
      expect(find.textContaining('vidstreaming'), findsNothing);
      await tester.tap(find.text('AnimeFLV'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(switchedProvider, 'animeflv');
    },
  );

  testWidgets(
    'PlayerSourceCard gives each audio server a distinct label and keeps actions out of the server menu',
    (tester) async {
      const localizedSources = [
        OnlinestreamVideoSource(
          server: 'Server 1 [Latino]',
          url: 'https://example.com/latino.m3u8',
          quality: '1080p',
        ),
        OnlinestreamVideoSource(
          server: 'Server 1 [Sub]',
          url: 'https://example.com/sub.m3u8',
          quality: '1080p',
        ),
        OnlinestreamVideoSource(
          server: 'Server 1 [Castellano]',
          url: 'https://example.com/castellano.m3u8',
          quality: '1080p',
        ),
      ];

      await tester.pumpWidget(
        _buildWrapper(
          overrides: [
            onlinestreamProvidersProvider.overrideWith(
              (ref) async => const [
                OnlinestreamProvider(id: 'espanime', name: 'EspAnime'),
              ],
            ),
          ],
          child: PlayerSourceCard(
            isResolvingSources: false,
            availableSources: localizedSources,
            activeSource: localizedSources.first,
            providerName: 'espanime',
            episodeNumber: 1,
            onReloadSources: () {},
            onToggleDubbed: () {},
            onSelectSource: (_) {},
            onSelectProvider: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The active label keeps the audio language instead of collapsing to
      // three indistinguishable "Server 1" entries.
      expect(find.text('SERVER 1 • LATINO'), findsOneWidget);

      await tester.tap(find.byType(PlayerSourceCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Server 1 • Latino • 1080p'), findsOneWidget);
      expect(find.text('Server 1 • Sub • 1080p'), findsOneWidget);
      expect(find.text('Server 1 • Castellano • 1080p'), findsOneWidget);

      // Provider, reload and dub actions no longer pollute the server dropdown.
      expect(find.text('Recargar fuentes'), findsNothing);
      expect(find.text('Audio: Doblado (toca para subtitulado)'), findsNothing);
    },
  );
}
