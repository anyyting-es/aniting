import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/anime_playback_source_provider.dart';
import 'package:seanime_app/core/preferences/player_engine_provider.dart';
import 'package:seanime_app/core/preferences/player_gesture_provider.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/core/preferences/volume_boost_provider.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/widgets/anime_details_modal_sheet.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_keyboard_handler.dart';
import 'package:seanime_app/presentation/widgets/player/layouts/player_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/player/layouts/player_mobile_layout.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:seanime_app/presentation/widgets/player/services/performance_stats_service.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_playback_coordinator.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_progress_manager.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_shader_service.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_source_controller.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_window_manager.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/player_settings_launcher.dart';
import 'package:seanime_app/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:seanime_app/core/player/mpris_service.dart';
import 'package:seanime_app/presentation/widgets/player/viewport/player_viewport.dart';

export 'package:seanime_app/presentation/widgets/player/models/player_types.dart'
    show UiTrack, ShaderPreset, PerformanceStats, PlayerFitMode;

/// Main video playback screen featuring a modern, clean UI inspired by Plezy & YouTube.
/// Provides dual-engine playback (ExoPlayer + libmpv), YouTube-style watch page on mobile,
/// collapsible right info panel on desktop, TV direct fullscreen mode, and audio/subtitle sync.
class VideoPlayerScreen extends ConsumerStatefulWidget {
  final int? mediaId;
  final String videoUrl;
  final String title;
  final String? episodeTitle;
  final int? episodeNumber;
  final Map<String, String>? headers;
  final String? mimeType;
  final String? videoSource;
  final List<dynamic>? externalSubtitles;
  final Duration? startPosition;
  final VoidCallback? onDispose;
  final bool? isTv;
  final AnimeDetails? initialAnimeDetails;
  final AniZipData? initialAniZipData;
  final String? onlineStreamProvider;
  final bool? onlineStreamDubbed;
  final String? onlineStreamServer;
  final bool isLocalFile;

  /// TMDB (movies / series): when [isTmdbMedia] is true, [mediaId] is the TMDB ID
  /// and online streaming is resolved through a TMDB-capable provider.
  final bool isTmdbMedia;
  final String? tmdbMediaType;
  final int? tmdbSeason;
  final String? tmdbEnglishTitle;
  final int? tmdbYear;

  const VideoPlayerScreen({
    super.key,
    this.mediaId,
    this.videoUrl = '',
    required this.title,
    this.episodeTitle,
    this.episodeNumber,
    this.headers,
    this.mimeType,
    this.videoSource,
    this.externalSubtitles,
    this.startPosition,
    this.onDispose,
    this.isTv,
    this.initialAnimeDetails,
    this.initialAniZipData,
    this.onlineStreamProvider,
    this.onlineStreamDubbed,
    this.onlineStreamServer,
    this.isLocalFile = false,
    this.isTmdbMedia = false,
    this.tmdbMediaType,
    this.tmdbSeason,
    this.tmdbEnglishTitle,
    this.tmdbYear,
  });

