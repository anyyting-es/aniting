import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anizip_data.dart';

class AnimeEpisode {
  final int episodeNumber;
  final String title;
  final String? description;
  final String? image;
  final bool isDownloaded;

  AnimeEpisode({
    required this.episodeNumber,
    required this.title,
    this.description,
    this.image,
    this.isDownloaded = false,
  });

  factory AnimeEpisode.fromJson(Map<String, dynamic> json) {
    final epNum = json['episodeNumber'] as int? ?? json['progressNumber'] as int? ?? 1;
    final displayTitle = json['displayTitle'] as String? ?? json['title'] as String? ?? 'Episodio $epNum';
    return AnimeEpisode(
      episodeNumber: epNum,
      title: displayTitle,
      description: json['description'] as String?,
      image: json['image'] as String?,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }
}

class AnimeDetails {
  final int id;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? nativeTitle;
  final String? coverImage;
  final String? coverColor;
  final String? bannerImage;
  final String? description;
  final List<String> genres;
  final int? totalEpisodes;
  final String? format;
  final double? score;
  final String? status;
  final int? progress;
  final String? userStatus;
  final double? userScore;
  final String? studio;
  final String? season;
  final int? seasonYear;
  final List<AnimeEpisode> episodes;
  final AniZipData? aniZipData;
  final bool isAdult;
  final Map<String, dynamic>? rawMedia;

  AnimeDetails({
    required this.id,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    this.nativeTitle,
    this.coverImage,
    this.coverColor,
    this.bannerImage,
    this.description,
    this.genres = const [],
    this.totalEpisodes,
    this.format,
    this.score,
    this.status,
    this.progress,
    this.userStatus,
    this.userScore,
    this.studio,
    this.season,
    this.seasonYear,
    this.episodes = const [],
    this.aniZipData,
    this.isAdult = false,
    this.rawMedia,
  });

  /// Extracts the main character (MC) image from AniList characters edge list
  String? get mainCharacterImage {
    if (rawMedia == null) return null;
    final characters = rawMedia!['characters'] as Map<String, dynamic>?;
    if (characters == null) return null;
    final edges = characters['edges'] as List?;
    if (edges == null || edges.isEmpty) return null;

    // 1. Look for MAIN character
    for (final edge in edges) {
      if (edge is Map<String, dynamic>) {
        final role = edge['role'] as String?;
        if (role == 'MAIN') {
          final node = edge['node'] as Map<String, dynamic>?;
          final img = (node?['image'] as Map<String, dynamic>?)?['large'] ??
              (node?['image'] as Map<String, dynamic>?)?['medium'];
          if (img is String && img.isNotEmpty) return img;
        }
      }
    }

    // 2. Fallback to first available character image
    for (final edge in edges) {
      if (edge is Map<String, dynamic>) {
        final node = edge['node'] as Map<String, dynamic>?;
        final img = (node?['image'] as Map<String, dynamic>?)?['large'] ??
            (node?['image'] as Map<String, dynamic>?)?['medium'];
        if (img is String && img.isNotEmpty) return img;
      }
    }

    return null;
  }

  /// Returns character edges from rawMedia
  List get characters {
    final raw = rawMedia;
    if (raw == null) return const [];
    final chars = raw['characters'];
    if (chars is Map<String, dynamic>) {
      return (chars['edges'] as List?) ?? (chars['nodes'] as List?) ?? const [];
    }
    if (chars is List) return chars;
    return const [];
  }

  /// Returns relation edges from rawMedia
  List get relations {
    final raw = rawMedia;
    if (raw == null) return const [];
    final rels = raw['relations'];
    if (rels is Map<String, dynamic>) {
      return (rels['edges'] as List?) ?? (rels['nodes'] as List?) ?? const [];
    }
    if (rels is List) return rels;
    return const [];
  }

  /// Returns recommendation edges from rawMedia
  List get recommendations {
    final raw = rawMedia;
    if (raw == null) return const [];
    final recs = raw['recommendations'];
    if (recs is Map<String, dynamic>) {
      return (recs['edges'] as List?) ?? (recs['nodes'] as List?) ?? const [];
    }
    if (recs is List) return recs;
    return const [];
  }

