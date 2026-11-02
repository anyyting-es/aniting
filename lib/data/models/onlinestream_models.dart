import 'package:seanime_app/core/i18n/translations/translations.dart';

/// What kind of media an onlinestream provider can resolve.
///
/// `anime` = AniList/AniDB ids, `tmdb` = TMDB movies/series, `both` = both.
enum OnlinestreamProviderType { anime, tmdb, both }

class OnlinestreamProvider {
  final String id;
  final String name;
  final String lang;
  final List<String> episodeServers;
  final bool supportsDub;
  final OnlinestreamProviderType type;

  const OnlinestreamProvider({
    required this.id,
    required this.name,
    this.lang = 'multi',
    this.episodeServers = const [],
    this.supportsDub = false,
    this.type = OnlinestreamProviderType.anime,
  });

  /// Backwards-compatible getter for callers that only need TMDB support.
  bool get supportsTmdb => type != OnlinestreamProviderType.anime;

  bool get supportsAnime => type != OnlinestreamProviderType.tmdb;

  bool get isTmdbOnly => type == OnlinestreamProviderType.tmdb;

  bool get isBoth => type == OnlinestreamProviderType.both;

  /// Short capability label for badges: "Anime", "TMDB" or "Anime + TMDB".
  String get capabilityLabel => switch (type) {
        OnlinestreamProviderType.anime => 'Anime',
        OnlinestreamProviderType.tmdb => 'TMDB',
        OnlinestreamProviderType.both => 'Anime + TMDB',
      };

