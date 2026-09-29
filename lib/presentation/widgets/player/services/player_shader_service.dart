import 'package:flutter/foundation.dart';
import 'package:seanime_app/core/player/mpv_player_service.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Service managing GLSL video enhancement shaders for the player.
/// By default, shaders are OFF (disabled) to guarantee optimal performance and battery efficiency.
class PlayerShaderService {
  ShaderPreset _currentPreset = ShaderPreset.none;

  ShaderPreset get currentPreset => _currentPreset;

  /// Applies a shader preset to the MPV player engine.
  /// If [preset] is none, clears all GLSL shaders.
  Future<void> applyPreset(MpvPlayerService? mpv, ShaderPreset preset) async {
    _currentPreset = preset;

    if (mpv == null) {
      debugPrint('[ShaderService] Shaders can only be applied to the libmpv engine.');
      return;
    }

    try {
      if (preset.isNone) {
        // Clear shaders
        await mpv.setProperty('glsl-shaders', '');
        debugPrint('[ShaderService] Shaders disabled (cleared).');
      } else {
        // In MPV, custom shader paths or built-in hooks can be passed.
        // For bundled shaders or user-configured paths, we set glsl-shaders.
        final path = preset.glslPath ?? '';
        if (path.isNotEmpty) {
          await mpv.setProperty('glsl-shaders', path);
        } else {
          // If no external shader file exists, ensure safe state
          await mpv.setProperty('glsl-shaders', '');
        }
        debugPrint('[ShaderService] Applied shader preset: ${preset.name}');
      }
    } catch (e) {
      debugPrint('[ShaderService] Error applying shader preset: $e');
    }
  }
}
