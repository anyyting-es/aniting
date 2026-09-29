import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/player_engine_provider.dart';
import 'package:seanime_app/core/preferences/player_gesture_provider.dart';
import 'package:seanime_app/core/preferences/resume_bar_preferences_provider.dart';
import 'package:seanime_app/core/preferences/tv_mode_provider.dart';
import 'package:seanime_app/core/preferences/volume_boost_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart' show OnlinestreamSubtitle;
import 'package:seanime_app/data/repositories/seanime_repository.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/torrent_stream_provider.dart';
import 'package:seanime_app/presentation/widgets/anime_details_modal_sheet.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';
import 'package:seanime_app/presentation/widgets/player/controls/player_keyboard_handler.dart';
import 'package:seanime_app/presentation/widgets/player/layouts/player_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/player/layouts/player_mobile_layout.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:seanime_app/presentation/widgets/player/services/performance_stats_service.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_episode_resolver.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_playback_coordinator.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_shader_service.dart';
import 'package:seanime_app/presentation/widgets/player/sheets/player_settings_launcher.dart';
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

  const VideoPlayerScreen({
    super.key,
    this.mediaId,
    required this.videoUrl,
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
  });

  static Route<void> route({
    int? mediaId,
    required String videoUrl,
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
      ),
    );
  }

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late final PlayerPlaybackCoordinator _coordinator;

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
  bool _isFullscreen = false;
  bool _isTransitioningOrientation = false;
  final FocusNode _focusNode = FocusNode();

  // YouTube-style watch page & TV mode state
  bool _isSidePanelCollapsed = false;
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

  // Cached notifiers to safely reference in dispose without touching ref
  late final SeanimeRepository _repository;
  late final LastSessionNotifier _lastSessionNotifier;
  late final TorrentStreamStatusNotifier _torrentStreamNotifier;

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

  // Track if screen is exiting cleanly
  bool _isExiting = false;

  // Mutable episode and source state for seamless in-player episode switching
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
  bool _isLoadingNextEpisode = false;
  Timer? _prefetchTimer;
  Timer? _continuityTimer;

  // AniList progress sync latch — prevents duplicate sync calls during a single episode
  bool _hasUpdatedAnimeProgress = false;

  int? _lastExoTop;
  int? _lastExoHeight;

  bool get _isMovie =>
      _animeDetails?.format?.toUpperCase() == 'MOVIE' ||
      (_animeDetails?.totalEpisodes == 1 && (_animeDetails?.episodes.length ?? 0) <= 1);

  bool get _hasNextEpisode {
    if (_isMovie) return false;
    final cur = _currentEpisodeNumber;
    if (cur == null || cur < 1) return false;
    final nextNum = cur + 1;

    final total = _animeDetails?.totalEpisodes;
    if (total != null && total > 0) return nextNum <= total;

    final eps = _animeDetails?.episodes ?? [];
    if (eps.any((e) => e.episodeNumber == nextNum)) return true;

    final aniZip = _aniZipData ?? _animeDetails?.aniZipData;
    if (aniZip?.getEpisode(nextNum) != null) return true;

    return total == null || nextNum <= total;
  }

  bool get _hasPreviousEpisode => !_isMovie && (_currentEpisodeNumber ?? 1) > 1;

  String? get _effectiveCharacterImage =>
      _animeDetails?.mainCharacterImage ?? widget.initialAnimeDetails?.mainCharacterImage;

  String? get _effectiveCoverImage =>
      _animeDetails?.coverImage ?? widget.initialAnimeDetails?.coverImage;

  void _savePlaybackProgress() {
    if (widget.mediaId != null) {
      final pos = _position.inSeconds.toDouble();
      final dur = _duration.inSeconds.toDouble();
      _repository.updateContinuityItem(
        mediaId: widget.mediaId!,
        episodeNumber: _currentEpisodeNumber ?? 1,
        currentTime: pos,
        duration: dur,
      );

      final sessionItem = LastSessionItem(
        mediaType: 'ANIME',
        mediaId: widget.mediaId!,
        title: widget.title,
        coverImage: _effectiveCoverImage,
        characterImage: _effectiveCharacterImage,
        episodeNumber: _currentEpisodeNumber,
        episodeTitle: _currentEpisodeTitle,
        videoUrl: _currentVideoUrl,
        headers: _currentHeaders,
        mimeType: _currentMimeType,
        videoSource: _currentVideoSource,
        positionMs: _position.inMilliseconds,
        durationMs: _duration.inMilliseconds,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      Future.microtask(() {
        _lastSessionNotifier.saveSession(sessionItem);
      });
    }
  }

  /// Checks whether the playback position has reached the threshold to sync
  /// the episode as watched on AniList (~80% of duration OR within 2 min of the end).
  /// Mirrors the manga reader's chapter completion sync pipeline.
  void _syncAnimeProgressIfNeeded() {
    if (_hasUpdatedAnimeProgress) return;
    if (widget.mediaId == null) return;
    final epNum = _currentEpisodeNumber;
    if (epNum == null || epNum < 1) return;

    final durSec = _duration.inSeconds;
    final posSec = _position.inSeconds;
    if (durSec <= 0 || posSec <= 0) return;

    // Threshold: 80% watched OR within 120 seconds of the end (with at least 2 min watched)
    final fraction = posSec / durSec;
    final remaining = durSec - posSec;
    final isNearEnd = fraction >= 0.80 || (posSec >= 120 && remaining <= 120);

    if (!isNearEnd) return;

    _hasUpdatedAnimeProgress = true;

    // Fire-and-forget AniList sync
    _repository.updateAnimeProgress(
      mediaId: widget.mediaId!,
      episodeNumber: epNum,
      totalEpisodes: _animeDetails?.totalEpisodes,
    ).then((_) {
      // Invalidate providers to refresh feeds, collection, and continue watching
      if (mounted) {
        ref.invalidate(animeCollectionProvider);
        ref.invalidate(continueWatchingProvider);
      }
    });
  }

  Future<void> _fetchAnimeDetails() async {
    if (widget.mediaId != null) {
      if (_animeDetails == null && _aniZipData == null) {
        setState(() => _isLoadingDetails = true);
      }
      try {
        final repo = ref.read(repositoryProvider);
        final results = await Future.wait([
          repo.getAnimeDetails(widget.mediaId!).catchError((_) => null),
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

          // Auto-update active session with main character (MC) image once details load
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

    _repository = ref.read(repositoryProvider);
    _lastSessionNotifier = ref.read(lastSessionProvider.notifier);
    _torrentStreamNotifier = ref.read(torrentStreamStatusProvider.notifier);

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

    _animeDetails = widget.initialAnimeDetails;
    _aniZipData = widget.initialAniZipData ?? widget.initialAnimeDetails?.aniZipData;

    _fetchAnimeDetails();

    // Record initial watch event immediately so anime is marked as recently watched
    if (widget.mediaId != null) {
      ref.read(repositoryProvider).updateContinuityItem(
        mediaId: widget.mediaId!,
        episodeNumber: _currentEpisodeNumber ?? 1,
        currentTime: (widget.startPosition?.inSeconds ?? 0).toDouble(),
        duration: 0.0,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(lastSessionProvider.notifier).saveSession(
          LastSessionItem(
            mediaType: 'ANIME',
            mediaId: widget.mediaId!,
            title: widget.title,
            coverImage: _effectiveCoverImage,
            characterImage: _effectiveCharacterImage,
            episodeNumber: _currentEpisodeNumber,
            episodeTitle: _currentEpisodeTitle,
            videoUrl: _currentVideoUrl,
            headers: _currentHeaders,
            mimeType: _currentMimeType,
            videoSource: _currentVideoSource,
            positionMs: widget.startPosition?.inMilliseconds ?? 0,
            durationMs: 0,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      });
      _continuityTimer = Timer.periodic(const Duration(seconds: 20), (_) {
        if (_isPlaying) {
          _savePlaybackProgress();
        }
      });
    }

    // Determine initial orientation and fullscreen mode based on TV mode
    final isTv = _isTvActive;
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    if (isDesktop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(desktopTitleBarBrightnessOverrideProvider.notifier).setBrightness(Brightness.dark);
      });
    }
    int initialTop = 0;
    int initialHeight = -1;
    if (isTv) {
      _isFullscreen = true;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      _isFullscreen = false;
      if (Platform.isAndroid || Platform.isIOS) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
      if (Platform.isAndroid) {
        try {
          final view = WidgetsBinding.instance.platformDispatcher.views.firstOrNull;
          if (view != null) {
            final physicalWidth = view.physicalSize.width;
            final physicalHeight = view.physicalSize.height;
            // Pre-calculate exact top bounds if device is currently held in portrait
            if (physicalHeight > physicalWidth && physicalWidth > 0) {
              initialTop = view.padding.top.round();
              initialHeight = (physicalWidth / (16 / 9)).round();
            }
          }
        } catch (_) {}
      }
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
        // Check if episode progress threshold is reached for AniList sync
        _syncAnimeProgressIfNeeded();
      },
      onDuration: (dur) {
        if (_duration != dur && mounted) {
          setState(() => _duration = dur);
          _loadChapters();
        }
      },
      onBuffer: (buf) {
        _buffer = buf;
        _bufferNotifier.value = buf;
      },
      onPlaying: (playing) {
        if (mounted) setState(() => _isPlaying = playing);
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

    final isOnline = !widget.isLocalFile &&
        (widget.onlineStreamProvider != null || _currentOnlineStreamProvider != null);

    _coordinator.init(
      videoUrl: _currentVideoUrl,
      title: widget.title,
      episodeTitle: _currentEpisodeTitle,
      headers: _currentHeaders,
      mimeType: _currentMimeType,
      startPosition: widget.startPosition,
      externalSubtitles: _currentExternalSubtitles,
      fitMode: _fitMode,
      activeShaderPreset: _activeShaderPreset,
      isOnlineStream: isOnline,
      initialSurfaceTop: initialTop,
      initialSurfaceHeight: initialHeight,
    );

    _initStatsService();
    _startHideTimer();
    _initBrightness();
    _schedulePrefetchNextEpisode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  static const _nativeChannel = MethodChannel('com.seanime.app/exo_player');

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

  void _switchVideoSource({
    required String videoUrl,
    required int episodeNumber,
    required String episodeTitle,
    Map<String, String>? headers,
    String? mimeType,
    String? videoSource,
    List<dynamic>? externalSubtitles,
  }) {
    if (!mounted) return;

    _savePlaybackProgress();

    // Reset AniList sync latch for the new episode
    _hasUpdatedAnimeProgress = false;

    setState(() {
      _currentVideoUrl = videoUrl;
      _currentEpisodeNumber = episodeNumber;
      _currentEpisodeTitle = episodeTitle;
      _currentHeaders = headers;
      _currentMimeType = mimeType;
      _currentVideoSource = videoSource;
      _currentExternalSubtitles = externalSubtitles;
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

    final isOnline = !widget.isLocalFile &&
        (widget.onlineStreamProvider != null || _currentOnlineStreamProvider != null);

    _coordinator.open(
      videoUrl: videoUrl,
      title: widget.title,
      episodeTitle: episodeTitle,
      headers: headers,
      mimeType: mimeType,
      startPosition: Duration.zero,
      externalSubtitles: externalSubtitles,
      isOnlineStream: isOnline,
    );

    if (widget.mediaId != null) {
      ref.read(repositoryProvider).updateContinuityItem(
        mediaId: widget.mediaId!,
        episodeNumber: episodeNumber,
        currentTime: 0.0,
        duration: 0.0,
      );
      ref.read(lastSessionProvider.notifier).saveSession(
        LastSessionItem(
          mediaType: 'ANIME',
          mediaId: widget.mediaId!,
          title: widget.title,
          coverImage: _effectiveCoverImage,
          characterImage: _effectiveCharacterImage,
          episodeNumber: episodeNumber,
          episodeTitle: episodeTitle,
          videoUrl: videoUrl,
          headers: headers,
          mimeType: mimeType,
          videoSource: videoSource,
          positionMs: 0,
          durationMs: 0,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    // Schedule background prefetch for the following episode
    _schedulePrefetchNextEpisode();
  }

  Future<void> _handlePlayEpisode(int targetEpNum) async {
    if (widget.mediaId == null) return;
    if (_isLoadingNextEpisode) return;

    _prefetchTimer?.cancel();

    // 1. Save progress of the current episode before transitioning
    _savePlaybackProgress();
    _syncAnimeProgressIfNeeded();

    // 2. Immediately stop current playback so audio and video cease instantly
    _coordinator.pause();
    _coordinator.stop();

    // 3. Anticipate title from AniZip metadata
    final targetAniZipEp = (_aniZipData ?? _animeDetails?.aniZipData)?.getEpisode(targetEpNum);
    final targetEpTitle = targetAniZipEp?.displayTitle.isNotEmpty == true
        ? targetAniZipEp!.displayTitle
        : 'Episodio $targetEpNum';

    // 4. Update UI state immediately: old video disappears, loading spinner shows, no toast
    setState(() {
      _isLoadingNextEpisode = true;
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

    try {
      final resolver = PlayerEpisodeResolver(
        repository: ref.read(repositoryProvider),
        serverManager: ref.read(serverManagerProvider),
      );

      final resolved = await resolver.resolveEpisode(
        mediaId: widget.mediaId!,
        targetEpNum: targetEpNum,
        isCurrentLocalFile: _isCurrentLocalFile,
        currentVideoUrl: _currentVideoUrl,
        onlineStreamProvider: _currentOnlineStreamProvider ?? widget.onlineStreamProvider,
        onlineStreamDubbed: _currentOnlineStreamDubbed ?? widget.onlineStreamDubbed,
        onlineStreamServer: _currentOnlineStreamServer ?? widget.onlineStreamServer,
        animeDetails: _animeDetails,
        aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
      );

      if (resolved != null) {
        _switchVideoSource(
          videoUrl: resolved.videoUrl,
          episodeNumber: resolved.episodeNumber,
          episodeTitle: resolved.episodeTitle,
          headers: resolved.headers,
          mimeType: resolved.mimeType,
          videoSource: resolved.videoSource,
          externalSubtitles: resolved.externalSubtitles,
        );
        return;
      }

      if (mounted) {
        AnimeDetailsModalSheet.show(
          context: context,
          mediaId: widget.mediaId!,
          animeDetails: _animeDetails,
        );
      }
    } catch (e) {
      debugPrint('Error loading episode $targetEpNum: $e');
      if (mounted) {
        AnimeDetailsModalSheet.show(
          context: context,
          mediaId: widget.mediaId!,
          animeDetails: _animeDetails,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingNextEpisode = false);
      }
    }
  }

  void _schedulePrefetchNextEpisode() {
    _prefetchTimer?.cancel();
    if (!_hasNextEpisode || widget.mediaId == null) return;

    // Prefetch upcoming episode in the background after 12s so it is ready in RAM
    _prefetchTimer = Timer(const Duration(seconds: 12), () {
      if (!mounted || !_hasNextEpisode || widget.mediaId == null) return;
      final targetEp = (_currentEpisodeNumber ?? 1) + 1;
      final resolver = PlayerEpisodeResolver(
        repository: ref.read(repositoryProvider),
        serverManager: ref.read(serverManagerProvider),
      );
      resolver.prefetchEpisode(
        mediaId: widget.mediaId!,
        targetEpNum: targetEp,
        isCurrentLocalFile: _isCurrentLocalFile,
        currentVideoUrl: _currentVideoUrl,
        onlineStreamProvider: _currentOnlineStreamProvider ?? widget.onlineStreamProvider,
        onlineStreamDubbed: _currentOnlineStreamDubbed ?? widget.onlineStreamDubbed,
        onlineStreamServer: _currentOnlineStreamServer ?? widget.onlineStreamServer,
        animeDetails: _animeDetails,
        aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
      );
    });
  }

  @override
  void dispose() {
    _prefetchTimer?.cancel();
    _continuityTimer?.cancel();
    try {
      _savePlaybackProgress();
    } catch (e) {
      debugPrint('Error saving playback progress on dispose: $e');
    }
    try {
      _syncAnimeProgressIfNeeded();
    } catch (e) {
      debugPrint('Error syncing anime progress on dispose: $e');
    }

    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fallbackNoticeTimer?.cancel();

    _statsSub?.cancel();
    _statsService?.dispose();

    _coordinator.dispose();

    _positionNotifier.dispose();
    _bufferNotifier.dispose();

    try {
      _torrentStreamNotifier.reset();
    } catch (_) {}

    if (Platform.isAndroid) {
      try {
        _nativeChannel.invokeMethod('setBrightness', {'brightness': -1.0});
      } catch (_) {}
    }

    if (_isFullscreen) {
      defaultExitNativeFullscreen();
    }
    try {
      ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
      ref.read(desktopTitleBarBrightnessOverrideProvider.notifier).setBrightness(null);
    } catch (_) {}

    widget.onDispose?.call();

    // Restore portrait orientation and normal system UI on exit
    if (Platform.isAndroid || Platform.isIOS) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    if (!isDesktop && _isFullscreen && !_isTvActive) {
      _toggleFullscreen();
      return;
    }

    if (_isExiting) return;
    setState(() => _isExiting = true);

    if (_isFullscreen) {
      try {
        ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
        defaultExitNativeFullscreen();
      } catch (_) {}
    }

    _savePlaybackProgress();
    try {
      ref.invalidate(continueWatchingProvider);
    } catch (_) {}

    // 1. Immediately pause playback
    try {
      _coordinator.pause();
    } catch (_) {}

    // 2. Restore portrait orientation & system UI while solid black covers the screen
    if (Platform.isAndroid || Platform.isIOS) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    // 3. Short delay so Android WindowManager finishes rotation behind black curtain
    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      Navigator.of(context).pop();
    }
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
    if (!_areControlsVisible) {
      setState(() => _areControlsVisible = true);
    }
    _startHideTimer();
  }

  void _onMouseExit() {
    if (!mounted) return;
    if (_isInteractingWithVolume) return;
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

    // Optimistic update: show the new position immediately
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
    // Optimistic update: show the new position immediately
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

  void _updateExoSurfaceBounds(BuildContext context) {
    if (!Platform.isAndroid || !_coordinator.isUsingExoPlayer) return;

    final mq = MediaQuery.of(context);
    final isPhysicalLandscape = mq.orientation == Orientation.landscape;
    final bool effectiveFullscreen = _isFullscreen || _isTvActive || isPhysicalLandscape;

    if (effectiveFullscreen) {
      if (_lastExoTop != 0 || _lastExoHeight != -1) {
        _lastExoTop = 0;
        _lastExoHeight = -1;
        _coordinator.setSurfaceBounds(top: 0, height: -1);
      }
    } else {
      final density = mq.devicePixelRatio;
      final top = (mq.padding.top * density).round();
      final width = mq.size.width;
      final height = ((width / (16 / 9)) * density).round();
      if (_lastExoTop != top || _lastExoHeight != height) {
        _lastExoTop = top;
        _lastExoHeight = height;
        _coordinator.setSurfaceBounds(top: top, height: height);
      }
    }
  }

  void _toggleFullscreen() {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    if (isDesktop) {
      setState(() => _isFullscreen = !_isFullscreen);
      if (_isFullscreen) {
        try {
          ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(false);
        } catch (_) {}
        defaultEnterNativeFullscreen();
      } else {
        try {
          ref.read(desktopTitleBarVisibleProvider.notifier).setVisible(true);
        } catch (_) {}
        defaultExitNativeFullscreen();
      }
    } else {
      // Mobile: switch between landscape immersive and portrait edge-to-edge
      final willBeFullscreen = !_isFullscreen;
      setState(() {
        _isTransitioningOrientation = true;
        _areControlsVisible = false; // Hide controls while rotating to prevent erratic layout jumps
        _isFullscreen = willBeFullscreen;
      });

      if (willBeFullscreen) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }

      // Allow orientation transition to stabilize
      Future.delayed(const Duration(milliseconds: 380), () {
        if (mounted) {
          setState(() {
            _isTransitioningOrientation = false;
          });
        }
      });
    }
  }

  String? _getVideoSourceLabel() {
    if (widget.videoSource != null && widget.videoSource!.isNotEmpty) {
      return widget.videoSource;
    }
    if (widget.videoUrl.startsWith('http://') || widget.videoUrl.startsWith('https://')) {
      try {
        final uri = Uri.parse(widget.videoUrl);
        return uri.host;
      } catch (_) {}
    }
    if (widget.videoUrl.startsWith('/')) {
      return widget.videoUrl.split('/').last;
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
          _startHideTimer();
        }
      },
      brightness: _brightness,
      onBrightnessChanged: _setBrightness,
      isBuffering: _isBuffering,
      isLoadingNextEpisode: _isLoadingNextEpisode,
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
          ? () => _handlePlayEpisode((_currentEpisodeNumber ?? 1) + 1)
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isFullscreen = _isFullscreen || _isTvActive;

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
      _updateExoSurfaceBounds(context);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateExoSurfaceBounds(context);
        }
      });
    }

    final scaffoldBg = _coordinator.isUsingExoPlayer
        ? Colors.transparent
        : (effectiveFullscreen ? Colors.black : theme.scaffoldBackgroundColor);

    return PopScope(
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
                  cursor: (!isDesktop || _areControlsVisible)
                      ? SystemMouseCursors.basic
                      : SystemMouseCursors.none,
                  onEnter: isDesktop ? (_) => _onMouseEnter() : null,
                  onHover: isDesktop ? (_) => _onMouseMove() : null,
                  onExit: isDesktop ? (_) => _onMouseExit() : null,
                  child: effectiveFullscreen
                      ? _buildPlayerViewport(
                          context,
                          isFullscreen: true,
                          isDesktop: isDesktop,
                        )
                      : (isDesktop
                          ? PlayerDesktopLayout(
                              playerViewport: _buildPlayerViewport(
                                context,
                                isFullscreen: false,
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
                                onPlayNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
                                    ? () => _handlePlayEpisode((_currentEpisodeNumber ?? 1) + 1)
                                    : null,
                                onPlayPreviousEpisode: (_hasPreviousEpisode && !_isLoadingNextEpisode)
                                    ? () => _handlePlayEpisode((_currentEpisodeNumber ?? 1) - 1)
                                    : null,
                              ),
                              isSidePanelCollapsed: _isSidePanelCollapsed,
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
                                onPlayNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
                                    ? () => _handlePlayEpisode((_currentEpisodeNumber ?? 1) + 1)
                                    : null,
                                onPlayPreviousEpisode: (_hasPreviousEpisode && !_isLoadingNextEpisode)
                                    ? () => _handlePlayEpisode((_currentEpisodeNumber ?? 1) - 1)
                                    : null,
                              ),
                            )),
                ),
              ),
      ),
    );
  }
}
