import 'package:flutter/foundation.dart';

/// The GPU/renderer the **active** libmpv instance is really using.
///
/// Hybrid laptops (Intel/AMD iGPU + discrete GPU) make this the only honest
/// answer to "which GPU is playing my video?": the OS picks the adapter at
/// process creation, so the only way to know is to read it back from mpv's own
/// log (`GL_VENDOR` / `GL_RENDERER` under `vo/gpu=debug`).
class RendererInfo {
  /// `GL_RENDERER`, e.g. "Intel(R) UHD Graphics" or "NVIDIA GeForce RTX 3050 Ti".
  final String renderer;

  /// `GL_VENDOR`, e.g. "Intel", "NVIDIA Corporation".
  final String? vendor;

  const RendererInfo({required this.renderer, this.vendor});

  String get label {
    final vendorName = vendor?.trim();
    if (vendorName == null || vendorName.isEmpty) return renderer;
    if (renderer.toLowerCase().contains(vendorName.toLowerCase())) {
      return renderer;
    }
    return '$renderer ($vendorName)';
  }
}

/// Last renderer reported by a player instance, or null when no video has been
/// played yet in this session.
final ValueNotifier<RendererInfo?> activeRenderer =
    ValueNotifier<RendererInfo?>(null);

final RegExp _rendererPattern = RegExp(r"GL_RENDERER='([^']+)'");
final RegExp _vendorPattern = RegExp(r"GL_VENDOR='([^']+)'");

String? _pendingVendor;

/// Consumes one libmpv log line.
///
/// Returns true when the renderer was identified, so the caller can stop
/// listening for it and lower mpv's verbosity again.
bool ingestMpvLogLine(String line) {
  final vendor = _vendorPattern.firstMatch(line)?.group(1);
  if (vendor != null) _pendingVendor = vendor.trim();

  final renderer = _rendererPattern.firstMatch(line)?.group(1);
  if (renderer == null) return false;

  activeRenderer.value = RendererInfo(
    renderer: renderer.trim(),
    vendor: _pendingVendor ?? activeRenderer.value?.vendor,
  );
  _pendingVendor = null;
  return true;
}

/// Test helper: resets the shared state.
@visibleForTesting
void resetRendererInfo() {
  _pendingVendor = null;
  activeRenderer.value = null;
}
