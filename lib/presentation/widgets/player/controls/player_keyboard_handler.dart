import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handler class for desktop and web keyboard shortcuts in the video player.
class PlayerKeyboardHandler {
  final VoidCallback onPlayPause;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onExit;
  final void Function(int seconds) onSeekRelative;
  final void Function(double delta) onAdjustVolume;
  final VoidCallback onToggleMute;
  final VoidCallback? onSkipChapter;
  final void Function(double fraction)? onSeekPercentage;
  final bool isFullscreen;
  final Duration duration;
  final bool canSkipChapter;

  const PlayerKeyboardHandler({
    required this.onPlayPause,
    required this.onToggleFullscreen,
    required this.onExit,
    required this.onSeekRelative,
    required this.onAdjustVolume,
    required this.onToggleMute,
    this.onSkipChapter,
    this.onSeekPercentage,
    required this.isFullscreen,
    required this.duration,
    required this.canSkipChapter,
  });

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;

    // Play / Pause: Space or K
    if (key == LogicalKeyboardKey.space || key == LogicalKeyboardKey.keyK) {
      onPlayPause();
      return KeyEventResult.handled;
    }

    // Fullscreen: F
    if (key == LogicalKeyboardKey.keyF) {
      onToggleFullscreen();
      return KeyEventResult.handled;
    }

    // Escape: exit fullscreen if in fullscreen, else exit player
    if (key == LogicalKeyboardKey.escape) {
      if (isFullscreen) {
        onToggleFullscreen();
      } else {
        onExit();
      }
      return KeyEventResult.handled;
    }

    // Seek backward: Arrow Left or J
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyJ) {
      onSeekRelative(-10);
      return KeyEventResult.handled;
    }

    // Seek forward: Arrow Right or L
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyL) {
      onSeekRelative(10);
      return KeyEventResult.handled;
    }

    // Volume Up: Arrow Up
    if (key == LogicalKeyboardKey.arrowUp) {
      onAdjustVolume(5.0);
      return KeyEventResult.handled;
    }

    // Volume Down: Arrow Down
    if (key == LogicalKeyboardKey.arrowDown) {
      onAdjustVolume(-5.0);
      return KeyEventResult.handled;
    }

    // Mute: M
    if (key == LogicalKeyboardKey.keyM) {
      onToggleMute();
      return KeyEventResult.handled;
    }

    // Skip Opening / Ending / Chapter: S
    if (key == LogicalKeyboardKey.keyS) {
      if (canSkipChapter && onSkipChapter != null) {
        onSkipChapter!();
        return KeyEventResult.handled;
      }
    }

    // Number keys 0-9: Seek to percentage (0 = 0%, 1 = 10%, ..., 9 = 90%)
    if (event is KeyDownEvent && duration > Duration.zero && onSeekPercentage != null) {
      final digit = getDigitKey(key);
      if (digit != null) {
        onSeekPercentage!(digit / 10.0);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  static int? getDigitKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.digit0 || key == LogicalKeyboardKey.numpad0) return 0;
    if (key == LogicalKeyboardKey.digit1 || key == LogicalKeyboardKey.numpad1) return 1;
    if (key == LogicalKeyboardKey.digit2 || key == LogicalKeyboardKey.numpad2) return 2;
    if (key == LogicalKeyboardKey.digit3 || key == LogicalKeyboardKey.numpad3) return 3;
    if (key == LogicalKeyboardKey.digit4 || key == LogicalKeyboardKey.numpad4) return 4;
    if (key == LogicalKeyboardKey.digit5 || key == LogicalKeyboardKey.numpad5) return 5;
    if (key == LogicalKeyboardKey.digit6 || key == LogicalKeyboardKey.numpad6) return 6;
    if (key == LogicalKeyboardKey.digit7 || key == LogicalKeyboardKey.numpad7) return 7;
    if (key == LogicalKeyboardKey.digit8 || key == LogicalKeyboardKey.numpad8) return 8;
    if (key == LogicalKeyboardKey.digit9 || key == LogicalKeyboardKey.numpad9) return 9;
    return null;
  }
}
