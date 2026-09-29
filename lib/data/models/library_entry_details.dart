class LibraryEntryDetails {
  final int mediaId;
  final bool hasLibraryData;
  final List<LibraryEpisode> episodes;
  final int progress;

  const LibraryEntryDetails({
    required this.mediaId,
    required this.hasLibraryData,
    required this.episodes,
    this.progress = 0,
  });

  factory LibraryEntryDetails.fromJson(Map<String, dynamic> json) {
    final root = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;
    final mId = root['mediaId'] as int? ?? 0;
    final hasLib = root['libraryData'] != null;

    final listData = root['listData'] as Map<String, dynamic>?;
    final progress = listData?['progress'] as int? ?? 0;

    final epList = <LibraryEpisode>[];
    if (root['episodes'] is List) {
      for (final e in root['episodes'] as List) {
        if (e is Map<String, dynamic>) {
          epList.add(LibraryEpisode.fromJson(e));
        }
      }
    }

    return LibraryEntryDetails(
      mediaId: mId,
      hasLibraryData: hasLib,
      episodes: epList,
      progress: progress,
    );
  }
}

class LibraryEpisode {
  final int episodeNumber;
  final String displayTitle;
  final String? episodeTitle;
  final bool isDownloaded;
  final String? localFilePath;
  final String? thumbnail;

  const LibraryEpisode({
    required this.episodeNumber,
    required this.displayTitle,
    this.episodeTitle,
    this.isDownloaded = false,
    this.localFilePath,
    this.thumbnail,
  });

  factory LibraryEpisode.fromJson(Map<String, dynamic> json) {
    final localFile = json['localFile'] as Map<String, dynamic>?;
    final meta = json['episodeMetadata'] as Map<String, dynamic>?;

    return LibraryEpisode(
      episodeNumber: json['episodeNumber'] as int? ??
          json['progressNumber'] as int? ??
          1,
      displayTitle: json['displayTitle'] as String? ??
          'Episodio ${json['episodeNumber'] ?? 1}',
      episodeTitle: json['episodeTitle'] as String?,
      isDownloaded:
          json['isDownloaded'] as bool? ?? (localFile != null),
      localFilePath: localFile?['path'] as String?,
      thumbnail: meta?['image'] as String?,
    );
  }
}
