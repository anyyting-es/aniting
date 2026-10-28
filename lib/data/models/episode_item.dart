import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';

/// Unified, media-agnostic episode data item.
/// Represents an episode or film across Anime (AniList/AniZip),
/// TV Series (TMDB), and Local Library media.
class EpisodeItem {
  final String id;
  final int number;
  final int? seasonNumber;
  final String title;
  final String? synopsis;
  final String? image;
  final String? airDate;
  final int? durationMinutes;
  final double? rating;
  final String? aniDBEpisode;

  // Playback & Watch status
  final bool isWatched;
  final double progress; // 0.0 to 1.0 fraction
  final int? playbackPositionSeconds;
  final int? durationSeconds;

  // Local storage & downloads
  final bool isDownloaded;
  final bool isDownloading;
  final double? downloadProgress;
  final String? localFilePath;

  // Metadata flags
  final bool isFiller;
  final bool isSpecial;

  const EpisodeItem({
    required this.id,
    required this.number,
    this.seasonNumber,
    required this.title,
    this.synopsis,
    this.image,
    this.airDate,
    this.durationMinutes,
    this.rating,
    this.aniDBEpisode,
    this.isWatched = false,
    this.progress = 0.0,
    this.playbackPositionSeconds,
    this.durationSeconds,
    this.isDownloaded = false,
    this.isDownloading = false,
    this.downloadProgress,
    this.localFilePath,
    this.isFiller = false,
    this.isSpecial = false,
  });

  /// Factory from TMDB Episode
  factory EpisodeItem.fromTmdb(
    TmdbEpisode ep, {
    bool isWatched = false,
    double progress = 0.0,
    bool isDownloaded = false,
    String? localFilePath,
  }) {
    return EpisodeItem(
      id: 'tmdb_${ep.seasonNumber}_${ep.episodeNumber}',
      number: ep.episodeNumber,
      seasonNumber: ep.seasonNumber,
      title: ep.name.isNotEmpty ? ep.name : 'Episodio ${ep.episodeNumber}',
      synopsis: ep.overview,
      image: ep.stillUrl,
      airDate: ep.airDate,
      durationMinutes: ep.runtime,
      rating: ep.voteAverage,
      isWatched: isWatched,
      progress: progress,
      isDownloaded: isDownloaded,
      localFilePath: localFilePath,
    );
  }

  /// Factory from AniZip episode metadata
  factory EpisodeItem.fromAniZip(
    int episodeNumber,
    AniZipEpisode? zipEp, {
    String? fallbackTitle,
    String? fallbackImage,
    bool isWatched = false,
    double progress = 0.0,
    bool isDownloaded = false,
    String? localFilePath,
    bool isDownloading = false,
    double? downloadProgress,
  }) {
    final title = zipEp?.displayTitle.isNotEmpty == true
        ? zipEp!.displayTitle
        : (fallbackTitle?.isNotEmpty == true ? fallbackTitle! : 'Episodio $episodeNumber');
    return EpisodeItem(
      id: 'anizip_$episodeNumber',
      number: episodeNumber,
      title: title,
      synopsis: zipEp?.synopsis,
      image: zipEp?.image ?? fallbackImage,
      airDate: zipEp?.airDate,
      rating: zipEp?.rating != null ? double.tryParse(zipEp!.rating!) : null,
      aniDBEpisode: zipEp?.anidbEid?.toString(),
      isWatched: isWatched,
      progress: progress,
      isDownloaded: isDownloaded,
      localFilePath: localFilePath,
      isDownloading: isDownloading,
      downloadProgress: downloadProgress,
    );
  }

  /// Factory from Library episode (local scan)
  factory EpisodeItem.fromLibraryEpisode(
    LibraryEpisode ep, {
    AniZipEpisode? zipEp,
    String? fallbackImage,
    int? currentWatchedEpisode,
  }) {
    final num = ep.episodeNumber;
    final isWatched = currentWatchedEpisode != null && currentWatchedEpisode >= num;
    final title = ep.displayTitle.isNotEmpty
        ? ep.displayTitle
        : (zipEp?.displayTitle.isNotEmpty == true ? zipEp!.displayTitle : 'Episodio $num');

    return EpisodeItem(
      id: 'local_$num',
      number: num,
      title: title,
      synopsis: zipEp?.synopsis,
      image: zipEp?.image ?? fallbackImage,
      airDate: zipEp?.airDate,
      aniDBEpisode: zipEp?.anidbEid?.toString(),
      isWatched: isWatched,
      isDownloaded: ep.isDownloaded,
      localFilePath: ep.localFilePath,
    );
  }

  EpisodeItem copyWith({
    String? id,
    int? number,
    int? seasonNumber,
    String? title,
    String? synopsis,
    String? image,
    String? airDate,
    int? durationMinutes,
    double? rating,
    String? aniDBEpisode,
    bool? isWatched,
    double? progress,
    int? playbackPositionSeconds,
    int? durationSeconds,
    bool? isDownloaded,
    bool? isDownloading,
    double? downloadProgress,
    String? localFilePath,
    bool? isFiller,
    bool? isSpecial,
  }) {
    return EpisodeItem(
      id: id ?? this.id,
      number: number ?? this.number,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      title: title ?? this.title,
      synopsis: synopsis ?? this.synopsis,
      image: image ?? this.image,
      airDate: airDate ?? this.airDate,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      rating: rating ?? this.rating,
      aniDBEpisode: aniDBEpisode ?? this.aniDBEpisode,
      isWatched: isWatched ?? this.isWatched,
      progress: progress ?? this.progress,
      playbackPositionSeconds: playbackPositionSeconds ?? this.playbackPositionSeconds,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      localFilePath: localFilePath ?? this.localFilePath,
      isFiller: isFiller ?? this.isFiller,
      isSpecial: isSpecial ?? this.isSpecial,
    );
  }
}
