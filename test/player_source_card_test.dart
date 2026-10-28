import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_source_card.dart';

import 'package:seanime_app/presentation/providers/app_providers.dart';

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
      home: Scaffold(
        body: child,
      ),
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

  testWidgets('PlayerSourceCard renders searching state while resolving', (tester) async {
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

  testWidgets('PlayerSourceCard renders active source info and allows reload', (tester) async {
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

  testWidgets('Tapping PlayerSourceCard opens the source dropdown and selects a different source', (tester) async {
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
  });

  testWidgets('PlayerSourceCard displays error state and reloads when tapped without sources', (tester) async {
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
  });

  testWidgets('PlayerSourceCard allows changing provider from the dropdown', (tester) async {
    String? switchedProvider;

    await tester.pumpWidget(
      _buildWrapper(
        overrides: [
          onlinestreamProvidersProvider.overrideWith((ref) async => const [
            OnlinestreamProvider(id: 'gogoanime', name: 'Gogoanime'),
            OnlinestreamProvider(id: 'animeflv', name: 'AnimeFLV'),
          ]),
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

    // Open the dropdown and switch provider
    await tester.tap(find.byType(PlayerSourceCard));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('AnimeFLV'), findsOneWidget);
    await tester.tap(find.text('AnimeFLV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(switchedProvider, 'animeflv');
  });
}
