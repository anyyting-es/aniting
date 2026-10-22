import 'package:flutter/services.dart';

/// Provides audio and haptic feedback for 10-foot TV / console navigation.
///
/// On Android TV / Fire TV / mobile, [SystemSound.play] automatically triggers
/// the OS-native console directional tick and select chime.
abstract final class TvAudioFeedback {
  /// Feedback triggered when moving focus between elements with the DPAD / remote.
  static void playMove() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Feedback triggered when an action, tile, or button is selected (Enter / OK / A).
  static void playSelect() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Feedback triggered when backing out or cancelling an action.
  static void playBack() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Feedback triggered when a connection or action succeeds.
  static void playSuccess() {
    try {
      SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }
}
