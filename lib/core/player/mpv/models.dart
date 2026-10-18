final RegExp _httpStatusPattern = RegExp(r'\b(?:HTTP error |Response code: )(\d{3})\b');

const Set<int> fatalPlaybackHttpStatuses = {403, 404, 500};

class PlayerInitializationException implements Exception {
  const PlayerInitializationException();

  @override
  String toString() => 'PlayerInitializationException';
}

class BufferRange {
  final Duration start;
  final Duration end;

  const BufferRange({required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BufferRange &&
          runtimeType == other.runtimeType &&
          start == other.start &&
          end == other.end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'BufferRange(start: $start, end: $end)';
}

class PlayerError {
  final String message;
  final String? cause;

  const PlayerError(this.message, {this.cause});

  static const String serverHttp500 = 'server-http-500';
  static const String serverHttp404 = 'server-http-404';
  static const String serverHttp503 = 'server-http-503';
  static const String playerInitFailed = 'player-init-failed';
  static const String openTimedOut = 'open-timed-out';
  static const String streamInitFailed = 'stream-init-failed';
  static const String audioOutputFailed = 'audio-output-failed';

  static int? httpStatusFromLog(String logText) {
    final match = _httpStatusPattern.firstMatch(logText);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  @override
  String toString() => message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlayerError &&
          runtimeType == other.runtimeType &&
          message == other.message &&
          cause == other.cause;

  @override
  int get hashCode => Object.hash(message, cause);
}

enum PlayerLogLevel { fatal, error, warn, info, verbose, debug, trace }

enum AudioChannelLimit {
  original,
  surround51,
  stereo;

  static List<AudioChannelLimit> available({required bool exoPlayer}) =>
      exoPlayer ? const [original, stereo] : values;
}

class AudioTrack {
  final String id;
  final String? title;
  final String? language;
  final String? codec;
  final String? codecProfile;
  final int? channels;
  final int? sampleRate;
  final int? bitrate;
  final bool isDefault;
  final bool isForced;

  const AudioTrack({
    required this.id,
    this.title,
    this.language,
    this.codec,
    this.codecProfile,
    this.channels,
    this.sampleRate,
    this.bitrate,
    this.isDefault = false,
    this.isForced = false,
  });

  static const auto = AudioTrack(id: 'auto', title: 'Auto');
  static const off = AudioTrack(id: 'no', title: 'Off');

  int? get channelsCount => channels;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTrack &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AudioTrack(id: $id, title: $title, lang: $language)';
}

class SubtitleTrack {
  final String id;
  final String? title;
  final String? language;
  final String? codec;
  final bool isDefault;
  final bool isForced;
  final bool isExternal;
  final bool isContainer;
  final String? uri;

  const SubtitleTrack({
    required this.id,
    this.title,
    this.language,
    this.codec,
    this.isDefault = false,
    this.isForced = false,
    this.isExternal = false,
    this.isContainer = false,
    this.uri,
  });

  factory SubtitleTrack.uri(
    String uri, {
    String? title,
    String? language,
    String? codec,
    bool isDefault = false,
    bool isForced = false,
    bool isContainer = false,
  }) =>
      SubtitleTrack(
        id: 'external:$uri',
        title: title,
        language: language,
        codec: codec,
        isDefault: isDefault,
        isForced: isForced,
        isExternal: true,
        isContainer: isContainer,
        uri: uri,
      );

  static const auto = SubtitleTrack(id: 'auto', title: 'Auto');
  static const off = SubtitleTrack(id: 'no', title: 'Off');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SubtitleTrack &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubtitleTrack(id: $id, title: $title, lang: $language)';
}

class Tracks {
  final List<AudioTrack> audio;
  final List<SubtitleTrack> subtitle;

  const Tracks({
    this.audio = const <AudioTrack>[],
    this.subtitle = const <SubtitleTrack>[],
  });

  @override
  String toString() => 'Tracks(audio: ${audio.length}, subtitle: ${subtitle.length})';
}

class TrackSelection {
  final AudioTrack? audio;
  final SubtitleTrack? subtitle;
  final SubtitleTrack? secondarySubtitle;

  const TrackSelection({
    this.audio,
    this.subtitle,
    this.secondarySubtitle,
  });

  TrackSelection copyWith({
    AudioTrack? audio,
    SubtitleTrack? subtitle,
    SubtitleTrack? secondarySubtitle,
  }) {
    return TrackSelection(
      audio: audio ?? this.audio,
      subtitle: subtitle ?? this.subtitle,
      secondarySubtitle: secondarySubtitle ?? this.secondarySubtitle,
    );
  }

  @override
  String toString() => 'TrackSelection(audio: $audio, sub: $subtitle, secSub: $secondarySubtitle)';
}

class AudioDevice {
  final String name;
  final String description;

  const AudioDevice({required this.name, this.description = ''});

  static const auto = AudioDevice(name: 'auto', description: 'Auto');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioDevice &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'AudioDevice(name: $name, desc: $description)';
}

class PlayerLog {
  final PlayerLogLevel level;
  final String prefix;
  final String text;

  const PlayerLog({
    required this.level,
    required this.prefix,
    required this.text,
  });

  @override
  String toString() => '[$prefix] ${level.name}: $text';
}

class Media {
  final String uri;
  final Map<String, String>? headers;
  final Duration? start;

  const Media(this.uri, {this.headers, this.start});

  @override
  String toString() => 'Media($uri, start: $start)';
}
