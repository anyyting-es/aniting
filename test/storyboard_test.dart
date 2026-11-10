import 'dart:ui' show Rect, Size;

import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/presentation/widgets/player/services/seek_preview_service.dart';

const _realVtt = '''
WEBVTT

00:00:00.000 --> 00:00:03.000
storyboard.webp#xywh=0,0,180,101

00:00:03.000 --> 00:00:06.000
storyboard.webp#xywh=180,0,180,101

00:00:06.000 --> 00:00:09.000
https://cdn.example/sheet2.webp#xywh=0,101,180,101
''';

void main() {
  group('parseStoryboard', () {
    test('parses timing, tile and resolves relative urls', () {
      final cues = parseStoryboard(
        _realVtt,
        'https://seiryuu.vid-cdn.xyz/abc/storyboard.vtt',
      );

      expect(cues.length, 3);
      expect(cues.first.start, Duration.zero);
      expect(cues.first.end, const Duration(seconds: 3));
      expect(cues.first.tile, const Rect.fromLTRB(0, 0, 180, 101));
      expect(
        cues.first.imageUrl,
        'https://seiryuu.vid-cdn.xyz/abc/storyboard.webp',
      );
      // Absolute urls are kept as they are.
      expect(cues.last.imageUrl, 'https://cdn.example/sheet2.webp');
    });

    test('derives the sprite sheet size from the tiles', () {
      final cues = parseStoryboard(
        _realVtt,
        'https://seiryuu.vid-cdn.xyz/abc/storyboard.vtt',
      );
      // widest tile ends at x=360, tallest at y=202.
      expect(cues.first.sheet.width, 360);
      expect(cues.first.sheet.height, 202);
    });

    test('accepts cues without #xywh (whole image per cue)', () {
      final cues = parseStoryboard(
        'WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nhttps://cdn.example/one.jpg\n',
        'https://cdn.example/vtt',
      );

      expect(cues.length, 1);
      expect(cues.first.tile, Rect.zero);
      expect(cues.first.sheet, Size.zero);
    });

    test('ignores the header and empty input', () {
      expect(parseStoryboard('WEBVTT\n', 'https://x/y.vtt'), isEmpty);
      expect(parseStoryboard('', 'https://x/y.vtt'), isEmpty);
    });

    test('tolerates CRLF line endings', () {
      final cues = parseStoryboard(
        _realVtt.replaceAll('\n', '\r\n'),
        'https://a/b/c.vtt',
      );
      expect(cues.length, 3);
    });
  });

  group('cueAt', () {
    final cues = parseStoryboard(_realVtt, 'https://a/b/c.vtt');

    test('finds the cue covering the position', () {
      expect(cueAt(cues, const Duration(seconds: 1))!.tile.left, 0);
      expect(cueAt(cues, const Duration(seconds: 4))!.tile.left, 180);
      expect(cueAt(cues, const Duration(seconds: 8))!.tile.top, 101);
    });

    test('clamps past the end to the last cue', () {
      expect(cueAt(cues, const Duration(minutes: 30))!.tile.top, 101);
    });

    test('returns null on an empty storyboard', () {
      expect(cueAt(const [], const Duration(seconds: 1)), isNull);
    });
  });
}
