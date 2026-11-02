import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_direct_episode.dart';

/// Resolved source configuration to play a target episode.
class ResolvedEpisodeSource {
  final String videoUrl;
  final int episodeNumber;
  final String episodeTitle;
  final Map<String, String>? headers;
  final String? mimeType;
  final String? videoSource;
  final List<dynamic>? externalSubtitles;

  const ResolvedEpisodeSource({
    required this.videoUrl,
    required this.episodeNumber,
    required this.episodeTitle,
    this.headers,
    this.mimeType,
    this.videoSource,
    this.externalSubtitles,
  });
}

/// Helper service to resolve next/previous episode streams from local library
/// or active online stream providers with in-memory caching and background prefetching.
class PlayerEpisodeResolver {
  final SeanimeRepository repository;
  final ServerManager serverManager;
  final AppTranslations? l10n;

  // In-memory cache of resolved episode streams to allow instantaneous (0ms) episode switching
  static final Map<String, ResolvedEpisodeSource> _cache = {};
  static final Map<String, Future<ResolvedEpisodeSource?>> _inflight = {};

  const PlayerEpisodeResolver({
    required this.repository,
    required this.serverManager,
    this.l10n,
  });

  static String _makeKey({
    required int mediaId,
    required int targetEpNum,
    required String? onlineStreamProvider,
    required bool? onlineStreamDubbed,
    required String? onlineStreamServer,
  }) {
    return '$mediaId:$targetEpNum:${onlineStreamProvider ?? "local"}:${onlineStreamDubbed ?? false}:${onlineStreamServer ?? "default"}';
  }

  /// Clears in-memory episode stream cache
  static void clearCache() {
    _cache.clear();
    _inflight.clear();
  }

  /// Attempts to resolve the stream source for [targetEpNum].
  /// Uses memory cache or in-flight deduplication if already requested or prefetched.
  Future<ResolvedEpisodeSource?> resolveEpisode({
    required int mediaId,
    required int targetEpNum,
    required bool isCurrentLocalFile,
    required String currentVideoUrl,
    required String? onlineStreamProvider,
    required bool? onlineStreamDubbed,
    required String? onlineStreamServer,
    required AnimeDetails? animeDetails,
    required AniZipData? aniZipData,
  }) async {
    final key = _makeKey(
      mediaId: mediaId,
      targetEpNum: targetEpNum,
      onlineStreamProvider: onlineStreamProvider,
      onlineStreamDubbed: onlineStreamDubbed,
      onlineStreamServer: onlineStreamServer,
    );

    // 1. Instant Cache Hit (0ms)
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // 2. In-flight request deduplication
    if (_inflight.containsKey(key)) {
      return await _inflight[key];
    }

    // 3. Initiate resolution and track in-flight Future
    final future = _doResolve(
      mediaId: mediaId,
      targetEpNum: targetEpNum,
      isCurrentLocalFile: isCurrentLocalFile,
      currentVideoUrl: currentVideoUrl,
      onlineStreamProvider: onlineStreamProvider,
      onlineStreamDubbed: onlineStreamDubbed,
      onlineStreamServer: onlineStreamServer,
      animeDetails: animeDetails,
      aniZipData: aniZipData,
    );
    _inflight[key] = future;

    try {
      final result = await future;
      if (result != null) {
        _cache[key] = result;
      }
      return result;
    } finally {
      _inflight.remove(key);
    }
  }

  /// Background prefetch helper to resolve upcoming episode without blocking playback.
  Future<void> prefetchEpisode({
    required int mediaId,
    required int targetEpNum,
    required bool isCurrentLocalFile,
    required String currentVideoUrl,
    required String? onlineStreamProvider,
    required bool? onlineStreamDubbed,
    required String? onlineStreamServer,
    required AnimeDetails? animeDetails,
    required AniZipData? aniZipData,
  }) async {
    try {
      await resolveEpisode(
        mediaId: mediaId,
        targetEpNum: targetEpNum,
        isCurrentLocalFile: isCurrentLocalFile,
        currentVideoUrl: currentVideoUrl,
        onlineStreamProvider: onlineStreamProvider,
        onlineStreamDubbed: onlineStreamDubbed,
        onlineStreamServer: onlineStreamServer,
        animeDetails: animeDetails,
        aniZipData: aniZipData,
      );
    } catch (_) {
      // Silently ignore prefetch errors
    }
  }

