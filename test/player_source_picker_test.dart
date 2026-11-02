import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:g1455/g1455.dart';

import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/i18n/translations/es.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/widgets/player/dialogs/player_source_picker.dart';

void main() {
  testWidgets('source picker loads provider sources and returns a selection',
      (tester) async {
    final providers = [
      const OnlinestreamProvider(
        id: 'torrentio',
        name: 'Torrentio',
        type: OnlinestreamProviderType.tmdb,
      ),
      const OnlinestreamProvider(
        id: 'vidsrc',
        name: 'VidSrc TMDB',
        type: OnlinestreamProviderType.tmdb,
      ),
    ];

    final loaded = <String>[];
    OnlinestreamProvider? selectedProvider;
    OnlinestreamVideoSource? selectedSource;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          translationsProvider.overrideWithValue(const SpanishTranslations()),
        ],
        child: MaterialApp(
          builder: (context, child) => GlassHost(child: child!),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showPlayerSourcePicker(
                    context,
                    title: 'Frieren',
                    episodeTitle: 'Episodio 1',
                    providers: providers,
                    initialProviderId: 'torrentio',
                    loadSources: (providerId) async {
                      loaded.add(providerId);
                      if (providerId == 'torrentio') {
                        return const [
                          OnlinestreamVideoSource(
                            server: 'Torrentio',
                            url: 'magnet:?xt=urn:btih:aaa',
                            quality: '1080p',
                            label: 'episode.01.mkv',
                            type: 'torrent',
                            infoHash: 'aaa',
                            seeders: 27,
                            size: 3521873183,
                            sizeFormatted: '3.28 GB',
                            languages: ['EN', 'ES'],
                            codec: 'HEVC',
                            indexer: 'NyaaSi',
                          ),
                        ];
                      }
                      return const [
                        OnlinestreamVideoSource(
                          server: 'VidSrc',
                          url: 'https://example.com/master.m3u8',
                          quality: '720p',
                          type: 'm3u8',
                        ),
                      ];
                    },
                    onSourceSelected: (provider, source) {
                      selectedProvider = provider;
                      selectedSource = source;
                    },
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(loaded, ['torrentio']);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('TORRENT'), findsOneWidget);
    expect(find.text('HEVC'), findsOneWidget);
    expect(find.text('👤 27'), findsOneWidget);
    expect(find.textContaining('3.28 GB'), findsOneWidget);

    await tester.tap(find.text('VidSrc TMDB'));
    await tester.pumpAndSettle();

    expect(loaded, ['torrentio', 'vidsrc']);
    expect(find.text('720p'), findsOneWidget);
    expect(find.text('TORRENT'), findsNothing);

    await tester.tap(find.text('720p'));
    await tester.pumpAndSettle();

    expect(selectedProvider?.id, 'vidsrc');
    expect(selectedSource?.quality, '720p');
  });
}
