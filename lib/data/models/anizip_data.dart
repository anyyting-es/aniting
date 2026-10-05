class AniZipMappings {
  final int? anilistId;
  final int? malId;
  final int? anidbId;
  final int? thetvdbId;
  final int? kitsuId;
  final String? imdbId;
  final String? themoviedbId;
  final String? animePlanetId;

  AniZipMappings({
    this.anilistId,
    this.malId,
    this.anidbId,
    this.thetvdbId,
    this.kitsuId,
    this.imdbId,
    this.themoviedbId,
    this.animePlanetId,
  });

  factory AniZipMappings.fromJson(Map<String, dynamic> json) {
    return AniZipMappings(
      anilistId: json['anilist_id'] as int?,
      malId: json['mal_id'] as int?,
      anidbId: json['anidb_id'] as int?,
      thetvdbId: json['thetvdb_id'] as int?,
      kitsuId: json['kitsu_id'] as int?,
      imdbId: json['imdb_id']?.toString(),
      themoviedbId: json['themoviedb_id']?.toString(),
      animePlanetId: json['animeplanet_id']?.toString(),
    );
  }
}

class AniZipEpisode {
  final String episode;
  final int episodeNumber;
  final int? seasonNumber;
  final int? absoluteEpisodeNumber;
  final Map<String, String> titleMap;
  final String? image;
  final String? airDate;
  final int? runtime;
  final String? overview;
  final String? summary;
  final String? rating;
  final int? anidbEid;
  final int? tvdbId;
  final bool isSpecial;
  bool isDownloaded;

  AniZipEpisode({
    required this.episode,
    required this.episodeNumber,
    this.seasonNumber,
    this.absoluteEpisodeNumber,
    required this.titleMap,
    this.image,
    this.airDate,
    this.runtime,
    this.overview,
    this.summary,
    this.rating,
    this.anidbEid,
    this.tvdbId,
    required this.isSpecial,
    this.isDownloaded = false,
  });

  factory AniZipEpisode.fromJson(String key, Map<String, dynamic> json) {
    final epNum = json['episodeNumber'] as int? ??
        json['absoluteEpisodeNumber'] as int? ??
        int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ??
        1;

    final seasonNum = json['seasonNumber'] as int?;

    // Special check: key starts with S, O, SP, etc. or seasonNumber == 0
    final upperKey = key.toUpperCase();
    final special = upperKey.startsWith('S') ||
        upperKey.startsWith('O') ||
        upperKey.startsWith('SP') ||
        upperKey.startsWith('E') ||
        (seasonNum != null && seasonNum == 0) ||
        int.tryParse(key) == null;

    final titles = <String, String>{};
    final rawTitle = json['title'];
    if (rawTitle is Map<String, dynamic>) {
      for (final entry in rawTitle.entries) {
        if (entry.value != null && entry.value.toString().trim().isNotEmpty) {
          titles[entry.key] = entry.value.toString().trim();
        }
      }
    } else if (rawTitle is String && rawTitle.trim().isNotEmpty) {
      titles['en'] = rawTitle.trim();
    }

    final rawLength = json['runtime'] as int? ?? json['length'] as int?;
    final date = (json['airDate'] ?? json['airdate']) as String?;

    return AniZipEpisode(
      episode: key,
      episodeNumber: epNum,
      seasonNumber: seasonNum,
      absoluteEpisodeNumber: json['absoluteEpisodeNumber'] as int?,
      titleMap: titles,
      image: json['image'] as String?,
      airDate: date,
      runtime: rawLength != null && rawLength > 0 ? rawLength : null,
      overview: json['overview'] as String?,
      summary: json['summary'] as String?,
      rating: json['rating']?.toString(),
      anidbEid: json['anidbEid'] as int?,
      tvdbId: json['tvdbId'] as int? ?? json['tvdbEid'] as int?,
      isSpecial: special,
      isDownloaded: json['isDownloaded'] as bool? ?? false,
    );
  }

  /// Returns title prioritizing the given language ('en', 'es', etc.)
  String displayTitleForLang(String? langCode) {
    final isEn = langCode?.toLowerCase().startsWith('en') ?? false;
    if (isEn) {
      final en = titleMap['en'];
      if (en != null && en.isNotEmpty) return en.replaceAll('`', "'");
      final ro = titleMap['x-jat'];
      if (ro != null && ro.isNotEmpty) return ro.replaceAll('`', "'");
      final es = titleMap['es'];
      if (es != null && es.isNotEmpty) return es.replaceAll('`', "'");
    } else {
      final es = titleMap['es'];
      if (es != null && es.isNotEmpty) return es.replaceAll('`', "'");
      final en = titleMap['en'];
      if (en != null && en.isNotEmpty) return en.replaceAll('`', "'");
      final ro = titleMap['x-jat'];
      if (ro != null && ro.isNotEmpty) return ro.replaceAll('`', "'");
    }
    final ja = titleMap['ja'];
    if (ja != null && ja.isNotEmpty) return ja;
    for (final val in titleMap.values) {
      if (val.isNotEmpty) return val.replaceAll('`', "'");
    }
    return isSpecial
        ? (isEn ? 'Special $episode' : 'Especial $episode')
        : (isEn ? 'Episode $episodeNumber' : 'Episodio $episodeNumber');
  }

