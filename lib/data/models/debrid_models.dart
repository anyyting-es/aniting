class DebridSettings {
  final bool enabled;
  final String provider;
  final String apiKey;
  final bool includeDebridStreamInLibrary;
  final bool streamAutoSelect;
  final String streamPreferredResolution;

  const DebridSettings({
    this.enabled = false,
    this.provider = 'realdebrid',
    this.apiKey = '',
    this.includeDebridStreamInLibrary = false,
    this.streamAutoSelect = true,
    this.streamPreferredResolution = '1080p',
  });

  factory DebridSettings.fromJson(Map<String, dynamic> json) {
    return DebridSettings(
      enabled: json['enabled'] as bool? ?? false,
      provider: json['provider'] as String? ?? 'realdebrid',
      apiKey: json['apiKey'] as String? ?? '',
      includeDebridStreamInLibrary:
          json['includeDebridStreamInLibrary'] as bool? ?? false,
      streamAutoSelect: json['streamAutoSelect'] as bool? ?? true,
      streamPreferredResolution:
          json['streamPreferredResolution'] as String? ?? '1080p',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'provider': provider,
      'apiKey': apiKey,
      'includeDebridStreamInLibrary': includeDebridStreamInLibrary,
      'streamAutoSelect': streamAutoSelect,
      'streamPreferredResolution': streamPreferredResolution,
    };
  }

  DebridSettings copyWith({
    bool? enabled,
    String? provider,
    String? apiKey,
    bool? includeDebridStreamInLibrary,
    bool? streamAutoSelect,
    String? streamPreferredResolution,
  }) {
    return DebridSettings(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      includeDebridStreamInLibrary:
          includeDebridStreamInLibrary ?? this.includeDebridStreamInLibrary,
      streamAutoSelect: streamAutoSelect ?? this.streamAutoSelect,
      streamPreferredResolution:
          streamPreferredResolution ?? this.streamPreferredResolution,
    );
  }
}

class DebridTorrentFile {
  final String id;
  final int index;
  final String name;
  final String path;
  final int size;

  const DebridTorrentFile({
    required this.id,
    this.index = 0,
    required this.name,
    this.path = '',
    this.size = 0,
  });

  factory DebridTorrentFile.fromJson(Map<String, dynamic> json) {
    return DebridTorrentFile(
      id: json['id']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'index': index,
      'name': name,
      'path': path,
      'size': size,
    };
  }
}

class DebridTorrentItem {
  final String id;
  final String name;
  final String hash;
  final int size;
  final String formattedSize;
  final int completionPercentage;
  final String eta;
  final String status;
  final String added;
  final String? speed;
  final int? seeders;
  final bool isReady;
  final bool isQueuedForLocalDownload;
  final bool isDownloadingLocally;
  final List<DebridTorrentFile> files;

  const DebridTorrentItem({
    required this.id,
    required this.name,
    this.hash = '',
    this.size = 0,
    this.formattedSize = '',
    this.completionPercentage = 0,
    this.eta = '',
    this.status = '',
    this.added = '',
    this.speed,
    this.seeders,
    this.isReady = false,
    this.isQueuedForLocalDownload = false,
    this.isDownloadingLocally = false,
    this.files = const [],
  });

  factory DebridTorrentItem.fromJson(Map<String, dynamic> json) {
    return DebridTorrentItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      hash: json['hash'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      formattedSize: json['formattedSize'] as String? ?? '',
      completionPercentage:
          (json['completionPercentage'] as num?)?.toInt() ?? 0,
      eta: json['eta'] as String? ?? '',
      status: json['status'] as String? ?? '',
      added: json['added'] as String? ?? '',
      speed: json['speed'] as String?,
      seeders: (json['seeders'] as num?)?.toInt(),
      isReady: json['isReady'] as bool? ?? false,
      isQueuedForLocalDownload:
          json['isQueuedForLocalDownload'] as bool? ?? false,
      isDownloadingLocally: json['isDownloadingLocally'] as bool? ?? false,
      files: (json['files'] as List<dynamic>?)
              ?.map(
                  (f) => DebridTorrentFile.fromJson(f as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'hash': hash,
      'size': size,
      'formattedSize': formattedSize,
      'completionPercentage': completionPercentage,
      'eta': eta,
      'status': status,
      'added': added,
      if (speed != null) 'speed': speed,
      if (seeders != null) 'seeders': seeders,
      'isReady': isReady,
      'isQueuedForLocalDownload': isQueuedForLocalDownload,
      'isDownloadingLocally': isDownloadingLocally,
      'files': files.map((f) => f.toJson()).toList(),
    };
  }
}

class DebridCachedFile {
  final int size;
  final String name;

  const DebridCachedFile({
    this.size = 0,
    required this.name,
  });

  factory DebridCachedFile.fromJson(Map<String, dynamic> json) {
    return DebridCachedFile(
      size: (json['size'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'size': size,
      'name': name,
    };
  }
}

class DebridInstantAvailability {
  final Map<String, DebridCachedFile> cachedFiles;

  const DebridInstantAvailability({
    this.cachedFiles = const {},
  });

  factory DebridInstantAvailability.fromJson(Map<String, dynamic> json) {
    final rawFiles = json['cachedFiles'] as Map<String, dynamic>?;
    final Map<String, DebridCachedFile> parsed = {};
    if (rawFiles != null) {
      rawFiles.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          parsed[key] = DebridCachedFile.fromJson(value);
        }
      } );
    }
    return DebridInstantAvailability(cachedFiles: parsed);
  }

  bool get isCached => cachedFiles.isNotEmpty;
}
