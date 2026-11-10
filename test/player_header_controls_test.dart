import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/data/models/torrent_models.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/providers/torrent_stream_provider.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_header_controls.dart';

class _MaterialIconPackNotifier extends IconPackNotifier {
  @override
  AppIconPack build() => AppIconPack.material;
}

class _FakeTorrentStatusNotifier extends TorrentStreamStatusNotifier {
  _FakeTorrentStatusNotifier(this.status);

  final TorrentStreamStatus? status;

  @override
  TorrentStreamStatus? build() => status;
}

Widget _buildWrapper({required Widget child, List<dynamic>? overrides}) {
  return ProviderScope(
    overrides: [
      iconPackProvider.overrideWith(_MaterialIconPackNotifier.new),
      ...?overrides?.cast(),
    ],
    child: MaterialApp(
      builder: (context, childWidget) => GlassHost(child: childWidget!),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

void main() {
  const sources = [
    OnlinestreamVideoSource(
      server: 'Vidhide',
      url: 'https://example.com/stream1.m3u8',
      quality: '1080p',
    ),
    OnlinestreamVideoSource(
      server: 'Vidstreaming',
      url: 'https://example.com/stream2.m3u8',
      quality: '720p',
    ),
  ];

  testWidgets('renders separate provider and server dropdowns', (tester) async {
    String? switchedProvider;
    OnlinestreamVideoSource? selectedSource;

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
        child: PlayerHeaderControls(
          showSource: true,
          sources: sources,
          activeSource: sources.first,
          providerName: 'gogoanime',
          isDubbed: true,
          onSelectProvider: (id) => switchedProvider = id,
          onSelectSource: (src) => selectedSource = src,
          onReloadSources: () {},
          onToggleDubbed: () {},
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // One button per choice: provider and server.
    expect(find.text('Gogoanime'), findsOneWidget);
    expect(find.text('Vidhide • 1080p'), findsOneWidget);

    // Provider dropdown groups the provider-level actions.
    await tester.tap(find.text('Gogoanime'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('AnimeFLV'), findsOneWidget);
    expect(find.text('Recargar fuentes'), findsOneWidget);
    expect(find.text('Audio: Doblado (toca para subtitulado)'), findsOneWidget);
    await tester.tap(find.text('AnimeFLV'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(switchedProvider, 'animeflv');

    // Server dropdown stays server-only: no reload or dub actions.
    await tester.tap(find.text('Vidhide • 1080p'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Vidstreaming • 720p'), findsOneWidget);
    expect(find.text('Recargar fuentes'), findsNothing);
    expect(find.text('Audio: Doblado (toca para subtitulado)'), findsNothing);
    await tester.tap(find.text('Vidstreaming • 720p'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(selectedSource?.server, 'Vidstreaming');
  });

  testWidgets('torrent streams show download, upload and seeders tile',
      (tester) async {
    await tester.pumpWidget(
      _buildWrapper(
        overrides: [
          torrentStreamStatusProvider.overrideWith(
            () => _FakeTorrentStatusNotifier(
              const TorrentStreamStatus(
                downloadSpeed: '12.3 MB/s',
                uploadSpeed: '1.2 MB/s',
                seeders: 34,
              ),
            ),
          ),
        ],
        child: const PlayerHeaderControls(isTorrentStream: true),
      ),
    );
    await tester.pump();

    expect(find.text('12.3 MB/s'), findsOneWidget);
    expect(find.text('1.2 MB/s'), findsOneWidget);
    expect(find.text('34'), findsOneWidget);
  });
}