  static Route<void> route({
    int? mediaId,
    String videoUrl = '',
    required String title,
    String? episodeTitle,
    int? episodeNumber,
    Duration? startPosition,
    Map<String, String>? headers,
    String? mimeType,
    String? videoSource,
    List<OnlinestreamSubtitle>? externalSubtitles,
    VoidCallback? onDispose,
    bool? isTv,
    AnimeDetails? animeDetails,
    AniZipData? aniZipData,
    String? onlineStreamProvider,
    bool? onlineStreamDubbed,
    String? onlineStreamServer,
    bool isLocalFile = false,
    bool isTmdbMedia = false,
    String? tmdbMediaType,
    int? tmdbSeason,
    String? tmdbEnglishTitle,
    int? tmdbYear,
  }) {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, animation, secondaryAnimation) => VideoPlayerScreen(
        mediaId: mediaId,
        videoUrl: videoUrl,
        title: title,
        episodeTitle: episodeTitle,
        episodeNumber: episodeNumber,
        startPosition: startPosition,
        headers: headers,
        mimeType: mimeType,
        videoSource: videoSource,
        externalSubtitles: externalSubtitles,
        onDispose: onDispose,
        isTv: isTv,
        initialAnimeDetails: animeDetails,
        initialAniZipData: aniZipData,
        onlineStreamProvider: onlineStreamProvider,
        onlineStreamDubbed: onlineStreamDubbed,
        onlineStreamServer: onlineStreamServer,
        isLocalFile: isLocalFile,
        isTmdbMedia: isTmdbMedia,
        tmdbMediaType: tmdbMediaType,
        tmdbSeason: tmdbSeason,
        tmdbEnglishTitle: tmdbEnglishTitle,
        tmdbYear: tmdbYear,
      ),
    );
  }

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final PlayerPlaybackCoordinator _coordinator;
  late final PlayerWindowManager _windowManager;
  late final PlayerProgressManager _progressManager;
  late final PlayerSourceController _sourceController;

  // Playback state
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _buffer = Duration.zero;
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(Duration.zero);
  final ValueNotifier<Duration> _bufferNotifier = ValueNotifier<Duration>(Duration.zero);
  bool _canSkipCurrentChapter = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  double _playbackRate = 1.0;
  double _volume = 100.0;
  double _lastNonZeroVolume = 100.0;
  final FocusNode _focusNode = FocusNode();

  // YouTube-style watch page & TV mode state (hidden/collapsed by default on desktop)
  bool _isSidePanelCollapsed = !Platform.isAndroid && !Platform.isIOS;
  AnimeDetails? _animeDetails;
  AniZipData? _aniZipData;
  bool _isLoadingDetails = false;
  bool get _isTvActive => widget.isTv ?? ref.read(tvModeProvider);

  // Chapters & Editions (MKV)
  List<PlayerChapter> _chapters = [];
  PlayerChapter? get _activeChapter {
    for (final ch in _chapters) {
      if (_position >= ch.start && (ch.end == null || _position < ch.end!)) {
        return ch;
      }
    }
    return null;
  }

  // Tracks
  List<UiTrack> _audioTracks = [];
  List<UiTrack> _subtitleTracks = [];
  String? _selectedAudioTrackId;
  String? _selectedSubtitleTrackId;
  String _currentSubtitleText = '';

  late final TorrentStreamStatusNotifier _torrentStreamNotifier;

  // Captured up-front so that dispose() never touches `ref` (which is unsafe
  // once the widget is being unmounted).
  late final SeanimeRepository _repository;
  bool _hasActiveTorrentStream = false;
  bool _pauseTorrentStreamOnExit = true;

  // Sync offsets in ms
  int _subtitleDelayMs = 0;
  int _audioDelayMs = 0;

  // Shaders (OFF by default)
  final PlayerShaderService _shaderService = PlayerShaderService();
  ShaderPreset _activeShaderPreset = ShaderPreset.none;

  // Stats overlay
  bool _isStatsVisible = false;
  PerformanceStatsService? _statsService;
  final ValueNotifier<PerformanceStats?> _performanceStatsNotifier = ValueNotifier<PerformanceStats?>(null);
  StreamSubscription<PerformanceStats>? _statsSub;

  // Torrent progress overlay
  bool _isTorrentProgressVisible = false;

  // Viewport fit mode
  PlayerFitMode _fitMode = PlayerFitMode.contain;

  // Controls UI visibility
  bool _areControlsVisible = true;
  bool _isInteractingWithVolume = false;
  Timer? _hideTimer;

  // Seek feedback toast
  String? _seekFeedback;
  int _seekFeedbackKey = 0;
  Timer? _seekFeedbackTimer;

  // Fallback notice
  String? _fallbackNotice;
  Timer? _fallbackNoticeTimer;

  // Brightness for gesture control (0.0 to 1.0)
  double _brightness = 0.5;

  // Mutable episode and source state
  late String _currentVideoUrl;
  late String? _currentEpisodeTitle;
  late int? _currentEpisodeNumber;
  late String? _currentVideoSource;
  late Map<String, String>? _currentHeaders;
  late String? _currentMimeType;
  late List<dynamic>? _currentExternalSubtitles;
  String? _currentOnlineStreamProvider;
  bool? _currentOnlineStreamDubbed;
  String? _currentOnlineStreamServer;
  bool _isCurrentLocalFile = false;
  Duration? _initialStartPosition;
  bool _isMouseInside = false;

  bool _isPlayerDisposed = false;

  // Delegated getters to modular services
  bool get _isFullscreen => _windowManager.isFullscreen;
  bool get _isTransitioningOrientation => _windowManager.isTransitioningOrientation;
  bool get _isExiting => _windowManager.isExiting;
  bool get _isResolvingSources => _sourceController.isResolvingSources;
  List<OnlinestreamVideoSource> get _availableSources => _sourceController.availableSources;
  OnlinestreamVideoSource? get _activeSource => _sourceController.activeSource;
  String? get _sourceResolutionError => _sourceController.sourceResolutionError;
  bool get _isLoadingNextEpisode => _sourceController.isLoadingNextEpisode;

  /// Where the current video comes from. Only online streams expose switchable
  /// providers/servers, so the playback card renders differently for local files
  /// and torrent streams.
  PlayerPlaybackOrigin get _playbackOrigin {
    if (_isCurrentLocalFile || _currentVideoUrl.contains('/api/v1/mediastream')) {
      return PlayerPlaybackOrigin.local;
    }
    if (_currentVideoUrl.contains('torrentstream') ||
        (_currentVideoSource?.toLowerCase().contains('torrent') ?? false)) {
      return PlayerPlaybackOrigin.torrent;
    }
    return PlayerPlaybackOrigin.online;
  }

  List<OnlinestreamEpisode>? _onlineEpisodes;

  Future<void> _fetchOnlineEpisodes() async {
    if (widget.mediaId == null || _currentOnlineStreamProvider == null) return;
    final repo = ref.read(repositoryProvider);
    final providerId = _currentOnlineStreamProvider!;
    final dubbed = _currentOnlineStreamDubbed ?? false;

    final cached = repo.getCachedOnlinestreamEpisodes(
      mediaId: widget.mediaId!,
      provider: providerId,
      dubbed: dubbed,
    );
    if (cached != null && cached.isNotEmpty && mounted) {
      setState(() => _onlineEpisodes = cached);
    }

    try {
      final list = await repo.getOnlinestreamEpisodes(
        mediaId: widget.mediaId!,
        provider: providerId,
        dubbed: dubbed,
      );
      if (mounted) {
        setState(() => _onlineEpisodes = list);
      }
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Error loading online episodes: $e');
    }
  }

  bool get _isMovie =>
      _animeDetails?.format?.toUpperCase() == 'MOVIE' ||
      (_animeDetails?.totalEpisodes == 1 && (_animeDetails?.episodes.length ?? 0) <= 1);

  bool get _hasNextEpisode {
    if (_isMovie) return false;
    final cur = _currentEpisodeNumber;
    if (cur == null || cur < 1) return false;
    final nextNum = cur + 1;

    // 1. Total episodes ceiling
    final total = _animeDetails?.totalEpisodes;
    if (total != null && total > 0 && nextNum > total) {
      return false;
    }

    // 2. Unreleased series status
    final status = _animeDetails?.status?.toUpperCase();
    if (status == 'NOT_YET_RELEASED') {
      return false;
    }

    // 3. Airing guard via AniList nextAiringEpisode
    final rawMedia = _animeDetails?.rawMedia;
    final nextAiring = rawMedia?['nextAiringEpisode'] as Map<String, dynamic>?;
    final nextAiringEpNum = (nextAiring?['episode'] as num?)?.toInt();
    if (nextAiringEpNum != null && nextAiringEpNum > 0) {
      if (nextNum >= nextAiringEpNum) {
        return false;
      }
    }

    // 4. Airing guard via AniZip episode airDate & releasing stubs
    final aniZip = _aniZipData ?? _animeDetails?.aniZipData;
    final nextAniZipEp = aniZip?.getEpisode(nextNum);
    if (nextAniZipEp != null) {
      if (nextAniZipEp.airDate != null && nextAniZipEp.airDate!.isNotEmpty) {
        final airDt = DateTime.tryParse(nextAniZipEp.airDate!);
        if (airDt != null && airDt.isAfter(DateTime.now().add(const Duration(hours: 4)))) {
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
    if (_currentOnlineStreamProvider != null) {
      if (_onlineEpisodes != null) {
        return _onlineEpisodes!.any((e) => e.number == nextNum);
      }
    }

    // 6. If playing a local library file
    if (_isCurrentLocalFile) {
      final eps = _animeDetails?.episodes ?? [];
      final hasLocal = eps.any((e) => e.episodeNumber == nextNum && e.isDownloaded);
      if (hasLocal) return true;
    }

    // 7. General availability fallback (AniZip or episodes metadata)
    if (nextAniZipEp != null) {
      return true;
    }

    final eps = _animeDetails?.episodes ?? [];
    if (eps.any((e) => e.episodeNumber == nextNum)) {
      return true;
    }

    if (status == 'FINISHED' || status == 'COMPLETED') {
      if (total != null && total > 0) {
        return nextNum <= total;
      }
    }

    if (aniZip != null && aniZip.episodeCount > 0 && nextNum > aniZip.episodeCount) {
      return false;
    }

    return false;
  }

  bool get _hasPreviousEpisode => !_isMovie && (_currentEpisodeNumber ?? 1) > 1;

  String? get _effectiveCharacterImage =>
      _animeDetails?.mainCharacterImage ?? widget.initialAnimeDetails?.mainCharacterImage;

  String? get _effectiveCoverImage =>
      _animeDetails?.coverImage ?? widget.initialAnimeDetails?.coverImage;

  Future<void> _fetchAnimeDetails() async {
    if (widget.mediaId != null) {
      if (_animeDetails == null && _aniZipData == null) {
        setState(() => _isLoadingDetails = true);
      }
      try {
        final repo = ref.read(repositoryProvider);
        final results = await Future.wait([
          repo.getAnimeDetails(widget.mediaId!).catchError((_) => null),
          // TMDB media doesn't exist on AniZip (which is keyed by AniList ID),
          // so skip the request entirely to avoid a guaranteed 404.
          if (widget.isTmdbMedia)
            Future<AniZipData?>.value(null)
          else
            repo.getAniZipData(widget.mediaId!).catchError((_) => null),
        ]);
        if (mounted) {
          final details = results[0] as AnimeDetails?;
          final aniZip = (results[1] as AniZipData?) ?? details?.aniZipData ?? _aniZipData;
          setState(() {
            _animeDetails = details ?? _animeDetails;
            _aniZipData = aniZip;
            _isLoadingDetails = false;
          });

          // Auto-update active session with main character image once details load
          final currentSession = ref.read(lastSessionProvider);
          if (currentSession != null && currentSession.mediaId == widget.mediaId) {
            final mc = _effectiveCharacterImage;
            final cover = _effectiveCoverImage;
            if (mc != null || cover != null) {
              ref.read(lastSessionProvider.notifier).saveSession(
                currentSession.copyWith(
                  characterImage: mc ?? currentSession.characterImage,
                  coverImage: cover ?? currentSession.coverImage,
                ),
              );
            }
          }
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingDetails = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    _torrentStreamNotifier = ref.read(torrentStreamStatusProvider.notifier);
    _repository = ref.read(repositoryProvider);
    _isTorrentProgressVisible = ref.read(torrentProgressOverlayEnabledProvider);

    _currentVideoUrl = widget.videoUrl;
    _currentEpisodeTitle = widget.episodeTitle;
    _currentEpisodeNumber = widget.episodeNumber;
    _currentVideoSource = widget.videoSource;
    _currentHeaders = widget.headers;
    _currentMimeType = widget.mimeType;
    _currentExternalSubtitles = widget.externalSubtitles;
    _currentOnlineStreamProvider = widget.onlineStreamProvider;
    _currentOnlineStreamDubbed = widget.onlineStreamDubbed;
    _currentOnlineStreamServer = widget.onlineStreamServer;
    _isCurrentLocalFile = widget.isLocalFile;
    _initialStartPosition = widget.startPosition;

    _animeDetails = widget.initialAnimeDetails;
    _aniZipData = widget.initialAniZipData ?? widget.initialAnimeDetails?.aniZipData;

    _fetchAnimeDetails();
    if (widget.mediaId != null && _currentOnlineStreamProvider != null) {
      _fetchOnlineEpisodes();
    }

    final preferredEngine = ref.read(playerEngineProvider);
    final useExo = Platform.isAndroid && preferredEngine == PlayerEngine.exoplayer;

    _coordinator = PlayerPlaybackCoordinator(
      isUsingExoPlayer: useExo,
      shaderService: _shaderService,
      l10n: ref.read(translationsProvider),
      onPosition: (pos) {
        _position = pos;
        _positionNotifier.value = pos;
        final canSkip = _activeChapter != null && _activeChapter!.isSkippable(pos);
        if (canSkip != _canSkipCurrentChapter && mounted) {
          setState(() => _canSkipCurrentChapter = canSkip);
        }
        _progressManager.syncAnimeProgressIfNeeded();
        if (Platform.isLinux) {
          MprisService.instance.updatePlaybackState(
            isPlaying: _isPlaying,
            position: pos,
            duration: _duration,
          );
        }
      },
      onDuration: (dur) {
        if (_duration != dur && mounted) {
          setState(() => _duration = dur);
          _loadChapters();
          if (Platform.isLinux) {
            MprisService.instance.updateMetadata(
              title: _currentEpisodeTitle ?? widget.episodeTitle ?? widget.title,
              artist: widget.title,
              album: widget.title,
              artUrl: _effectiveCoverImage,
              duration: dur,
            );
          }
        }
      },
      onBuffer: (buf) {
        final effectiveBuf =
            _playbackOrigin == PlayerPlaybackOrigin.local ? Duration.zero : buf;
        _buffer = effectiveBuf;
        _bufferNotifier.value = effectiveBuf;
      },
      onPlaying: (playing) {
        if (mounted) setState(() => _isPlaying = playing);
        if (!playing) {
          _progressManager.savePlaybackProgress();
        }
        if (Platform.isLinux) {
          MprisService.instance.updatePlaybackState(
            isPlaying: playing,
            position: _position,
            duration: _duration,
          );
        }
      },
      onBuffering: (buffering) {
        if (mounted) setState(() => _isBuffering = buffering);
      },
      onEnded: () {
        if (mounted) setState(() => _isPlaying = false);
      },
      onTracks: (audio, subs, selectedAudio, selectedSub) {
        if (!mounted) return;
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = subs;
          _selectedAudioTrackId = selectedAudio;
          _selectedSubtitleTrackId = selectedSub;
        });
        _loadChapters();
      },
      onCues: (text) {
        if (mounted && _currentSubtitleText != text) {
          setState(() => _currentSubtitleText = text);
        }
      },
      onFallbackToMpv: (reason, fallbackPos) {
        if (!mounted) return;
        setState(() {
          _isBuffering = true;
          _fallbackNotice = ref.read(translationsProvider).switchingToMpvNotice;
        });
        _fallbackNoticeTimer?.cancel();
        _fallbackNoticeTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _fallbackNotice = null);
        });
        _initStatsService();
      },
      onChapters: (chs) {
        if (mounted && chs.isNotEmpty) {
          setState(() => _chapters = chs);
        }
      },
    );
    _coordinator.applySubtitleStyle(ref.read(subtitleStylePreferencesProvider));

    _windowManager = PlayerWindowManager(
      isTv: _isTvActive,
      ref: ref,
      coordinator: _coordinator,
    );
    final winInit = _windowManager.initWindow();

    final isOnline = !widget.isLocalFile &&
        (widget.onlineStreamProvider != null || _currentOnlineStreamProvider != null);

    Duration? getSavedProgress([int? epNumber]) {
      final ep = epNumber ?? _currentEpisodeNumber;
      if (widget.mediaId != null && ep != null) {
        final progress = ref.read(playbackProgressPreferencesProvider.notifier).getProgress(widget.mediaId!, ep);
        if (progress != null && progress.positionMs > 0) {
          final fraction = progress.durationMs > 0 ? progress.positionMs / progress.durationMs : 0.0;
          if (fraction < 0.95) {
            return Duration(milliseconds: progress.positionMs);
          }
        }
      }
      return null;
    }

    final resolvedStartPosition = widget.startPosition ?? getSavedProgress();

    ref.listenManual(subtitleStylePreferencesProvider, (_, next) {
      _coordinator.applySubtitleStyle(next);
      if (mounted) setState(() {});
    });

    _progressManager = PlayerProgressManager(
      repository: ref.read(repositoryProvider),
      lastSessionNotifier: ref.read(lastSessionProvider.notifier),
      playbackProgressNotifier: ref.read(playbackProgressPreferencesProvider.notifier),
      animePlaybackSourceNotifier: ref.read(animePlaybackSourceProvider.notifier),
      mediaId: widget.mediaId,
      title: widget.title,
      isTmdb: _animeDetails?.isTmdb ?? false,
      getCoverImage: () => _effectiveCoverImage,
      getCharacterImage: () => _effectiveCharacterImage,
      getEpisodeNumber: () => _currentEpisodeNumber,
      getEpisodeTitle: () => _currentEpisodeTitle,
      getVideoUrl: () => _currentVideoUrl,
      getHeaders: () => _currentHeaders,
      getMimeType: () => _currentMimeType,
      getVideoSource: () => _currentVideoSource,
      getOnlineStreamProvider: () => _currentOnlineStreamProvider,
      getOnlineStreamDubbed: () => _currentOnlineStreamDubbed,
      getOnlineStreamServer: () => _currentOnlineStreamServer,
      getIsLocalFile: () => _isCurrentLocalFile,
      getPosition: () => _position,
      getDuration: () => _duration,
      getIsPlaying: () => _isPlaying,
      getTotalEpisodes: () => _animeDetails?.totalEpisodes,
      getBannerImage: () => _animeDetails?.bannerImage,
      getCoverColor: () => _animeDetails?.coverColor,
      getGenres: () => _animeDetails?.genres,
      getScore: () => _animeDetails?.score,
      getDescription: () => _animeDetails?.description,
      getYear: () => _animeDetails?.seasonYear,
      getFormat: () => _animeDetails?.format,
      getEpisodeThumbnail: () {
        final ep = _aniZipData?.getEpisode(_currentEpisodeNumber ?? 1);
        return ep?.image ?? _effectiveCoverImage;
      },
      onLocalWatchRecorded: () {
        if (mounted && !_isPlayerDisposed) {
          try {
            ref.invalidate(animeCollectionProvider);
            ref.invalidate(continueWatchingProvider);
            ref.invalidate(recommendationsProvider);
          } catch (_) {}
        }
      },
      onProgressSynced: () {
        if (mounted && !_isPlayerDisposed) {
          try {
            ref.invalidate(animeCollectionProvider);
            ref.invalidate(continueWatchingProvider);
            ref.invalidate(recommendationsProvider);
          } catch (_) {}
        }
      },
    );

    _sourceController = PlayerSourceController(
      repository: ref.read(repositoryProvider),
      serverManager: ref.read(serverManagerProvider),
      coordinator: _coordinator,
      mediaId: widget.mediaId,
      title: widget.title,
      getL10n: () => ref.read(translationsProvider),
      getAnimeDetails: () => _animeDetails,
      getAniZipData: () => _aniZipData ?? _animeDetails?.aniZipData,
      getEpisodeNumber: () => _currentEpisodeNumber,
      getEpisodeTitle: () => _currentEpisodeTitle,
      getOnlineStreamProvider: () => _currentOnlineStreamProvider,
      getOnlineStreamDubbed: () => _currentOnlineStreamDubbed,
      getOnlineStreamServer: () => _currentOnlineStreamServer,
      getIsLocalFile: () => _isCurrentLocalFile,
      getVideoUrl: () => _currentVideoUrl,
      getPosition: () => _position,
      getStartPosition: () {
        final pos = _initialStartPosition;
        _initialStartPosition = null;
        return pos ?? getSavedProgress();
      },
      getSavedProgress: (epNum) => getSavedProgress(epNum),
      getHasNextEpisode: () => _hasNextEpisode,
      onUpdateUi: () {
        if (mounted && !_isPlayerDisposed) setState(() {});
      },
      onSourceActivated: _onSourceActivated,
      onShowEpisodePicker: () {
        if (mounted && widget.mediaId != null) {
          AnimeDetailsModalSheet.show(
            context: context,
            mediaId: widget.mediaId!,
            animeDetails: _animeDetails,
          );
        }
      },
      getIsTmdb: () => widget.isTmdbMedia,
      getTmdbMediaType: () => widget.tmdbMediaType,
      getTmdbSeason: () => widget.tmdbSeason,
      getTmdbEnglishTitle: () => widget.tmdbEnglishTitle,
      getTmdbYear: () => widget.tmdbYear,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPlayerDisposed) return;
      _focusNode.requestFocus();

      _coordinator.init(
        videoUrl: _currentVideoUrl,
        title: widget.title,
        episodeTitle: _currentEpisodeTitle,
        headers: _currentHeaders,
        mimeType: _currentMimeType,
        startPosition: resolvedStartPosition,
        externalSubtitles: _currentExternalSubtitles,
        fitMode: _fitMode,
        activeShaderPreset: _activeShaderPreset,
        isOnlineStream: isOnline,
        initialSurfaceTop: winInit.initialTop,
        initialSurfaceHeight: winInit.initialHeight,
      );
      _initialStartPosition = null;

      _progressManager.startTracking(initialPosition: resolvedStartPosition);
      if (widget.mediaId != null) {
        final isLocal = _isCurrentLocalFile || _currentVideoUrl.contains('/api/v1/mediastream');
        final isTorrent = _currentVideoUrl.contains('torrentstream') ||
            (_currentVideoSource?.toLowerCase().contains('torrent') ?? false);
        final sourceType = isLocal ? 'local' : (isTorrent ? 'torrent' : 'online');
        ref.read(animePlaybackSourceProvider.notifier).saveSource(
          mediaId: widget.mediaId!,
          sourceType: sourceType,
          onlineStreamProvider: _currentOnlineStreamProvider,
          onlineStreamDubbed: _currentOnlineStreamDubbed,
          onlineStreamServer: _currentOnlineStreamServer,
          videoSource: _currentVideoSource,
          videoUrl: _currentVideoUrl,
          headers: _currentHeaders,
          mimeType: _currentMimeType,
          episodeNumber: _currentEpisodeNumber,
        );
      }
      _initStatsService();
      _startHideTimer();
      _initBrightness();
      _sourceController.schedulePrefetchNextEpisode();

      if (_currentVideoUrl.isEmpty && _currentOnlineStreamProvider != null) {
        _sourceController.resolveInitialSources();
      } else if (_currentOnlineStreamProvider != null) {
        _sourceController.fetchAvailableSourcesInBackground(currentVideoUrl: _currentVideoUrl);
      }

      if (Platform.isLinux) {
        MprisService.instance.onPlay = () => _coordinator.play();
        MprisService.instance.onPause = () => _coordinator.pause();
        MprisService.instance.onPlayPause = () => _playOrPause();
        MprisService.instance.onStop = () => _handleExit();
        MprisService.instance.onSeek = (offset) => _seekTo(_position + offset);
        MprisService.instance.onSetPosition = (pos) => _seekTo(pos);
        MprisService.instance.onNext = () {
          if (_hasNextEpisode && !_isLoadingNextEpisode) {
            _sourceController.playEpisode(
              targetEpNum: (_currentEpisodeNumber ?? 1) + 1,
              onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
            );
          }
        };
        MprisService.instance.onPrevious = () {
          if (_hasPreviousEpisode && !_isLoadingNextEpisode) {
            _sourceController.playEpisode(
              targetEpNum: (_currentEpisodeNumber ?? 1) - 1,
              onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
            );
          }
        };
        MprisService.instance.updateMetadata(
          title: _currentEpisodeTitle ?? widget.episodeTitle ?? widget.title,
          artist: widget.title,
          album: widget.title,
          artUrl: _effectiveCoverImage,
          duration: _duration,
        );
        MprisService.instance.updatePlaybackState(
          isPlaying: _isPlaying,
          position: _position,
          duration: _duration,
        );
      }
    });
  }

  static const _nativeChannel = MethodChannel('com.anyyting.aniting/exo_player');

  Future<void> _initBrightness() async {
    if (!Platform.isAndroid) return;
    try {
      final current = await _nativeChannel.invokeMethod<double>('getBrightness');
      if (current != null && mounted) {
        setState(() => _brightness = current.clamp(0.0, 1.0));
      }
    } catch (_) {}
  }

  void _setBrightness(double value) {
    setState(() => _brightness = value);
    if (!Platform.isAndroid) return;
    try {
      _nativeChannel.invokeMethod('setBrightness', {'brightness': value});
    } catch (_) {}
  }

  Future<void> _loadChapters() async {
    final chs = await _coordinator.getChapters();
    if (mounted && chs.isNotEmpty) {
      setState(() => _chapters = chs);
    }
  }

  void _initStatsService() {
    _statsSub?.cancel();
    _statsService?.dispose();

    _statsService = PerformanceStatsService(
      mpvService: _coordinator.mpvService,
      isUsingExoPlayer: _coordinator.isUsingExoPlayer,
      buffer: _buffer,
    );

    _statsSub = _statsService!.statsStream.listen((stats) {
      if (mounted) _performanceStatsNotifier.value = stats;
    });

    if (_isStatsVisible) {
      _statsService!.startPolling();
    }
  }

  void _onSourceActivated({
    required String videoUrl,
    required int episodeNumber,
    required String episodeTitle,
    Map<String, String>? headers,
    String? mimeType,
    String? videoSource,
    List<dynamic>? externalSubtitles,
    String? onlineStreamServer,
  }) {
    if (!mounted) return;
    setState(() {
      _currentVideoUrl = videoUrl;
      _currentEpisodeNumber = episodeNumber;
      _currentEpisodeTitle = episodeTitle;
      _currentHeaders = headers;
      _currentMimeType = mimeType;
      _currentVideoSource = videoSource;
      _currentExternalSubtitles = externalSubtitles;
      if (onlineStreamServer != null) {
        _currentOnlineStreamServer = onlineStreamServer;
      }
      _position = Duration.zero;
      _duration = Duration.zero;
      _buffer = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _bufferNotifier.value = Duration.zero;
      _chapters = [];
      _canSkipCurrentChapter = false;
      _selectedAudioTrackId = null;
      _selectedSubtitleTrackId = null;
      _seekFeedback = null;
    });

    _seekFeedbackTimer?.cancel();
    _progressManager.resetEpisodeLatch();
    _progressManager.savePlaybackProgress();
  }

  void _onEpisodeTransitionStarted(int targetEpNum, String targetEpTitle) {
    _initialStartPosition = null;
    _progressManager.savePlaybackProgress();
    _progressManager.syncAnimeProgressIfNeeded();
    setState(() {
      _currentEpisodeNumber = targetEpNum;
      _currentEpisodeTitle = targetEpTitle;
      _currentVideoUrl = '';
      _position = Duration.zero;
      _duration = Duration.zero;
      _buffer = Duration.zero;
      _positionNotifier.value = Duration.zero;
      _bufferNotifier.value = Duration.zero;
      _chapters = [];
      _canSkipCurrentChapter = false;
      _seekFeedback = null;
    });
    _seekFeedbackTimer?.cancel();
    if (Platform.isLinux) {
      MprisService.instance.updateMetadata(
        title: targetEpTitle.isNotEmpty ? targetEpTitle : widget.title,
        artist: widget.title,
        album: widget.title,
        artUrl: _effectiveCoverImage,
        duration: Duration.zero,
      );
      MprisService.instance.updatePlaybackState(
        isPlaying: false,
        position: Duration.zero,
        duration: Duration.zero,
      );
    }
  }

  void _switchOnlineStreamProvider(String newProviderId) {
    if (_currentOnlineStreamProvider == newProviderId) return;
    setState(() {
      _currentOnlineStreamProvider = newProviderId;
      _currentVideoUrl = '';
      _currentVideoSource = newProviderId;
      _onlineEpisodes = null;
    });
    _fetchOnlineEpisodes();
    _sourceController.resolveInitialSources(preservePosition: true);
  }

  void _toggleOnlineStreamDubbed() {
    setState(() {
      _currentOnlineStreamDubbed = !(_currentOnlineStreamDubbed ?? false);
      _onlineEpisodes = null;
    });
    _fetchOnlineEpisodes();
    _sourceController.resolveInitialSources(preservePosition: true);
  }

  @override
  void dispose() {
    _isPlayerDisposed = true;
    _sourceController.dispose();
    _progressManager.dispose();

    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fallbackNoticeTimer?.cancel();

    _statsSub?.cancel();
    _statsService?.dispose();

    _coordinator.dispose();

    final isTorrent = _currentVideoUrl.contains('torrentstream') ||
        widget.videoUrl.contains('torrentstream') ||
        _hasActiveTorrentStream;
    if (isTorrent && _pauseTorrentStreamOnExit) {
      _repository.pauseTorrentStream();
    }

    try {
      _torrentStreamNotifier.reset();
    } catch (_) {}

    _windowManager.dispose(onCustomDispose: widget.onDispose);

    if (Platform.isLinux) {
      MprisService.instance.reset();
    }

    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    await _windowManager.handleExit(
      context: context,
      onSaveProgress: () async {
        _progressManager.savePlaybackProgress();
        // Schedule cache refresh in microtask after pop animation has unmounted
        Future.microtask(() {
          try {
            ref.invalidate(continueWatchingProvider);
          } catch (_) {}
        });
      },
      onUpdateUi: () {
        if (mounted) setState(() {});
      },
    );
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isInteractingWithVolume) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isInteractingWithVolume) {
        setState(() => _areControlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_isTransitioningOrientation) return;
    setState(() => _areControlsVisible = !_areControlsVisible);
    if (_areControlsVisible) {
      _startHideTimer();
    }
  }

  void _onMouseEnter() {
    if (!mounted) return;
    _isMouseInside = true;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startHideTimer();
  }

  void _onMouseMove() {
    if (!mounted) return;
    if (!_isMouseInside) return;
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startHideTimer();
  }

  void _onMouseExit() {
    if (!mounted) return;
    _isMouseInside = false;
    _isInteractingWithVolume = false;
    _hideTimer?.cancel();
    if (_areControlsVisible) {
      setState(() => _areControlsVisible = false);
    }
  }

  void _adjustVolume(double delta) {
    final maxVal = ref.read(volumeBoostProvider) ? 200.0 : 100.0;
    final newVol = (_volume + delta).clamp(0.0, maxVal);
    _setVolume(newVol);
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startHideTimer();
  }

  void _toggleMute() {
    if (_volume > 0) {
      _lastNonZeroVolume = _volume;
      _setVolume(0.0);
    } else {
      _setVolume(_lastNonZeroVolume > 0 ? _lastNonZeroVolume : 100.0);
    }
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startHideTimer();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final handler = PlayerKeyboardHandler(
      onPlayPause: _playOrPause,
      onToggleFullscreen: _toggleFullscreen,
      onExit: _handleExit,
      onSeekRelative: (seconds) {
        _seekRelative(seconds);
        if (!_areControlsVisible) {
          setState(() => _areControlsVisible = true);
        }
        _startHideTimer();
      },
      onAdjustVolume: _adjustVolume,
      onToggleMute: _toggleMute,
      onSkipChapter: () {
        if (_activeChapter?.end != null) {
          _seekTo(_activeChapter!.end!);
        }
      },
      onSeekPercentage: (fraction) => _seekTo(_duration * fraction),
      isFullscreen: _isFullscreen,
      duration: _duration,
      canSkipChapter: _canSkipCurrentChapter && _activeChapter?.end != null,
    );

    return handler.handleKeyEvent(node, event);
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > _duration && _duration > Duration.zero ? _duration : target);

    _position = clamped;
    _positionNotifier.value = clamped;
    _coordinator.seek(clamped);

    setState(() {
      _seekFeedback = seconds > 0 ? '+$seconds s' : '$seconds s';
      _seekFeedbackKey++;
    });
    _seekFeedbackTimer?.cancel();
    _seekFeedbackTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _seekFeedback = null);
    });
    _startHideTimer();
  }

  void _seekTo(Duration target) {
    _position = target;
    _positionNotifier.value = target;
    _coordinator.seek(target);
    _startHideTimer();
  }

  void _playOrPause() {
    if (_isPlaying) {
      _coordinator.pause();
    } else {
      _coordinator.play();
    }
    _startHideTimer();
  }

  void _setVolume(double newVolume) {
    setState(() => _volume = newVolume);
    _coordinator.setVolume(newVolume);
    _startHideTimer();
  }

  void _setPlaybackRate(double rate) {
    setState(() => _playbackRate = rate);
    _coordinator.setRate(rate);
  }

  void _selectAudioTrack(UiTrack track) {
    setState(() {
      _selectedAudioTrackId = track.id;
      _audioTracks = _audioTracks.map((t) => t.copyWith(selected: t.id == track.id)).toList();
    });
    _coordinator.selectAudioTrack(track);
  }

  void _selectSubtitleTrack(UiTrack? track) {
    setState(() {
      _selectedSubtitleTrackId = track?.id;
      _currentSubtitleText = '';
      _subtitleTracks = _subtitleTracks.map((t) => t.copyWith(selected: t.id == track?.id)).toList();
    });
    _coordinator.selectSubtitleTrack(track, _currentExternalSubtitles);
  }

  void _setSubtitleDelay(int ms) {
    setState(() => _subtitleDelayMs = ms);
    _coordinator.setSubtitleDelay(ms);
  }

  void _setAudioDelay(int ms) {
    setState(() => _audioDelayMs = ms);
    _coordinator.setAudioDelay(ms);
  }

  void _setShaderPreset(ShaderPreset preset) {
    setState(() => _activeShaderPreset = preset);
    _coordinator.setShaderPreset(preset);
  }

  void _setFitMode(PlayerFitMode mode) {
    setState(() => _fitMode = mode);
    _coordinator.setFitMode(mode);
  }

  void _toggleStatsVisibility(bool visible) {
    setState(() => _isStatsVisible = visible);
    if (visible) {
      _statsService?.startPolling();
    } else {
      _statsService?.stopPolling();
    }
  }

  void _toggleTorrentProgressVisibility(bool visible) {
    setState(() => _isTorrentProgressVisible = visible);
    ref.read(torrentProgressOverlayEnabledProvider.notifier).setEnabled(visible);
  }

  void _toggleFullscreen() {
    _windowManager.toggleFullscreen(
      onUpdateUi: () {
        if (mounted) setState(() {});
      },
      onOrientationTransitionStarted: () {
        _areControlsVisible = false;
      },
    );
  }

  String? _getVideoSourceLabel() {
    if (_currentVideoSource != null && _currentVideoSource!.isNotEmpty) {
      return _currentVideoSource;
    }
    if (widget.videoSource != null && widget.videoSource!.isNotEmpty) {
      return widget.videoSource;
    }
    if (_currentVideoUrl.startsWith('http://') || _currentVideoUrl.startsWith('https://')) {
      try {
        final uri = Uri.parse(_currentVideoUrl);
        return uri.host;
      } catch (_) {}
    }
    if (_currentVideoUrl.startsWith('/')) {
      return _currentVideoUrl.split('/').last;
    }
    return null;
  }

  void _openSettingsModal() {
    _hideTimer?.cancel();
    if (_areControlsVisible) {
      setState(() => _areControlsVisible = false);
    }

    final isFullscreen = _isFullscreen || _isTvActive;

    PlayerSettingsLauncher.show(
      context: context,
      isFullscreen: isFullscreen,
      isSidePanelCollapsed: _isSidePanelCollapsed,
      chapters: _chapters,
      currentPosition: _position,
      onChapterSelected: (chapter) => _seekTo(chapter.start),
      audioTracks: _audioTracks,
      subtitleTracks: _subtitleTracks,
      selectedAudioTrackId: _selectedAudioTrackId,
      selectedSubtitleTrackId: _selectedSubtitleTrackId,
      onAudioTrackSelected: _selectAudioTrack,
      onSubtitleTrackSelected: _selectSubtitleTrack,
      subtitleDelayMs: _subtitleDelayMs,
      onSubtitleDelayChanged: _setSubtitleDelay,
      audioDelayMs: _audioDelayMs,
      onAudioDelayChanged: _setAudioDelay,
      playbackRate: _playbackRate,
      onPlaybackRateChanged: _setPlaybackRate,
      activeShaderPreset: _activeShaderPreset,
      onShaderPresetSelected: _setShaderPreset,
      isStatsVisible: _isStatsVisible,
      onStatsVisibilityChanged: _toggleStatsVisibility,
      isTorrentProgressVisible: _isTorrentProgressVisible,
      onTorrentProgressVisibilityChanged: _toggleTorrentProgressVisibility,
      fitMode: _fitMode,
      onFitModeChanged: _setFitMode,
      isUsingExoPlayer: _coordinator.isUsingExoPlayer,
      gesturesEnabled: ref.read(playerGesturesProvider),
      onGesturesChanged: (enabled) {
        ref.read(playerGesturesProvider.notifier).setEnabled(enabled);
      },
      videoSource: _getVideoSourceLabel(),
      videoUrl: widget.videoUrl,
      volumeBoostEnabled: ref.read(volumeBoostProvider),
      onVolumeBoostChanged: (enabled) {
        ref.read(volumeBoostProvider.notifier).setEnabled(enabled);
      },
    ).whenComplete(() {
      if (mounted) {
        setState(() => _areControlsVisible = true);
        _startHideTimer();
        _focusNode.requestFocus();
      }
    });
  }

  Widget _buildPlayerViewport(
    BuildContext context, {
    required bool isFullscreen,
    required bool isDesktop,
  }) {
    return PlayerViewport(
      isUsingExoPlayer: _coordinator.isUsingExoPlayer,
      mpvPlayerService: _coordinator.mpvService,
      fitMode: _fitMode,
      selectedSubtitleTrackId: _selectedSubtitleTrackId,
      currentSubtitleText: _currentSubtitleText,
      areControlsVisible: _areControlsVisible,
      isTransitioningOrientation: _isTransitioningOrientation,
      isExiting: _isExiting,
      onToggleControls: _toggleControls,
      onPlayOrPause: _playOrPause,
      onSeekRelative: _seekRelative,
      onSeekTo: _seekTo,
      onToggleFullscreen: _toggleFullscreen,
      isFullscreen: isFullscreen,
      isDesktop: isDesktop,
      volume: _volume,
      onVolumeChanged: _setVolume,
      onVolumeHoverChanged: (active) {
        _isInteractingWithVolume = active;
        if (active) {
          _hideTimer?.cancel();
          if (!_areControlsVisible) {
            setState(() => _areControlsVisible = true);
          }
        } else {
          if (_isMouseInside) {
            _startHideTimer();
          } else {
            if (_areControlsVisible) {
              setState(() => _areControlsVisible = false);
            }
          }
        }
      },
      brightness: _brightness,
      onBrightnessChanged: _setBrightness,
      isBuffering: _isBuffering,
      isLoadingNextEpisode: _isLoadingNextEpisode || _isResolvingSources,
      seekFeedback: _seekFeedback,
      seekFeedbackKey: _seekFeedbackKey,
      fallbackNotice: _fallbackNotice,
      isStatsVisible: _isStatsVisible,
      performanceStatsNotifier: _performanceStatsNotifier,
      onCloseStats: () => _toggleStatsVisibility(false),
      canSkipCurrentChapter: _canSkipCurrentChapter,
      activeChapter: _activeChapter,
      onSkipChapter: () {
        if (_activeChapter?.end != null) {
          _seekTo(_activeChapter!.end!);
        }
      },
      chapters: _chapters,
      title: widget.title,
      episodeTitle: _currentEpisodeTitle,
      videoSource: _currentVideoSource ?? _getVideoSourceLabel(),
      videoUrl: _currentVideoUrl,
      onBack: _handleExit,
      onOpenSettings: _openSettingsModal,
      onToggleSidePanel: (isDesktop && !isFullscreen)
          ? () => setState(() => _isSidePanelCollapsed = !_isSidePanelCollapsed)
          : null,
      isSidePanelCollapsed: _isSidePanelCollapsed,
      positionNotifier: _positionNotifier,
      bufferNotifier: _bufferNotifier,
      duration: _duration,
      isPlaying: _isPlaying,
      hasNextEpisode: _hasNextEpisode && !_isLoadingNextEpisode,
      onNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
          ? () => _sourceController.playEpisode(
              targetEpNum: (_currentEpisodeNumber ?? 1) + 1,
              onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isFullscreen = _isFullscreen || _isTvActive;

    // Keep dispose() safe: cache the values it needs while the widget is alive.
    _hasActiveTorrentStream = ref.watch(torrentStreamStatusProvider) != null;
    _pauseTorrentStreamOnExit =
        ref.watch(streamingPreferencesProvider).pauseTorrentStreamOnExit;

    final mq = MediaQuery.of(context);
    final isPhysicalLandscape = mq.orientation == Orientation.landscape;

    // Mobile orientation stabilization:
    // When returning from fullscreen to screen corta (embedded portrait), ignore intermediate landscape
    // frames where device rotation is still animating. Rendering fullscreen player viewport until
    // physical portrait orientation actually arrives prevents the 16:9 AspectRatio Column from
    // overflowing the landscape display bounds and violently disrupting controls layout.
    final bool effectiveFullscreen = isFullscreen || (!isDesktop && isPhysicalLandscape);

    // Keep Android ExoPlayer surface layout perfectly synchronized with Flutter's container
    if (Platform.isAndroid && _coordinator.isUsingExoPlayer) {
      _windowManager.updateExoSurfaceBounds(context, effectiveFullscreen: effectiveFullscreen);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _windowManager.updateExoSurfaceBounds(context, effectiveFullscreen: effectiveFullscreen);
        }
      });
    }

    final isNativePlayerActive =
        _coordinator.isUsingExoPlayer || _coordinator.mpvService != null;
    final scaffoldBg = isNativePlayerActive
        ? Colors.transparent
        : (effectiveFullscreen ? Colors.black : theme.scaffoldBackgroundColor);

    final isThemeDark = theme.brightness == Brightness.dark;
    final statusBarIconBrightness = (effectiveFullscreen || isThemeDark)
        ? Brightness.light
        : Brightness.dark;
    final statusBarBrightness = (effectiveFullscreen || isThemeDark)
        ? Brightness.dark
        : Brightness.light;

    final systemOverlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: statusBarIconBrightness,
      statusBarBrightness: statusBarBrightness,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: statusBarIconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleExit();
        },
        child: Scaffold(
          backgroundColor: _isExiting ? Colors.black : scaffoldBg,
          body: _isExiting
              ? const ColoredBox(color: Colors.black, child: SizedBox.expand())
            : Focus(
                focusNode: _focusNode,
                autofocus: true,
                onKeyEvent: _handleKeyEvent,
                child: MouseRegion(
                  cursor: (!isDesktop || _areControlsVisible || !_isMouseInside)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.none,
                  onEnter: isDesktop ? (_) => _onMouseEnter() : null,
                  onHover: isDesktop ? (_) => _onMouseMove() : null,
                  onExit: isDesktop ? (_) => _onMouseExit() : null,
                  child: isDesktop
                      ? PlayerDesktopLayout(
                          playerViewport: _buildPlayerViewport(
                            context,
                            isFullscreen: effectiveFullscreen,
                            isDesktop: true,
                          ),
                          sidePanel: PlayerInfoPanel(
                            mediaId: widget.mediaId,
                            animeTitle: widget.title,
                            episodeNumber: _currentEpisodeNumber,
                            episodeTitle: _currentEpisodeTitle,
                            animeDetails: _animeDetails,
                            aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
                            isLoading: _isLoadingDetails,
                            isDesktop: true,
                            onCollapse: () => setState(() => _isSidePanelCollapsed = true),
                            chapters: _chapters,
                            activeChapter: _activeChapter,
                            onSeekToChapter: _seekTo,
                            hasNextEpisode: _hasNextEpisode,
                            onPlayNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
                                ? () => _sourceController.playEpisode(
                                    targetEpNum: (_currentEpisodeNumber ?? 1) + 1,
                                    onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
                                  )
                                : null,
                            onPlayPreviousEpisode: (_hasPreviousEpisode && !_isLoadingNextEpisode)
                                ? () => _sourceController.playEpisode(
                                    targetEpNum: (_currentEpisodeNumber ?? 1) - 1,
                                    onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
                                  )
                                : null,
                            sourceController: _sourceController,
                            playbackOrigin: _playbackOrigin,
                            isResolvingSources: _isResolvingSources,
                            availableSources: _availableSources,
                            activeSource: _activeSource,
                            sourceResolutionError: _sourceResolutionError,
                            onlineStreamProvider: _currentOnlineStreamProvider,
                            isDubbed: _currentOnlineStreamDubbed ?? false,
                            onToggleDubbed: _toggleOnlineStreamDubbed,
                            onReloadSources: () => _sourceController.resolveInitialSources(preservePosition: true),
                            onSelectSource: _sourceController.selectSource,
                            onSelectProvider: _switchOnlineStreamProvider,
                          ),
                          isSidePanelCollapsed: effectiveFullscreen || _isSidePanelCollapsed,
                        )
                      : (effectiveFullscreen
                          ? _buildPlayerViewport(
                              context,
                              isFullscreen: true,
                              isDesktop: false,
                            )
                          : PlayerMobileLayout(
                              playerViewport: _buildPlayerViewport(
                                context,
                                isFullscreen: false,
                                isDesktop: false,
                              ),
                              infoPanel: PlayerInfoPanel(
                                mediaId: widget.mediaId,
                                animeTitle: widget.title,
                                episodeNumber: _currentEpisodeNumber,
                                episodeTitle: _currentEpisodeTitle,
                                animeDetails: _animeDetails,
                                aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
                                isLoading: _isLoadingDetails,
                                isDesktop: false,
                                chapters: _chapters,
                                activeChapter: _activeChapter,
                                onSeekToChapter: _seekTo,
                                hasNextEpisode: _hasNextEpisode,
                                onPlayNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
                                    ? () => _sourceController.playEpisode(
                                        targetEpNum: (_currentEpisodeNumber ?? 1) + 1,
                                        onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
                                      )
                                    : null,
                                onPlayPreviousEpisode: (_hasPreviousEpisode && !_isLoadingNextEpisode)
                                    ? () => _sourceController.playEpisode(
                                        targetEpNum: (_currentEpisodeNumber ?? 1) - 1,
                                        onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
                                      )
                                    : null,
                                sourceController: _sourceController,
                                playbackOrigin: _playbackOrigin,
                                isResolvingSources: _isResolvingSources,
                                availableSources: _availableSources,
                                activeSource: _activeSource,
                                sourceResolutionError: _sourceResolutionError,
                                onlineStreamProvider: _currentOnlineStreamProvider,
                                isDubbed: _currentOnlineStreamDubbed ?? false,
                                onToggleDubbed: _toggleOnlineStreamDubbed,
                                onReloadSources: () => _sourceController.resolveInitialSources(preservePosition: true),
                                onSelectSource: _sourceController.selectSource,
                                onSelectProvider: _switchOnlineStreamProvider,
                              ),
                            )),
                ),
              ),
            ),
      ),
    );
  }
}
