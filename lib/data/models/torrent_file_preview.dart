class TorrentFilePreview {
  final String path;
  final String displayPath;
  final String displayTitle;
  final int episodeNumber;
  final int relativeEpisodeNumber;
  final bool isLikely;
  final int index;

  const TorrentFilePreview({
    required this.path,
    required this.displayPath,
    required this.displayTitle,
    required this.episodeNumber,
    this.relativeEpisodeNumber = 0,
    required this.isLikely,
    required this.index,
  });

  factory TorrentFilePreview.fromJson(Map<String, dynamic> json) {
    return TorrentFilePreview(
      path: json['path'] as String? ?? '',
      displayPath: json['displayPath'] as String? ?? '',
      displayTitle: json['displayTitle'] as String? ?? '',
      episodeNumber: json['episodeNumber'] as int? ?? -1,
      relativeEpisodeNumber: json['relativeEpisodeNumber'] as int? ?? 0,
      isLikely: json['isLikely'] as bool? ?? false,
      index: json['index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'displayPath': displayPath,
      'displayTitle': displayTitle,
      'episodeNumber': episodeNumber,
      'relativeEpisodeNumber': relativeEpisodeNumber,
      'isLikely': isLikely,
      'index': index,
    };
  }

  /// Evaluates whether this file is a video file based on extension.
  bool get isVideo {
    final lower = (displayPath.isNotEmpty ? displayPath : path).toLowerCase();
    return lower.endsWith('.mkv') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');
  }

  /// Extracts clean filename without directory path.
  String get fileName {
    final raw = displayPath.isNotEmpty ? displayPath : path;
    if (raw.isEmpty) return 'Archivo #$index';
    final parts = raw.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : raw;
  }
}
