import 'dart:async';
import 'dart:io' show Platform;
import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

/// Service implementing Linux MPRIS D-Bus specification (org.mpris.MediaPlayer2 and org.mpris.MediaPlayer2.Player).
/// Allows Linux desktop media keys, sound applets, GNOME Shell, KDE Plasma, and playerctl to control media playback.
class MprisService {
  static final MprisService instance = MprisService._();

  MprisService._();

  DBusClient? _client;
  _MprisDBusObject? _object;
  bool _initialized = false;

  VoidCallback? onPlay;
  VoidCallback? onPause;
  VoidCallback? onPlayPause;
  VoidCallback? onStop;
  VoidCallback? onNext;
  VoidCallback? onPrevious;
  void Function(Duration offset)? onSeek;
  void Function(Duration position)? onSetPosition;

  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String _title = '';
  String _artist = '';
  String _album = '';
  String _artUrl = '';

  Future<void> init() async {
    if (!Platform.isLinux || _initialized) return;

    try {
      _client = DBusClient.session();
      _object = _MprisDBusObject(this);
      await _client!.registerObject(_object!);
      final res = await _client!.requestName('org.mpris.MediaPlayer2.aniting');
      if (res != DBusRequestNameReply.primaryOwner && res != DBusRequestNameReply.alreadyOwner) {
        debugPrint('[MprisService] Could not acquire primary owner for org.mpris.MediaPlayer2.aniting');
      }
      _initialized = true;
    } catch (e) {
      debugPrint('[MprisService] Failed to initialize MPRIS: $e');
    }
  }

  void updateMetadata({
    required String title,
    String? artist,
    String? album,
    String? artUrl,
    Duration? duration,
  }) {
    if (!Platform.isLinux) return;
    _title = title;
    _artist = artist ?? '';
    _album = album ?? '';
    _artUrl = artUrl ?? '';
    if (duration != null && duration > Duration.zero) {
      _duration = duration;
    }
    _object?.notifyMetadataChanged();
  }

  DateTime _lastPositionEmission = DateTime.fromMillisecondsSinceEpoch(0);

  void updatePlaybackState({
    required bool isPlaying,
    required Duration position,
    Duration? duration,
  }) {
    if (!Platform.isLinux) return;
    final statusChanged = _isPlaying != isPlaying;
    _isPlaying = isPlaying;
    _position = position;
    if (duration != null && duration > Duration.zero) {
      _duration = duration;
    }

    if (statusChanged) {
      _object?.notifyPlaybackStatusChanged();
    } else {
      // Throttle position notifications to at most once per 2 seconds
      final now = DateTime.now();
      if (now.difference(_lastPositionEmission).inSeconds >= 2) {
        _lastPositionEmission = now;
        _object?.notifyPositionChanged();
      }
    }
  }

  void reset() {
    if (!Platform.isLinux) return;
    _isPlaying = false;
    _position = Duration.zero;
    _duration = Duration.zero;
    _title = '';
    _artist = '';
    _album = '';
    _artUrl = '';
    onPlay = null;
    onPause = null;
    onPlayPause = null;
    onStop = null;
    onNext = null;
    onPrevious = null;
    onSeek = null;
    onSetPosition = null;
    _object?.notifyPlaybackStatusChanged();
  }

  Future<void> dispose() async {
    if (!Platform.isLinux) return;
    reset();
    try {
      if (_client != null) {
        await _client!.close();
        _client = null;
      }
    } catch (_) {}
    _initialized = false;
  }
}

class _MprisDBusObject extends DBusObject {
  final MprisService _service;

