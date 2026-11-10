import 'package:flutter_test/flutter_test.dart';
import 'package:aniting/data/models/trailer_streams.dart';

void main() {
  group('TrailerStreams.fromJson', () {
    test('parses the full payload', () {
      final streams = TrailerStreams.fromJson({
        'videoId': 'aqz-KE-bpKQ',
        'title': 'Big Buck Bunny',
        'author': 'Blender',
        'duration': 635,
        'muxedUrl': 'https://x/muxed',
        'muxedHeight': 360,
        'videoUrl': 'https://x/video',
        'videoHeight': 1080,
        'audioUrl': 'https://x/audio',
        'audioCodec': 'mp4a.40.2',
        'expiresAt': '2026-11-05T02:30:00Z',
        'resolutionMs': 8568,
        'cached': false,
      });

      expect(streams.videoId, 'aqz-KE-bpKQ');
      expect(streams.duration, 635);
      expect(streams.videoHeight, 1080);
      expect(streams.muxedHeight, 360);
      expect(streams.audioCodec, 'mp4a.40.2');
      expect(streams.resolutionMs, 8568);
      expect(streams.singleUrl, 'https://x/video');
      expect(streams.needsExternalAudio, isTrue);
      expect(streams.expiresAt, isNotNull);
      expect(streams.isExpired, isFalse);
    });

    test('falls back to the muxed url when there are no split tracks', () {
      final streams = TrailerStreams.fromJson({
        'videoId': 'abc',
        'muxedUrl': 'https://x/muxed',
        'muxedHeight': 360,
      });

      expect(streams.singleUrl, 'https://x/muxed');
      expect(streams.needsExternalAudio, isFalse);
      expect(streams.videoUrl, isNull);
    });

    test('tolerates missing and null fields', () {
      final streams = TrailerStreams.fromJson({
        'videoId': 'abc',
        'title': null,
        'duration': null,
        'cached': null,
      });

      expect(streams.title, '');
      expect(streams.duration, 0);
      expect(streams.cached, isFalse);
      expect(streams.singleUrl, isNull);
      expect(streams.expiresAt, isNull);
      expect(streams.isExpired, isFalse);
    });

    test('detects an already expired url', () {
      final streams = TrailerStreams.fromJson({
        'videoId': 'abc',
        'videoUrl': 'https://x/video',
        'expiresAt': '2020-01-01T00:00:00Z',
      });

      expect(streams.isExpired, isTrue);
    });
  });
}
