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

  DesktopEpisodeItemData copyWith({
    int? number,
    String? title,
    String? synopsis,
    String? image,
    String? aniDBEpisode,
    bool? isWatched,
    bool? isDownloaded,
    bool? isDownloading,
    double? downloadProgress,
    String? localFilePath,
  }) {
    return DesktopEpisodeItemData(
      number: number ?? this.number,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      image: image ?? this.image,
      aniDBEpisode: aniDBEpisode ?? this.aniDBEpisode,
      isWatched: isWatched ?? this.isWatched,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localFilePath: localFilePath ?? this.localFilePath,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesktopEpisodeItemData &&
          runtimeType == other.runtimeType &&
          number == other.number &&
          title == other.title &&
          synopsis == other.synopsis &&
          image == other.image &&
          aniDBEpisode == other.aniDBEpisode &&
          isWatched == other.isWatched &&
          isDownloaded == other.isDownloaded &&
          isDownloading == other.isDownloading &&
          downloadProgress == other.downloadProgress &&
          localFilePath == other.localFilePath;

  @override
  int get hashCode => Object.hash(
        number,
        title,
        synopsis,
        image,
        aniDBEpisode,
        isWatched,
        isDownloaded,
        isDownloading,
        downloadProgress,
        localFilePath,
      );
}

