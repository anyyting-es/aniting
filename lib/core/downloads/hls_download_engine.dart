import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';

/// Reason why an HLS stream could not be downloaded.
enum HlsDownloadFailure {
  /// The stream is DRM protected (e.g. SAMPLE-AES) and cannot be decrypted.
  protected,

  /// The playlist did not contain any downloadable segment.
  noSegments,

  /// Anything else (network, malformed key, ...).
  unknown,
}

/// Raised when an HLS stream cannot be downloaded/decrypted. Carries a
/// [failure] code so the UI can show a localized message.
class HlsDownloadException implements Exception {
  final HlsDownloadFailure failure;
  final String message;

  const HlsDownloadException(this.failure, this.message);

  @override
  String toString() => message;
}

/// Reports (progress 0..1, total bytes written, bytes per second).
typedef HlsProgressCallback = void Function(
  double progress,
  int bytes,
  int bytesPerSecond,
);

class _HlsKey {
  final String method;
  final String? uri;
  final Uint8List? iv;

  const _HlsKey(this.method, this.uri, this.iv);

  bool get isEncrypted => method != 'NONE';
}

class _HlsSegment {
  final String uri;
  final int sequence;
  final int? rangeStart;
  final int? rangeLength;
  final _HlsKey? key;

  const _HlsSegment({
    required this.uri,
    required this.sequence,
    this.rangeStart,
    this.rangeLength,
    this.key,
  });
}

class _HlsMediaPlaylist {
  final List<_HlsSegment> segments;
  final String? mapUri;

  const _HlsMediaPlaylist(this.segments, this.mapUri);
}

/// Pure-Dart HLS downloader that handles the cases the old implementation
/// missed (which produced unplayable files on Android/iOS, where no ffmpeg is
/// available):
///
///  * master/variant playlists,
///  * `#EXT-X-BYTERANGE` segments,
///  * `#EXT-X-MAP` init segments (fMP4 / CMAF),
///  * `#EXT-X-KEY` AES-128 (CBC) decryption.
///
/// SAMPLE-AES (and any other DRM) is reported with a clear error instead of
/// writing hundreds of MB of encrypted garbage.
class HlsDownloadEngine {
  HlsDownloadEngine({required this.dio});

  final Dio dio;

  static const int _concurrency = 3;

  Future<void> download({
    required String url,
    required String savePath,
    required String preferredQuality,
    Map<String, String>? headers,
    required CancelToken cancelToken,
    required HlsProgressCallback onProgress,
  }) async {
    var playlistUrl = url;
    var content = await _fetchText(playlistUrl, headers, cancelToken);

    // Master playlist -> pick the best matching variant.
    if (content.contains('#EXT-X-STREAM-INF')) {
      final variant = _resolveBestVariantUrl(
        playlistUrl,
        content,
        preferredQuality,
      );
      if (variant != null) {
        playlistUrl = variant;
        content = await _fetchText(playlistUrl, headers, cancelToken);
      }
    }

    final playlist = _parseMediaPlaylist(content, playlistUrl);
    if (playlist.segments.isEmpty) {
      throw const HlsDownloadException(
        HlsDownloadFailure.noSegments,
        'No video segments found in HLS playlist',
      );
    }

    final outFile = File(savePath);
    try {
      if (await outFile.exists()) {
        await outFile.delete();
      }
    } catch (e) {
      debugPrint('[HlsDownloadEngine] Note: Could not delete existing output file: $e');
    }
    final ioSink = outFile.openWrite(mode: FileMode.writeOnly);

    final keyCache = <String, Uint8List>{};
    var completedSegments = 0;
    var totalBytesWritten = 0;
    var bytesSinceLastCheck = 0;
    var lastTime = DateTime.now();

    try {
      // fMP4 / CMAF requires the init segment before any media fragment.
      if (playlist.mapUri != null && playlist.mapUri!.isNotEmpty) {
        final mapBytes = await _fetchBytes(
          _resolve(playlistUrl, playlist.mapUri!),
          headers,
          cancelToken,
        );
        if (mapBytes != null && mapBytes.isNotEmpty) {
          ioSink.add(mapBytes);
          totalBytesWritten += mapBytes.length;
          bytesSinceLastCheck += mapBytes.length;
        }
      }

      final totalSegments = playlist.segments.length;
      for (var i = 0; i < totalSegments; i += _concurrency) {
        if (cancelToken.isCancelled) {
          throw DioException(
            requestOptions: RequestOptions(path: playlistUrl),
            type: DioExceptionType.cancel,
            message: 'Download cancelled',
          );
        }

        final batchEnd = (i + _concurrency).clamp(0, totalSegments);
        final batch = playlist.segments.sublist(i, batchEnd);

        final batchResults = await Future.wait(
          batch.map(
            (seg) =>
                _fetchSegment(seg, playlistUrl, headers, cancelToken, keyCache),
          ),
        );

        for (final bytes in batchResults) {
          if (bytes != null && bytes.isNotEmpty) {
            ioSink.add(bytes);
            totalBytesWritten += bytes.length;
            bytesSinceLastCheck += bytes.length;
          }
          completedSegments++;
        }

        final now = DateTime.now();
        final elapsed = now.difference(lastTime).inMilliseconds;
        var bytesPerSecond = 0;
        if (elapsed >= 500) {
          bytesPerSecond = (bytesSinceLastCheck / (elapsed / 1000)).round();
          bytesSinceLastCheck = 0;
          lastTime = now;
        }

        onProgress(
          (completedSegments / totalSegments).clamp(0.0, 1.0),
          totalBytesWritten,
          bytesPerSecond,
        );
      }

      await ioSink.flush();
    } finally {
      await ioSink.close();
    }
  }