  _MprisDBusObject(this._service) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  @override
  List<DBusIntrospectInterface> introspect() {
    return [
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2',
        methods: [
          DBusIntrospectMethod('Raise'),
          DBusIntrospectMethod('Quit'),
        ],
        properties: [
          DBusIntrospectProperty('CanQuit', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanRaise', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('HasTrackList', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('Identity', DBusSignature('s'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('SupportedUriSchemes', DBusSignature('as'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('SupportedMimeTypes', DBusSignature('as'), access: DBusPropertyAccess.read),
        ],
      ),
      DBusIntrospectInterface(
        'org.mpris.MediaPlayer2.Player',
        methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod('Seek', args: [DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Offset')]),
          DBusIntrospectMethod('SetPosition', args: [
            DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_, name: 'TrackId'),
            DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Position'),
          ]),
        ],
        properties: [
          DBusIntrospectProperty('PlaybackStatus', DBusSignature('s'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('LoopStatus', DBusSignature('s'), access: DBusPropertyAccess.readwrite),
          DBusIntrospectProperty('Rate', DBusSignature('d'), access: DBusPropertyAccess.readwrite),
          DBusIntrospectProperty('Shuffle', DBusSignature('b'), access: DBusPropertyAccess.readwrite),
          DBusIntrospectProperty('Metadata', DBusSignature('a{sv}'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('Volume', DBusSignature('d'), access: DBusPropertyAccess.readwrite),
          DBusIntrospectProperty('Position', DBusSignature('x'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('MinimumRate', DBusSignature('d'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('MaximumRate', DBusSignature('d'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanGoNext', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanGoPrevious', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanPlay', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanPause', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanSeek', DBusSignature('b'), access: DBusPropertyAccess.read),
          DBusIntrospectProperty('CanControl', DBusSignature('b'), access: DBusPropertyAccess.read),
        ],
      ),
    ];
  }

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall methodCall) async {
    if (methodCall.interface == 'org.mpris.MediaPlayer2') {
      switch (methodCall.name) {
        case 'Raise':
          try {
            await windowManager.show();
            await windowManager.focus();
          } catch (_) {}
          return DBusMethodSuccessResponse();
        case 'Quit':
          try {
            await windowManager.close();
          } catch (_) {}
          return DBusMethodSuccessResponse();
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    }

    if (methodCall.interface == 'org.mpris.MediaPlayer2.Player') {
      switch (methodCall.name) {
        case 'Play':
          _service.onPlay?.call();
          return DBusMethodSuccessResponse();
        case 'Pause':
          _service.onPause?.call();
          return DBusMethodSuccessResponse();
        case 'PlayPause':
          _service.onPlayPause?.call();
          return DBusMethodSuccessResponse();
        case 'Stop':
          _service.onStop?.call();
          return DBusMethodSuccessResponse();
        case 'Next':
          _service.onNext?.call();
          return DBusMethodSuccessResponse();
        case 'Previous':
          _service.onPrevious?.call();
          return DBusMethodSuccessResponse();
        case 'Seek':
          if (methodCall.values.isNotEmpty && methodCall.values.first is DBusInt64) {
            final offsetMicro = (methodCall.values.first as DBusInt64).value;
            _service.onSeek?.call(Duration(microseconds: offsetMicro));
          }
          return DBusMethodSuccessResponse();
        case 'SetPosition':
          if (methodCall.values.length >= 2 && methodCall.values[1] is DBusInt64) {
            final posMicro = (methodCall.values[1] as DBusInt64).value;
            _service.onSetPosition?.call(Duration(microseconds: posMicro));
          }
          return DBusMethodSuccessResponse();
        default:
          return DBusMethodErrorResponse.unknownMethod();
      }
    }

    return DBusMethodErrorResponse.unknownInterface();
  }

  DBusValue _buildMetadataDict() {
    final metadata = <String, DBusValue>{
      'mpris:trackid': DBusObjectPath('/org/mpris/MediaPlayer2/Track/1'),
      'mpris:length': DBusInt64(_service._duration.inMicroseconds),
      'xesam:title': DBusString(_service._title.isNotEmpty ? _service._title : 'Sin título'),
    };
    if (_service._artist.isNotEmpty) {
      metadata['xesam:artist'] = DBusArray.string([_service._artist]);
    }
    if (_service._album.isNotEmpty) {
      metadata['xesam:album'] = DBusString(_service._album);
    }
    if (_service._artUrl.isNotEmpty) {
      metadata['mpris:artUrl'] = DBusString(_service._artUrl);
    }
    return DBusDict.stringVariant(metadata);
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    if (interface == 'org.mpris.MediaPlayer2') {
      switch (name) {
        case 'CanQuit':
          return DBusGetPropertyResponse(const DBusBoolean(false));
        case 'CanRaise':
          return DBusGetPropertyResponse(const DBusBoolean(true));
        case 'HasTrackList':
          return DBusGetPropertyResponse(const DBusBoolean(false));
        case 'Identity':
          return DBusGetPropertyResponse(const DBusString('aniting'));
        case 'SupportedUriSchemes':
          return DBusGetPropertyResponse(DBusArray.string(['file', 'http', 'https']));
        case 'SupportedMimeTypes':
          return DBusGetPropertyResponse(DBusArray.string(['video/mp4', 'video/x-matroska', 'video/webm']));
        default:
          return DBusMethodErrorResponse.unknownProperty();
      }
    }

    if (interface == 'org.mpris.MediaPlayer2.Player') {
      switch (name) {
        case 'PlaybackStatus':
          final status = _service._isPlaying ? 'Playing' : (_service._title.isNotEmpty ? 'Paused' : 'Stopped');
          return DBusGetPropertyResponse(DBusString(status));
        case 'LoopStatus':
          return DBusGetPropertyResponse(const DBusString('None'));
        case 'Rate':
          return DBusGetPropertyResponse(const DBusDouble(1.0));
        case 'Shuffle':
          return DBusGetPropertyResponse(const DBusBoolean(false));
        case 'Metadata':
          return DBusGetPropertyResponse(_buildMetadataDict());
        case 'Volume':
          return DBusGetPropertyResponse(const DBusDouble(1.0));
        case 'Position':
          return DBusGetPropertyResponse(DBusInt64(_service._position.inMicroseconds));
        case 'MinimumRate':
        case 'MaximumRate':
          return DBusGetPropertyResponse(const DBusDouble(1.0));
        case 'CanGoNext':
        case 'CanGoPrevious':
        case 'CanPlay':
        case 'CanPause':
        case 'CanSeek':
        case 'CanControl':
          return DBusGetPropertyResponse(const DBusBoolean(true));
        default:
          return DBusMethodErrorResponse.unknownProperty();
      }
    }

    return DBusMethodErrorResponse.unknownProperty();
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async {
    final properties = <String, DBusValue>{};
    if (interface == 'org.mpris.MediaPlayer2') {
      properties['CanQuit'] = const DBusBoolean(false);
      properties['CanRaise'] = const DBusBoolean(true);
      properties['HasTrackList'] = const DBusBoolean(false);
      properties['Identity'] = const DBusString('aniting');
      properties['SupportedUriSchemes'] = DBusArray.string(['file', 'http', 'https']);
      properties['SupportedMimeTypes'] = DBusArray.string(['video/mp4', 'video/x-matroska', 'video/webm']);
    } else if (interface == 'org.mpris.MediaPlayer2.Player') {
      final status = _service._isPlaying ? 'Playing' : (_service._title.isNotEmpty ? 'Paused' : 'Stopped');
      properties['PlaybackStatus'] = DBusString(status);
      properties['LoopStatus'] = const DBusString('None');
      properties['Rate'] = const DBusDouble(1.0);
      properties['Shuffle'] = const DBusBoolean(false);
      properties['Metadata'] = _buildMetadataDict();
      properties['Volume'] = const DBusDouble(1.0);
      properties['Position'] = DBusInt64(_service._position.inMicroseconds);
      properties['MinimumRate'] = const DBusDouble(1.0);
      properties['MaximumRate'] = const DBusDouble(1.0);
      properties['CanGoNext'] = const DBusBoolean(true);
      properties['CanGoPrevious'] = const DBusBoolean(true);
      properties['CanPlay'] = const DBusBoolean(true);
      properties['CanPause'] = const DBusBoolean(true);
      properties['CanSeek'] = const DBusBoolean(true);
      properties['CanControl'] = const DBusBoolean(true);
    }
    return DBusGetAllPropertiesResponse(properties);
  }

  void notifyPlaybackStatusChanged() {
    final status = _service._isPlaying ? 'Playing' : (_service._title.isNotEmpty ? 'Paused' : 'Stopped');
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'PlaybackStatus': DBusString(status),
        'Position': DBusInt64(_service._position.inMicroseconds),
      },
    );
  }

  void notifyMetadataChanged() {
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'Metadata': _buildMetadataDict(),
      },
    );
  }

  void notifyPositionChanged() {
    emitPropertiesChanged(
      'org.mpris.MediaPlayer2.Player',
      changedProperties: {
        'Position': DBusInt64(_service._position.inMicroseconds),
      },
    );
  }
}