  /// Returns title prioritizing Spanish, then English, then Romaji, then Japanese
  String get displayTitle => displayTitleForLang('es');

  /// Original Japanese or Romaji title if different
  String? get originalTitle {
    final ro = titleMap['x-jat'];
    final ja = titleMap['ja'];
    final cur = displayTitle;
    if (ro != null && ro.isNotEmpty && ro != cur) return ro.replaceAll('`', "'");
    if (ja != null && ja.isNotEmpty && ja != cur) return ja;
    return null;
  }

  /// Episode overview or summary
  String? get synopsis {
    final text = (overview != null && overview!.trim().isNotEmpty) ? overview : summary;
    if (text == null || text.trim().isEmpty) return null;
    return text.replaceAll('`', "'").trim();
  }

  /// Clean formatted duration
  String? get formattedDuration {
    if (runtime == null || runtime! <= 0) return null;
    return '$runtime min';
  }

  /// Formatted air date in Spanish (e.g. "29 sep 2023")
  String? get formattedAirDate {
    if (airDate == null || airDate!.isEmpty) return null;
    try {
      final dt = DateTime.parse(airDate!);
      const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return airDate;
    }
  }

  /// Label for badges: "EP 1" or "SP 1"
  String get episodeBadge {
    if (isSpecial) {
      final clean = episode.replaceAll(RegExp(r'[^0-9]'), '');
      return clean.isNotEmpty ? 'SP $clean' : episode;
    }
    return 'EP $episodeNumber';
  }
}

class AniZipData {
  final Map<String, String> titles;
  final int episodeCount;
  final int specialCount;
  final List<AniZipEpisode> episodes;
  final AniZipMappings? mappings;

  AniZipData({
    this.titles = const {},
    this.episodeCount = 0,
    this.specialCount = 0,
    this.episodes = const [],
    this.mappings,
  });

  List<AniZipEpisode> get mainEpisodes {
    final mains = episodes.where((e) => !e.isSpecial).toList();
    if (mains.isEmpty && episodes.isNotEmpty) {
      // If all episodes were classified as special (e.g. movies in TVDB Season 0),
      // treat them as main episodes so movies/single-episode works aren't left empty.
      return episodes;
    }
    return mains;
  }

  List<AniZipEpisode> get specialEpisodes =>
      episodes.where((e) => e.isSpecial).toList();

  /// Returns main episode by episode number, prioritizing main episodes (excludes specials).
  /// Falls back to special episodes or single-episode movie if no main episode matches.
  AniZipEpisode? getEpisode(int episodeNumber) {
    for (final ep in episodes) {
      if (!ep.isSpecial && ep.episodeNumber == episodeNumber) {
        return ep;
      }
    }
    // Fallback: If no non-special episode found (e.g. movies where seasonNumber is 0 in TVDB),
    // check all episodes matching episodeNumber
    for (final ep in episodes) {
      if (ep.episodeNumber == episodeNumber) {
        return ep;
      }
    }
    // Fallback 2: Single-episode movie where episodeNumber might be 1
    if (episodeNumber == 1 && episodes.length == 1) {
      return episodes.first;
    }
    return null;
  }

  /// Returns special episode by special number (e.g., S1 -> 1, S2 -> 2)
  AniZipEpisode? getSpecial(int specialNumber) {
    for (final ep in episodes) {
      if (ep.isSpecial && ep.episodeNumber == specialNumber) {
        return ep;
      }
    }
    return null;
  }

  factory AniZipData.fromJson(Map<String, dynamic> json) {
    final titlesMap = <String, String>{};
    final rawTitles = json['titles'];
    if (rawTitles is Map<String, dynamic>) {
      for (final entry in rawTitles.entries) {
        if (entry.value != null) {
          titlesMap[entry.key] = entry.value.toString();
        }
      }
    }

    final parsedEpisodes = <AniZipEpisode>[];
    final rawEpisodes = json['episodes'];
    if (rawEpisodes is Map<String, dynamic>) {
      for (final entry in rawEpisodes.entries) {
        if (entry.value is Map<String, dynamic>) {
          parsedEpisodes.add(
            AniZipEpisode.fromJson(entry.key, entry.value as Map<String, dynamic>),
          );
        }
      }
    }

    // Sort episodes: main episodes first (by episodeNumber), then specials
    parsedEpisodes.sort((a, b) {
      if (a.isSpecial != b.isSpecial) {
        return a.isSpecial ? 1 : -1;
      }
      if (a.episodeNumber != b.episodeNumber) {
        return a.episodeNumber.compareTo(b.episodeNumber);
      }
      return a.episode.compareTo(b.episode);
    });

    AniZipMappings? mappings;
    if (json['mappings'] is Map<String, dynamic>) {
      mappings = AniZipMappings.fromJson(json['mappings'] as Map<String, dynamic>);
    }

    return AniZipData(
      titles: titlesMap,
      episodeCount: json['episodeCount'] as int? ?? 0,
      specialCount: json['specialCount'] as int? ?? 0,
      episodes: parsedEpisodes,
      mappings: mappings,
    );
  }
}
