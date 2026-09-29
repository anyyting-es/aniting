import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

class ExoPlayerTrack {
  final String id;
  final int index;
  final String title;
  final String language;
  final bool selected;

  const ExoPlayerTrack({
    required this.id,
    required this.index,
    required this.title,
    required this.language,
    required this.selected,
  });

  factory ExoPlayerTrack.fromMap(Map<dynamic, dynamic> map) {
    return ExoPlayerTrack(
      id: map['id']?.toString() ?? '',
      index: (map['index'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? 'Track',
      language: map['language']?.toString() ?? '',
      selected: map['selected'] == true,
    );
  }
}

class ExoPlayerTracks {
  final List<ExoPlayerTrack> audio;
  final List<ExoPlayerTrack> subtitles;

  const ExoPlayerTracks({
    this.audio = const [],
    this.subtitles = const [],
  });
}

class ExoPlayerError {
  final String message;
  final int errorCode;
  final bool isCodecOrFormatError;

  const ExoPlayerError({
    required this.message,
    required this.errorCode,
    required this.isCodecOrFormatError,
  });
}

class ExoPlayerService {
  static const _methodChannel = MethodChannel('com.seanime.app/exo_player');
  static const _eventChannel = EventChannel('com.seanime.app/exo_player/events');

  StreamSubscription? _eventSub;

  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration>.broadcast();
  final _bufferController = StreamController<Duration>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _tracksController = StreamController<ExoPlayerTracks>.broadcast();
  final _cuesController = StreamController<String>.broadcast();
  final _chaptersController = StreamController<List<PlayerChapter>>.broadcast();
  final _errorController = StreamController<ExoPlayerError>.broadcast();
  final _endedController = StreamController<void>.broadcast();

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration> get durationStream => _durationController.stream;
  Stream<Duration> get bufferStream => _bufferController.stream;
  Stream<bool> get playingStream => _playingController.stream;
  Stream<bool> get bufferingStream => _bufferingController.stream;
  Stream<ExoPlayerTracks> get tracksStream => _tracksController.stream;
  Stream<String> get cuesStream => _cuesController.stream;
  Stream<List<PlayerChapter>> get chaptersStream => _chaptersController.stream;
  Stream<ExoPlayerError> get errorStream => _errorController.stream;
  Stream<void> get endedStream => _endedController.stream;

  List<PlayerChapter> _currentChapters = [];
  List<PlayerChapter> get currentChapters => _currentChapters;

  bool _isDisposed = false;

  ExoPlayerService() {
    _startListening();
  }

  void _startListening() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (data) {
        if (_isDisposed || data is! Map) return;
        final event = data['event'];
        switch (event) {
          case 'position':
            final posMs = (data['position'] as num?)?.toInt() ?? 0;
            final durMs = (data['duration'] as num?)?.toInt() ?? 0;
            final bufMs = (data['buffer'] as num?)?.toInt() ?? 0;
            _positionController.add(Duration(milliseconds: posMs));
            if (durMs > 0) {
              _durationController.add(Duration(milliseconds: durMs));
            }
            _bufferController.add(Duration(milliseconds: bufMs));
            break;
          case 'playing':
            _playingController.add(data['value'] == true);
            break;
          case 'buffering':
            _bufferingController.add(data['value'] == true);
            break;
          case 'ended':
            _endedController.add(null);
            break;
          case 'tracks':
            final rawAudio = (data['audio'] as List?) ?? [];
            final rawSubs = (data['subtitles'] as List?) ?? [];
            final audio = rawAudio
                .whereType<Map>()
                .map((m) => ExoPlayerTrack.fromMap(m))
                .toList();
            final subs = rawSubs
                .whereType<Map>()
                .map((m) => ExoPlayerTrack.fromMap(m))
                .toList();
            _tracksController.add(ExoPlayerTracks(audio: audio, subtitles: subs));
            break;
          case 'chapters':
            final rawList = (data['chapters'] as List?) ?? [];
            final List<PlayerChapter> chList = [];
            for (final item in rawList) {
              if (item is Map) {
                final idx = (item['index'] as num?)?.toInt() ?? 0;
                final title = item['title']?.toString() ?? 'Capítulo ${idx + 1}';
                final startMs = (item['startMs'] as num?)?.toInt() ?? 0;
                final endMs = (item['endMs'] as num?)?.toInt();
                chList.add(PlayerChapter(
                  index: idx,
                  title: title,
                  start: Duration(milliseconds: startMs),
                  end: endMs != null ? Duration(milliseconds: endMs) : null,
                ));
              }
            }
            _currentChapters = chList;
            _chaptersController.add(chList);
            break;
          case 'cues':
            final text = data['text']?.toString() ?? '';
            _cuesController.add(text);
            break;
          case 'error':
            final msg = data['message']?.toString() ?? 'ExoPlayer playback error';
            final code = (data['errorCode'] as num?)?.toInt() ?? 0;
            final isCodec = data['isCodecOrFormatError'] == true;
            _errorController.add(ExoPlayerError(
              message: msg,
              errorCode: code,
              isCodecOrFormatError: isCodec,
            ));
            break;
        }
      },
      onError: (err) {
        if (!_isDisposed) {
          _errorController.add(ExoPlayerError(
            message: err.toString(),
            errorCode: -1,
            isCodecOrFormatError: false,
          ));
        }
      },
    );
  }

