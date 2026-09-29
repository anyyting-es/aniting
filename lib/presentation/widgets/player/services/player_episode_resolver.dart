import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';

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

  // In-memory cache of resolved episode streams to allow instantaneous (0ms) episode switching
  static final Map<String, ResolvedEpisodeSource> _cache = {};
  static final Map<String, Future<ResolvedEpisodeSource?>> _inflight = {};

  const PlayerEpisodeResolver({
    required this.repository,
    required this.serverManager,
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
        final sourceDesc = fileName != null ? 'Local • $fileName' : 'Biblioteca Local';

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

        final aniZipEp = (aniZipData ?? animeDetails?.aniZipData)?.getEpisode(targetEpNum);
        final epTitle = aniZipEp?.displayTitle.isNotEmpty == true
            ? aniZipEp!.displayTitle
            : 'Episodio $targetEpNum';

        return ResolvedEpisodeSource(
          videoUrl: selectedSource.url,
          episodeNumber: targetEpNum,
          episodeTitle: epTitle,
          headers: selectedSource.headers,
          mimeType: selectedSource.isHls ? 'application/x-mpegURL' : null,
          videoSource: sourceDesc,
          externalSubtitles: selectedSource.subtitles,
        );
      }
    }

    return null;
  }
}