  /// Returns trailer data map from rawMedia
  Map<String, dynamic>? get trailer {
    final raw = rawMedia;
    if (raw == null) return null;
    return raw['trailer'] as Map<String, dynamic>?;
  }

  factory AnimeDetails.fromJson(Map<String, dynamic> json, {List<AnimeEpisode> episodes = const []}) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    final mediaMap = data['media'] is Map<String, dynamic>
        ? data['media'] as Map<String, dynamic>
        : (data['baseAnime'] is Map<String, dynamic> ? data['baseAnime'] as Map<String, dynamic> : data);

    final titleObj = (mediaMap['title'] is Map<String, dynamic>)
        ? mediaMap['title'] as Map<String, dynamic>
        : (data['title'] is Map<String, dynamic> ? data['title'] as Map<String, dynamic> : {});

    final romaji = titleObj['romaji'] as String?;
    final english = titleObj['english'] as String?;
    final native = titleObj['native'] as String?;
    final preferred = titleObj['userPreferred'] as String? ??
        english ??
        romaji ??
        native ??
        (mediaMap['title'] is String ? mediaMap['title'] as String : null) ??
        'Sin título';

    final cover = (mediaMap['coverImage'] is Map<String, dynamic>)
        ? mediaMap['coverImage'] as Map<String, dynamic>
        : (data['coverImage'] is Map<String, dynamic> ? data['coverImage'] as Map<String, dynamic> : null);
    final coverUrl = cover?['large'] ?? cover?['extraLarge'] ?? cover?['medium'];
    final coverColor = cover?['color'] as String? ?? (data['coverColor'] as String?);

    final rawGenres = mediaMap['genres'] as List? ?? data['genres'] as List? ?? [];
    final genresList = rawGenres.map((g) => g.toString()).toList();

    // Studio parsing
    String? studioName;
    final studios = (mediaMap['studios'] ?? data['studios']) as Map<String, dynamic>?;
    if (studios != null && studios['nodes'] is List && (studios['nodes'] as List).isNotEmpty) {
      studioName = studios['nodes'][0]['name'] as String?;
    }

    final isAdult = (mediaMap['isAdult'] ?? data['isAdult']) as bool? ?? false;

    // Combine mediaMap and data so characters, relations, recommendations, trailer, etc. are never lost
    final combinedRawMedia = Map<String, dynamic>.from(data);
    combinedRawMedia.addAll(mediaMap);
    for (final key in [
      'characters',
      'relations',
      'recommendations',
      'trailer',
      'studios',
      'staff',
      'rankings',
      'duration',
      'meanScore',
      'popularity',
      'description',
      'genres',
      'startDate',
      'endDate',
    ]) {
      if (data[key] != null) {
        combinedRawMedia[key] = data[key];
      }
    }

    return AnimeDetails(
      id: (mediaMap['id'] ?? data['id'] ?? data['mediaId']) as int? ?? 0,
      title: preferred,
      englishTitle: english,
      romajiTitle: romaji,
      nativeTitle: native,
      coverImage: coverUrl as String?,
      coverColor: coverColor,
      bannerImage: (mediaMap['bannerImage'] ?? data['bannerImage']) as String?,
      description: (mediaMap['description'] ?? data['description']) as String?,
      genres: genresList,
      totalEpisodes: (mediaMap['episodes'] ?? data['episodes']) as int?,
      format: (mediaMap['format'] ?? data['format']) as String?,
      score: ((mediaMap['averageScore'] ?? data['averageScore']) as num?)?.toDouble(),
      status: (mediaMap['status'] ?? data['status']) as String?,
      progress: (data['listData'] is Map ? (data['listData']['progress'] as num?)?.toInt() : null) ??
          (data['progress'] as num?)?.toInt(),
      userStatus: (data['listData'] is Map ? data['listData']['status'] as String? : null) ??
          data['userStatus'] as String?,
      userScore: (data['listData'] is Map ? ((data['listData']['score']) as num?)?.toDouble() : null) ??
          ((data['userScore']) as num?)?.toDouble(),
      studio: studioName,
      season: (mediaMap['season'] ?? data['season']) as String?,
      seasonYear: (mediaMap['seasonYear'] ?? data['seasonYear']) as int?,
      episodes: episodes,
      isAdult: isAdult,
      rawMedia: combinedRawMedia,
    );
  }

