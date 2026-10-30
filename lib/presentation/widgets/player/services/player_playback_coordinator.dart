import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' as media_kit;
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/player/exo_player_service.dart';
import 'package:seanime_app/core/player/media_kit_player_service.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_shader_service.dart';

/// Coordinates playback with ExoPlayer on Android and media_kit elsewhere.
/// Encapsulates stream listening, track parsing, subtitle auto-selection, and automatic fallback.
class PlayerPlaybackCoordinator {
  bool isUsingExoPlayer;
  ExoPlayerService? exoService;
  MediaKitPlayerService? mediaKitService;
  SubtitleStylePrefs? currentSubtitleStyle;

  String? get videoUrl => _videoUrl;

  final PlayerShaderService shaderService;
  final AppTranslations l10n;

  // Stream event callbacks
  final ValueChanged<Duration> onPosition;
  final ValueChanged<Duration> onDuration;
  final ValueChanged<Duration> onBuffer;
  final ValueChanged<bool> onPlaying;
  final ValueChanged<bool> onBuffering;
  final VoidCallback onEnded;
  final void Function(List<UiTrack> audio, List<UiTrack> subtitles, String? selectedAudioId, String? selectedSubId) onTracks;
  final ValueChanged<String> onCues;
  final void Function(String? reason, Duration currentPos) onFallbackToMediaKit;
  final ValueChanged<List<PlayerChapter>>? onChapters;
  final String Function(String url, Map<String, String>? headers)? buildProxyUrl;

  // Subscriptions
  StreamSubscription? _exoPosSub;
  StreamSubscription? _exoDurSub;
  StreamSubscription? _exoBufSub;
  StreamSubscription? _exoPlayingSub;
  StreamSubscription? _exoBufferingSub;
  StreamSubscription? _exoTracksSub;
  StreamSubscription? _exoErrorSub;
  StreamSubscription? _exoEndedSub;
  StreamSubscription? _exoCuesSub;
  StreamSubscription? _exoChaptersSub;

  StreamSubscription? _mediaKitPosSub;
  StreamSubscription? _mediaKitDurSub;
  StreamSubscription? _mediaKitBufSub;
  StreamSubscription? _mediaKitPlayingSub;
  StreamSubscription? _mediaKitBufferingSub;
  StreamSubscription? _mediaKitTracksSub;
  StreamSubscription? _mediaKitEndedSub;
  StreamSubscription? _mediaKitErrorSub;

  Duration _currentPos = Duration.zero;

  // Stored configuration for seamless engine fallback
  String? _videoUrl;
  String? _title;
  String? _episodeTitle;
  Map<String, String>? _headers;
  Duration? _startPosition;
  List<dynamic>? _externalSubtitles;
  ShaderPreset _activeShaderPreset = ShaderPreset.none;
  bool _isOnlineStream = false;
  bool _hasRetriedDirectUrl = false;

  static String _getSubUrl(dynamic s) {
    if (s == null) return '';
    if (s is Map) return s['url']?.toString() ?? '';
    try { return (s as dynamic).url?.toString() ?? ''; } catch (_) { return ''; }
  }

  static String _getSubLanguage(dynamic s) {
    if (s == null) return '';
    if (s is Map) return s['language']?.toString() ?? '';
    try { return (s as dynamic).language?.toString() ?? ''; } catch (_) { return ''; }
  }

