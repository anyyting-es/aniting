import 'package:seanime_app/core/preferences/title_language_provider.dart';

class MangaEntry {
  final int id;
  final int mediaId;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? nativeTitle;
  final String? coverImage;
  final String? bannerImage;
  final int progress;
  final int? totalChapters;
  final int? totalVolumes;
  final String status;
  final double? score;
  final String? format;
  final String? description;
  final List<String> genres;
  final int? currentChapter;
  final String? chapterTitle;
  final int? updatedAt;
  final int? year;
  final String? localCoverPath;
  final String? localBannerPath;
  final bool isDownloaded;
  final int downloadedChaptersCount;
  final String? coverColor;
  final Map<String, dynamic>? rawMedia;

  MangaEntry({
    required this.id,
    required this.mediaId,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    this.nativeTitle,
    this.coverImage,
    this.bannerImage,
    required this.progress,
    this.totalChapters,
    this.totalVolumes,
    required this.status,
    this.score,
    this.format,
    this.description,
    this.genres = const [],
    this.currentChapter,
    this.chapterTitle,
    this.updatedAt,
    this.year,
    this.localCoverPath,
    this.localBannerPath,
    this.isDownloaded = false,
    this.downloadedChaptersCount = 0,
    this.coverColor,
    this.rawMedia,
  });

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

  String getTitle(TitleLanguage pref) {
    switch (pref) {
      case TitleLanguage.romaji:
        return (romajiTitle != null && romajiTitle!.isNotEmpty) ? romajiTitle! : title;
      case TitleLanguage.english:
        return (englishTitle != null && englishTitle!.isNotEmpty) ? englishTitle! : title;
      case TitleLanguage.native:
        return (nativeTitle != null && nativeTitle!.isNotEmpty) ? nativeTitle! : title;
    }
  }

  String displayTitle(TitleLanguage pref) => getTitle(pref);

  MangaEntry copyWith({
    int? id,
    int? mediaId,
    String? title,
    String? englishTitle,
    String? romajiTitle,
    String? nativeTitle,
    String? coverImage,
    String? bannerImage,
    int? progress,
    int? totalChapters,
    int? totalVolumes,
    String? status,
    double? score,
    String? format,
    String? description,
    List<String>? genres,
    int? currentChapter,
    String? chapterTitle,
    int? updatedAt,
    int? year,
    String? localCoverPath,
    String? localBannerPath,
    bool? isDownloaded,
    int? downloadedChaptersCount,
    String? coverColor,
    Map<String, dynamic>? rawMedia,
  }) {
    return MangaEntry(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      englishTitle: englishTitle ?? this.englishTitle,
      romajiTitle: romajiTitle ?? this.romajiTitle,
      nativeTitle: nativeTitle ?? this.nativeTitle,
      coverImage: coverImage ?? this.coverImage,
      bannerImage: bannerImage ?? this.bannerImage,
      progress: progress ?? this.progress,
      totalChapters: totalChapters ?? this.totalChapters,
      totalVolumes: totalVolumes ?? this.totalVolumes,
      status: status ?? this.status,
      score: score ?? this.score,
      format: format ?? this.format,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      currentChapter: currentChapter ?? this.currentChapter,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      updatedAt: updatedAt ?? this.updatedAt,
      year: year ?? this.year,
      localCoverPath: localCoverPath ?? this.localCoverPath,
      localBannerPath: localBannerPath ?? this.localBannerPath,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadedChaptersCount: downloadedChaptersCount ?? this.downloadedChaptersCount,
      coverColor: coverColor ?? this.coverColor,
      rawMedia: rawMedia ?? this.rawMedia,
    );
  }

