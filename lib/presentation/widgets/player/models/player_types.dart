import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Represents a media track (audio or subtitle) for the player UI.
class UiTrack {
  final String id;
  final int index;
  final String title;
  final String language;
  final bool selected;

  const UiTrack({
    required this.id,
    required this.index,
    required this.title,
    required this.language,
    required this.selected,
  });

  UiTrack copyWith({
    String? id,
    int? index,
    String? title,
    String? language,
    bool? selected,
  }) {
    return UiTrack(
      id: id ?? this.id,
      index: index ?? this.index,
      title: title ?? this.title,
      language: language ?? this.language,
      selected: selected ?? this.selected,
    );
  }
}

/// Shader preset definition for mpv video enhancements.
class ShaderPreset {
  final String id;
  final String name;
  final String description;
  final String? glslPath;

  const ShaderPreset({
    required this.id,
    required this.name,
    this.description = '',
    this.glslPath,
  });

  bool get isNone => id == 'none';

  String localizedName(AppTranslations l10n) {
    switch (id) {
      case 'none':
        return l10n.disabled;
      case 'anime4k_mode_a':
        return 'Anime4K - ${l10n.mode} A';
      case 'anime4k_mode_b':
        return 'Anime4K - ${l10n.mode} B';
      case 'anime4k_mode_c':
        return 'Anime4K - ${l10n.mode} C';
      case 'nvscaler':
        return 'NVScaler';
      case 'artcnn':
        return 'ArtCNN C4F16';
      default:
        return name;
    }
  }

  static const ShaderPreset none = ShaderPreset(
    id: 'none',
    name: 'Disabled',
  );

  static const List<ShaderPreset> presets = [
    none,
    ShaderPreset(
      id: 'anime4k_mode_a',
      name: 'Anime4K - Mode A',
    ),
    ShaderPreset(
      id: 'anime4k_mode_b',
      name: 'Anime4K - Mode B',
    ),
    ShaderPreset(
      id: 'anime4k_mode_c',
      name: 'Anime4K - Mode C',
    ),
    ShaderPreset(
      id: 'nvscaler',
      name: 'NVScaler',
    ),
    ShaderPreset(
      id: 'artcnn',
      name: 'ArtCNN C4F16',
    ),
  ];
}

/// Real-time playback performance metrics (Stats for Nerds / Plezy style).
class PerformanceStats {
  final String engine;
  final String? videoCodec;
  final String? videoFormat;
  final String? audioCodec;
  final String? resolution;
  final String? aspectRatio;
  final double? fps;
  final double? containerFps;
  final int? bitrate;
  final int? audioBitrate;
  final String? hwdec;
  final String? pixelFormat;
  final int? droppedFrames;
  final int? decoderDroppedFrames;
  final int? audioChannels;
  final int? audioSampleRate;
  final double? avsync;
  final double? cacheDuration;
  final Duration? buffer;
  final String? subtitleFormat;

  const PerformanceStats({
    required this.engine,
    this.videoCodec,
    this.videoFormat,
    this.audioCodec,
    this.resolution,
    this.aspectRatio,
    this.fps,
    this.containerFps,
    this.bitrate,
    this.audioBitrate,
    this.hwdec,
    this.pixelFormat,
    this.droppedFrames,
    this.decoderDroppedFrames,
    this.audioChannels,
    this.audioSampleRate,
    this.avsync,
    this.cacheDuration,
    this.buffer,
    this.subtitleFormat,
  });

  const PerformanceStats.empty({this.engine = 'Desconocido'})
      : videoCodec = null,
        videoFormat = null,
        audioCodec = null,
        resolution = null,
        aspectRatio = null,
        fps = null,
        containerFps = null,
        bitrate = null,
        audioBitrate = null,
        hwdec = null,
        pixelFormat = null,
        droppedFrames = null,
        decoderDroppedFrames = null,
        audioChannels = null,
        audioSampleRate = null,
        avsync = null,
        cacheDuration = null,
        buffer = null,
        subtitleFormat = null;
}

/// Video fit mode for scaling the video viewport.
enum PlayerFitMode {
  contain('Ajustar', BoxFit.contain),
  cover('Rellenar (Recortar)', BoxFit.cover),
  fill('Estirar pantalla', BoxFit.fill);

  final String label;
  final BoxFit boxFit;

  const PlayerFitMode(this.label, this.boxFit);

  IconData getIcon([AppIconPack? pack]) {
    switch (this) {
      case PlayerFitMode.contain:
        return AppIcons.fitContain(pack);
      case PlayerFitMode.cover:
        return AppIcons.fitCover(pack);
      case PlayerFitMode.fill:
        return AppIcons.fitFill(pack);
    }
  }

  IconData get icon => getIcon();

  String localizedLabel(AppTranslations l10n) {
    switch (this) {
      case PlayerFitMode.contain:
        return l10n.fitContain;
      case PlayerFitMode.cover:
        return l10n.fitCover;
      case PlayerFitMode.fill:
        return l10n.fitFill;
    }
  }
}

/// Represents a chapter/segment inside a media file (MKV chapters, OP, ED, parts, etc.)
class PlayerChapter {
  final int index;
  final String title;
  final Duration start;
  final Duration? end;

  const PlayerChapter({
    required this.index,
    required this.title,
    required this.start,
    this.end,
  });

  bool get isOpening {
    final lower = title.toLowerCase();
    return lower.contains('opening') ||
        lower == 'op' ||
        lower.contains('op ') ||
        lower.startsWith('op:') ||
        lower.contains('theme song');
  }

  bool get isEnding {
    final lower = title.toLowerCase();
    return lower.contains('ending') ||
        lower == 'ed' ||
        lower.contains('ed ') ||
        lower.startsWith('ed:');
  }

  bool get isIntro {
    final lower = title.toLowerCase();
    return lower.contains('intro') ||
        lower.contains('prologue') ||
        lower.contains('prólogo');
  }

  bool get isCredits {
    final lower = title.toLowerCase();
    return lower.contains('credit') ||
        lower.contains('crédit');
  }

  bool get isPreview {
    final lower = title.toLowerCase();
    return lower.contains('preview') ||
        lower.contains('avance');
  }

  bool isSkippable(Duration position) {
    if (position < start) return false;
    if (end != null && position >= end!) return false;
    return isOpening || isEnding || isIntro || isCredits;
  }

  String localizedSkipButtonLabel(AppTranslations l10n) {
    if (isOpening) return l10n.skipOpening;
    if (isEnding) return l10n.skipEnding;
    if (isCredits) return l10n.skipCredits;
    if (isIntro) return l10n.skipIntro;
    if (isPreview) return l10n.skipPreview;
    return l10n.skip;
  }

  String get skipButtonLabel {
    if (isOpening) return 'Saltar Opening';
    if (isEnding) return 'Saltar Ending';
    if (isCredits) return 'Saltar Créditos';
    if (isIntro) return 'Saltar Intro';
    if (isPreview) return 'Saltar Avance';
    return 'Saltar';
  }
}
