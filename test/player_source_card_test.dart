import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_source_card.dart';

class _MaterialIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.material;
}

Widget _buildWrapper({required Widget child}) {
  return ProviderScope(
    overrides: [
      iconPackProvider.overrideWith(_MaterialIconPackNotifier.new),
    ],
    child: MaterialApp(
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
    expect(find.text('Reproduciendo primera opción encontrada'), findsOneWidget);
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

  testWidgets('Tapping PlayerSourceCard opens modal and selects different source', (tester) async {
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

    // Tap the card to open modal sheet
    await tester.tap(find.byType(PlayerSourceCard));
    await tester.pumpAndSettle();

    // Check modal contents
    expect(find.text('Opciones de reproducción'), findsOneWidget);
    expect(find.text('VIDSTREAMING'), findsOneWidget);
    expect(find.text('STREAMWISH'), findsOneWidget);

    // Select the second source (VIDSTREAMING)
    await tester.tap(find.text('VIDSTREAMING'));
    await tester.pumpAndSettle();

    expect(selectedSource, isNotNull);
    expect(selectedSource!.server, 'vidstreaming');
    expect(selectedSource!.quality, '720p');
  });

  testWidgets('PlayerSourceCard displays error message when resolution fails', (tester) async {
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

    expect(find.text('Error de conexión con el proveedor'), findsOneWidget);

    // Tapping card triggers retry
    await tester.tap(find.byType(PlayerSourceCard));
    expect(reloaded, isTrue);
  });
}