  factory OnlinestreamProvider.fromJson(Map<String, dynamic> json) {
    final legacySupportsTmdb = json['supportsTmdb'] as bool? ?? false;
    final rawType = json['providerType']?.toString().toLowerCase();
    final OnlinestreamProviderType type;
    switch (rawType) {
      case 'tmdb':
      case 'tv':
      case 'movie':
        type = OnlinestreamProviderType.tmdb;
        break;
      case 'both':
      case 'all':
        type = OnlinestreamProviderType.both;
        break;
      case 'anime':
      case 'anilist':
        type = OnlinestreamProviderType.anime;
        break;
      default:
        // Legacy extensions only declare supportsTmdb. Assume they also serve
        // anime; TMDB-only extensions should send providerType: "tmdb".
        type = legacySupportsTmdb
            ? OnlinestreamProviderType.both
            : OnlinestreamProviderType.anime;
    }

    return OnlinestreamProvider(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Sin nombre',
      lang: json['lang'] as String? ?? 'multi',
      episodeServers:
          (json['episodeServers'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      supportsDub: json['supportsDub'] as bool? ?? false,
      type: type,
    );
  }
}

class OnlinestreamEpisode {
  final int number;
  final String? title;
  final String? image;
  final String? description;
  final bool isFiller;

  const OnlinestreamEpisode({
    required this.number,
    this.title,
    this.image,
    this.description,
    this.isFiller = false,
  });

  factory OnlinestreamEpisode.fromJson(Map<String, dynamic> json) {
    return OnlinestreamEpisode(
      number: json['number'] as int? ?? 1,
      title: json['title'] as String?,
      image: json['image'] as String?,
      description: json['description'] as String?,
      isFiller: json['isFiller'] as bool? ?? false,
    );
  }

  String localizedDisplayTitle([AppTranslations? l10n]) {
    if (title != null && title!.trim().isNotEmpty) {
      return title!.trim();
    }
    if (l10n != null) {
      return l10n.episodeNumber(number);
    }
    return 'Episode $number';
  }

  String get displayTitle => localizedDisplayTitle();
}

class OnlinestreamSubtitle {
  final String? id;
  final String url;
  final String language;
  final bool isDefault;

  const OnlinestreamSubtitle({
    this.id,
    required this.url,
    required this.language,
    this.isDefault = false,
  });

  factory OnlinestreamSubtitle.fromJson(Map<String, dynamic> json) {
    final lang = json['language']?.toString() ??
        json['lang']?.toString() ??
        json['title']?.toString() ??
        json['label']?.toString() ??
        'Sub';
    return OnlinestreamSubtitle(
      id: json['id']?.toString(),
      url: json['url'] as String? ?? '',
      language: lang,
      isDefault: json['isDefault'] == true || json['default'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'url': url,
      'language': language,
      'isDefault': isDefault,
    };
  }
}

class OnlinestreamVideoSource {
  final String server;
  final Map<String, String>? headers;
  final String url;
  final String quality;
  final String? label;
  final String? type;
  final List<OnlinestreamSubtitle> subtitles;
  final String? infoHash;
  final int? fileIndex;
  final int? seeders;
  final int? size;
  final String? sizeFormatted;
  final List<String> languages;
  final String? codec;
  final String? indexer;
  final String? releaseName;

  const OnlinestreamVideoSource({
    required this.server,
    this.headers,
    required this.url,
    this.quality = 'default',
    this.label,
    this.type,
    this.subtitles = const [],
    this.infoHash,
    this.fileIndex,
    this.seeders,
    this.size,
    this.sizeFormatted,
    this.languages = const [],
    this.codec,
    this.indexer,
    this.releaseName,
  });

  bool get isHls =>
      type != 'torrent' &&
      (type == 'm3u8' ||
          url.contains('.m3u8') ||
          url.contains('/segs/') ||
          url.contains('/hls/'));

  /// A torrent source must be resolved by the torrent engine instead of being
  /// played directly. Torrentio and similar indexers return magnets/infoHashes.
  bool get isTorrent =>
      type == 'torrent' ||
      url.startsWith('magnet:') ||
      (url.trim().isEmpty && infoHash != null && infoHash!.isNotEmpty);

  factory OnlinestreamVideoSource.fromJson(Map<String, dynamic> json) {
    Map<String, String>? headersMap;
    if (json['headers'] is Map) {
      headersMap = (json['headers'] as Map)
          .map((k, v) => MapEntry(k.toString(), v.toString()));
    }

    final rawSubs = json['subtitles'] as List?;
    final subs = rawSubs != null
        ? rawSubs
            .whereType<Map>()
            .map((e) => OnlinestreamSubtitle.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <OnlinestreamSubtitle>[];

    return OnlinestreamVideoSource(
      server: json['server'] as String? ?? 'default',
      headers: headersMap,
      url: json['url'] as String? ?? '',
      quality: json['quality'] as String? ?? 'auto',
      label: json['label'] as String?,
      type: json['type'] as String?,
      subtitles: subs,
      infoHash: json['infoHash'] as String?,
      fileIndex: (json['fileIndex'] as num?)?.toInt(),
      seeders: (json['seeders'] as num?)?.toInt(),
      size: (json['size'] as num?)?.toInt(),
      sizeFormatted: json['sizeFormatted'] as String?,
      languages:
          (json['languages'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      codec: json['codec'] as String?,
      indexer: json['indexer'] as String?,
      releaseName: json['releaseName'] as String?,
    );
  }

  String get displayLabel {
    if (label != null && label!.isNotEmpty) return label!;
    if (quality.isNotEmpty && quality != 'auto') return '$server ($quality)';
    return server;
  }
}

class OnlinestreamSearchResult {
  final String id;
  final String title;
  final String url;
  final String? subOrDub;

  const OnlinestreamSearchResult({
    required this.id,
    required this.title,
    required this.url,
    this.subOrDub,
  });

  factory OnlinestreamSearchResult.fromJson(Map<String, dynamic> json) {
    return OnlinestreamSearchResult(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      subOrDub: json['subOrDub'] as String?,
    );
  }
}

class OnlinestreamMapping {
  final String provider;
  final int mediaId;
  final String animeId;

  const OnlinestreamMapping({
    required this.provider,
    required this.mediaId,
    required this.animeId,
  });

  factory OnlinestreamMapping.fromJson(Map<String, dynamic> json) {
    return OnlinestreamMapping(
      provider: json['provider'] as String? ?? '',
      mediaId: json['mediaId'] as int? ?? 0,
      animeId: json['animeId'] as String? ?? '',
    );
  }
}