  factory MangaEntry.fromJson(Map<String, dynamic> json) {
    // 1. Resolve media object (can be under 'media', 'baseManga', or root)
    final media = (json['media'] is Map<String, dynamic>)
        ? json['media'] as Map<String, dynamic>
        : (json['baseManga'] is Map<String, dynamic>
            ? json['baseManga'] as Map<String, dynamic>
            : json);

    final titleObj = (media['title'] is Map<String, dynamic>)
        ? media['title'] as Map<String, dynamic>
        : (json['title'] is Map<String, dynamic> ? json['title'] as Map<String, dynamic> : {});

    final cover = (media['coverImage'] is Map<String, dynamic>)
        ? media['coverImage'] as Map<String, dynamic>
        : (json['coverImage'] is Map<String, dynamic> ? json['coverImage'] as Map<String, dynamic> : null);

    final romaji = titleObj['romaji'] as String?;
    final english = titleObj['english'] as String?;
    final native = titleObj['native'] as String?;
    final preferred = titleObj['userPreferred'] as String? ??
        english ??
        romaji ??
        native ??
        (media['title'] is String ? media['title'] as String : 'Manga');

    // Parse listData if present
    final listData = json['listData'] as Map<String, dynamic>?;
    int progress = 0;
    if (listData != null && listData['progress'] is num) {
      progress = (listData['progress'] as num).toInt();
    } else if (json['progress'] is num) {
      progress = (json['progress'] as num).toInt();
    }

    String status = 'PLANNING';
    if (listData != null && listData['status'] is String) {
      status = listData['status'] as String;
    } else if (json['status'] is String) {
      status = json['status'] as String;
    }

    double? score;
    if (listData != null && listData['score'] is num) {
      score = (listData['score'] as num).toDouble();
    } else if (media['averageScore'] is num) {
      score = (media['averageScore'] as num).toDouble() / 10.0;
    } else if (media['meanScore'] is num) {
      score = (media['meanScore'] as num).toDouble() / 10.0;
    }

    int? totalChapters;
    if (media['chapters'] is num) {
      totalChapters = (media['chapters'] as num).toInt();
    } else if (json['totalChapters'] is num) {
      totalChapters = (json['totalChapters'] as num).toInt();
    }

    int? totalVolumes;
    if (media['volumes'] is num) {
      totalVolumes = (media['volumes'] as num).toInt();
    }

    final genresList = <String>[];
    if (media['genres'] is List) {
      for (final g in media['genres'] as List) {
        if (g is String && g.isNotEmpty) genresList.add(g);
      }
    }

    int? year;
    if (media['startDate'] is Map && (media['startDate'] as Map)['year'] is num) {
      year = ((media['startDate'] as Map)['year'] as num).toInt();
    } else if (media['year'] is num) {
      year = (media['year'] as num).toInt();
    }

    final id = (json['id'] is num)
        ? (json['id'] as num).toInt()
        : ((media['id'] is num) ? (media['id'] as num).toInt() : 0);
    final mediaId = (media['id'] is num) ? (media['id'] as num).toInt() : id;

    final String? resolvedCover = cover is Map<String, dynamic>
        ? (cover['large'] ?? cover['extraLarge'] ?? cover['medium'] ?? cover['url'])
        : (json['coverImage'] is String
            ? json['coverImage'] as String
            : (media['coverImage'] is String ? media['coverImage'] as String : null));

    final String? resolvedBanner =
        (media['bannerImage'] as String?) ?? (json['bannerImage'] as String?);
    final String? resolvedDesc =
        (media['description'] as String?) ?? (json['description'] as String?);
    final String? resolvedFormat =
        (media['format'] as String?) ?? (json['format'] as String?);
    final String? resolvedCoverColor = cover is Map<String, dynamic>
        ? cover['color'] as String?
        : (json['coverColor'] as String?);
    final rawMediaMap = media.isNotEmpty ? media : null;

    return MangaEntry(
      id: id,
      mediaId: mediaId,
      title: preferred,
      englishTitle: english,
      romajiTitle: romaji,
      nativeTitle: native,
      coverImage: resolvedCover,
      bannerImage: resolvedBanner,
      progress: progress,
      totalChapters: totalChapters,
      totalVolumes: totalVolumes,
      status: status,
      score: score,
      format: resolvedFormat,
      description: resolvedDesc,
      genres: genresList,
      currentChapter: (json['currentChapter'] is num)
          ? (json['currentChapter'] as num).toInt()
          : (progress > 0 ? progress : 1),
      chapterTitle: json['chapterTitle'] as String?,
      updatedAt: (json['updatedAt'] as num?)?.toInt(),
      year: year,
      localCoverPath: json['localCoverPath'] as String?,
      localBannerPath: json['localBannerPath'] as String?,
      isDownloaded: json['isDownloaded'] == true,
      downloadedChaptersCount:
          (json['downloadedChaptersCount'] as num?)?.toInt() ?? 0,
      coverColor: resolvedCoverColor,
      rawMedia: rawMediaMap,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'mediaId': mediaId,
      'title': title,
      'englishTitle': englishTitle,
      'romajiTitle': romajiTitle,
      'nativeTitle': nativeTitle,
      'coverImage': coverImage,
      'bannerImage': bannerImage,
      'progress': progress,
      'totalChapters': totalChapters,
      'totalVolumes': totalVolumes,
      'status': status,
      'score': score,
      'format': format,
      'description': description,
      'genres': genres,
      'currentChapter': currentChapter,
      'chapterTitle': chapterTitle,
      'updatedAt': updatedAt,
      'year': year,
      'localCoverPath': localCoverPath,
      'localBannerPath': localBannerPath,
      'isDownloaded': isDownloaded,
      'downloadedChaptersCount': downloadedChaptersCount,
      'coverColor': coverColor,
    };
  }
}