  Future<ResolvedEpisodeSource?> _doResolve({
    required int mediaId,
    required int targetEpNum,
    required bool isCurrentLocalFile,
    required String currentVideoUrl,
    required String? onlineStreamProvider,
    required bool? onlineStreamDubbed,
    required String? onlineStreamServer,
    required AnimeDetails? animeDetails,
    required AniZipData? aniZipData,
  }) async {
    // 1. Try Local Library source
    if (isCurrentLocalFile || currentVideoUrl.contains('/api/v1/mediastream')) {
      final entry = await repository.getAnimeLibraryEntry(mediaId);
      final nextLocal = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
        (e) => e?.episodeNumber == targetEpNum,
        orElse: () => null,
      );
      if (nextLocal != null) {
        final streamUrl = nextLocal.localFilePath != null && nextLocal.localFilePath!.isNotEmpty
            ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(nextLocal.localFilePath!)}'
            : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=$mediaId&episodeNumber=${nextLocal.episodeNumber}';
        final fileName = nextLocal.localFilePath != null && nextLocal.localFilePath!.isNotEmpty
            ? nextLocal.localFilePath!.split(RegExp(r'[/\\]')).last
            : null;
        final sourceDesc = fileName != null ? 'Local • $fileName' : (l10n?.downloadedLibrary ?? 'Local Library');

        return ResolvedEpisodeSource(
          videoUrl: streamUrl,
          episodeNumber: targetEpNum,
          episodeTitle: nextLocal.displayTitle,
          videoSource: sourceDesc,
        );
      }
    }

    // 2. Try Online Stream provider source
    if (onlineStreamProvider != null && onlineStreamProvider.isNotEmpty) {
      final sources = await repository.getOnlinestreamSource(
        mediaId: mediaId,
        episodeNumber: targetEpNum,
        provider: onlineStreamProvider,
        title: animeDetails?.romajiTitle ?? animeDetails?.title,
        dubbed: onlineStreamDubbed ?? false,
      );

      if (sources.isNotEmpty) {
        final selectedSource = sources.firstWhere(
          (s) => onlineStreamServer != null &&
              s.server.toLowerCase() == onlineStreamServer.toLowerCase(),
          orElse: () => sources.first,
        );

        final providerName = onlineStreamProvider;
        final serverPart = selectedSource.server.isNotEmpty ? ' • ${selectedSource.server.toUpperCase()}' : '';
        final qualityPart = selectedSource.quality.isNotEmpty ? ' (${selectedSource.quality})' : '';
        final sourceDesc = '$providerName$serverPart$qualityPart';

        var playUrl = selectedSource.url;
        if (selectedSource.isTorrent) {
          final magnet =
              selectedSource.url.startsWith('magnet:') ? selectedSource.url : '';
          final infoHash = selectedSource.infoHash ??
              (magnet.isEmpty && selectedSource.url.trim().isNotEmpty
                  ? selectedSource.url.trim()
                  : null);
          final started = await repository.startTorrentMagnetStream(
            magnet: magnet,
            infoHash: infoHash,
            fileIndex: selectedSource.fileIndex,
            fileNameHint: selectedSource.label,
          );
          if (!started) {
            return null;
          }
          playUrl = 'http://${serverManager.host}:${serverManager.port}/api/v1/torrentstream/stream/video.mkv';
        }

        final aniZipEp = (aniZipData ?? animeDetails?.aniZipData)?.getEpisode(targetEpNum);
        final epTitle = aniZipEp?.displayTitle.isNotEmpty == true
            ? aniZipEp!.displayTitle
            : (l10n != null ? l10n!.episodeNumber(targetEpNum) : 'Episode $targetEpNum');

        return ResolvedEpisodeSource(
          videoUrl: playUrl,
          episodeNumber: targetEpNum,
          episodeTitle: epTitle,
          headers: selectedSource.isTorrent ? null : selectedSource.headers,
          mimeType: selectedSource.isHls ? 'application/x-mpegURL' : null,
          videoSource: sourceDesc,
          externalSubtitles: selectedSource.subtitles,
        );
      }
    }

    // 3. Try Torrent Stream source
    final isTorrent = currentVideoUrl.contains('torrentstream') ||
        (onlineStreamProvider == null && !isCurrentLocalFile);
    if (isTorrent) {
      try {
        final success = await repository.startTorrentStream(
          mediaId: mediaId,
          episodeNumber: targetEpNum,
          autoSelect: true,
        );
        if (success) {
          final streamUrl =
              'http://${serverManager.host}:${serverManager.port}/api/v1/torrentstream/stream/video.mkv';
          final aniZipEp =
              (aniZipData ?? animeDetails?.aniZipData)?.getEpisode(targetEpNum);
          final epTitle = aniZipEp?.displayTitle.isNotEmpty == true
              ? aniZipEp!.displayTitle
              : (l10n != null
                  ? l10n!.episodeNumber(targetEpNum)
                  : 'Episode $targetEpNum');
          return ResolvedEpisodeSource(
            videoUrl: streamUrl,
            episodeNumber: targetEpNum,
            episodeTitle: epTitle,
            videoSource: 'Torrent',
          );
        }
      } catch (e) {
        // Fall back to null if auto-select fails
      }
    }

    return null;
  }

  /// Determines whether a next episode is logically available for playback.
  static bool hasNextEpisode({
    required bool isMovie,
    required List<PlayerDirectEpisode>? directEpisodes,
    required int? currentEpisodeNumber,
    required AnimeDetails? animeDetails,
    required AniZipData? aniZipData,
    required String? onlineStreamProvider,
    required List<OnlinestreamEpisode>? onlineEpisodes,
    required bool isCurrentLocalFile,
  }) {
    if (isMovie) return false;

    if (directEpisodes != null && directEpisodes.isNotEmpty) {
      final current = currentEpisodeNumber ?? 0;
      return directEpisodes.any((episode) => episode.number > current);
    }

    final cur = currentEpisodeNumber;
    if (cur == null || cur < 1) return false;
    final nextNum = cur + 1;

    // 1. Total episodes ceiling
    final total = animeDetails?.totalEpisodes;
    if (total != null && total > 0 && nextNum > total) {
      return false;
    }

    // 2. Unreleased series status
    final status = animeDetails?.status?.toUpperCase();
    if (status == 'NOT_YET_RELEASED') {
      return false;
    }

    // 3. Airing guard via AniList nextAiringEpisode
    final rawMedia = animeDetails?.rawMedia;
    final nextAiring = rawMedia?['nextAiringEpisode'] as Map<String, dynamic>?;
    final nextAiringEpNum = (nextAiring?['episode'] as num?)?.toInt();
    if (nextAiringEpNum != null && nextAiringEpNum > 0) {
      if (nextNum >= nextAiringEpNum) {
        return false;
      }
    }

    // 4. Airing guard via AniZip episode airDate & releasing stubs
    final aniZip = aniZipData ?? animeDetails?.aniZipData;
    final nextAniZipEp = aniZip?.getEpisode(nextNum);
    if (nextAniZipEp != null) {
      if (nextAniZipEp.airDate != null && nextAniZipEp.airDate!.isNotEmpty) {
        final airDt = DateTime.tryParse(nextAniZipEp.airDate!);
        if (airDt != null &&
            airDt.isAfter(DateTime.now().add(const Duration(hours: 4)))) {
          return false;
        }
      }
      if (status == 'RELEASING') {
        if ((nextAniZipEp.airDate == null || nextAniZipEp.airDate!.isEmpty) &&
            (nextAniZipEp.image == null || nextAniZipEp.image!.isEmpty)) {
          return false;
        }
      }
    }

    // 5. If streaming via an online provider, check the provider's loaded catalog
    if (onlineStreamProvider != null) {
      if (onlineEpisodes != null) {
        return onlineEpisodes.any((e) => e.number == nextNum);
      }
    }

    // 6. If playing a local library file
    if (isCurrentLocalFile) {
      final eps = animeDetails?.episodes ?? [];
      final hasLocal = eps.any(
        (e) => e.episodeNumber == nextNum && e.isDownloaded,
      );
      if (hasLocal) return true;
    }

    // 7. General availability fallback (AniZip or episodes metadata)
    if (nextAniZipEp != null) {
      return true;
    }

    final eps = animeDetails?.episodes ?? [];
    if (eps.any((e) => e.episodeNumber == nextNum)) {
      return true;
    }

    if (status == 'FINISHED' || status == 'COMPLETED') {
      if (total != null && total > 0) {
        return nextNum <= total;
      }
    }

    if (aniZip != null &&
        aniZip.episodeCount > 0 &&
        nextNum > aniZip.episodeCount) {
      return false;
    }

    return false;
  }

  /// Determines whether a previous episode is available.
  static bool hasPreviousEpisode({
    required bool isMovie,
    required List<PlayerDirectEpisode>? directEpisodes,
    required int? currentEpisodeNumber,
  }) {
    if (isMovie) return false;
    if (directEpisodes != null && directEpisodes.isNotEmpty) {
      final current = currentEpisodeNumber ?? 0;
      return directEpisodes.any((episode) => episode.number < current);
    }
    final cur = currentEpisodeNumber;
    return cur != null && cur > 1;
  }

  /// Builds the episode list for the right rail, falling back to 1..total stubs if needed.
  static List<AnimeEpisode> buildRailEpisodes({
    required AnimeDetails? animeDetails,
    required String Function(int episodeNumber) episodeNumberLabel,
  }) {
    final eps = animeDetails?.episodes ?? const <AnimeEpisode>[];
    if (eps.isNotEmpty) return eps;
    final total = animeDetails?.totalEpisodes ?? 0;
    if (total <= 0) return const [];
    return List.generate(
      total,
      (i) => AnimeEpisode(
        episodeNumber: i + 1,
        title: episodeNumberLabel(i + 1),
      ),
    );
  }
}
