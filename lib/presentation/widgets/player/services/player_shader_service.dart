import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:seanime_app/core/player/mpv_player_service.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Utility for extracting and preparing GLSL shader assets for libmpv.
///
/// libmpv operates as native code and requires absolute filesystem paths for shaders,
/// so bundled Flutter assets are extracted to the application's cache directory on demand.
class ShaderAssetLoader {
  static const String _shaderAssetBase = 'assets/shaders';
  static String? _cachedShaderDir;
  static final Map<String, String> _extractedCache = {};

  static Future<String> _getShaderDirectory() async {
    if (_cachedShaderDir != null) return _cachedShaderDir!;
    final cacheDir = await getApplicationCacheDirectory();
    final shaderDir = Directory('${cacheDir.path}/shaders');
    if (!await shaderDir.exists()) {
      await shaderDir.create(recursive: true);
    }
    _cachedShaderDir = shaderDir.path;
    return shaderDir.path;
  }

  /// Extracts a bundled shader asset to the cache filesystem if not already present.
  static Future<String?> extractShader(String relativePath) async {
    final cached = _extractedCache[relativePath];
    if (cached != null && await File(cached).exists()) {
      return cached;
    }

    try {
      final shaderDir = await _getShaderDirectory();
      final targetFile = File('$shaderDir/$relativePath');
      final parentDir = targetFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }

      final data = await rootBundle.load('$_shaderAssetBase/$relativePath');
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      // Reuse file if it exists and has identical length
      if (await targetFile.exists()) {
        final length = await targetFile.length();
        if (length == bytes.length) {
          _extractedCache[relativePath] = targetFile.path;
          return targetFile.path;
        }
      }

      await targetFile.writeAsBytes(bytes, flush: true);
      _extractedCache[relativePath] = targetFile.path;
      return targetFile.path;
    } catch (e) {
      debugPrint('[ShaderAssetLoader] Failed to extract shader $relativePath: $e');
      return null;
    }
  }

  /// Resolves the filesystem paths for a given preset in execution order.
  static Future<List<String>> getShadersForPreset(ShaderPreset preset) async {
    if (preset.isNone) return [];

    final relativeFiles = <String>[];
    switch (preset.id) {
      case 'anime4k_mode_a':
        relativeFiles.addAll([
          'anime4k/Anime4K_Clamp_Highlights.glsl',
          'anime4k/Anime4K_Restore_CNN_M.glsl',
          'anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
        ]);
        break;
      case 'anime4k_mode_b':
        relativeFiles.addAll([
          'anime4k/Anime4K_Clamp_Highlights.glsl',
          'anime4k/Anime4K_Restore_CNN_M.glsl',
          'anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
          'anime4k/Anime4K_AutoDownscalePre_x2.glsl',
        ]);
        break;
      case 'anime4k_mode_c':
        relativeFiles.addAll([
          'anime4k/Anime4K_Clamp_Highlights.glsl',
          'anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
          'anime4k/Anime4K_AutoDownscalePre_x2.glsl',
        ]);
        break;
      case 'nvscaler':
        relativeFiles.add('nvscaler/NVScaler.glsl');
        break;
      case 'artcnn':
        relativeFiles.add('artcnn/ArtCNN_C4F16.glsl');
        break;
      default:
        if (preset.glslPath != null && preset.glslPath!.isNotEmpty) {
          relativeFiles.add(preset.glslPath!);
        }
        break;
    }

    final result = <String>[];
    for (final rel in relativeFiles) {
      final extracted = await extractShader(rel);
      if (extracted != null && extracted.isNotEmpty) {
        result.add(extracted);
      }
    }
    return result;
  }
}

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
        // Clear shaders using mpv change-list and fallback property
        await mpv.command(['change-list', 'glsl-shaders', 'clr', '']);
        await mpv.setProperty('glsl-shaders', '');
        debugPrint('[ShaderService] Shaders disabled (cleared).');
      } else {
        final shaderPaths = await ShaderAssetLoader.getShadersForPreset(preset);

        if (shaderPaths.isEmpty) {
          await mpv.command(['change-list', 'glsl-shaders', 'clr', '']);
          await mpv.setProperty('glsl-shaders', '');
          debugPrint('[ShaderService] No valid shader paths resolved for preset: ${preset.name}');
          return;
        }

        // 1. Clear current shaders
        await mpv.command(['change-list', 'glsl-shaders', 'clr', '']);

        // 2. Append each shader in order
        for (final shaderPath in shaderPaths) {
          await mpv.command(['change-list', 'glsl-shaders', 'append', shaderPath]);
        }

        // 3. Fallback set property
        final delimiter = Platform.isWindows ? ';' : ':';
        await mpv.setProperty('glsl-shaders', shaderPaths.join(delimiter));

        debugPrint('[ShaderService] Applied shader preset: ${preset.name} (${shaderPaths.length} shaders)');
      }
    } catch (e) {
      debugPrint('[ShaderService] Error applying shader preset: $e');
    }
  }
}
