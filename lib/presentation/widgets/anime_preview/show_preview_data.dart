import 'package:flutter/material.dart';
import 'package:aniting/core/media_servers/models/media_server_item.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/core/theme/theme_provider.dart' show parseHexColor;
import 'package:aniting/core/utils/synopsis_utils.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/manga_entry.dart';

/// One metadata chip of the immersive preview.
class ShowPreviewMeta {
  final String label;
  final IconData icon;

  const ShowPreviewMeta(this.label, this.icon);
}

/// Episode details shown when the preview is opened from a "Continue watching"
/// card (or from a media-server episode).
class ShowPreviewEpisode {
  /// Short badge such as `EP 4` or `T1 · E4`.
  final String label;
  final String? title;
  final String? imageUrl;
  final String? synopsis;
  final String? rating;
  final String? duration;
  final String? airDate;

  const ShowPreviewEpisode({
    required this.label,
    this.title,
    this.imageUrl,
    this.synopsis,
    this.rating,
    this.duration,
    this.airDate,
  });
}

/// Everything the immersive preview needs, for every feed card type.
class ShowPreviewData {
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final String? backgroundUrl;
  final Color? accentColor;
  final String? description;
  final List<String> genres;
  final List<ShowPreviewMeta> meta;
  final bool isManga;

  /// Present when the preview is about a specific episode.
  final ShowPreviewEpisode? episode;

  // ── Tracking / quick actions ──────────────────────────────────────────
  /// AniList / TMDB media id (null for media-server items).
  final int? mediaId;
  final int? year;
  final bool isInList;
  final String? userStatus;
  final int? progress;
  final int? totalCount;
  final double? userScore;
  final int? repeat;
  final String? startedAt;
  final String? completedAt;
  final bool isTmdb;

  /// False for media-server items that are not part of AniList/local lists.
  final bool canTrack;

  const ShowPreviewData({
    required this.title,
    this.subtitle,
    this.coverUrl,
    this.backgroundUrl,
    this.accentColor,
    this.description,
    this.genres = const [],
    this.meta = const [],
    this.isManga = false,
    this.episode,
    this.mediaId,
    this.year,
    this.isInList = false,
    this.userStatus,
    this.progress,
    this.totalCount,
    this.userScore,
    this.repeat,
    this.startedAt,
    this.completedAt,
    this.isTmdb = false,
    this.canTrack = false,
  });

  static const _userListStatuses = {
    'CURRENT',
    'PLANNING',
    'COMPLETED',
    'PAUSED',
    'DROPPED',
    'REPEATING',
  };

  static bool _isUserListStatus(String status) =>
      _userListStatuses.contains(status.trim().toUpperCase());

