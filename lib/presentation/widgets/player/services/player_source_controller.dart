import 'dart:async';
import 'package:flutter/material.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_episode_resolver.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_playback_coordinator.dart';

/// Controller responsible for managing online video sources, in-player auto-streaming,
/// live server/quality switching, episode transitions, and background prefetching.
class PlayerSourceController {
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
  final ValueGetter<Duration> getPosition;
  final ValueGetter<Duration?> getStartPosition;
  final ValueGetter<bool> getHasNextEpisode;
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
    required this.getPosition,
    required this.getStartPosition,
    required this.getHasNextEpisode,
    required this.onUpdateUi,
    required this.onSourceActivated,
    required this.onShowEpisodePicker,
  });

  /// Resolves online stream sources for the current episode and immediately begins
  /// streaming the first available source without manual intervention.
  Future<void> resolveInitialSources({bool preservePosition = false}) async {
    final epNum = getEpisodeNumber();
    final provider = getOnlineStreamProvider();
    if (mediaId == null || epNum == null || provider == null) {
      return;
    }

    isResolvingSources = true;
    sourceResolutionError = null;
    availableSources = [];
    activeSource = null;
    onUpdateUi();

    try {
      final sources = await repository.getOnlinestreamSource(
        mediaId: mediaId!,
        episodeNumber: epNum,
        provider: provider,
        dubbed: getOnlineStreamDubbed() ?? false,
      );

      if (sources.isEmpty) {
        final l10n = getL10n();
        isResolvingSources = false;
        availableSources = [];
        activeSource = null;
        sourceResolutionError = l10n.noSourcesFoundForEpisode;
        onUpdateUi();
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
      final serverPart = chosenSource.server.isNotEmpty ? ' • ${chosenSource.server.toUpperCase()}' : '';
      final qualityPart = chosenSource.quality.isNotEmpty ? ' (${chosenSource.quality})' : '';
      final sourceDesc = '$providerName$serverPart$qualityPart';

      isResolvingSources = false;
      availableSources = sources;
      activeSource = chosenSource;
      sourceResolutionError = null;

      final targetStartPos = preservePosition ? getPosition() : (getStartPosition() ?? Duration.zero);

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

      onUpdateUi();
      schedulePrefetchNextEpisode();
    } catch (e) {
      isResolvingSources = false;
      sourceResolutionError = 'Error: $e';
      onUpdateUi();
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
        dubbed: getOnlineStreamDubbed() ?? false,
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
      onUpdateUi();
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
    final serverPart = newSource.server.isNotEmpty ? ' • ${newSource.server.toUpperCase()}' : '';
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
    final targetAniZipEp = aniZip?.getEpisode(targetEpNum);
    final targetEpTitle = targetAniZipEp?.displayTitle.isNotEmpty == true
        ? targetAniZipEp!.displayTitle
        : getL10n().episodeNumber(targetEpNum);

    isLoadingNextEpisode = true;
    isResolvingSources = !getIsLocalFile() && getOnlineStreamProvider() != null;
    availableSources = [];
    activeSource = null;
    sourceResolutionError = null;

    onEpisodeTransitionStarted(targetEpNum, targetEpTitle);
    onUpdateUi();

    if (!getIsLocalFile() && getOnlineStreamProvider() != null) {
      try {
        await resolveInitialSources();
      } finally {
        isLoadingNextEpisode = false;
        onUpdateUi();
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
        currentVideoUrl: '',
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

        coordinator.open(
          videoUrl: resolved.videoUrl,
          title: title,
          episodeTitle: resolved.episodeTitle,
          headers: resolved.headers,
          mimeType: resolved.mimeType,
          startPosition: Duration.zero,
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
      onUpdateUi();
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

  /// Disposes timers.
  void dispose() {
    _prefetchTimer?.cancel();
  }
}
