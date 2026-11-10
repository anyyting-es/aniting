/// Host GPU information as reported by the companion server
/// (`/api/v1/system/gpu`).
///
/// The client cannot enumerate display adapters on its own, and on Windows the
/// per-app "high performance" preference lives in the registry, so both are
/// resolved server-side.
class GpuInfo {
  final String name;
  final String? vendor;

  /// Heuristic: true for the discrete adapter.
  final bool dedicated;

  const GpuInfo({
    required this.name,
    this.vendor,
    this.dedicated = false,
  });

  factory GpuInfo.fromJson(Map<String, dynamic> json) {
    return GpuInfo(
      name: (json['name'] as String?)?.trim() ?? '',
      vendor: (json['vendor'] as String?)?.trim(),
      dedicated: json['dedicated'] == true,
    );
  }
}

/// Per-app GPU preference modes. Mirrors the backend constants.
class GpuPreference {
  static const String auto = 'auto';
  static const String high = 'high';
  static const String power = 'power';
}

class GpuSettings {
  final List<GpuInfo> gpus;
  final String preference;

  /// False on platforms without a per-app preference (Linux, Android).
  final bool canSetPreference;

  final String? executablePath;

  /// Platform hint (e.g. `DRI_PRIME=1` on Linux).
  final String? note;

  const GpuSettings({
    this.gpus = const [],
    this.preference = GpuPreference.auto,
    this.canSetPreference = false,
    this.executablePath,
    this.note,
  });

  GpuInfo? get dedicatedGpu {
    for (final gpu in gpus) {
      if (gpu.dedicated) return gpu;
    }
    return null;
  }

  bool get hasDedicatedGpu => dedicatedGpu != null;

  factory GpuSettings.fromJson(Map<String, dynamic> json) {
    final rawGpus = json['gpus'];
    final gpus = <GpuInfo>[];
    if (rawGpus is List) {
      for (final entry in rawGpus) {
        if (entry is Map<String, dynamic>) {
          final gpu = GpuInfo.fromJson(entry);
          if (gpu.name.isNotEmpty) gpus.add(gpu);
        }
      }
    }

    return GpuSettings(
      gpus: gpus,
      preference: (json['preference'] as String?) ?? GpuPreference.auto,
      canSetPreference: json['canSetPreference'] == true,
      executablePath: json['executablePath'] as String?,
      note: json['note'] as String?,
    );
  }

  static const GpuSettings empty = GpuSettings();
}
