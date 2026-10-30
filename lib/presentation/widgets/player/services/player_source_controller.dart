import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_episode_header.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_episode_resolver.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_playback_coordinator.dart';

/// Controller responsible for managing online video sources, in-player auto-streaming,
/// live server/quality switching, episode transitions, and background prefetching.
class PlayerSourceController extends ChangeNotifier {
  final SeanimeRepository repository;
  final ServerManager serverManager;
  final PlayerPlaybackCoordinator coordinator;
  final int? mediaId;
  final String title;
  final AppTranslations Function() getL10n;
  final ValueGetter<AnimeDetails?> getAnimeDetails;
  final ValueGetter<AniZipData?> getAniZipData;
  final ValueGetter<int?> getEpisodeNumber;
  final ValueGetter<String?> getEpisodeTitle;
  final ValueGetter<String?> getOnlineStreamProvider;
  final ValueGetter<bool?> getOnlineStreamDubbed;
  final ValueGetter<String?> getOnlineStreamServer;
  final ValueGetter<bool> getIsLocalFile;
  final ValueGetter<String>? getVideoUrl;
  final ValueGetter<Duration> getPosition;
  final ValueGetter<Duration?> getStartPosition;
  final Duration? Function(int episodeNumber)? getSavedProgress;
  final ValueGetter<bool> getHasNextEpisode;

  /// TMDB (movies / series) support.
  /// When [getIsTmdb] returns true, online sources are resolved against a
  /// TMDB-capable onlinestream provider (mediaId is the TMDB ID).
  final ValueGetter<bool>? getIsTmdb;
  final ValueGetter<String?>? getTmdbMediaType;
  final ValueGetter<int?>? getTmdbSeason;
  final ValueGetter<String?>? getTmdbEnglishTitle;
  final ValueGetter<int?>? getTmdbYear;

  final VoidCallback onUpdateUi;
  final void Function({
    required String videoUrl,
    required int episodeNumber,
    required String episodeTitle,
    Map<String, String>? headers,
    String? mimeType,
    String? videoSource,
    List<dynamic>? externalSubtitles,
    String? onlineStreamServer,
  }) onSourceActivated;
  final VoidCallback onShowEpisodePicker;

  bool isResolvingSources = false;
  List<OnlinestreamVideoSource> availableSources = [];
  OnlinestreamVideoSource? activeSource;
  String? sourceResolutionError;
  bool isLoadingNextEpisode = false;
  bool _isDisposed = false;

  void _safeUpdateUi() {
    if (!_isDisposed) {
      notifyListeners();
      onUpdateUi();
    }
  }

  Timer? _prefetchTimer;

  PlayerSourceController({
    required this.repository,
    required this.serverManager,
    required this.coordinator,
    required this.mediaId,
    required this.title,
    required this.getL10n,
    required this.getAnimeDetails,
    required this.getAniZipData,
    required this.getEpisodeNumber,
    required this.getEpisodeTitle,
    required this.getOnlineStreamProvider,
    required this.getOnlineStreamDubbed,
    required this.getOnlineStreamServer,
    required this.getIsLocalFile,
    this.getVideoUrl,
    required this.getPosition,
    required this.getStartPosition,
    this.getSavedProgress,
    required this.getHasNextEpisode,
    required this.onUpdateUi,
    required this.onSourceActivated,
    required this.onShowEpisodePicker,
    this.getIsTmdb,
    this.getTmdbMediaType,
    this.getTmdbSeason,
    this.getTmdbEnglishTitle,
    this.getTmdbYear,
  });

