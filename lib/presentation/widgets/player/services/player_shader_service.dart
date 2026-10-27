import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/player/media_kit_player_service.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Tracks the selected enhancement preset.
///
/// Backend-specific GLSL commands are intentionally not exposed by media_kit,
/// so presets remain available to the UI without invoking custom libmpv code.
class PlayerShaderService {
  ShaderPreset _currentPreset = ShaderPreset.none;

  ShaderPreset get currentPreset => _currentPreset;

  Future<void> applyPreset(
    MediaKitPlayerService? player,
    ShaderPreset preset,
  ) async {
    _currentPreset = preset;
    if (player != null && !preset.isNone) {
      debugPrint('[ShaderService] Shader presets are unavailable with media_kit.');
    }
  }
}