  factory ShowPreviewData.fromAnime(
    AnimeEntry entry,
    TitleLanguage language, {
    bool includeCurrentEpisode = false,
    AniZipEpisode? aniZipEpisode,
  }) {
    final title = entry.displayTitle(language);
    final subtitle = _secondaryTitle(
      title,
      entry.englishTitle,
      entry.romajiTitle,
    );
    final score = _scoreLabel(entry.score);
    final episodes = entry.totalEpisodes;

    final rawStatus = entry.status.trim().toUpperCase();
    final userStatus = _isUserListStatus(rawStatus) ? rawStatus : null;
    final isInList = userStatus != null || entry.progress > 0;

    ShowPreviewEpisode? episode;
    if (includeCurrentEpisode) {
      final number = entry.episodeNumber ?? (entry.progress + 1);
      final episodeTitle = _preferredEpisodeTitle(
        aniZipEpisode?.displayTitle,
        entry.episodeTitle,
        number,
      );
      episode = ShowPreviewEpisode(
        label: 'EP $number',
        title: episodeTitle,
        imageUrl: _nonEmpty(aniZipEpisode?.image) ??
            _nonEmpty(entry.episodeThumbnail),
        synopsis: _nonEmpty(aniZipEpisode?.synopsis),
        rating: _nonEmpty(aniZipEpisode?.rating),
        duration: _nonEmpty(aniZipEpisode?.formattedDuration),
        airDate: _nonEmpty(aniZipEpisode?.formattedAirDate),
      );
    }

    return ShowPreviewData(
      title: title,
      subtitle: subtitle,
      coverUrl: entry.coverImage,
      backgroundUrl: entry.bannerImage ?? entry.coverImage,
      accentColor: parseHexColor(entry.coverColor),
      description: _cleanDescription(entry.description),
      genres: entry.genres.take(6).toList(),
      episode: episode,
      mediaId: entry.mediaId > 0 ? entry.mediaId : null,
      year: entry.year,
      isInList: isInList,
      userStatus: userStatus ?? (isInList ? 'CURRENT' : null),
      progress: entry.progress,
      totalCount: episodes,
      userScore: entry.score,
      isTmdb: entry.isTmdb,
      canTrack: true,
      meta: [
        if (entry.year != null && entry.year! > 0)
          ShowPreviewMeta('${entry.year}', Icons.calendar_today_rounded),
        if ((entry.format ?? '').trim().isNotEmpty)
          ShowPreviewMeta(entry.format!.trim(), Icons.movie_filter_rounded),
        if (score != null) ShowPreviewMeta(score, Icons.star_rounded),
        if (episodes != null && episodes > 0)
          ShowPreviewMeta('$episodes', Icons.live_tv_rounded),
      ],
    );
  }

  factory ShowPreviewData.fromManga(MangaEntry entry, TitleLanguage language) {
    final title = entry.displayTitle(language);
    final subtitle = _secondaryTitle(
      title,
      entry.englishTitle,
      entry.romajiTitle,
    );
    final score = _scoreLabel(entry.score);
    final chapters = entry.totalChapters;
    final volumes = entry.totalVolumes;

    final rawStatus = entry.status.trim().toUpperCase();
    final userStatus = _isUserListStatus(rawStatus) ? rawStatus : null;
    final isInList = userStatus != null || entry.progress > 0;

    return ShowPreviewData(
      title: title,
      subtitle: subtitle,
      coverUrl: entry.coverImage ?? entry.localCoverPath,
      backgroundUrl:
          entry.bannerImage ?? entry.localBannerPath ?? entry.coverImage,
      accentColor: parseHexColor(entry.coverColor),
      description: _cleanDescription(entry.description),
      genres: entry.genres.take(6).toList(),
      isManga: true,
      mediaId: entry.mediaId > 0 ? entry.mediaId : null,
      year: entry.year,
      isInList: isInList,
      userStatus: userStatus ?? (isInList ? 'CURRENT' : null),
      progress: entry.progress,
      totalCount: chapters,
      userScore: entry.score,
      canTrack: true,
      meta: [
        if (entry.year != null && entry.year! > 0)
          ShowPreviewMeta('${entry.year}', Icons.calendar_today_rounded),
        if ((entry.format ?? '').trim().isNotEmpty)
          ShowPreviewMeta(entry.format!.trim(), Icons.menu_book_rounded),
        if (score != null) ShowPreviewMeta(score, Icons.star_rounded),
        if (chapters != null && chapters > 0)
          ShowPreviewMeta('$chapters', Icons.menu_book_rounded),
        if (volumes != null && volumes > 0)
          ShowPreviewMeta('$volumes', Icons.layers_rounded),
      ],
    );
  }

