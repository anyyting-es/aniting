class DesktopEpisodeItemData {
  final int number;
  final String title;
  final String? synopsis;
  final String? image;
  final String? aniDBEpisode;
  final bool isWatched;
  final bool isDownloaded;
  final bool isDownloading;
  final double? downloadProgress;
  final String? localFilePath;

  const DesktopEpisodeItemData({
    required this.number,
    required this.title,
    this.synopsis,
    this.image,
    this.aniDBEpisode,
    this.isWatched = false,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.localFilePath,
  });
}

