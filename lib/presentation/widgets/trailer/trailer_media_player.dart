import 'dart:async';

import 'package:aniting/data/models/trailer_streams.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Plays a resolved YouTube trailer with media_kit (libmpv) on every platform
/// where the embedded iFrame player is unavailable — i.e. Linux and Windows
/// desktop.
///
/// YouTube serves video and audio as separate tracks above 360p, so the video is
/// opened as the main file and the audio track is attached to the same mpv
/// instance (libmpv keeps them in sync by timestamps). When only a muxed URL is
/// available it is used directly.
class TrailerMediaPlayer extends StatefulWidget {
  final TrailerStreams streams;

  /// Called once playback started, so the dialog can hide its spinner.
  final VoidCallback? onReady;

  const TrailerMediaPlayer({
    super.key,
    required this.streams,
    this.onReady,
  });

  @override
  State<TrailerMediaPlayer> createState() => _TrailerMediaPlayerState();
}

class _TrailerMediaPlayerState extends State<TrailerMediaPlayer> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    unawaited(_open());
  }

  Future<void> _open() async {
    final videoUrl = widget.streams.videoUrl ?? widget.streams.muxedUrl;
    if (videoUrl == null) return;

    try {
      final audioUrl = widget.streams.audioUrl;
      final platform = _player.platform;

      // File-local option: applied when the following `loadfile` runs, exactly
      // like `mpv --audio-file=<url> <video>`.
      if (audioUrl != null && widget.streams.videoUrl != null && platform is NativePlayer) {
        try {
          await platform.setProperty('audio-files', audioUrl);
        } catch (_) {}
      }

      await _player.open(Media(videoUrl), play: true);

      // Fallback for builds where the pre-load option was ignored: attach the
      // audio track once the video is the current file.
      if (audioUrl != null &&
          widget.streams.videoUrl != null &&
          platform is NativePlayer) {
        final hasAudio = _player.state.tracks.audio.isNotEmpty;
        if (!hasAudio) {
          try {
            await platform.command(['audio-add', audioUrl]);
          } catch (_) {}
        }
      }

      await _player.setVolume(100);
      widget.onReady?.call();
    } catch (_) {
      // The dialog keeps its loading state; the caller falls back to the
      // external player after its own timeout.
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Video(
      controller: _controller,
      controls: NoVideoControls,
      fit: BoxFit.contain,
    );
  }
}
