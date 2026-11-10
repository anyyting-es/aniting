import 'dart:async';
import 'dart:ui' show Rect, Size;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// One cue of a WebVTT storyboard (trickplay): a rectangle inside a sprite
/// sheet, valid for a `[start, end)` window of the video.
class StoryboardCue {
  final Duration start;
  final Duration end;
  final String imageUrl;
  final Rect tile;

  /// Full sprite sheet size, derived from the largest tile of the file.
  final Size sheet;

  const StoryboardCue({
    required this.start,
    required this.end,
    required this.imageUrl,
    required this.tile,
    required this.sheet,
  });
}

/// The seek bar preview URL published by the active online source.
///
/// Extensions that support trickplay return a `thumbnails` field (AniZone's
/// `storyboard`, MegaPlay's `thumbnails` track); everything else leaves it null
/// and the slider simply draws no preview.
final ValueNotifier<String?> seekThumbnailsUrl = ValueNotifier<String?>(null);

/// Headers the sprite sheet needs (some CDNs gate on Referer).
final ValueNotifier<Map<String, String>?> seekThumbnailsHeaders =
    ValueNotifier<Map<String, String>?>(null);

/// Parsed storyboards, kept per URL for the session.
///
/// A storyboard is ~35 KB of text for a 26 minute episode, so caching every one
/// played in the session costs almost nothing.
final Map<String, List<StoryboardCue>> _storyboardCache = {};

final Dio _dio = Dio(
  BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
  ),
);

/// Loads and parses the storyboard for [url], or null when it is unavailable.
Future<List<StoryboardCue>?> loadStoryboard(
  String url, {
  Map<String, String>? headers,
}) async {
  if (url.isEmpty) return null;
  final cached = _storyboardCache[url];
  if (cached != null) return cached;

  try {
    final response = await _dio.get<String>(
      url,
      options: Options(
        responseType: ResponseType.plain,
        headers: headers,
        validateStatus: (status) => status != null && status < 400,
      ),
    );
    final body = response.data;
    if (body == null || body.isEmpty) return null;

    final cues = parseStoryboard(body, url);
    if (cues.isEmpty) return null;

    _storyboardCache[url] = cues;
    return cues;
  } catch (error) {
    debugPrint('[Storyboard] Failed to load $url: $error');
    return null;
  }
}

final RegExp _timingPattern = RegExp(
  r'^(\d+):(\d{2}):(\d{2})\.(\d{3})\s+-->\s+(\d+):(\d{2}):(\d{2})\.(\d{3})',
);
final RegExp _xywhPattern = RegExp(r'#xywh=(\d+),(\d+),(\d+),(\d+)');

/// Parses a WebVTT storyboard.
///
/// Format (AniZone / MegaPlay / Plex style):
///
/// ```
/// WEBVTT
///
/// 00:00:00.000 --> 00:00:03.000
/// storyboard.webp#xywh=0,0,180,101
/// ```
///
/// A cue without `#xywh=` means the whole image is the tile (some providers ship
/// one image per cue).
List<StoryboardCue> parseStoryboard(String body, String baseUrl) {
  final lines = body.split(RegExp(r'\r?\n'));
  final base = Uri.tryParse(baseUrl);

  final raw = <({Duration start, Duration end, String image, Rect tile})>[];
  Duration? pendingStart;
  Duration? pendingEnd;

  Duration toDuration(Match m, int offset) {
    final hours = int.parse(m.group(offset)!);
    final minutes = int.parse(m.group(offset + 1)!);
    final seconds = int.parse(m.group(offset + 2)!);
    final millis = int.parse(m.group(offset + 3)!);
    return Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
      milliseconds: millis,
    );
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    final timing = _timingPattern.firstMatch(trimmed);
    if (timing != null) {
      pendingStart = toDuration(timing, 1);
      pendingEnd = toDuration(timing, 5);
      continue;
    }

    if (pendingStart == null || pendingEnd == null) continue;
    if (trimmed.startsWith('WEBVTT') ||
        trimmed.startsWith('NOTE') ||
        trimmed.startsWith('STYLE')) {
      continue;
    }

    // Cue payload: the image reference.
    final url = base != null
        ? base.resolve(trimmed.split('#').first).toString()
        : trimmed.split('#').first;

    final xywh = _xywhPattern.firstMatch(trimmed);
    final tile = xywh != null
        ? Rect.fromLTWH(
            double.parse(xywh.group(1)!),
            double.parse(xywh.group(2)!),
            double.parse(xywh.group(3)!),
            double.parse(xywh.group(4)!),
          )
        : Rect.zero;

    raw.add((start: pendingStart, end: pendingEnd, image: url, tile: tile));
    pendingStart = null;
    pendingEnd = null;
  }

  if (raw.isEmpty) return const [];

  // Sprite sheet size = the union of every tile.
  var sheetWidth = 0.0;
  var sheetHeight = 0.0;
  for (final entry in raw) {
    if (entry.tile == Rect.zero) continue;
    if (entry.tile.right > sheetWidth) sheetWidth = entry.tile.right;
    if (entry.tile.bottom > sheetHeight) sheetHeight = entry.tile.bottom;
  }
  final sheet = sheetWidth > 0 && sheetHeight > 0
      ? Size(sheetWidth, sheetHeight)
      : Size.zero;

  return [
    for (final entry in raw)
      StoryboardCue(
        start: entry.start,
        end: entry.end,
        imageUrl: entry.image,
        tile: entry.tile,
        sheet: sheet,
      ),
  ];
}

/// The cue covering [position].
StoryboardCue? cueAt(List<StoryboardCue> cues, Duration position) {
  if (cues.isEmpty) return null;

  var low = 0;
  var high = cues.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    final cue = cues[mid];
    if (position < cue.start) {
      high = mid - 1;
    } else if (position >= cue.end) {
      low = mid + 1;
    } else {
      return cue;
    }
  }
  // Past the end: keep showing the last frame.
  return cues.last;
}

@visibleForTesting
void clearStoryboardCache() => _storyboardCache.clear();