  /// Resolves online stream sources for the current episode and immediately begins
  /// streaming the first available source without manual intervention.
  Future<void> resolveInitialSources({
    bool preservePosition = false,
    int? targetEpisodeNumber,
  }) async {
    final epNum = targetEpisodeNumber ?? getEpisodeNumber();
    final provider = getOnlineStreamProvider();
    if (mediaId == null || epNum == null || provider == null) {
      return;
    }

    isResolvingSources = true;
    sourceResolutionError = null;
    availableSources = [];
    activeSource = null;
    _safeUpdateUi();

    try {
      final sources = await repository.getOnlinestreamSource(
        mediaId: mediaId!,
        episodeNumber: epNum,
        provider: provider,
        title: title,
        dubbed: getOnlineStreamDubbed() ?? false,
        isTmdb: getIsTmdb?.call() ?? false,
        tmdbMediaType: getTmdbMediaType?.call(),
        tmdbSeason: getTmdbSeason?.call(),
        tmdbEnglishTitle: getTmdbEnglishTitle?.call(),
        tmdbYear: getTmdbYear?.call(),
      );

      if (sources.isEmpty) {
        final l10n = getL10n();
        isResolvingSources = false;
        availableSources = [];
        activeSource = null;
        sourceResolutionError = l10n.noSourcesFoundForEpisode;
        _safeUpdateUi();
        return;
      }

      final preferredServer = getOnlineStreamServer();
      final chosenSource = sources.firstWhere(
        (s) =>
            preferredServer != null &&
            s.server.toLowerCase() == preferredServer.toLowerCase(),
        orElse: () => sources.first,
      );

      final providerName = provider;
      final serverPart = chosenSource.server.isNotEmpty ? ' â€¢ ${chosenSource.server.toUpperCase()}' : '';
      final qualityPart = chosenSource.quality.isNotEmpty ? ' (${chosenSource.quality})' : '';
      final sourceDesc = '$providerName$serverPart$qualityPart';

      isResolvingSources = false;
      availableSources = sources;
      activeSource = chosenSource;
      sourceResolutionError = null;

      final currentPos = getPosition();
      final Duration savedPos;
      if (targetEpisodeNumber != null) {
        savedPos = getSavedProgress?.call(targetEpisodeNumber) ?? Duration.zero;
      } else {
        savedPos = getStartPosition() ?? Duration.zero;
      }
      final targetStartPos = preservePosition
          ? (currentPos > Duration.zero ? currentPos : savedPos)
          : savedPos;

      onSourceActivated(
        videoUrl: chosenSource.url,
        episodeNumber: epNum,
        episodeTitle: getEpisodeTitle() ?? getL10n().episodeNumber(epNum),
        headers: chosenSource.headers,
        mimeType: chosenSource.isHls ? 'application/x-mpegURL' : null,
        videoSource: sourceDesc,
        externalSubtitles: chosenSource.subtitles,
        onlineStreamServer: chosenSource.server,
      );

      coordinator.open(
        videoUrl: chosenSource.url,
        title: title,
        episodeTitle: getEpisodeTitle(),
        headers: chosenSource.headers,
        mimeType: chosenSource.isHls ? 'application/x-mpegURL' : null,
        startPosition: targetStartPos,
        externalSubtitles: chosenSource.subtitles,
        isOnlineStream: true,
      );

      _safeUpdateUi();
      schedulePrefetchNextEpisode();
    } catch (e) {
      isResolvingSources = false;
      sourceResolutionError = 'Error: $e';
      _safeUpdateUi();
    }
  }

  /// Quietly fetches online stream sources in the background without resetting active playback.
  Future<void> fetchAvailableSourcesInBackground({required String currentVideoUrl}) async {
    final epNum = getEpisodeNumber();
    final provider = getOnlineStreamProvider();
    if (mediaId == null || epNum == null || provider == null) {
      return;
    }

    try {
      final sources = await repository.getOnlinestreamSource(
        mediaId: mediaId!,
        episodeNumber: epNum,
        provider: provider,
        title: title,
        dubbed: getOnlineStreamDubbed() ?? false,
        isTmdb: getIsTmdb?.call() ?? false,
        tmdbMediaType: getTmdbMediaType?.call(),
        tmdbSeason: getTmdbSeason?.call(),
        tmdbEnglishTitle: getTmdbEnglishTitle?.call(),
        tmdbYear: getTmdbYear?.call(),
      );

      if (sources.isEmpty) return;

      final preferredServer = getOnlineStreamServer();
      final matched = sources.firstWhere(
        (s) =>
            s.url == currentVideoUrl ||
            (preferredServer != null && s.server.toLowerCase() == preferredServer.toLowerCase()),
        orElse: () => sources.first,
      );

      availableSources = sources;
      activeSource = matched;
      _safeUpdateUi();
    } catch (_) {}
  }

  /// Switches playback live to a selected alternative source while preserving position.
  void selectSource(OnlinestreamVideoSource newSource) {
    if (activeSource != null &&
        activeSource!.url == newSource.url &&
        activeSource!.server == newSource.server &&
        activeSource!.quality == newSource.quality) {
      return;
    }

    final currentPos = getPosition();
    final providerName = getOnlineStreamProvider() ?? 'Online';
    final serverPart = newSource.server.isNotEmpty ? ' â€¢ ${newSource.server.toUpperCase()}' : '';
    final qualityPart = newSource.quality.isNotEmpty ? ' (${newSource.quality})' : '';
    final sourceDesc = '$providerName$serverPart$qualityPart';

    activeSource = newSource;

    onSourceActivated(
      videoUrl: newSource.url,
      episodeNumber: getEpisodeNumber() ?? 1,
      episodeTitle: getEpisodeTitle() ?? '',
      headers: newSource.headers,
      mimeType: newSource.isHls ? 'application/x-mpegURL' : null,
      videoSource: sourceDesc,
      externalSubtitles: newSource.subtitles,
      onlineStreamServer: newSource.server,
    );

    coordinator.open(
      videoUrl: newSource.url,
      title: title,
      episodeTitle: getEpisodeTitle(),
      headers: newSource.headers,
      mimeType: newSource.isHls ? 'application/x-mpegURL' : null,
      startPosition: currentPos,
      externalSubtitles: newSource.subtitles,
      isOnlineStream: true,
    );

    onUpdateUi();
  }

