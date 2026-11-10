import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/anime_playback_source_provider.dart';
import 'package:aniting/core/preferences/playback_progress_preferences_provider.dart';
import 'package:aniting/core/preferences/resume_bar_preferences_provider.dart';
import 'package:aniting/core/preferences/title_language_provider.dart';
import 'package:aniting/data/models/anime_entry.dart';
import 'package:aniting/data/models/library_entry_details.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/screens/video_player_screen.dart';

/// Service that launches playback directly for an episode in "Continue Watching" (Seguir Viendo)
/// using the exact same source the user was watching (Local Library, Online Stream provider, or Torrent).
class ContinueWatchingPlaybackLauncher {
  static const String _prefLastProviderKey = 'last_selected_online_provider';

  /// Launches the video player directly for [entry] at the target episode and resume position.
  /// Falls back to [onFallbackToDetail] or [AnimeDetailScreen.navigate] if resolution cannot proceed.
  static Future<void> launch(
    BuildContext context,
    WidgetRef ref,
    AnimeEntry entry, {
    VoidCallback? onFallbackToDetail,
  }) async {
    HapticFeedback.lightImpact();

    final l10n = ref.read(translationsProvider);
    final titleLang = ref.read(titleLanguageProvider);
    final repo = ref.read(repositoryProvider);
    final serverManager = ref.read(serverManagerProvider);

    final mediaTitle = entry.displayTitle(titleLang);
    final epNum = entry.episodeNumber ?? (entry.progress + 1);

    // 1. Resolve start position from local playback progress
    final playbackMap = ref.read(playbackProgressPreferencesProvider);
    final epKey = '${entry.mediaId}_$epNum';
    final mediaProgress = playbackMap[entry.mediaId.toString()];
    final localProgress = playbackMap[epKey] ??
        (mediaProgress != null && mediaProgress.episodeNumber == epNum
            ? mediaProgress
            : null);

    Duration? startPos;
    if (localProgress != null &&
        localProgress.positionMs > 0 &&
        localProgress.durationMs > 0) {
      final fraction = localProgress.positionMs / localProgress.durationMs;
      if (fraction < 0.95) {
        startPos = Duration(milliseconds: localProgress.positionMs);
      }
    }

    // 2. Resolve known source from animePlaybackSourceProvider or lastSession
    final savedSource = entry.isTmdb
        ? null
        : ref.read(animePlaybackSourceProvider.notifier).getSource(entry.mediaId);
    final lastSession = ref.read(lastSessionProvider);
    final bool isSessionMatching = lastSession != null &&
        lastSession.mediaId == entry.mediaId &&
        lastSession.isTmdb == entry.isTmdb;

    final String? onlineProvider = savedSource?.onlineStreamProvider ??
        (isSessionMatching ? lastSession.onlineStreamProvider : null);
    final bool? onlineDubbed = savedSource?.onlineStreamDubbed ??
        (isSessionMatching ? lastSession.onlineStreamDubbed : null);
    final String? onlineServer = savedSource?.onlineStreamServer ??
        (isSessionMatching ? lastSession.onlineStreamServer : null);

    final bool isSavedLocal = savedSource?.isLocal == true ||
        (isSessionMatching && lastSession.isLocalFile) ||
        (isSessionMatching &&
            (lastSession.videoUrl?.contains('/api/v1/mediastream') ?? false));

    final bool isSavedTorrent = savedSource?.isTorrent == true ||
        (isSessionMatching &&
            ((lastSession.videoUrl?.contains('torrentstream') ?? false) ||
                (lastSession.videoSource
                        ?.toLowerCase()
                        .contains('torrent') ??
                    false)));

    final defaultEpTitle = entry.episodeTitle != null &&
            entry.episodeTitle!.trim().isNotEmpty &&
            !entry.episodeTitle!.toLowerCase().startsWith('episod')
        ? entry.episodeTitle!.trim()
        : l10n.episodeNumber(epNum);

    final isTmdb = entry.isTmdb;
    final tmdbMediaType =
        (entry.format ?? '').toUpperCase() == 'MOVIE' ? 'movie' : 'tv';
    final tmdbSeason =
        isSessionMatching ? lastSession.tmdbSeason : null;
    final tmdbEnglishTitle = entry.englishTitle;
    final tmdbYear = entry.year;

    // ─── 3. Instant Local Fast-Path (0ms, no await) ───
    // Downloaded episodes (local library files or completed torrents) are
    // already indexed in memory by the feed. Resolving them synchronously lets
    // the player open on the same frame as the tap, just like a local file.
    if (!isTmdb) {
      final cachedPath = repo.getCachedLocalFilePath(entry.mediaId, epNum);
      if (cachedPath != null && cachedPath.isNotEmpty && context.mounted) {
        final fileName = cachedPath.split(RegExp(r'[/\\]')).last;
        final streamUrl =
            'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(cachedPath)}';
        _openLocalFile(
          context,
          mediaId: entry.mediaId,
          streamUrl: streamUrl,
          title: mediaTitle,
          episodeTitle: defaultEpTitle,
          episodeNumber: epNum,
          startPosition: startPos,
          videoSource: 'Local • $fileName',
          isTmdb: isTmdb,
          tmdbMediaType: tmdbMediaType,
          tmdbSeason: tmdbSeason,
          tmdbEnglishTitle: tmdbEnglishTitle,
          tmdbYear: tmdbYear,
        );
        return;
      }
    }

    // ─── 4. Local Library Async Fallback ───
    // If the anime has local files, was watched locally, or was resumed from a
    // torrent, look up the episode on disk (covers a stale in-memory index).
    if (!isTmdb && (isSavedLocal || isSavedTorrent || entry.hasLocalFiles)) {
      try {
        final libEntry =
            await repo.getAnimeLibraryEntry(entry.mediaId, forceRefresh: true);
        final localEp = libEntry?.episodes.cast<LibraryEpisode?>().firstWhere(
              (e) => e?.episodeNumber == epNum,
              orElse: () => null,
            );
        if (localEp != null && context.mounted) {
          final streamUrl = localEp.localFilePath != null &&
                  localEp.localFilePath!.isNotEmpty
              ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
              : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${entry.mediaId}&episodeNumber=${localEp.episodeNumber}';
          final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;
          final epTitle = localEp.displayTitle.isNotEmpty
              ? localEp.displayTitle
              : defaultEpTitle;

          _openLocalFile(
            context,
            mediaId: entry.mediaId,
            streamUrl: streamUrl,
            title: mediaTitle,
            episodeTitle: epTitle,
            episodeNumber: epNum,
            startPosition: startPos,
            videoSource:
                fileName != null ? 'Local • $fileName' : l10n.localLibrary,
            isTmdb: isTmdb,
            tmdbMediaType: tmdbMediaType,
            tmdbSeason: tmdbSeason,
            tmdbEnglishTitle: tmdbEnglishTitle,
            tmdbYear: tmdbYear,
          );
          return;
        }
      } catch (_) {}
    }

    // ─── 5. Torrent Stream Resume ───
    if (!isTmdb && isSavedTorrent) {
      try {
        final success = await repo.startTorrentStream(
          mediaId: entry.mediaId,
          episodeNumber: epNum,
          autoSelect: true,
          playbackType: 'none',
        );
        if (success && context.mounted) {
          final streamUrl =
              'http://${serverManager.host}:${serverManager.port}/api/v1/torrentstream/stream/video.mkv';
          Navigator.of(context, rootNavigator: true).push(
            VideoPlayerScreen.route(
              mediaId: entry.mediaId,
              videoUrl: streamUrl,
              title: mediaTitle,
              episodeTitle: defaultEpTitle,
              episodeNumber: epNum,
              startPosition: startPos,
              videoSource: savedSource?.videoSource ??
                  lastSession?.videoSource ??
                  'Torrent',
              onDispose: () => repo.stopTorrentStream(),
              isTmdbMedia: isTmdb,
              tmdbMediaType: tmdbMediaType,
              tmdbSeason: tmdbSeason,
              tmdbEnglishTitle: tmdbEnglishTitle,
              tmdbYear: tmdbYear,
            ),
          );
          return;
        }
      } catch (_) {}
    }

    // ─── 6. Online Stream Source (same provider, sub/dub, server) ───
    String? resolvedProviderId = onlineProvider;
    if (resolvedProviderId == null || resolvedProviderId.isEmpty) {
      // Check global last selected provider
      try {
        final prefs = await SharedPreferences.getInstance();
        resolvedProviderId = prefs.getString(_prefLastProviderKey);
      } catch (_) {}
    }

    if (resolvedProviderId == null || resolvedProviderId.isEmpty) {
      // Fallback to first available provider
      try {
        final providers = await repo.getOnlinestreamProviders();
        final candidates = isTmdb
            ? providers.where((p) => p.supportsTmdb).toList()
            : providers;
        if (candidates.isNotEmpty) {
          resolvedProviderId = candidates.first.id;
        }
      } catch (_) {}
    }

    if (resolvedProviderId != null && resolvedProviderId.isNotEmpty && context.mounted) {
      final providerLabel =
          savedSource?.videoSource ?? resolvedProviderId.toUpperCase();
      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: entry.mediaId,
          videoUrl: '', // Auto-resolves sources in VideoPlayerScreen using provider
          title: mediaTitle,
          episodeTitle: defaultEpTitle,
          episodeNumber: epNum,
          videoSource: providerLabel,
          startPosition: startPos,
          onlineStreamProvider: resolvedProviderId,
          onlineStreamDubbed: onlineDubbed ?? false,
          onlineStreamServer: onlineServer,
          isTmdbMedia: isTmdb,
          tmdbMediaType: tmdbMediaType,
          tmdbSeason: tmdbSeason,
          tmdbEnglishTitle: tmdbEnglishTitle,
          tmdbYear: tmdbYear,
        ),
      );
      return;
    }

    // ─── 7. Ultimate Fallback to Detail Screen ───
    if (context.mounted) {
      if (onFallbackToDetail != null) {
        onFallbackToDetail();
      } else {
        AnimeDetailScreen.navigate(
          context,
          mediaId: entry.mediaId,
          initialEntry: entry,
          isTmdb: entry.isTmdb,
        );
      }
    }
  }

  /// Opens the video player for a file that lives on the server's disk.
  static void _openLocalFile(
    BuildContext context, {
    required int mediaId,
    required String streamUrl,
    required String title,
    required String episodeTitle,
    required int episodeNumber,
    required Duration? startPosition,
    required String videoSource,
    required bool isTmdb,
    required String tmdbMediaType,
    required int? tmdbSeason,
    required String? tmdbEnglishTitle,
    required int? tmdbYear,
  }) {
    Navigator.of(context, rootNavigator: true).push(
      VideoPlayerScreen.route(
        mediaId: mediaId,
        videoUrl: streamUrl,
        title: title,
        episodeTitle: episodeTitle,
        episodeNumber: episodeNumber,
        videoSource: videoSource,
        startPosition: startPosition,
        isLocalFile: true,
        isTmdbMedia: isTmdb,
        tmdbMediaType: tmdbMediaType,
        tmdbSeason: tmdbSeason,
        tmdbEnglishTitle: tmdbEnglishTitle,
        tmdbYear: tmdbYear,
      ),
    );
  }
}