  Future<void> initialize({int top = 0, int height = -1}) async {
    try {
      await _methodChannel.invokeMethod('initialize', {
        'top': top,
        'height': height,
      });
    } catch (e) {
      debugPrint('ExoPlayer initialize error: $e');
    }
  }

  Future<List<PlayerChapter>> getChapters() async {
    try {
      final res = await _methodChannel.invokeMethod('getChapters');
      if (res is List) {
        final List<PlayerChapter> chList = [];
        for (final item in res) {
          if (item is Map) {
            final idx = (item['index'] as num?)?.toInt() ?? 0;
            final title = item['title']?.toString() ?? 'Capítulo ${idx + 1}';
            final startMs = (item['startMs'] as num?)?.toInt() ?? 0;
            final endMs = (item['endMs'] as num?)?.toInt();
            chList.add(PlayerChapter(
              index: idx,
              title: title,
              start: Duration(milliseconds: startMs),
              end: endMs != null ? Duration(milliseconds: endMs) : null,
            ));
          }
        }
        if (chList.isNotEmpty) {
          _currentChapters = chList;
        }
        return _currentChapters;
      }
    } catch (_) {}
    return _currentChapters;
  }

  Future<void> open(
    String uri, {
    Map<String, String>? headers,
    String? mimeType,
    Duration? startPosition,
    bool autoPlay = true,
    List<Map<String, dynamic>>? subtitles,
  }) async {
    _currentChapters = [];
    try {
      await _methodChannel.invokeMethod('open', {
        'uri': uri,
        'headers': headers,
        'mimeType': mimeType,
        'startPositionMs': startPosition?.inMilliseconds ?? 0,
        'autoPlay': autoPlay,
        'subtitles': subtitles,
      });
    } catch (e) {
      debugPrint('ExoPlayer open error: $e');
      _errorController.add(ExoPlayerError(
        message: e.toString(),
        errorCode: -1,
        isCodecOrFormatError: true,
      ));
    }
  }

  Future<void> play() async {
    try {
      await _methodChannel.invokeMethod('play');
    } catch (_) {}
  }

  Future<void> pause() async {
    try {
      await _methodChannel.invokeMethod('pause');
    } catch (_) {}
  }

  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
    } catch (_) {}
  }

  Future<void> seek(Duration position) async {
    try {
      await _methodChannel.invokeMethod('seek', {
        'positionMs': position.inMilliseconds,
      });
    } catch (_) {}
  }

  Future<void> setVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setVolume', {
        'volume': volume.clamp(0.0, 1.0),
      });
    } catch (_) {}
  }

  Future<void> setRate(double rate) async {
    try {
      await _methodChannel.invokeMethod('setRate', {
        'rate': rate,
      });
    } catch (_) {}
  }

  Future<void> selectAudioTrack(int index) async {
    try {
      await _methodChannel.invokeMethod('selectAudioTrack', {
        'index': index,
      });
    } catch (_) {}
  }

  Future<void> selectSubtitleTrack(int index) async {
    try {
      await _methodChannel.invokeMethod('selectSubtitleTrack', {
        'index': index,
      });
    } catch (_) {}
  }

  Future<void> setSubtitleDelay(int delayMs) async {
    try {
      await _methodChannel.invokeMethod('setSubtitleDelay', {
        'delayMs': delayMs,
      });
    } catch (_) {}
  }

  Future<void> setVisible(bool visible) async {
    try {
      await _methodChannel.invokeMethod('setVisible', {
        'visible': visible,
      });
    } catch (_) {}
  }

  Future<void> setSurfaceBounds({int top = 0, int height = -1}) async {
    try {
      await _methodChannel.invokeMethod('setSurfaceBounds', {
        'top': top,
        'height': height,
      });
    } catch (_) {}
  }

  Future<void> setFitMode(String mode) async {
    try {
      await _methodChannel.invokeMethod('setFitMode', {
        'mode': mode,
      });
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    _eventSub?.cancel();

    try {
      await _methodChannel.invokeMethod('dispose');
    } catch (_) {}

    await _positionController.close();
    await _durationController.close();
    await _bufferController.close();
    await _playingController.close();
    await _bufferingController.close();
    await _tracksController.close();
    await _cuesController.close();
    await _chaptersController.close();
    await _errorController.close();
    await _endedController.close();
  }
}
