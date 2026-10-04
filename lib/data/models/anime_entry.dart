import 'package:seanime_app/core/preferences/title_language_provider.dart';

class AnimeEntry {
  final int id;
  final int mediaId;
  final String title;
  final String? englishTitle;
  final String? romajiTitle;
  final String? nativeTitle;
  final String? coverImage;
  final String? coverColor;
  final String? bannerImage;
  final int progress;
  final int? totalEpisodes;
  final String status;
  final double? score;
  final String? format;
  final String? description;
  final int? currentEpisode;
  final String? episodeTitle;
  final int? episodeNumber;
  final String? episodeThumbnail;
  final int? updatedAt;
  final String? airDate;
  final int? lastWatchedTime;
  final int? nextAiringEpisodeNumber;
  final int? nextAiringEpisodeAiringAt;
  final int? year;
  final List<String> genres;
  final bool hasLocalFiles;
  final int mainFileCount;

  AnimeEntry({
    required this.id,
    required this.mediaId,
    required this.title,
    this.englishTitle,
    this.romajiTitle,
    this.nativeTitle,
    this.coverImage,
    this.coverColor,
    this.bannerImage,
    required this.progress,
    this.totalEpisodes,
    required this.status,
    this.score,
    this.format,
    this.description,
    this.genres = const [],
    this.currentEpisode,
    this.episodeTitle,
    this.episodeNumber,
    this.episodeThumbnail,
    this.updatedAt,
    this.airDate,
    this.lastWatchedTime,
    this.nextAiringEpisodeNumber,
    this.nextAiringEpisodeAiringAt,
    this.year,
    this.hasLocalFiles = false,
    this.mainFileCount = 0,
  });

