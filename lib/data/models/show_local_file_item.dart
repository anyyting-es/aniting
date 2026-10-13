/// Local TV Show and Movie file indexed by the Seanime / TMDB hybrid scanner.
class ShowLocalFileItem {
  final String path;
  final String name;
  final String parsedTitle;
  final int? year;
  final int season;
  final int episode;
  final String? resolution;
  final int tmdbId;
  final String mediaType; // "tv" or "movie"
  final bool locked;
  final bool ignored;
  final String folderPath;
  final String folderName;

  const ShowLocalFileItem({
    required this.path,
    required this.name,
    required this.parsedTitle,
    this.year,
    this.season = 1,
    this.episode = 1,
    this.resolution,
    this.tmdbId = 0,
    this.mediaType = 'tv',
    this.locked = false,
    this.ignored = false,
    required this.folderPath,
    required this.folderName,
  });

  bool get isMatched => tmdbId > 0;
  bool get isUnmatched => tmdbId == 0 && !ignored;

  factory ShowLocalFileItem.fromJson(Map<String, dynamic> json) {
    final rawYear = json['year'];
    final year = rawYear is num ? rawYear.toInt() : int.tryParse('$rawYear');
    final rawSeason = json['season'];
    final season = rawSeason is num ? rawSeason.toInt() : (int.tryParse('$rawSeason') ?? 1);
    final rawEpisode = json['episode'];
    final episode = rawEpisode is num ? rawEpisode.toInt() : (int.tryParse('$rawEpisode') ?? 1);
    final rawTmdbId = json['tmdbId'];
    final tmdbId = rawTmdbId is num ? rawTmdbId.toInt() : (int.tryParse('$rawTmdbId') ?? 0);

    return ShowLocalFileItem(
      path: json['path'] as String? ?? '',
      name: json['name'] as String? ?? '',
      parsedTitle: json['parsedTitle'] as String? ?? '',
      year: year,
      season: season,
      episode: episode,
      resolution: json['resolution'] as String?,
      tmdbId: tmdbId,
      mediaType: json['mediaType'] as String? ?? 'tv',
      locked: json['locked'] == true,
      ignored: json['ignored'] == true,
      folderPath: json['folderPath'] as String? ?? '',
      folderName: json['folderName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'parsedTitle': parsedTitle,
        if (year != null) 'year': year,
        'season': season,
        'episode': episode,
        if (resolution != null) 'resolution': resolution,
        'tmdbId': tmdbId,
        'mediaType': mediaType,
        'locked': locked,
        'ignored': ignored,
        'folderPath': folderPath,
        'folderName': folderName,
      };
}

/// Represents a TV show or movie entry grouping local files.
class ShowEntryItem {
  final int tmdbId;
  final String title;
  final int? year;
  final String mediaType;
  final Map<int, List<ShowLocalFileItem>> seasons;
  final List<ShowLocalFileItem> files;
  final int episodeCount;
  final int seasonCount;

  const ShowEntryItem({
    required this.tmdbId,
    required this.title,
    this.year,
    this.mediaType = 'tv',
    required this.seasons,
    required this.files,
    this.episodeCount = 0,
    this.seasonCount = 0,
  });

  factory ShowEntryItem.fromJson(Map<String, dynamic> json) {
    final rawSeasons = json['seasons'] is Map ? (json['seasons'] as Map) : {};
    final seasonsMap = <int, List<ShowLocalFileItem>>{};
    rawSeasons.forEach((k, v) {
      final sNum = int.tryParse('$k') ?? 1;
      if (v is List) {
        seasonsMap[sNum] = v
            .whereType<Map>()
            .map((e) => ShowLocalFileItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    });

    final rawFiles = json['files'] is List ? (json['files'] as List) : [];
    final filesList = rawFiles
        .whereType<Map>()
        .map((e) => ShowLocalFileItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    final rawYear = json['year'];
    final year = rawYear is num ? rawYear.toInt() : int.tryParse('$rawYear');
    final rawTmdbId = json['tmdbId'];
    final tmdbId = rawTmdbId is num ? rawTmdbId.toInt() : (int.tryParse('$rawTmdbId') ?? 0);
    final rawEpCount = json['episodeCount'];
    final epCount = rawEpCount is num ? rawEpCount.toInt() : (int.tryParse('$rawEpCount') ?? filesList.length);
    final rawSeasonCount = json['seasonCount'];
    final seasonCount = rawSeasonCount is num ? rawSeasonCount.toInt() : (int.tryParse('$rawSeasonCount') ?? seasonsMap.length);

    return ShowEntryItem(
      tmdbId: tmdbId,
      title: json['title'] as String? ?? '',
      year: year,
      mediaType: json['mediaType'] as String? ?? 'tv',
      seasons: seasonsMap,
      files: filesList,
      episodeCount: epCount,
      seasonCount: seasonCount,
    );
  }
}

/// Grouped collection of shows and unmatched local files.
class ShowCollectionItem {
  final List<ShowEntryItem> shows;
  final List<ShowLocalFileItem> unmatched;
  final int totalFiles;
  final int matchedShowsCount;
  final int localEpisodesCount;
  final int unmatchedFilesCount;

  const ShowCollectionItem({
    this.shows = const [],
    this.unmatched = const [],
    this.totalFiles = 0,
    this.matchedShowsCount = 0,
    this.localEpisodesCount = 0,
    this.unmatchedFilesCount = 0,
  });

  factory ShowCollectionItem.fromJson(Map<String, dynamic> json) {
    final rawShows = json['shows'] is List ? (json['shows'] as List) : [];
    final rawUnmatched = json['unmatched'] is List ? (json['unmatched'] as List) : [];

    final rawTotal = json['totalFiles'];
    final rawMatched = json['matchedShowsCount'];
    final rawLocalEps = json['localEpisodesCount'];
    final rawUnmatchedCount = json['unmatchedFilesCount'];

    return ShowCollectionItem(
      shows: rawShows
          .whereType<Map>()
          .map((e) => ShowEntryItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      unmatched: rawUnmatched
          .whereType<Map>()
          .map((e) => ShowLocalFileItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      totalFiles: rawTotal is num ? rawTotal.toInt() : (int.tryParse('$rawTotal') ?? 0),
      matchedShowsCount: rawMatched is num ? rawMatched.toInt() : (int.tryParse('$rawMatched') ?? 0),
      localEpisodesCount: rawLocalEps is num ? rawLocalEps.toInt() : (int.tryParse('$rawLocalEps') ?? 0),
      unmatchedFilesCount: rawUnmatchedCount is num ? rawUnmatchedCount.toInt() : (int.tryParse('$rawUnmatchedCount') ?? 0),
    );
  }
}