  static String _getSubLabel(dynamic s) {
    if (s == null) return '';
    if (s is Map) return s['label']?.toString() ?? s['language']?.toString() ?? '';
    try {
      final dyn = s as dynamic;
      return dyn.label?.toString() ?? dyn.language?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  static bool _getSubIsDefault(dynamic s) {
    if (s == null) return false;
    if (s is Map) return s['isDefault'] == true;
    try { return (s as dynamic).isDefault == true; } catch (_) { return false; }
  }

  int _resolveBestExternalSubtitleIndex(List<dynamic> subs) {
    final defaultIdx = subs.indexWhere((s) => _getSubIsDefault(s));
    if (defaultIdx >= 0) return defaultIdx;

    final isEn = l10n is EnglishTranslations;
    int findLangIdx(bool english) {
      return subs.indexWhere((s) {
        final lang = _getSubLanguage(s).toLowerCase();
        final label = _getSubLabel(s).toLowerCase();
        if (english) {
          return lang == 'en' || lang == 'eng' || label.contains('eng') || label.contains('english');
        } else {
          return lang == 'es' || lang == 'spa' || label.contains('spa') || label.contains('es') || label.contains('castellano') || label.contains('latino');
        }
      });
    }

    final primaryIdx = findLangIdx(isEn);
    if (primaryIdx >= 0) return primaryIdx;
    final secondaryIdx = findLangIdx(!isEn);
    if (secondaryIdx >= 0) return secondaryIdx;
    return 0;
  }

  PlayerPlaybackCoordinator({
    required this.isUsingExoPlayer,
    required this.shaderService,
    required this.l10n,
    required this.onPosition,
    required this.onDuration,
    required this.onBuffer,
    required this.onPlaying,
    required this.onBuffering,
    required this.onEnded,
    required this.onTracks,
    required this.onCues,
    required this.onFallbackToMediaKit,
    this.onChapters,
    this.buildProxyUrl,
  });

  /// Initialize the chosen engine and start playback
  void init({
    required String videoUrl,
    required String title,
    String? episodeTitle,
    Map<String, String>? headers,
    String? mimeType,
    Duration? startPosition,
    List<dynamic>? externalSubtitles,
    PlayerFitMode fitMode = PlayerFitMode.contain,
    ShaderPreset activeShaderPreset = ShaderPreset.none,
    bool isOnlineStream = false,
    int initialSurfaceTop = 0,
    int initialSurfaceHeight = -1,
  }) {
    _videoUrl = videoUrl;
    _title = title;
    _episodeTitle = episodeTitle;
    _headers = headers;
    _startPosition = startPosition;
    _externalSubtitles = externalSubtitles;
    _activeShaderPreset = activeShaderPreset;
    _isOnlineStream = isOnlineStream;

    if (isUsingExoPlayer && Platform.isAndroid) {
      _initExo(
        videoUrl: videoUrl,
        headers: headers,
        mimeType: mimeType,
        startPosition: startPosition,
        externalSubtitles: externalSubtitles,
        fitMode: fitMode,
        initialSurfaceTop: initialSurfaceTop,
        initialSurfaceHeight: initialSurfaceHeight,
      );
    } else {
      _initMediaKit(
        videoUrl: videoUrl,
        title: title,
        episodeTitle: episodeTitle,
        headers: headers,
        startPosition: startPosition,
        externalSubtitles: externalSubtitles,
        activeShaderPreset: activeShaderPreset,
        isOnlineStream: isOnlineStream,
      );
    }
  }

  void _initExo({
    required String videoUrl,
    Map<String, String>? headers,
    String? mimeType,
    Duration? startPosition,
    List<dynamic>? externalSubtitles,
    PlayerFitMode fitMode = PlayerFitMode.contain,
    int initialSurfaceTop = 0,
    int initialSurfaceHeight = -1,
  }) {
    _cancelExoSubs();
    final exo = ExoPlayerService();
    exoService = exo;

    _exoPosSub = exo.positionStream.listen((pos) {
      _currentPos = pos;
      onPosition(pos);
    });
    _exoDurSub = exo.durationStream.listen(onDuration);
    _exoBufSub = exo.bufferStream.listen(onBuffer);
    _exoPlayingSub = exo.playingStream.listen(onPlaying);
    _exoBufferingSub = exo.bufferingStream.listen(onBuffering);
    _exoEndedSub = exo.endedStream.listen((_) => onEnded());
    _exoCuesSub = exo.cuesStream.listen(onCues);
    _exoChaptersSub = exo.chaptersStream.listen((chapters) {
      if (chapters.isNotEmpty) {
        onChapters?.call(chapters);
      }
    });

    _exoTracksSub = exo.tracksStream.listen((tracks) {
      final audioList = tracks.audio.map((t) => UiTrack(
        id: t.id,
        index: t.index,
        title: t.title,
        language: t.language,
        selected: t.selected,
      )).toList();

      final subList = tracks.subtitles.map((t) => UiTrack(
        id: t.id,
        index: t.index,
        title: t.title,
        language: t.language,
        selected: t.selected,
      )).toList();

      String? selectedAudio;
      String? selectedSub;
      for (final t in audioList) {
        if (t.selected) selectedAudio = t.id;
      }
      for (final t in subList) {
        if (t.selected) selectedSub = t.id;
      }

      // Intelligent subtitle auto-selection if none active
      if (selectedSub == null && subList.isNotEmpty) {
        UiTrack? trackToSelect;

        // 1. External default
        if (externalSubtitles != null) {
          final def = externalSubtitles.where((s) => _getSubIsDefault(s)).firstOrNull;
          if (def != null) {
            final lang = _getSubLanguage(def).toLowerCase();
            trackToSelect = subList.where((t) =>
              t.language.toLowerCase() == lang || t.title.toLowerCase().contains(lang)
            ).firstOrNull;
          }
        }

        final isEn = l10n is EnglishTranslations;

        UiTrack? findSpanish() {
          return subList.where((t) {
            final l = t.language.toLowerCase();
            final title = t.title.toLowerCase();
            return l == 'es' || l == 'spa' || l.contains('es') ||
                   title.contains('spa') || title.contains('es') ||
                   title.contains('castellano') || title.contains('latino') ||
                   title.contains('español');
          }).firstOrNull;
        }

        UiTrack? findEnglish() {
          return subList.where((t) {
            final l = t.language.toLowerCase();
            final title = t.title.toLowerCase();
            return l == 'en' || l == 'eng' || title.contains('eng') || title.contains('english');
          }).firstOrNull;
        }

        if (isEn) {
          trackToSelect ??= findEnglish();
          trackToSelect ??= findSpanish();
        } else {
          trackToSelect ??= findSpanish();
          trackToSelect ??= findEnglish();
        }

        // 4. First available
        trackToSelect ??= subList.first;

        selectedSub = trackToSelect.id;
        exo.selectSubtitleTrack(trackToSelect.index);
      }

      onTracks(audioList, subList, selectedAudio, selectedSub);
    });

    _exoErrorSub = exo.errorStream.listen((err) {
      debugPrint('[PlayerCoordinator] ExoPlayer error: ${err.message} (code: ${err.errorCode})');
      triggerFallbackToMediaKit(err.message);
    });

    final mime = mimeType ?? _detectMimeType(videoUrl);
    final externalSubs = externalSubtitles?.map((s) => {
      'url': _getSubUrl(s),
      'language': _getSubLanguage(s),
      'label': _getSubLabel(s).isNotEmpty ? _getSubLabel(s) : _getSubLanguage(s),
      'isDefault': _getSubIsDefault(s),
    }).toList();

    exo.initialize(top: initialSurfaceTop, height: initialSurfaceHeight).then((_) {
      if (exoService != exo) return;
      exo.setFitMode(fitMode.name);
      if (currentSubtitleStyle != null) {
        applySubtitleStyle(currentSubtitleStyle!);
      }
      if (videoUrl.isNotEmpty) {
        exo.open(
          videoUrl,
          headers: headers,
          mimeType: mime,
          startPosition: startPosition,
          autoPlay: true,
          subtitles: externalSubs,
        );
      }
    });
  }

  void _initMediaKit({
    required String videoUrl,
    required String title,
    String? episodeTitle,
    Map<String, String>? headers,
    Duration? startPosition,
    List<dynamic>? externalSubtitles,
    ShaderPreset activeShaderPreset = ShaderPreset.none,
    bool isOnlineStream = false,
  }) {
    _cancelMediaKitSubs();
    final service = MediaKitPlayerService();
    mediaKitService = service;
    if (currentSubtitleStyle != null) {
      service.applySubtitleStyle(currentSubtitleStyle!);
    }

    _mediaKitPosSub = service.player.stream.position.listen((pos) {
      _currentPos = pos;
      onPosition(pos);
    });
    _mediaKitDurSub = service.player.stream.duration.listen(onDuration);
    _mediaKitBufSub = service.player.stream.buffer.listen(onBuffer);
    _mediaKitPlayingSub = service.player.stream.playing.listen(onPlaying);
    _mediaKitBufferingSub = service.player.stream.buffering.listen(onBuffering);
    _mediaKitEndedSub = service.player.stream.completed.listen((completed) {
      if (completed) onEnded();
    });
    _mediaKitErrorSub = service.player.stream.error.listen((errorMsg) {
      if (!_hasRetriedDirectUrl &&
          _isOnlineStream &&
          _videoUrl != null &&
          _videoUrl!.isNotEmpty) {
        _hasRetriedDirectUrl = true;
        service.open(
          _videoUrl!,
          title: _title,
          episodeTitle: _episodeTitle,
          startPosition: _currentPos != Duration.zero ? _currentPos : (_startPosition ?? Duration.zero),
          httpHeaders: _headers,
        );
      }
    });

    _mediaKitTracksSub = service.player.stream.tracks.listen((tracks) {
      final currentSub = service.player.state.track.subtitle;
      final currentAudio = service.player.state.track.audio;

      final audioList = tracks.audio
          .where((t) => t.id != 'no')
          .toList()
          .asMap()
          .entries
          .map((e) => UiTrack(
            id: e.value.id,
            index: e.key,
            title: e.value.id == 'auto'
                ? l10n.automatic
                : (e.value.title ?? e.value.language ?? '${l10n.audioTracks} #${e.value.id}'),
            language: e.value.language ?? '',
            selected: e.value.id == currentAudio.id,
          )).toList();

      final List<UiTrack> mergedSubs = [];

      // 1. Embedded subtitles
      for (final t in tracks.subtitle) {
        if (t.id == 'no') continue;
        final subTitle = t.id == 'auto'
            ? l10n.automatic
            : (t.title ?? t.language ?? '${l10n.subtitles} #${t.id}');
        mergedSubs.add(UiTrack(
          id: t.id,
          index: mergedSubs.length,
          title: subTitle,
          language: t.language ?? '',
          selected: t.id == currentSub.id,
        ));
      }

      // 2. External subtitles
      if (externalSubtitles != null) {
        for (int i = 0; i < externalSubtitles.length; i++) {
          final extSub = externalSubtitles[i];
          final trackId = 'ext_$i';
          final subLang = _getSubLanguage(extSub);
          final subLabel = _getSubLabel(extSub);
          final subTitle = subLabel.isNotEmpty ? subLabel : (subLang.isNotEmpty ? subLang : '${l10n.subtitles} ${i + 1}');
          final isDef = _getSubIsDefault(extSub);
          mergedSubs.add(UiTrack(
            id: trackId,
            index: 1000 + i,
            title: subTitle,
            language: subLang,
            selected: isDef,
          ));
        }
      }

      onTracks(audioList, mergedSubs, currentAudio.id, currentSub.id);
    });

    String effectiveVideoUrl = videoUrl;
    Map<String, String>? effectiveHeaders = headers;
    if (isOnlineStream && buildProxyUrl != null && videoUrl.isNotEmpty) {
      final proxied = buildProxyUrl!(videoUrl, headers);
      if (proxied != videoUrl) {
        effectiveVideoUrl = proxied;
        effectiveHeaders = null;
      }
    }

    if (effectiveVideoUrl.isNotEmpty) {
      service.open(
        effectiveVideoUrl,
        title: title,
        episodeTitle: episodeTitle,
        startPosition: startPosition,
        httpHeaders: effectiveHeaders,
      );

      // Auto-load default external subtitle if provided
      if (externalSubtitles != null && externalSubtitles.isNotEmpty) {
        final idxToUse = _resolveBestExternalSubtitleIndex(externalSubtitles);
        final subToUse = externalSubtitles[idxToUse];
        final url = _getSubUrl(subToUse);
        final lang = _getSubLanguage(subToUse);
        final label = _getSubLabel(subToUse);
        if (url.isNotEmpty) {
          service.setSubtitleTrack(media_kit.SubtitleTrack.uri(
            url,
            title: label.isNotEmpty ? label : lang,
            language: lang,
          ));
        }
      }
    }

    shaderService.applyPreset(service, activeShaderPreset);
  }

  void triggerFallbackToMediaKit([String? reason]) {
    if (!isUsingExoPlayer) return;
    final fallbackPos = _currentPos > Duration.zero ? _currentPos : (_startPosition ?? Duration.zero);
    debugPrint('[PlayerCoordinator] Triggering fallback to media_kit at $fallbackPos (reason: $reason)');
    _cancelExoSubs();
    exoService?.dispose();
    exoService = null;
    isUsingExoPlayer = false;

    // Immediately initialize and start MPV so the player continues seamlessly
    if (_videoUrl != null) {
      _initMediaKit(
        videoUrl: _videoUrl!,
        title: _title ?? '',
        episodeTitle: _episodeTitle,
        headers: _headers,
        startPosition: fallbackPos,
        externalSubtitles: _externalSubtitles,
        activeShaderPreset: _activeShaderPreset,
        isOnlineStream: _isOnlineStream,
      );
    }

    onFallbackToMediaKit(reason, fallbackPos);
  }

  void open({
    required String videoUrl,
    required String title,
    String? episodeTitle,
    Map<String, String>? headers,
    String? mimeType,
    Duration? startPosition,
    List<dynamic>? externalSubtitles,
    bool isOnlineStream = false,
  }) {
    _videoUrl = videoUrl;
    _title = title;
    _episodeTitle = episodeTitle;
    _headers = headers;
    _startPosition = startPosition;
    _externalSubtitles = externalSubtitles;
    _isOnlineStream = isOnlineStream;
    _hasRetriedDirectUrl = false;

    if (isUsingExoPlayer && exoService != null) {
      final mime = mimeType ?? _detectMimeType(videoUrl);
      final externalSubs = externalSubtitles?.map((s) => {
        'url': _getSubUrl(s),
        'language': _getSubLanguage(s),
        'label': _getSubLabel(s).isNotEmpty ? _getSubLabel(s) : _getSubLanguage(s),
        'isDefault': _getSubIsDefault(s),
      }).toList();

      exoService!.open(
        videoUrl,
        headers: headers,
        mimeType: mime,
        startPosition: startPosition ?? Duration.zero,
        autoPlay: true,
        subtitles: externalSubs,
      );
    } else if (mediaKitService != null) {
      String effectiveVideoUrl = videoUrl;
      Map<String, String>? effectiveHeaders = headers;
      if (isOnlineStream && buildProxyUrl != null && videoUrl.isNotEmpty) {
        final proxied = buildProxyUrl!(videoUrl, headers);
        if (proxied != videoUrl) {
          effectiveVideoUrl = proxied;
          effectiveHeaders = null;
        }
      }

      mediaKitService!.open(
        effectiveVideoUrl,
        title: title,
        episodeTitle: episodeTitle,
        startPosition: startPosition ?? Duration.zero,
        httpHeaders: effectiveHeaders,
      );

      if (externalSubtitles != null && externalSubtitles.isNotEmpty) {
        final idxToUse = _resolveBestExternalSubtitleIndex(externalSubtitles);
        final subToUse = externalSubtitles[idxToUse];
        final url = _getSubUrl(subToUse);
        final lang = _getSubLanguage(subToUse);
        final label = _getSubLabel(subToUse);
        if (url.isNotEmpty) {
          mediaKitService!.setSubtitleTrack(media_kit.SubtitleTrack.uri(
            url,
            title: label.isNotEmpty ? label : lang,
            language: lang,
          ));
        }
      }
    }
  }

  void play() {
    if (isUsingExoPlayer) {
      exoService?.play();
    } else {
      mediaKitService?.play();
    }
  }

  void pause() {
    if (isUsingExoPlayer) {
      exoService?.pause();
    } else {
      mediaKitService?.pause();
    }
  }

  void stop() {
    if (isUsingExoPlayer) {
      exoService?.stop();
    } else {
      mediaKitService?.stop();
    }
  }

  void seek(Duration position) {
    if (isUsingExoPlayer) {
      exoService?.seek(position);
    } else {
      mediaKitService?.seek(position);
    }
  }

  void setVolume(double volume) {
    if (isUsingExoPlayer) {
      exoService?.setVolume(volume / 100.0);
    } else {
      mediaKitService?.setVolume(volume);
    }
  }

  void setRate(double rate) {
    if (isUsingExoPlayer) {
      exoService?.setRate(rate);
    } else {
      mediaKitService?.setRate(rate);
    }
  }

  void setSubtitleDelay(int ms) {
    if (isUsingExoPlayer) {
      exoService?.setSubtitleDelay(ms);
    } else {
      // media_kit does not expose backend-specific subtitle delay controls.
    }
  }

  void applySubtitleStyle(SubtitleStylePrefs prefs) {
    currentSubtitleStyle = prefs;
    if (isUsingExoPlayer) {
      exoService?.setSubtitleStyle(
        fontFamily: prefs.fontFamily,
        fontSizeMultiplier: prefs.fontSizeMultiplier,
        bold: prefs.bold,
        italic: prefs.italic,
        textColor: prefs.textColor,
        backgroundColor: prefs.backgroundColor,
        borderStyle: prefs.borderStyle.name,
        borderColor: prefs.borderColor,
        borderSize: prefs.borderSize,
        overrideAss: prefs.overrideAss,
      );
    } else {
      mediaKitService?.applySubtitleStyle(prefs);
    }
  }

  void setAudioDelay(int ms) {
    // media_kit does not expose backend-specific audio delay controls.
  }

  void setShaderPreset(ShaderPreset preset) {
    shaderService.applyPreset(mediaKitService, preset);
  }

  void setSurfaceBounds({required int top, required int height}) {
    if (isUsingExoPlayer) {
      exoService?.setSurfaceBounds(top: top, height: height);
    }
  }

  Future<List<PlayerChapter>> getChapters() async {
    if (isUsingExoPlayer) {
      return await exoService?.getChapters() ?? [];
    }
    if (mediaKitService != null) {
      return await mediaKitService!.getChapters();
    }
    return [];
  }

  void selectAudioTrack(UiTrack track) {
    if (isUsingExoPlayer) {
      exoService?.selectAudioTrack(track.index);
    } else {
      mediaKitService?.setAudioTrack(media_kit.AudioTrack(
        track.id,
        track.title,
        track.language,
      ));
    }
  }

  void selectSubtitleTrack(UiTrack? track, List<dynamic>? externalSubtitles) {
    if (track == null) {
      if (isUsingExoPlayer) {
        exoService?.selectSubtitleTrack(-1);
      } else {
        mediaKitService?.setSubtitleTrack(media_kit.SubtitleTrack.no());
      }
      return;
    }

    if (track.id.startsWith('ext_')) {
      if (isUsingExoPlayer) {
        exoService?.selectSubtitleTrack(track.index);
      } else {
        final index = int.tryParse(track.id.substring(4));
        if (index != null && externalSubtitles != null && index < externalSubtitles.length) {
          final extSub = externalSubtitles[index];
          final url = _getSubUrl(extSub);
          final lang = _getSubLanguage(extSub);
          final label = _getSubLabel(extSub);
          if (url.isNotEmpty) {
            mediaKitService?.setSubtitleTrack(media_kit.SubtitleTrack.uri(
              url,
              title: label.isNotEmpty ? label : lang,
              language: lang,
            ));
          }
        }
      }
      return;
    }

    if (isUsingExoPlayer) {
      exoService?.selectSubtitleTrack(track.index);
    } else {
      if (track.id == 'auto') {
        mediaKitService?.setSubtitleTrack(media_kit.SubtitleTrack.auto());
      } else {
        mediaKitService?.setSubtitleTrack(media_kit.SubtitleTrack(
          track.id,
          track.title,
          track.language,
        ));
      }
    }
  }

  void setFitMode(PlayerFitMode mode) {
    if (isUsingExoPlayer) {
      exoService?.setFitMode(mode.name);
    }
  }

  static String? _detectMimeType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('.m3u8') || lower.contains('/segs/') || lower.contains('/hls/')) {
      return 'application/x-mpegURL';
    }
    if (lower.contains('.mpd')) {
      return 'application/dash+xml';
    }
    return null;
  }

  void _cancelExoSubs() {
    _exoPosSub?.cancel();
    _exoDurSub?.cancel();
    _exoBufSub?.cancel();
    _exoPlayingSub?.cancel();
    _exoBufferingSub?.cancel();
    _exoTracksSub?.cancel();
    _exoErrorSub?.cancel();
    _exoEndedSub?.cancel();
    _exoCuesSub?.cancel();
    _exoChaptersSub?.cancel();
    _exoChaptersSub = null;
  }

  void _cancelMediaKitSubs() {
    _mediaKitPosSub?.cancel();
    _mediaKitDurSub?.cancel();
    _mediaKitBufSub?.cancel();
    _mediaKitPlayingSub?.cancel();
    _mediaKitBufferingSub?.cancel();
    _mediaKitTracksSub?.cancel();
    _mediaKitEndedSub?.cancel();
    _mediaKitErrorSub?.cancel();
  }

  void dispose() {
    _cancelExoSubs();
    _cancelMediaKitSubs();
    exoService?.dispose();
    final mediaKit = mediaKitService;
    if (mediaKit != null) {
      Future.microtask(() async {
        try {
          await mediaKit.dispose();
        } catch (_) {}
      });
    }
    exoService = null;
    mediaKitService = null;
  }
}