  /// Handles in-player transition to a target episode number.
  Future<void> playEpisode({
    required int targetEpNum,
    required void Function(int targetEpNum, String targetEpTitle) onEpisodeTransitionStarted,
  }) async {
    if (mediaId == null || isLoadingNextEpisode) return;

    _prefetchTimer?.cancel();
    coordinator.pause();
    coordinator.stop();

    final aniZip = getAniZipData() ?? getAnimeDetails()?.aniZipData;
    final animeDetails = getAnimeDetails();
    final targetAniZipEp = aniZip?.getEpisode(targetEpNum);
    final eps = animeDetails?.episodes; final targetDetailsEp = eps?.where((e) => e.episodeNumber == targetEpNum).firstOrNull;

    final String targetEpTitle;
    if (targetAniZipEp != null &&
        !PlayerEpisodeHeader.isGenericTitle(targetAniZipEp.displayTitle, targetEpNum)) {
      targetEpTitle = targetAniZipEp.displayTitle;
    } else if (targetDetailsEp != null &&
        !PlayerEpisodeHeader.isGenericTitle(targetDetailsEp.title, targetEpNum)) {
      targetEpTitle = targetDetailsEp.title;
    } else if (targetAniZipEp?.displayTitle.isNotEmpty == true) {
      targetEpTitle = targetAniZipEp!.displayTitle;
    } else if (targetDetailsEp?.title.isNotEmpty == true) {
      targetEpTitle = targetDetailsEp!.title;
    } else {
      targetEpTitle = getL10n().episodeNumber(targetEpNum);
    }

    isLoadingNextEpisode = true;
    isResolvingSources = !getIsLocalFile() && getOnlineStreamProvider() != null;
    availableSources = [];
    activeSource = null;
    sourceResolutionError = null;

    onEpisodeTransitionStarted(targetEpNum, targetEpTitle);
    onUpdateUi();

    if (!getIsLocalFile() && getOnlineStreamProvider() != null) {
      try {
        await resolveInitialSources(targetEpisodeNumber: targetEpNum);
      } finally {
        isLoadingNextEpisode = false;
        _safeUpdateUi();
      }
      return;
    }

    try {
      final resolver = PlayerEpisodeResolver(
        repository: repository,
        serverManager: serverManager,
        l10n: getL10n(),
      );

      final resolved = await resolver.resolveEpisode(
        mediaId: mediaId!,
        targetEpNum: targetEpNum,
        isCurrentLocalFile: getIsLocalFile(),
        currentVideoUrl: getVideoUrl?.call() ?? coordinator.videoUrl ?? '',
        onlineStreamProvider: getOnlineStreamProvider(),
        onlineStreamDubbed: getOnlineStreamDubbed(),
        onlineStreamServer: getOnlineStreamServer(),
        animeDetails: getAnimeDetails(),
        aniZipData: aniZip,
      );

      if (resolved != null) {
        onSourceActivated(
          videoUrl: resolved.videoUrl,
          episodeNumber: resolved.episodeNumber,
          episodeTitle: resolved.episodeTitle,
          headers: resolved.headers,
          mimeType: resolved.mimeType,
          videoSource: resolved.videoSource,
          externalSubtitles: resolved.externalSubtitles,
        );

        final targetStartPos = getSavedProgress?.call(targetEpNum) ?? Duration.zero;
        coordinator.open(
          videoUrl: resolved.videoUrl,
          title: title,
          episodeTitle: resolved.episodeTitle,
          headers: resolved.headers,
          mimeType: resolved.mimeType,
          startPosition: targetStartPos,
          externalSubtitles: resolved.externalSubtitles,
          isOnlineStream: !getIsLocalFile(),
        );

        schedulePrefetchNextEpisode();
        return;
      }

      onShowEpisodePicker();
    } catch (e) {
      debugPrint('[PlayerSourceController] Error loading episode $targetEpNum: $e');
      onShowEpisodePicker();
    } finally {
      isLoadingNextEpisode = false;
      _safeUpdateUi();
    }
  }

  /// Schedules background prefetching for the next episode in RAM after 12 seconds.
  void schedulePrefetchNextEpisode() {
    _prefetchTimer?.cancel();
    if (!getHasNextEpisode() || mediaId == null) return;

    _prefetchTimer = Timer(const Duration(seconds: 12), () {
      if (!getHasNextEpisode() || mediaId == null) return;
      final targetEp = (getEpisodeNumber() ?? 1) + 1;
      final resolver = PlayerEpisodeResolver(
        repository: repository,
        serverManager: serverManager,
        l10n: getL10n(),
      );
      resolver.prefetchEpisode(
        mediaId: mediaId!,
        targetEpNum: targetEp,
        isCurrentLocalFile: getIsLocalFile(),
        currentVideoUrl: '',
        onlineStreamProvider: getOnlineStreamProvider(),
        onlineStreamDubbed: getOnlineStreamDubbed(),
        onlineStreamServer: getOnlineStreamServer(),
        animeDetails: getAnimeDetails(),
        aniZipData: getAniZipData() ?? getAnimeDetails()?.aniZipData,
      );
    });
  }

  /// Disposes timers and stops UI callbacks.
  @override
  void dispose() {
    _isDisposed = true;
    _prefetchTimer?.cancel();
    super.dispose();
  }
}