  /// Returns the title according to the chosen title language preference
  String displayTitle([TitleLanguage language = TitleLanguage.romaji]) {
    switch (language) {
      case TitleLanguage.english:
        if (englishTitle != null && englishTitle!.trim().isNotEmpty) return englishTitle!.trim();
        if (romajiTitle != null && romajiTitle!.trim().isNotEmpty) return romajiTitle!.trim();
        if (nativeTitle != null && nativeTitle!.trim().isNotEmpty) return nativeTitle!.trim();
        return title.trim().isNotEmpty && title != 'Sin título' ? title : (romajiTitle ?? englishTitle ?? 'Sin título');
      case TitleLanguage.native:
        if (nativeTitle != null && nativeTitle!.trim().isNotEmpty) return nativeTitle!.trim();
        if (romajiTitle != null && romajiTitle!.trim().isNotEmpty) return romajiTitle!.trim();
        if (englishTitle != null && englishTitle!.trim().isNotEmpty) return englishTitle!.trim();
        return title.trim().isNotEmpty && title != 'Sin título' ? title : (romajiTitle ?? englishTitle ?? 'Sin título');
      case TitleLanguage.romaji:
        if (romajiTitle != null && romajiTitle!.trim().isNotEmpty) return romajiTitle!.trim();
        if (englishTitle != null && englishTitle!.trim().isNotEmpty) return englishTitle!.trim();
        if (nativeTitle != null && nativeTitle!.trim().isNotEmpty) return nativeTitle!.trim();
        return title.trim().isNotEmpty && title != 'Sin título' ? title : (romajiTitle ?? englishTitle ?? 'Sin título');
    }
  }

