import 'dart:io';

import 'package:aniting/core/player/media_kit_player_service.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';

/// Ordered mpv `glsl-shaders` chain for a preset id.
///
/// Order matters: mpv applies the hooks top to bottom, and the Anime4K recipes
/// are defined as `Clamp_Highlights → Restore → Upscale → AutoDownscalePre`.
/// The `Upscale` hook is what turns a 1080p source into the display size, and
/// `AutoDownscalePre` prevents it from over-sharpening a source that is already
/// larger than the output.
List<String> shaderChainFor(String presetId) {
  switch (presetId) {
    case 'anime4k_mode_a':
      return const [
        'assets/shaders/anime4k/Anime4K_Clamp_Highlights.glsl',
        'assets/shaders/anime4k/Anime4K_Restore_CNN_VL.glsl',
        'assets/shaders/anime4k/Anime4K_Upscale_CNN_x2_VL.glsl',
        'assets/shaders/anime4k/Anime4K_AutoDownscalePre_x2.glsl',
      ];
    case 'anime4k_mode_b':
      return const [
        'assets/shaders/anime4k/Anime4K_Clamp_Highlights.glsl',
        'assets/shaders/anime4k/Anime4K_Restore_CNN_M.glsl',
        'assets/shaders/anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
        'assets/shaders/anime4k/Anime4K_AutoDownscalePre_x2.glsl',
      ];
    case 'anime4k_mode_c':
      return const [
        'assets/shaders/anime4k/Anime4K_Clamp_Highlights.glsl',
        'assets/shaders/anime4k/Anime4K_Restore_CNN_M.glsl',
        'assets/shaders/anime4k/Anime4K_Upscale_CNN_x2_M.glsl',
      ];
    case 'nvscaler':
      return const ['assets/shaders/nvscaler/NVScaler.glsl'];
    case 'artcnn':
      return const ['assets/shaders/artcnn/ArtCNN_C4F16.glsl'];
    default:
      return const [];
  }
}

/// Applies enhancement shaders to the active libmpv instance.
///
/// media_kit does not expose `glsl-shaders` as a typed API, but the underlying
/// `NativePlayer` still speaks the full mpv command set, so the chain is applied
/// with `change-list glsl-shaders` — exactly what the old raw libmpv path did.
///
/// Two things are easy to get wrong here and are handled explicitly:
///
/// 1. Flutter assets are **not files** (especially on Android), while mpv needs
///    a real path to `fopen`. The shaders are copied once to the application
///    support directory and the file paths are cached.
/// 2. `glsl-shaders` is a *list* option. Setting it repeatedly would stack
///    duplicate hooks, so the chain is always cleared first.
class PlayerShaderService {
  final Map<String, String> _materializedPaths = <String, String>{};

  /// Serialises applies: fast preset switching would otherwise interleave
  /// `clear`/`append` commands and leave a half-applied chain.
  Future<void> _pending = Future<void>.value();
  int _applyToken = 0;

  ShaderPreset _currentPreset = ShaderPreset.none;
  ShaderPreset get currentPreset => _currentPreset;

  /// Applies [preset] to [player].
  ///
  /// Safe to call with a null player (engine not created yet) or with an
  /// ExoPlayer-backed session, where GLSL hooks simply do not apply.
  Future<void> applyPreset(
    MediaKitPlayerService? player,
    ShaderPreset preset,
  ) {
    _currentPreset = preset;
    final token = ++_applyToken;

    final result = _pending.then((_) => _apply(player, preset, token));
    _pending = result.catchError((Object _) {});
    return result;
  }

  Future<void> _apply(
    MediaKitPlayerService? player,
    ShaderPreset preset,
    int token,
  ) async {
    // A newer selection arrived while this one was queued.
    if (token != _applyToken) return;

    if (player == null) return;
    final platform = player.player.platform;
    if (platform is! NativePlayer) return;

    try {
      // Clear first: otherwise switching presets stacks the previous chain.
      await platform.command(['change-list', 'glsl-shaders', 'clear']);

      final chain = shaderChainFor(preset.id);
      if (chain.isEmpty) return;

      for (final asset in chain) {
        final path = await _materialize(asset);
        if (path == null) continue;
        if (token != _applyToken) return;
        await platform.command([
          'change-list',
          'glsl-shaders',
          'append',
          path,
        ]);
      }
    } catch (error) {
      debugPrint('[ShaderService] Failed to apply ${preset.id}: $error');
    }
  }

  /// Copies an asset to a real file path once and returns it.
  Future<String?> _materialize(String asset) async {
    final cached = _materializedPaths[asset];
    if (cached != null && File(cached).existsSync()) return cached;

    try {
      final supportDir = await getApplicationSupportDirectory();
      final relative = asset.startsWith('assets/shaders/')
          ? asset.substring('assets/shaders/'.length)
          : asset.split('/').last;
      final separator = Platform.pathSeparator;
      final target = File(
        '${supportDir.path}${separator}shaders$separator'
        '${relative.replaceAll('/', separator)}',
      );

      await target.parent.create(recursive: true);
      final data = await rootBundle.load(asset);
      await target.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );

      _materializedPaths[asset] = target.path;
      return target.path;
    } catch (error) {
      debugPrint('[ShaderService] Could not materialize $asset: $error');
      return null;
    }
  }
}