  Future<Uint8List?> _fetchSegment(
    _HlsSegment segment,
    String baseUrl,
    Map<String, String>? headers,
    CancelToken cancelToken,
    Map<String, Uint8List> keyCache,
  ) async {
    final bytes = await _fetchBytes(
      _resolve(baseUrl, segment.uri),
      headers,
      cancelToken,
      range: (segment.rangeStart != null && segment.rangeLength != null)
          ? 'bytes=${segment.rangeStart}-${segment.rangeStart! + segment.rangeLength! - 1}'
          : null,
    );
    if (bytes == null || bytes.isEmpty) return bytes;

    final key = segment.key;
    if (key == null || !key.isEncrypted) return bytes;

    if (key.method == 'SAMPLE-AES') {
      throw const HlsDownloadException(
        HlsDownloadFailure.protected,
        'This source is DRM protected (SAMPLE-AES) and cannot be downloaded',
      );
    }
    if (key.method != 'AES-128' || key.uri == null || key.uri!.isEmpty) {
      throw HlsDownloadException(
        HlsDownloadFailure.protected,
        'Unsupported HLS encryption method: ${key.method}',
      );
    }

    final keyBytes = await _fetchKey(
      _resolve(baseUrl, key.uri!),
      headers,
      cancelToken,
      keyCache,
    );
    final iv = key.iv ?? sequenceIv(segment.sequence);
    return compute(_decryptSegmentInIsolate, (
      data: bytes,
      key: keyBytes,
      iv: iv,
    ));
  }

  static Uint8List _decryptSegmentInIsolate(
    ({Uint8List data, Uint8List key, Uint8List iv}) params,
  ) {
    return decryptAes128Cbc(params.data, params.key, params.iv);
  }

  Future<Uint8List> _fetchKey(
    String keyUrl,
    Map<String, String>? headers,
    CancelToken cancelToken,
    Map<String, Uint8List> cache,
  ) async {
    final cached = cache[keyUrl];
    if (cached != null) return cached;

    final bytes = await _fetchBytes(keyUrl, headers, cancelToken);
    if (bytes == null || bytes.length != 16) {
      throw const HlsDownloadException(
        HlsDownloadFailure.unknown,
        'Invalid AES-128 key received from source',
      );
    }
    cache[keyUrl] = bytes;
    return bytes;
  }

  Future<String> _fetchText(
    String url,
    Map<String, String>? headers,
    CancelToken cancelToken,
  ) async {
    final res = await dio.get<String>(
      url,
      options: Options(headers: headers, responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );
    return res.data ?? '';
  }

  Future<Uint8List?> _fetchBytes(
    String url,
    Map<String, String>? headers,
    CancelToken cancelToken, {
    String? range,
  }) async {
    final mergedHeaders = <String, String>{...?headers};
    if (range != null) {
      mergedHeaders['Range'] = range;
    }
    final res = await dio.get<List<int>>(
      url,
      options: Options(
        headers: mergedHeaders,
        responseType: ResponseType.bytes,
      ),
      cancelToken: cancelToken,
    );
    final data = res.data;
    return data == null ? null : Uint8List.fromList(data);
  }

  String _resolve(String baseUrl, String reference) {
    try {
      return Uri.parse(baseUrl).resolve(reference).toString();
    } catch (_) {
      return reference;
    }
  }

  // ---------------------------------------------------------------------------
  // Playlist parsing
  // ---------------------------------------------------------------------------

  _HlsMediaPlaylist _parseMediaPlaylist(String content, String baseUrl) {
    final lines = const LineSplitter().convert(content);
    final segments = <_HlsSegment>[];
    var mediaSequence = 0;
    var index = 0;
    _HlsKey? currentKey;
    String? mapUri;
    int? pendingLength;
    int? pendingOffset;

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.startsWith('#EXT-X-MEDIA-SEQUENCE:')) {
        mediaSequence =
            int.tryParse(line.substring(line.indexOf(':') + 1).trim()) ?? 0;
      } else if (line.startsWith('#EXT-X-KEY:')) {
        currentKey = _parseKey(line.substring(line.indexOf(':') + 1));
      } else if (line.startsWith('#EXT-X-MAP:')) {
        mapUri = _attr(line.substring(line.indexOf(':') + 1), 'URI');
      } else if (line.startsWith('#EXT-X-BYTERANGE:')) {
        final value = line.substring(line.indexOf(':') + 1).trim();
        final parts = value.split('@');
        pendingLength = int.tryParse(parts[0].trim());
        if (parts.length > 1) {
          pendingOffset = int.tryParse(parts[1].trim());
        }
      } else if (line.startsWith('#')) {
        continue;
      } else {
        segments.add(
          _HlsSegment(
            uri: line,
            sequence: mediaSequence + index,
            key: currentKey,
            rangeStart: pendingOffset,
            rangeLength: pendingLength,
          ),
        );
        index++;
        pendingLength = null;
        pendingOffset = null;
      }
    }