  Map<String, dynamic> toMediaMap() {
    final titleMap = <String, dynamic>{
      'romaji': romajiTitle ?? title,
      'english': englishTitle ?? title,
      'userPreferred': title,
    };

    final rawStartDate = rawMedia?['startDate'];
    final startDateMap = (rawStartDate is Map<String, dynamic>)
        ? {
            'year': rawStartDate['year'] ?? seasonYear ?? 2020,
            'month': rawStartDate['month'] ?? 1,
            'day': rawStartDate['day'] ?? 1,
          }
        : {
            'year': seasonYear ?? 2020,
            'month': 1,
            'day': 1,
          };

    final synonyms = (rawMedia?['synonyms'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];

    return {
      'id': id,
      'isAdult': isAdult,
      'status': status ?? 'FINISHED',
      'format': format ?? 'TV',
      'episodes': totalEpisodes ?? (episodes.isNotEmpty ? episodes.length : 12),
      'synonyms': synonyms,
      'title': titleMap,
      'startDate': startDateMap,
    };
  }

  AnimeDetails copyWith({
    int? id,
    String? title,
    String? englishTitle,
    String? romajiTitle,
    String? nativeTitle,
    String? coverImage,
    String? coverColor,
    String? bannerImage,
    String? description,
    List<String>? genres,
    int? totalEpisodes,
    String? format,
    double? score,
    String? status,
    int? progress,
    String? userStatus,
    double? userScore,
    String? studio,
    String? season,
    int? seasonYear,
    List<AnimeEpisode>? episodes,
    AniZipData? aniZipData,
    bool? isAdult,
    Map<String, dynamic>? rawMedia,
  }) {
    return AnimeDetails(
      id: id ?? this.id,
      title: title ?? this.title,
      englishTitle: englishTitle ?? this.englishTitle,
      romajiTitle: romajiTitle ?? this.romajiTitle,
      nativeTitle: nativeTitle ?? this.nativeTitle,
      coverImage: coverImage ?? this.coverImage,
      coverColor: coverColor ?? this.coverColor,
      bannerImage: bannerImage ?? this.bannerImage,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      format: format ?? this.format,
      score: score ?? this.score,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      userStatus: userStatus ?? this.userStatus,
      userScore: userScore ?? this.userScore,
      studio: studio ?? this.studio,
      season: season ?? this.season,
      seasonYear: seasonYear ?? this.seasonYear,
      episodes: episodes ?? this.episodes,
      aniZipData: aniZipData ?? this.aniZipData,
      isAdult: isAdult ?? this.isAdult,
      rawMedia: rawMedia ?? this.rawMedia,
    );
  }

  AnimeDetails copyWithEpisodes(List<AnimeEpisode> eps) {
    return AnimeDetails(
      id: id,
      title: title,
      englishTitle: englishTitle,
      romajiTitle: romajiTitle,
      nativeTitle: nativeTitle,
      coverImage: coverImage,
      bannerImage: bannerImage,
      description: description,
      genres: genres,
      totalEpisodes: totalEpisodes,
      format: format,
      score: score,
      status: status,
      progress: progress,
      userStatus: userStatus,
      userScore: userScore,
      studio: studio,
      season: season,
      seasonYear: seasonYear,
      episodes: eps,
      aniZipData: aniZipData,
      isAdult: isAdult,
      rawMedia: rawMedia,
    );
  }

  AnimeDetails copyWithAniZipData(AniZipData? data) {
    final aniZipEn = data?.titles['en'];
    final aniZipJa = data?.titles['ja'];
    final aniZipRo = data?.titles['x-jat'] ?? data?.titles['ro'];
    final aniZipEs = data?.titles['es'];

    final resolvedEnglish = englishTitle ?? aniZipEn;
    final resolvedRomaji = romajiTitle ?? aniZipRo;
    final resolvedNative = nativeTitle ?? aniZipJa;

    String resolvedTitle = title;
    if (resolvedTitle == 'Sin título' || resolvedTitle.trim().isEmpty) {
      resolvedTitle = resolvedRomaji ?? resolvedEnglish ?? resolvedNative ?? aniZipEs ?? 'Sin título';
    }

    return AnimeDetails(
      id: id,
      title: resolvedTitle,
      englishTitle: resolvedEnglish,
      romajiTitle: resolvedRomaji,
      nativeTitle: resolvedNative,
      coverImage: coverImage,
      bannerImage: bannerImage,
      description: description,
      genres: genres,
      totalEpisodes: totalEpisodes,
      format: format,
      score: score,
      status: status,
      progress: progress,
      userStatus: userStatus,
      userScore: userScore,
      studio: studio,
      season: season,
      seasonYear: seasonYear,
      episodes: episodes,
      aniZipData: data,
      isAdult: isAdult,
      rawMedia: rawMedia,
    );
  }

  /// Exports this [AnimeDetails] into an AniList `BaseAnime` compatible JSON map.
  /// Guarantees that the Go backend unmarshaler will find a valid `id`, `title`, etc.
  Map<String, dynamic> toBaseAnimeMap() {
    final base = <String, dynamic>{
      'id': id,
      'idMal': id,
      'isAdult': isAdult,
      'status': status ?? 'FINISHED',
      'format': format ?? 'TV',
      'episodes': totalEpisodes ?? 12,
      'synonyms': <String>[],
      'genres': genres,
      'title': {
        'romaji': romajiTitle ?? title,
        'english': englishTitle ?? title,
        'userPreferred': title,
        'native': nativeTitle ?? title,
      },
      'coverImage': {
        'large': coverImage ?? '',
        'medium': coverImage ?? '',
        'color': coverColor ?? '#3b82f6',
      },
      'startDate': {'year': seasonYear ?? 2024, 'month': 1, 'day': 1},
    };
    if (rawMedia != null && rawMedia!.isNotEmpty) {
      base.addAll(rawMedia!);
      base['id'] = id > 0 ? id : (rawMedia!['id'] as int? ?? 0);
      if (base['title'] == null || base['title'] is! Map) {
        base['title'] = {
          'romaji': romajiTitle ?? title,
          'english': englishTitle ?? title,
          'userPreferred': title,
          'native': nativeTitle ?? title,
        };
      }
    }
    return base;
  }
}