class MangaChapter {
  final String id;
  final String url;
  final String title;
  final String chapter;
  final int index;
  final String? scanlator;
  final String? language;
  final int? rating;
  final String? updatedAt;

  const MangaChapter({
    required this.id,
    required this.url,
    required this.title,
    required this.chapter,
    required this.index,
    this.scanlator,
    this.language,
    this.rating,
    this.updatedAt,
  });

  factory MangaChapter.fromJson(Map<String, dynamic> json) {
    return MangaChapter(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? '',
      chapter: json['chapter']?.toString() ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      scanlator: json['scanlator'] as String?,
      language: json['language'] as String?,
      rating: (json['rating'] as num?)?.toInt(),
      updatedAt: json['updatedAt'] as String?,
    );
  }

  double get chapterNumber {
    return double.tryParse(chapter) ?? (index + 1).toDouble();
  }
}

class MangaChapterContainer {
  final int mediaId;
  final String provider;
  final List<MangaChapter> chapters;

  const MangaChapterContainer({
    required this.mediaId,
    required this.provider,
    required this.chapters,
  });

  factory MangaChapterContainer.fromJson(Map<String, dynamic> json) {
    final chaptersList = (json['chapters'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(MangaChapter.fromJson)
            .toList() ??
        [];
    return MangaChapterContainer(
      mediaId: (json['mediaId'] as num?)?.toInt() ?? 0,
      provider: json['provider'] as String? ?? '',
      chapters: chaptersList,
    );
  }
}

class MangaPage {
  final String url;
  final int index;
  final Map<String, String> headers;

  const MangaPage({
    required this.url,
    required this.index,
    this.headers = const {},
  });

  factory MangaPage.fromJson(Map<String, dynamic> json) {
    final rawHeaders = json['headers'];
    final headersMap = <String, String>{};
    if (rawHeaders is Map) {
      rawHeaders.forEach((k, v) {
        if (k != null && v != null) headersMap[k.toString()] = v.toString();
      });
    }
    return MangaPage(
      url: json['url'] as String? ?? '',
      index: (json['index'] as num?)?.toInt() ?? 0,
      headers: headersMap,
    );
  }
}

class MangaProvider {
  final String id;
  final String name;
  final String? lang;
  final String? icon;

  const MangaProvider({
    required this.id,
    required this.name,
    this.lang,
    this.icon,
  });

  factory MangaProvider.fromJson(Map<String, dynamic> json) {
    return MangaProvider(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      lang: json['lang'] as String?,
      icon: json['icon'] as String?,
    );
  }
}