  factory ShowPreviewData.fromMediaServer(MediaServerItem item) {
    final isEpisode = item.type == MediaServerItemType.episode;
    final isShow = item.type == MediaServerItemType.show;
    final showTitle = item.grandParentTitle ?? item.parentTitle ?? item.title;

    final rating = item.rating;
    final ratingLabel = rating != null && rating > 0
        ? (rating > 10 ? rating / 10 : rating).toStringAsFixed(1)
        : null;
    final durationMinutes = item.durationMs != null && item.durationMs! > 0
        ? (item.durationMs! / 60000).round()
        : null;

    ShowPreviewEpisode? episode;
    if (isEpisode) {
      final season = item.seasonNumber;
      final number = item.episodeNumber;
      final label = season != null && number != null
          ? 'T$season · E$number'
          : (number != null ? 'EP $number' : 'EPISODIO');
      episode = ShowPreviewEpisode(
        label: label,
        title: _preferredEpisodeTitle(item.title, null, number),
        imageUrl: _nonEmpty(item.thumbUrl) ?? _nonEmpty(item.backdropUrl),
        synopsis: _nonEmpty(_cleanDescription(item.overview)),
        rating: ratingLabel,
        duration: durationMinutes != null ? '$durationMinutes min' : null,
        airDate: _formatAirDate(item.airDate),
      );
    }

    return ShowPreviewData(
      title: isEpisode ? showTitle : item.title,
      subtitle: isEpisode
          ? episode?.label
          : _secondaryTitle(item.title, null, item.originalTitle),
      coverUrl: item.thumbUrl ?? item.backdropUrl,
      backgroundUrl: item.backdropUrl ?? item.thumbUrl,
      accentColor: null,
      description: _cleanDescription(item.overview),
      genres: item.genres.take(6).toList(),
      episode: episode,
      year: item.year,
      totalCount: item.episodeCount,
      canTrack: false,
      meta: [
        if (item.year != null && item.year! > 0)
          ShowPreviewMeta('${item.year}', Icons.calendar_today_rounded),
        if (isShow)
          const ShowPreviewMeta('Serie', Icons.movie_filter_rounded),
        if (item.type == MediaServerItemType.movie)
          const ShowPreviewMeta('Película', Icons.movie_filter_rounded),
        if (!isEpisode && durationMinutes != null)
          ShowPreviewMeta('$durationMinutes min', Icons.schedule_rounded),
        if (!isEpisode && ratingLabel != null)
          ShowPreviewMeta(ratingLabel, Icons.star_rounded),
        if (item.episodeCount != null && item.episodeCount! > 0)
          ShowPreviewMeta('${item.episodeCount}', Icons.live_tv_rounded),
      ],
    );
  }

  /// Whether [title] is just a placeholder ("Episode 4", "4", …).
  static bool isGenericEpisodeTitle(String? title, int? number) {
    final trimmed = title?.trim().toLowerCase();
    if (trimmed == null || trimmed.isEmpty) return true;
    if (number != null) {
      if (trimmed == '$number' ||
          trimmed == 'episodio $number' ||
          trimmed == 'episode $number' ||
          trimmed == 'ep $number' ||
          trimmed == 'ep. $number') {
        return true;
      }
    }
    return RegExp(r'^(episode|episodio|ep\.?|e)\s*\d+$', caseSensitive: false)
        .hasMatch(trimmed);
  }

  static String? _preferredEpisodeTitle(
    String? primary,
    String? fallback,
    int? number,
  ) {
    for (final candidate in [primary, fallback]) {
      final trimmed = candidate?.trim();
      if (trimmed != null &&
          trimmed.isNotEmpty &&
          !isGenericEpisodeTitle(trimmed, number)) {
        return trimmed;
      }
    }
    return null;
  }

  static String? _secondaryTitle(
    String title,
    String? english,
    String? romaji,
  ) {
    for (final candidate in [english, romaji]) {
      final trimmed = candidate?.trim();
      if (trimmed != null &&
          trimmed.isNotEmpty &&
          trimmed.toLowerCase() != title.trim().toLowerCase()) {
        return trimmed;
      }
    }
    return null;
  }

  static String? _scoreLabel(double? score) {
    if (score == null || score <= 0) return null;
    final normalized = score > 10 ? score / 10 : score;
    return normalized.toStringAsFixed(1);
  }

  static String? _nonEmpty(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _formatAirDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    const months = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
  }

  static String _cleanDescription(String? text) {
    return cleanSynopsis(text);
  }
}
