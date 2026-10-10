import 'package:seanime_app/data/models/anime_details.dart';

class TmdbEpisode {
  final int id;
  final String name;
  final int episodeNumber;
  final int seasonNumber;
  final String? overview;
  final String? stillPath;
  final String? airDate;
  final double? voteAverage;
  final int? runtime;

  const TmdbEpisode({
    required this.id,
    required this.name,
    required this.episodeNumber,
    required this.seasonNumber,
    this.overview,
    this.stillPath,
    this.airDate,
    this.voteAverage,
    this.runtime,
  });

  String? get stillUrl =>
      stillPath != null ? 'https://image.tmdb.org/t/p/w500$stillPath' : null;

  factory TmdbEpisode.fromJson(Map<String, dynamic> json) {
    return TmdbEpisode(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? 'Episodio ${json['episode_number']}') as String,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 1,
      overview: json['overview'] as String?,
      stillPath: json['still_path'] as String?,
      airDate: json['air_date'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      runtime: (json['runtime'] as num?)?.toInt(),
    );
  }
}

class TmdbSeason {
  final int id;
  final String name;
  final int seasonNumber;
  final int episodeCount;
  final String? overview;
  final String? posterPath;
  final String? airDate;

  const TmdbSeason({
    required this.id,
    required this.name,
    required this.seasonNumber,
    required this.episodeCount,
    this.overview,
    this.posterPath,
    this.airDate,
  });

  String? get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;

  factory TmdbSeason.fromJson(Map<String, dynamic> json) {
    return TmdbSeason(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? 'Temporada ${json['season_number']}') as String,
      seasonNumber: (json['season_number'] as num?)?.toInt() ?? 0,
      episodeCount: (json['episode_count'] as num?)?.toInt() ?? 0,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      airDate: json['air_date'] as String?,
    );
  }
}

class TmdbShowDetails {
  final int id;
  final String name;
  final String? originalName;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final double? voteAverage;
  final String? firstAirDate;
  final String? status;
  final int? numberOfSeasons;
  final int? numberOfEpisodes;
  final List<String> genres;
  final List<TmdbSeason> seasons;
  final bool isMovie;
  final int? runtime;

  const TmdbShowDetails({
    required this.id,
    required this.name,
    this.originalName,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.voteAverage,
    this.firstAirDate,
    this.status,
    this.numberOfSeasons,
    this.numberOfEpisodes,
    this.genres = const [],
    this.seasons = const [],
    this.isMovie = false,
    this.runtime,
  });

  String? get posterUrl =>
      posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;
  String? get backdropUrl => backdropPath != null
      ? 'https://image.tmdb.org/t/p/w1280$backdropPath'
      : null;

  factory TmdbShowDetails.fromJson(
    Map<String, dynamic> json, {
    bool isMovie = false,
  }) {
    final rawGenres = json['genres'] as List<dynamic>? ?? [];
    final genres = rawGenres
        .map((g) => (g is Map ? g['name'] : g).toString())
        .where((g) => g.isNotEmpty)
        .toList();

    final rawSeasons = json['seasons'] as List<dynamic>? ?? [];
    final seasons = rawSeasons
        .map((s) => TmdbSeason.fromJson(s as Map<String, dynamic>))
        .toList();

    return TmdbShowDetails(
      id: json['id'] as int? ?? 0,
      name: (json['name'] ?? json['title'] ?? '') as String,
      originalName:
          (json['original_name'] ?? json['original_title']) as String?,
      overview: json['overview'] as String?,
      posterPath: json['poster_path'] as String?,
      backdropPath: json['backdrop_path'] as String?,
      voteAverage: (json['vote_average'] as num?)?.toDouble(),
      firstAirDate:
          (json['first_air_date'] ?? json['release_date']) as String?,
      status: json['status'] as String?,
      numberOfSeasons: (json['number_of_seasons'] as num?)?.toInt(),
      numberOfEpisodes: (json['number_of_episodes'] as num?)?.toInt(),
      genres: genres,
      seasons: seasons,
      isMovie: isMovie,
      runtime: (json['runtime'] as num?)?.toInt(),
    );
  }

  /// Converts to universal AnimeDetails for layout reuse
  AnimeDetails toAnimeDetails() {
    int? year;
    if (firstAirDate != null && firstAirDate!.length >= 4) {
      year = int.tryParse(firstAirDate!.substring(0, 4));
    }
    return AnimeDetails(
      id: id,
      title: name,
      englishTitle: name,
      romajiTitle: name,
      nativeTitle: originalName,
      coverImage: posterUrl,
      bannerImage: backdropUrl,
      description: overview,
      genres: genres,
      totalEpisodes: isMovie ? 1 : numberOfEpisodes,
      format: isMovie ? 'MOVIE' : 'TV',
      score: voteAverage != null ? (voteAverage! * 10).roundToDouble() : null,
      status: status ?? 'RELEASING',
      seasonYear: year,
      isTmdb: true,
      rawMedia: {
        'isTmdb': true,
        'numberOfSeasons': numberOfSeasons,
        'numberOfEpisodes': numberOfEpisodes,
        'runtime': runtime,
      },
    );
  }
}
