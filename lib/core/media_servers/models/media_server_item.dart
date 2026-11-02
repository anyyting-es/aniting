enum MediaServerItemType {
  movie,
  show,
  season,
  episode,
  other;

  static MediaServerItemType fromRaw(String? raw) {
    if (raw == null) return MediaServerItemType.other;
    final l = raw.toLowerCase();
    if (l == 'movie') return MediaServerItemType.movie;
    if (l == 'show' || l == 'series') return MediaServerItemType.show;
    if (l == 'season') return MediaServerItemType.season;
    if (l == 'episode') return MediaServerItemType.episode;
    return MediaServerItemType.other;
  }
}

/// Representa un elemento de contenido (película, serie, temporada o episodio).
class MediaServerItem {
  final String id;
  final String serverId;
  final String title;
  final String? originalTitle;
  final MediaServerItemType type;
  final String? parentId;
  final String? parentTitle;
  final String? grandParentTitle;

  /// Rating key / id of the series an episode belongs to. Used to fetch the
  /// full episode list when the player needs its right-hand rail.
  final String? grandParentId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String? overview;
  final int? year;

  /// Original air date as reported by the server (`yyyy-MM-dd`), when known.
  final String? airDate;
  final int? durationMs;
  final int? playbackPositionMs;
  final String? thumbUrl;
  final String? backdropUrl;
  final String? streamUrl;
  final int? introStartMs;
  final int? introEndMs;
  final bool isWatched;
  final double? rating;
  final Map<String, String>? externalIds;
  final List<String> genres;
  final String? studio;
  final String? logoUrl;

  /// Total episodes reported by the server for a show/movie (includes every
  /// season). Lets the UI show the count before the episode list is fetched.
  final int? episodeCount;

  /// Number of seasons reported by the server.
  final int? seasonCount;

  const MediaServerItem({
    required this.id,
    required this.serverId,
    required this.title,
    this.originalTitle,
    required this.type,
    this.parentId,
    this.parentTitle,
    this.grandParentTitle,
    this.grandParentId,
    this.seasonNumber,
    this.episodeNumber,
    this.overview,
    this.year,
    this.airDate,
    this.durationMs,
    this.playbackPositionMs,
    this.thumbUrl,
    this.backdropUrl,
    this.streamUrl,
    this.introStartMs,
    this.introEndMs,
    this.isWatched = false,
    this.rating,
    this.externalIds,
    this.genres = const [],
    this.studio,
    this.logoUrl,
    this.episodeCount,
    this.seasonCount,
  });

  /// Progreso relativo de visualización entre 0.0 y 1.0.
  double get progress {
    if (durationMs == null || durationMs! <= 0) return 0.0;
    if (playbackPositionMs == null || playbackPositionMs! <= 0) return 0.0;
    final p = playbackPositionMs! / durationMs!;
    return p.clamp(0.0, 1.0);
  }

  /// Título contextual formateado (ej. "S1:E4 · Nombre del episodio").
  String get displayEpisodeLabel {
    if (type == MediaServerItemType.episode) {
      final s = seasonNumber ?? 1;
      final e = episodeNumber ?? 1;
      return 'T$s:E$e · $title';
    }
    return title;
  }

  MediaServerItem copyWith({
    String? id,
    String? serverId,
    String? title,
    String? originalTitle,
    MediaServerItemType? type,
    String? parentId,
    String? parentTitle,
    String? grandParentTitle,
    String? grandParentId,
    int? seasonNumber,
    int? episodeNumber,
    String? overview,
    int? year,
    String? airDate,
    int? durationMs,
    int? playbackPositionMs,
    String? thumbUrl,
    String? backdropUrl,
    String? streamUrl,
    int? introStartMs,
    int? introEndMs,
    bool? isWatched,
    double? rating,
    Map<String, String>? externalIds,
    List<String>? genres,
    String? studio,
    String? logoUrl,
    int? episodeCount,
    int? seasonCount,
  }) {
    return MediaServerItem(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      title: title ?? this.title,
      originalTitle: originalTitle ?? this.originalTitle,
      type: type ?? this.type,
      parentId: parentId ?? this.parentId,
      parentTitle: parentTitle ?? this.parentTitle,
      grandParentTitle: grandParentTitle ?? this.grandParentTitle,
      grandParentId: grandParentId ?? this.grandParentId,
      seasonNumber: seasonNumber ?? this.seasonNumber,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      overview: overview ?? this.overview,
      year: year ?? this.year,
      airDate: airDate ?? this.airDate,
      durationMs: durationMs ?? this.durationMs,
      playbackPositionMs: playbackPositionMs ?? this.playbackPositionMs,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      backdropUrl: backdropUrl ?? this.backdropUrl,
      streamUrl: streamUrl ?? this.streamUrl,
      introStartMs: introStartMs ?? this.introStartMs,
      introEndMs: introEndMs ?? this.introEndMs,
      isWatched: isWatched ?? this.isWatched,
      rating: rating ?? this.rating,
      externalIds: externalIds ?? this.externalIds,
      genres: genres ?? this.genres,
      studio: studio ?? this.studio,
      logoUrl: logoUrl ?? this.logoUrl,
      episodeCount: episodeCount ?? this.episodeCount,
      seasonCount: seasonCount ?? this.seasonCount,
    );
  }
}
