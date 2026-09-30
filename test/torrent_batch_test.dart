import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seanime_app/data/models/torrent_file_preview.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_batch_files_sheet.dart';

void main() {
  group('TorrentFilePreview Model Tests', () {
    test('Correctly parses from JSON and formats properties', () {
      final json = {
        'path': 'Season 1/[Group] Frieren - 02 [1080p].mkv',
        'displayPath': '[Group] Frieren - 02 [1080p].mkv',
        'displayTitle': 'Episode 2 - It Didn\'t Have to Be Magic',
        'episodeNumber': 2,
        'relativeEpisodeNumber': 2,
        'isLikely': true,
        'index': 1,
      };

      final preview = TorrentFilePreview.fromJson(json);

      expect(preview.path, 'Season 1/[Group] Frieren - 02 [1080p].mkv');
      expect(preview.displayPath, '[Group] Frieren - 02 [1080p].mkv');
      expect(preview.displayTitle, 'Episode 2 - It Didn\'t Have to Be Magic');
      expect(preview.episodeNumber, 2);
      expect(preview.isLikely, isTrue);
      expect(preview.index, 1);
      expect(preview.isVideo, isTrue);
      expect(preview.fileName, '[Group] Frieren - 02 [1080p].mkv');
    });

    test('Identifies video and non-video files properly', () {
      const videoMpv = TorrentFilePreview(
        path: 'show/ep1.mp4',
        displayPath: 'ep1.mp4',
        displayTitle: 'Ep 1',
        episodeNumber: 1,
        isLikely: false,
        index: 0,
      );
      const textFile = TorrentFilePreview(
        path: 'show/readme.txt',
        displayPath: 'readme.txt',
        displayTitle: 'Info',
        episodeNumber: -1,
        isLikely: false,
        index: 1,
      );

      expect(videoMpv.isVideo, isTrue);
      expect(textFile.isVideo, isFalse);
    });
  });

  group('TorrentBatchFilesSheet.findBestMatch Matching Algorithm Tests', () {
    final sampleFiles = [
      const TorrentFilePreview(
        path: '[Group] Show - 01 (1080p).mkv',
        displayPath: '[Group] Show - 01 (1080p).mkv',
        displayTitle: 'Episode 1',
        episodeNumber: 1,
        isLikely: false,
        index: 0,
      ),
      const TorrentFilePreview(
        path: '[Group] Show - 02 (1080p).mkv',
        displayPath: '[Group] Show - 02 (1080p).mkv',
        displayTitle: 'Episode 2',
        episodeNumber: 2,
        isLikely: true,
        index: 1,
      ),
      const TorrentFilePreview(
        path: '[Group] Show - 03 (1080p).mkv',
        displayPath: '[Group] Show - 03 (1080p).mkv',
        displayTitle: 'Episode 3',
        episodeNumber: 3,
        isLikely: false,
        index: 2,
      ),
    ];

    test('Prefers isLikely flag when present', () {
      final match = TorrentBatchFilesSheet.findBestMatch(sampleFiles, 2);
      expect(match, isNotNull);
      expect(match!.index, 1);
      expect(match.episodeNumber, 2);
      expect(match.isLikely, isTrue);
    });

    test('Matches exact episodeNumber when isLikely is false', () {
      final filesWithoutLikely = sampleFiles
          .map((f) => TorrentFilePreview(
                path: f.path,
                displayPath: f.displayPath,
                displayTitle: f.displayTitle,
                episodeNumber: f.episodeNumber,
                isLikely: false,
                index: f.index,
              ))
          .toList();

      final match = TorrentBatchFilesSheet.findBestMatch(filesWithoutLikely, 3);
      expect(match, isNotNull);
      expect(match!.index, 2);
      expect(match.episodeNumber, 3);
    });

    test('Matches via regex heuristic when episodeNumber is not parsed (-1)', () {
      final unparsedFiles = [
        const TorrentFilePreview(
          path: '[Subs] Anime S01E01 [1080p].mkv',
          displayPath: '[Subs] Anime S01E01 [1080p].mkv',
          displayTitle: '',
          episodeNumber: -1,
          isLikely: false,
          index: 0,
        ),
        const TorrentFilePreview(
          path: '[Subs] Anime S01E02 [1080p].mkv',
          displayPath: '[Subs] Anime S01E02 [1080p].mkv',
          displayTitle: '',
          episodeNumber: -1,
          isLikely: false,
          index: 1,
        ),
      ];

      final match = TorrentBatchFilesSheet.findBestMatch(unparsedFiles, 2);
      expect(match, isNotNull);
      expect(match!.index, 1);
      expect(match.displayPath, contains('E02'));
    });
  });

  group('TorrentBatchFilesSheet Widget Tests', () {
    const testTorrent = TorrentItem(
      name: '[Group] Show (Season 1) [1080p] [Batch]',
      isBatch: true,
      size: 15000000000,
      formattedSize: '14.0 GB',
    );

    final testFiles = [
      const TorrentFilePreview(
        path: '[Group] Show - 01 (1080p).mkv',
        displayPath: '[Group] Show - 01 (1080p).mkv',
        displayTitle: 'Episode 1 - Beginning',
        episodeNumber: 1,
        isLikely: false,
        index: 0,
      ),
      const TorrentFilePreview(
        path: '[Group] Show - 02 (1080p).mkv',
        displayPath: '[Group] Show - 02 (1080p).mkv',
        displayTitle: 'Episode 2 - The Path',
        episodeNumber: 2,
        isLikely: true,
        index: 1,
      ),
      const TorrentFilePreview(
        path: '[Group] Show - 03 (1080p).mkv',
        displayPath: '[Group] Show - 03 (1080p).mkv',
        displayTitle: 'Episode 3 - Climax',
        episodeNumber: 3,
        isLikely: false,
        index: 2,
      ),
    ];

    testWidgets('Pre-selects target episode automatically and allows changing selection', (tester) async {
      TorrentBatchSelectionResult? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    result = await showModalBottomSheet<TorrentBatchSelectionResult>(
                      context: context,
                      isScrollControlled: true,
                      builder: (ctx) => TorrentBatchFilesSheet(
                        torrent: testTorrent,
                        files: testFiles,
                        targetEpisodeNumber: 2,
                      ),
                    );
                  },
                  child: const Text('Open Batch'),
                );
              },
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Batch'));
      await tester.pumpAndSettle();

      // Header details
      expect(find.text('Archivos del Batch'), findsOneWidget);
      expect(find.text('3 archivos'), findsOneWidget);
      expect(find.text(testTorrent.name), findsOneWidget);

      // Verify Episode 2 is marked with 'Episodio actual' badge
      expect(find.text('Episodio actual'), findsOneWidget);
      expect(find.text('Episode 2 - The Path'), findsOneWidget);

      // Verify default confirmation button targets Episode 2
      expect(find.text('Reproducir (Episode 2 - The Path)'), findsOneWidget);

      // User switches selection to Episode 3
      await tester.tap(find.text('Episode 3 - Climax'));
      await tester.pumpAndSettle();

      // Verify button now targets Episode 3
      expect(find.text('Reproducir (Episode 3 - Climax)'), findsOneWidget);

      // Tap play button
      await tester.tap(find.text('Reproducir (Episode 3 - Climax)'));
      await tester.pumpAndSettle();

      // Sheet should be popped with chosen Episode 3
      expect(result, isNotNull);
      expect(result!.file.index, 2);
      expect(result!.file.episodeNumber, 3);
      expect(result!.useExternalPlayer, isFalse);
    });
  });
}