    return _HlsMediaPlaylist(segments, mapUri);
  }

  _HlsKey _parseKey(String attributes) {
    final method = (_attr(attributes, 'METHOD') ?? 'NONE').toUpperCase();
    if (method == 'NONE') return const _HlsKey('NONE', null, null);

    final uri = _attr(attributes, 'URI');
    final ivHex = _attr(attributes, 'IV');
    Uint8List? iv;
    if (ivHex != null && ivHex.toLowerCase().startsWith('0x')) {
      iv = _hexToBytes(ivHex.substring(2));
    }
    return _HlsKey(method, uri, iv);
  }

  String? _attr(String attributes, String name) {
    final match = RegExp('$name=("[^"]*"|[^,]*)').firstMatch(attributes);
    if (match == null) return null;
    var value = match.group(1) ?? '';
    if (value.length >= 2 && value.startsWith('"') && value.endsWith('"')) {
      value = value.substring(1, value.length - 1);
    }
    return value.trim();
  }

  String? _resolveBestVariantUrl(
    String baseUrl,
    String masterContent,
    String preferredQuality,
  ) {
    final lines = const LineSplitter().convert(masterContent);
    String? matchedUrl;
    String? fallbackUrl;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-STREAM-INF') && i + 1 < lines.length) {
        final nextLine = lines[i + 1].trim();
        if (nextLine.isNotEmpty && !nextLine.startsWith('#')) {
          final resolved = _resolve(baseUrl, nextLine);
          fallbackUrl ??= resolved;
          if (preferredQuality.isNotEmpty &&
              line.toLowerCase().contains(preferredQuality.toLowerCase())) {
            matchedUrl = resolved;
            break;
          }
        }
      }
    }

    return matchedUrl ?? fallbackUrl;
  }

  // ---------------------------------------------------------------------------
  // AES-128 (CBC) decryption
  // ---------------------------------------------------------------------------

  /// Decrypts [data] (AES-128-CBC) and strips the PKCS7 padding. Exposed for
  /// testing.
  static Uint8List decryptAes128Cbc(
    Uint8List data,
    Uint8List key,
    Uint8List iv,
  ) {
    if (key.length != 16) {
      throw const HlsDownloadException(
        HlsDownloadFailure.unknown,
        'Invalid AES-128 key length',
      );
    }
    if (iv.length != 16) {
      throw const HlsDownloadException(
        HlsDownloadFailure.unknown,
        'Invalid AES-128 IV length',
      );
    }
    if (data.isEmpty) return data;

    try {
      final cipher =
          PaddedBlockCipherImpl(PKCS7Padding(), CBCBlockCipher(AESEngine()))
            ..init(
              false,
              PaddedBlockCipherParameters<ParametersWithIV<KeyParameter>, Null>(
                ParametersWithIV<KeyParameter>(KeyParameter(key), iv),
                null,
              ),
            );
      return cipher.process(data);
    } catch (_) {
      // Some servers use non-standard padding: fall back to raw CBC blocks.
      final cipher = CBCBlockCipher(AESEngine())
        ..init(false, ParametersWithIV<KeyParameter>(KeyParameter(key), iv));
      final out = Uint8List(data.length);
      for (var offset = 0; offset + 16 <= data.length; offset += 16) {
        cipher.processBlock(data, offset, out, offset);
      }
      return out;
    }
  }

  /// 128-bit big-endian IV derived from a media [sequence] (used when the
  /// `#EXT-X-KEY` tag carries no explicit `IV`). Exposed for testing.
  static Uint8List sequenceIv(int sequence) {
    final iv = Uint8List(16);
    var value = sequence;
    for (var i = 15; i >= 0 && value > 0; i--) {
      iv[i] = value & 0xff;
      value >>= 8;
    }
    return iv;
  }

  Uint8List _hexToBytes(String hex) {
    final clean = hex.length.isOdd ? '0$hex' : hex;
    final out = Uint8List(clean.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(clean.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