  /// Effective timestamp in milliseconds for sorting (watch history > updatedAt > airDate > 0)
  int get effectiveTimestamp {
    if (lastWatchedTime != null && lastWatchedTime! > 0) return lastWatchedTime!;
    if (updatedAt != null && updatedAt! > 0) {
      return updatedAt! > 10000000000 ? updatedAt! : updatedAt! * 1000;
    }
    if (airDate != null && airDate!.isNotEmpty) {
      final parsed = DateTime.tryParse(airDate!);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    return 0;
  }

  /// Returns true if the next episode to watch is available (already aired and not in the future)
  bool get hasNextEpisodeAired {
    if (status == 'NOT_YET_RELEASED') return false;
    final nextEp = episodeNumber ?? (progress + 1);

    // If user has already finished all episodes
    if (totalEpisodes != null && totalEpisodes! > 0 && progress >= totalEpisodes!) {
      return false;
    }

    // If AniList reports the next un-aired episode number
    if (nextAiringEpisodeNumber != null && nextAiringEpisodeNumber! > 0) {
      if (nextEp >= nextAiringEpisodeNumber!) {
        return false;
      }
    }

    // If AniZip / episode airDate is known and in the future
    if (airDate != null && airDate!.isNotEmpty) {
      final parsedDate = DateTime.tryParse(airDate!);
      if (parsedDate != null && parsedDate.isAfter(DateTime.now())) {
        return false;
      }
    }

    return true;
  }

  AnimeEntry copyWith({
    int? id,
    int? mediaId,
    String? title,
    String? englishTitle,
    String? romajiTitle,
    String? nativeTitle,
    String? coverImage,
    String? coverColor,
    String? bannerImage,
    int? progress,
    int? totalEpisodes,
    String? status,
    double? score,
    String? format,
    String? description,
    int? currentEpisode,
    String? episodeTitle,
    int? episodeNumber,
    String? episodeThumbnail,
    int? updatedAt,
    String? airDate,
    int? lastWatchedTime,
    int? nextAiringEpisodeNumber,
    int? nextAiringEpisodeAiringAt,
    int? year,
    List<String>? genres,
    bool? hasLocalFiles,
    int? mainFileCount,
  }) {
    return AnimeEntry(
      id: id ?? this.id,
      mediaId: mediaId ?? this.mediaId,
      title: title ?? this.title,
      englishTitle: englishTitle ?? this.englishTitle,
      romajiTitle: romajiTitle ?? this.romajiTitle,
      nativeTitle: nativeTitle ?? this.nativeTitle,
      coverImage: coverImage ?? this.coverImage,
      coverColor: coverColor ?? this.coverColor,
      bannerImage: bannerImage ?? this.bannerImage,
      progress: progress ?? this.progress,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      status: status ?? this.status,
      score: score ?? this.score,
      format: format ?? this.format,
      description: description ?? this.description,
      genres: genres ?? this.genres,
      currentEpisode: currentEpisode ?? this.currentEpisode,
      episodeTitle: episodeTitle ?? this.episodeTitle,
      episodeNumber: episodeNumber ?? this.episodeNumber,
      episodeThumbnail: episodeThumbnail ?? this.episodeThumbnail,
      updatedAt: updatedAt ?? this.updatedAt,
      airDate: airDate ?? this.airDate,
      lastWatchedTime: lastWatchedTime ?? this.lastWatchedTime,
      nextAiringEpisodeNumber: nextAiringEpisodeNumber ?? this.nextAiringEpisodeNumber,
      nextAiringEpisodeAiringAt: nextAiringEpisodeAiringAt ?? this.nextAiringEpisodeAiringAt,
      year: year ?? this.year,
      hasLocalFiles: hasLocalFiles ?? this.hasLocalFiles,
      mainFileCount: mainFileCount ?? this.mainFileCount,
    );
  }

  factory AnimeEntry.fromJson(Map<String, dynamic> json) {
    // Check if it's an Episode from continueWatchingList
    if (json.containsKey('baseAnime')) {
      final base = json['baseAnime'] as Map<String, dynamic>? ?? {};
      final titleObj = base['title'] as Map<String, dynamic>? ?? {};
      final cover = base['coverImage'] as Map<String, dynamic>?;
      final epNum = json['episodeNumber'] as int? ?? json['progressNumber'] as int? ?? 1;

      final epMetadata = json['episodeMetadata'] as Map<String, dynamic>?;
      
      String? epThumbnail;
      if (epMetadata?['image'] is String && (epMetadata!['image'] as String).trim().isNotEmpty) {
        epThumbnail = (epMetadata['image'] as String).trim();
      } else if (json['episodeThumbnail'] is String && (json['episodeThumbnail'] as String).trim().isNotEmpty) {
        epThumbnail = (json['episodeThumbnail'] as String).trim();
      }

      String epTitle = '';
      if (json['episodeTitle'] is String && (json['episodeTitle'] as String).trim().isNotEmpty) {
        epTitle = (json['episodeTitle'] as String).trim();
      } else if (epMetadata?['title'] is String && (epMetadata!['title'] as String).trim().isNotEmpty) {
        epTitle = (epMetadata['title'] as String).trim();
      } else if (json['displayTitle'] is String && (json['displayTitle'] as String).trim().isNotEmpty) {
        epTitle = (json['displayTitle'] as String).trim();
      } else {
        epTitle = 'Episodio $epNum';
      }

      final romaji = titleObj['romaji'] as String?;
      final english = titleObj['english'] as String?;
      final native = titleObj['native'] as String?;
      final preferred = titleObj['userPreferred'] as String? ?? romaji ?? english ?? base['title'] ?? 'Episodio $epNum';

      final airDate = epMetadata?['airDate'] as String? ?? json['airDate'] as String?;
      int? parsedLastWatched;
      final rawLast = json['lastWatchedTime'] ?? json['timeUpdated'];
      if (rawLast is int) {
        parsedLastWatched = rawLast > 10000000000 ? rawLast : rawLast * 1000;
      } else if (rawLast is String) {
        parsedLastWatched = DateTime.tryParse(rawLast)?.millisecondsSinceEpoch;
      }

      int? parsedUpdatedAt;
      final rawUp = json['updatedAt'] ?? json['createdAt'] ?? base['updatedAt'];
      if (rawUp is int) {
        parsedUpdatedAt = rawUp > 10000000000 ? rawUp : rawUp * 1000;
      } else if (rawUp is String) {
        parsedUpdatedAt = DateTime.tryParse(rawUp)?.millisecondsSinceEpoch;
      }

      final nextAiring = base['nextAiringEpisode'] as Map<String, dynamic>?;
      final nextAiringEp = nextAiring?['episode'] as int?;
      final nextAiringTime = nextAiring?['airingAt'] as int?;

      int? parsedYear;
      if (base['startDate'] is Map && (base['startDate'] as Map)['year'] is num) {
        parsedYear = ((base['startDate'] as Map)['year'] as num).toInt();
      } else if (base['seasonYear'] is num) {
        parsedYear = (base['seasonYear'] as num).toInt();
      } else if (airDate != null && airDate.isNotEmpty) {
        final parsed = DateTime.tryParse(airDate);
        if (parsed != null) parsedYear = parsed.year;
      }

      return AnimeEntry(
        id: json['id'] is int ? json['id'] : (base['id'] ?? 0),
        mediaId: base['id'] as int? ?? 0,
        title: preferred,
        englishTitle: english,
        romajiTitle: romaji,
        nativeTitle: native,
        coverImage: cover?['large'] ?? cover?['extraLarge'] ?? cover?['medium'],
        coverColor: cover?['color'] as String?,
        bannerImage: base['bannerImage'] as String?,
        progress: epNum,
        totalEpisodes: base['episodes'] as int?,
        status: 'CURRENT',
        currentEpisode: epNum,
        episodeTitle: epTitle,
        episodeNumber: epNum,
        episodeThumbnail: epThumbnail,
        updatedAt: parsedUpdatedAt,
        airDate: airDate,
        lastWatchedTime: parsedLastWatched,
        nextAiringEpisodeNumber: nextAiringEp,
        nextAiringEpisodeAiringAt: nextAiringTime,
        year: parsedYear,
      );
    }

    // Standard AniList media or Library Entry
    final media = (json['media'] is Map<String, dynamic>)
        ? json['media'] as Map<String, dynamic>
        : json;

    final titleObj = (media['title'] is Map<String, dynamic>)
        ? media['title'] as Map<String, dynamic>
        : (json['title'] is Map<String, dynamic> ? json['title'] as Map<String, dynamic> : {});

    final romaji = titleObj['romaji'] as String?;
    final english = titleObj['english'] as String?;
    final native = titleObj['native'] as String?;
    final preferred = titleObj['userPreferred'] as String? ??
        english ??
        romaji ??
        native ??
        (media['title'] is String ? media['title'] as String : 'Sin título');

    final cover = media['coverImage'] is Map<String, dynamic>
        ? media['coverImage'] as Map<String, dynamic>
        : (json['coverImage'] is Map<String, dynamic> ? json['coverImage'] as Map<String, dynamic> : null);

    final coverUrl = cover?['large'] ?? cover?['extraLarge'] ?? cover?['medium'];

    final listData = json['listData'] is Map ? json['listData'] as Map : null;
    final int entryProgress = (json['progress'] as num?)?.toInt() ??
        (listData?['progress'] as num?)?.toInt() ??
        0;
    final String entryStatus = json['status'] as String? ??
        listData?['status'] as String? ??
        media['status'] as String? ??
        'CURRENT';
    final int? totalEps = ((media['episodes'] ?? json['episodes']) as num?)?.toInt();
    final int nextEp = entryProgress + 1;

    final airDate = json['airDate'] as String?;
    int? parsedLastWatched;
    final rawLast = json['lastWatchedTime'] ?? json['timeUpdated'];
    if (rawLast is int) {
      parsedLastWatched = rawLast > 10000000000 ? rawLast : rawLast * 1000;
    } else if (rawLast is String) {
      parsedLastWatched = DateTime.tryParse(rawLast)?.millisecondsSinceEpoch;
    }

    int? parsedUpdatedAt;
    final rawUp = json['updatedAt'] ?? listData?['updatedAt'] ?? json['createdAt'] ?? listData?['createdAt'];
    if (rawUp is int) {
      parsedUpdatedAt = rawUp > 10000000000 ? rawUp : rawUp * 1000;
    } else if (rawUp is String) {
      parsedUpdatedAt = DateTime.tryParse(rawUp)?.millisecondsSinceEpoch;
    }

    final nextAiring = (media['nextAiringEpisode'] ?? json['nextAiringEpisode']) as Map<String, dynamic>?;
    final nextAiringEp = nextAiring?['episode'] as int?;
    final nextAiringTime = nextAiring?['airingAt'] as int?;

    int? parsedYear;
    if (media['startDate'] is Map && (media['startDate'] as Map)['year'] is num) {
      parsedYear = ((media['startDate'] as Map)['year'] as num).toInt();
    } else if (media['seasonYear'] is num) {
      parsedYear = (media['seasonYear'] as num).toInt();
    } else if (json['startDate'] is Map && (json['startDate'] as Map)['year'] is num) {
      parsedYear = ((json['startDate'] as Map)['year'] as num).toInt();
    } else if (json['seasonYear'] is num) {
      parsedYear = (json['seasonYear'] as num).toInt();
    } else if (airDate != null && airDate.isNotEmpty) {
      final parsed = DateTime.tryParse(airDate);
      if (parsed != null) parsedYear = parsed.year;
    }

    final rawGenres = (media['genres'] ?? json['genres']) as List?;
    final List<String> parsedGenres = rawGenres != null
        ? rawGenres.map((e) => e.toString()).toList()
        : const [];

    final int resolvedMediaId = (json['mediaId'] as num?)?.toInt() ??
        (json['media'] is Map ? (json['media'] as Map)['id'] as num? : null)?.toInt() ??
        (media['id'] as num?)?.toInt() ??
        (json['id'] as num?)?.toInt() ??
        0;
    final int resolvedId = (json['id'] as num?)?.toInt() ??
        (media['id'] as num?)?.toInt() ??
        resolvedMediaId;

    final libData = json['libraryData'] as Map<String, dynamic>?;
    final nakamaLibData = json['nakamaLibraryData'] as Map<String, dynamic>?;
    final int mainFiles = (libData?['mainFileCount'] as num?)?.toInt() ??
        (nakamaLibData?['mainFileCount'] as num?)?.toInt() ??
        (json['mainFileCount'] as num?)?.toInt() ??
        0;
    final bool hasLocal = json['hasLocalFiles'] as bool? ??
        (mainFiles > 0) ||
        (libData != null && libData.isNotEmpty) ||
        (nakamaLibData != null && nakamaLibData.isNotEmpty);

    return AnimeEntry(
      id: resolvedId,
      mediaId: resolvedMediaId,
      title: preferred,
      englishTitle: english,
      romajiTitle: romaji,
      nativeTitle: native,
      coverImage: coverUrl as String?,
      coverColor: cover?['color'] as String?,
      bannerImage: (media['bannerImage'] ?? json['bannerImage']) as String?,
      progress: entryProgress,
      totalEpisodes: totalEps,
      status: entryStatus,
      score: ((listData?['score'] ?? json['score'] ?? media['averageScore']) as num?)?.toDouble(),
      format: (media['format'] ?? json['format']) as String?,
      description: (media['description'] ?? json['description']) as String?,
      genres: parsedGenres,
      currentEpisode: nextEp,
      episodeNumber: nextEp,
      episodeTitle: json['episodeTitle'] as String? ?? 'Episodio $nextEp',
      episodeThumbnail: json['episodeThumbnail'] as String?,
      updatedAt: parsedUpdatedAt,
      airDate: airDate,
      lastWatchedTime: parsedLastWatched,
      nextAiringEpisodeNumber: nextAiringEp,
      nextAiringEpisodeAiringAt: nextAiringTime,
      year: parsedYear,
      hasLocalFiles: hasLocal,
      mainFileCount: mainFiles,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'mediaId': mediaId,
    'media': {
      'id': mediaId,
    },
    'title': {
      'userPreferred': title,
      'romaji': romajiTitle,
      'english': englishTitle,
      'native': nativeTitle,
    },
    'coverImage': {
      'extraLarge': coverImage,
      'color': coverColor,
    },
    'bannerImage': bannerImage,
    'progress': progress,
    'episodes': totalEpisodes,
    'status': status,
    'score': score,
    'format': format,
    'description': description,
    'genres': genres,
    'currentEpisode': currentEpisode,
    'episodeNumber': episodeNumber,
    'episodeTitle': episodeTitle,
    'episodeThumbnail': episodeThumbnail,
    'updatedAt': updatedAt,
    'airDate': airDate,
    'lastWatchedTime': lastWatchedTime,
    'nextAiringEpisode': nextAiringEpisodeNumber != null
        ? {
            'episode': nextAiringEpisodeNumber,
            'airingAt': nextAiringEpisodeAiringAt,
          }
        : null,
    'seasonYear': year,
    'hasLocalFiles': hasLocalFiles,
    'mainFileCount': mainFileCount,
  };
}
