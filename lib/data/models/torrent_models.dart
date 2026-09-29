class AnimeTorrentProvider {
  final String id;
  final String name;
  final String lang;

  const AnimeTorrentProvider({
    required this.id,
    required this.name,
    this.lang = 'multi',
  });

  factory AnimeTorrentProvider.fromJson(Map<String, dynamic> json) {
    return AnimeTorrentProvider(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      lang: json['lang'] as String? ?? 'multi',
    );
  }
}

class TorrentItem {
  final String name;
  final String? provider;
  final String? date;
  final int size;
  final String formattedSize;
  final int seeders;
  final int leechers;
  final String? link;
  final String? downloadUrl;
  final String? magnetLink;
  final String? infoHash;
  final String? resolution;
  final bool isBatch;
  final int? episodeNumber;
  final String? releaseGroup;
  final bool isBestRelease;
  final bool confirmed;

  const TorrentItem({
    required this.name,
    this.provider,
    this.date,
    this.size = 0,
    this.formattedSize = '',
    this.seeders = 0,
    this.leechers = 0,
    this.link,
    this.downloadUrl,
    this.magnetLink,
    this.infoHash,
    this.resolution,
    this.isBatch = false,
    this.episodeNumber,
    this.releaseGroup,
    this.isBestRelease = false,
    this.confirmed = false,
  });

  factory TorrentItem.fromJson(Map<String, dynamic> json) {
    return TorrentItem(
      name: json['name'] as String? ?? 'Sin nombre',
      provider: json['provider'] as String?,
      date: json['date'] as String?,
      size: json['size'] as int? ?? 0,
      formattedSize: json['formattedSize'] as String? ?? '',
      seeders: json['seeders'] as int? ?? 0,
      leechers: json['leechers'] as int? ?? 0,
      link: json['link'] as String?,
      downloadUrl: json['downloadUrl'] as String?,
      magnetLink: json['magnetLink'] as String?,
      infoHash: json['infoHash'] as String?,
      resolution: json['resolution'] as String?,
      isBatch: json['isBatch'] as bool? ?? false,
      episodeNumber: json['episodeNumber'] as int?,
      releaseGroup: json['releaseGroup'] as String?,
      isBestRelease: json['isBestRelease'] as bool? ?? false,
      confirmed: json['confirmed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (provider != null) 'provider': provider,
      if (date != null) 'date': date,
      'size': size,
      'formattedSize': formattedSize,
      'seeders': seeders,
      'leechers': leechers,
      if (link != null) 'link': link,
      if (downloadUrl != null) 'downloadUrl': downloadUrl,
      if (magnetLink != null) 'magnetLink': magnetLink,
      if (infoHash != null) 'infoHash': infoHash,
      if (resolution != null) 'resolution': resolution,
      'isBatch': isBatch,
      if (episodeNumber != null) 'episodeNumber': episodeNumber,
      if (releaseGroup != null) 'releaseGroup': releaseGroup,
      'isBestRelease': isBestRelease,
      'confirmed': confirmed,
    };
  }
}

/// Estado en tiempo real del stream de torrent emitido por el backend Go Seanime
/// a través de WebSocket (`torrentstream-state`).
class TorrentStreamStatus {
  final int uploadProgress;
  final int downloadProgress;
  final double progressPercentage;
  final String downloadSpeed;
  final String uploadSpeed;
  final String size;
  final int seeders;

  const TorrentStreamStatus({
    this.uploadProgress = 0,
    this.downloadProgress = 0,
    this.progressPercentage = 0.0,
    this.downloadSpeed = '',
    this.uploadSpeed = '',
    this.size = '',
    this.seeders = 0,
  });

  factory TorrentStreamStatus.fromJson(Map<String, dynamic> json) {
    return TorrentStreamStatus(
      uploadProgress: (json['uploadProgress'] as num?)?.toInt() ?? 0,
      downloadProgress: (json['downloadProgress'] as num?)?.toInt() ?? 0,
      progressPercentage:
          (json['progressPercentage'] as num?)?.toDouble() ?? 0.0,
      downloadSpeed: json['downloadSpeed'] as String? ?? '',
      uploadSpeed: json['uploadSpeed'] as String? ?? '',
      size: json['size'] as String? ?? '',
      seeders: (json['seeders'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isComplete => progressPercentage >= 100.0;

  /// Formatea los bytes descargados a una cadena legible (ej. "450.2 MB").
  String get formattedDownloaded {
    if (downloadProgress <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double d = downloadProgress.toDouble();
    while (d >= 1024 && i < suffixes.length - 1) {
      d /= 1024;
      i++;
    }
    return '${d.toStringAsFixed(i > 1 ? 1 : 0)} ${suffixes[i]}';
  }

  /// Estima el tiempo restante para completar la descarga (ETA).
  /// Devuelve "Completado", "4m 20s", "1h 15m", o "--".
  String get etaString {
    if (progressPercentage >= 100.0) return 'Completado';
    if (downloadSpeed.isEmpty || downloadProgress <= 0 || progressPercentage <= 0) {
      return '--';
    }

    final speedMatch = RegExp(
      r'([\d.]+)\s*([KMGTP]?B)/s',
      caseSensitive: false,
    ).firstMatch(downloadSpeed);

    if (speedMatch != null) {
      final val = double.tryParse(speedMatch.group(1) ?? '') ?? 0.0;
      final unit = (speedMatch.group(2) ?? 'B').toUpperCase();
      double bytesPerSec = val;
      if (unit == 'KB') {
        bytesPerSec *= 1024;
      } else if (unit == 'MB') {
        bytesPerSec *= 1024 * 1024;
      } else if (unit == 'GB') {
        bytesPerSec *= 1024 * 1024 * 1024;
      }

      if (bytesPerSec > 100) {
        final totalBytes = downloadProgress / (progressPercentage / 100.0);
        final remainingBytes = totalBytes - downloadProgress;
        if (remainingBytes > 0) {
          final remainingSecs = (remainingBytes / bytesPerSec).round();
          if (remainingSecs < 60) return '${remainingSecs}s';
          if (remainingSecs < 3600) {
            final m = remainingSecs ~/ 60;
            final s = remainingSecs % 60;
            return '${m}m ${s}s';
          }
          final h = remainingSecs ~/ 3600;
          final m = (remainingSecs % 3600) ~/ 60;
          return '${h}h ${m}m';
        }
      }
    }
    return '--';
  }
}

