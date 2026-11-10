import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/anime_playback_source_provider.dart';
import 'package:aniting/core/preferences/live_playback_progress_provider.dart';
import 'package:aniting/core/preferences/player_desktop_view_provider.dart';
import 'package:aniting/core/preferences/player_ambient_glow_provider.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_episode_target.dart';
import 'package:aniting/core/preferences/player_engine_provider.dart';
import 'package:aniting/core/preferences/player_smooth_motion_provider.dart';
import 'package:aniting/core/player/native_video_surface_provider.dart';
import 'package:aniting/core/preferences/player_gesture_provider.dart';
import 'package:aniting/core/preferences/playback_progress_preferences_provider.dart';
import 'package:aniting/core/preferences/resume_bar_preferences_provider.dart';
import 'package:aniting/core/preferences/track_preferences_provider.dart';
import 'package:aniting/core/preferences/tv_mode_provider.dart';
import 'package:aniting/core/preferences/volume_boost_provider.dart';
import 'package:aniting/core/preferences/online_stream_proxy_provider.dart';
import 'package:aniting/core/preferences/streaming_preferences_provider.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/data/repositories/aniting_repository.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/providers/torrent_stream_provider.dart';
import 'package:aniting/presentation/widgets/anime_details_modal_sheet.dart';
import 'package:aniting/presentation/widgets/player/controls/player_keyboard_handler.dart';
import 'package:aniting/presentation/widgets/player/dialogs/player_source_picker.dart';
import 'package:aniting/presentation/widgets/player/layouts/player_desktop_layout.dart';
import 'package:aniting/presentation/widgets/player/layouts/player_mobile_layout.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';
import 'package:aniting/presentation/widgets/player/models/player_direct_episode.dart';
import 'package:aniting/presentation/widgets/player/panels/player_info_panel.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episodes_rail.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_header_controls.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_movie_rail.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_watch_content.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episode_header.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_desktop_header.dart';
import 'package:aniting/presentation/widgets/player/services/performance_stats_service.dart';
import 'package:aniting/presentation/widgets/player/services/player_episode_resolver.dart';
import 'package:aniting/presentation/widgets/player/services/player_playback_coordinator.dart';
import 'package:aniting/presentation/widgets/player/services/player_progress_manager.dart';
import 'package:aniting/presentation/widgets/player/services/player_shader_service.dart';
import 'package:aniting/presentation/widgets/player/services/player_source_controller.dart';
import 'package:aniting/presentation/widgets/player/services/player_track_matcher.dart';
import 'package:aniting/presentation/widgets/player/services/player_window_manager.dart';
import 'package:aniting/presentation/widgets/player/viewport/ambient_video_glow.dart';
import 'package:aniting/presentation/widgets/player/viewport/player_viewport.dart';
import 'package:aniting/presentation/widgets/desktop_title_bar.dart';
import 'package:aniting/presentation/widgets/player/sheets/player_episodes_sheet.dart';
import 'package:aniting/presentation/widgets/player/sheets/player_settings_launcher.dart';
import 'package:aniting/presentation/widgets/toast/app_toast.dart';
import 'package:aniting/core/preferences/subtitle_style_preferences_provider.dart';
import 'package:aniting/core/player/mpris_service.dart';

export 'package:aniting/presentation/widgets/player/models/player_types.dart'
    show UiTrack, ShaderPreset, PerformanceStats, PlayerFitMode;

/// Main video playback screen featuring a modern, clean UI inspired by Plezy & YouTube.
/// Provides dual-engine playback (ExoPlayer + media_kit), YouTube-style watch page on mobile,
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
  final String? resolvedLoadingLogoUrl;
  final String? resolvedLoadingBannerUrl;
  final String? onlineStreamProvider;
  final bool? onlineStreamDubbed;
  final String? onlineStreamServer;
  final bool isLocalFile;

  /// True when the video is a direct stream from a Plex / Jellyfin server.
  ///
  /// These libraries are not part of AniList: the watch page gets its metadata
  /// and episode rail from [directEpisodes], and it must not offer online
  /// playback-source options.
  final bool isMediaServerMedia;

  /// Episodes that can be played directly (media servers), bypassing the
  /// AniList / online-stream resolver when the user switches episodes.
  final List<PlayerDirectEpisode>? directEpisodes;

  /// Hides the comments thread. External libraries and TMDB detail pages have
  /// no local comments to show.
  final bool hideComments;

  /// Called right before the player is disposed with the final playback
  /// position. Used by media-server integrations to report accurate progress
  /// when the user leaves (the value captured when the route was opened is
  /// stale by then). [sourceId] identifies the item that was playing.
  final void Function(String? sourceId, Duration position, Duration duration)?
  onPlaybackStopped;

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
    this.resolvedLoadingLogoUrl,
    this.resolvedLoadingBannerUrl,
    this.onlineStreamProvider,
    this.onlineStreamDubbed,
    this.onlineStreamServer,
    this.isLocalFile = false,
    this.isMediaServerMedia = false,
    this.directEpisodes,
    this.hideComments = false,
    this.isTmdbMedia = false,
    this.tmdbMediaType,
    this.tmdbSeason,
    this.tmdbEnglishTitle,
    this.tmdbYear,
    this.onPlaybackStopped,
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
    String? resolvedLoadingLogoUrl,
    String? resolvedLoadingBannerUrl,
    String? onlineStreamProvider,
    bool? onlineStreamDubbed,
    String? onlineStreamServer,
    bool isLocalFile = false,
    bool isMediaServerMedia = false,
    List<PlayerDirectEpisode>? directEpisodes,
    bool hideComments = false,
    bool isTmdbMedia = false,
    String? tmdbMediaType,
    int? tmdbSeason,
    String? tmdbEnglishTitle,
    int? tmdbYear,
    void Function(String? sourceId, Duration position, Duration duration)?
    onPlaybackStopped,
  }) {
    return PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      allowSnapshotting: false,
      pageBuilder: (context, animation, secondaryAnimation) =>
          VideoPlayerScreen(
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
            resolvedLoadingLogoUrl: resolvedLoadingLogoUrl,
            resolvedLoadingBannerUrl: resolvedLoadingBannerUrl,
            onlineStreamProvider: onlineStreamProvider,
            onlineStreamDubbed: onlineStreamDubbed,
            onlineStreamServer: onlineStreamServer,
            isLocalFile: isLocalFile,
            isMediaServerMedia: isMediaServerMedia,
            directEpisodes: directEpisodes,
            hideComments: hideComments,
            isTmdbMedia: isTmdbMedia,
            tmdbMediaType: tmdbMediaType,
            tmdbSeason: tmdbSeason,
            tmdbEnglishTitle: tmdbEnglishTitle,
            tmdbYear: tmdbYear,
            onPlaybackStopped: onPlaybackStopped,
          ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
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
  final ValueNotifier<Duration> _positionNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  final ValueNotifier<Duration> _bufferNotifier = ValueNotifier<Duration>(
    Duration.zero,
  );
  bool _canSkipCurrentChapter = false;
  bool _isPlaying = false;

  /// Drives the play/pause control only. Keeping it out of [setState] avoids
  /// rebuilding the whole player page (video, watch content and episode rail)
  /// on every play/pause, which caused a visible UI stall when pausing.
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  bool _isBuffering = false;
  bool _hasStartedPlayback = false;
  bool _isPreparingEngine = true;
  bool _isSeeking = false;
  Timer? _engineStartTimer;
  Timer? _prepareTimeout;
  Timer? _seekLoadingTimer;

  /// Last position bucket (250 ms) pushed to [livePlaybackProgressProvider], so
  /// episode cards follow the video without a rebuild storm per position tick.
  static const int _liveProgressBucketMs = 250;
  int _liveProgressBucket = -1;
  double _playbackRate = 1.0;
  double _volume = 100.0;
  double _lastNonZeroVolume = 100.0;
  final FocusNode _focusNode = FocusNode();
  final GlobalKey _videoCaptureKey = GlobalKey();

  // YouTube-style watch page & TV mode state

  /// Layout mode (normal / wide / cinema) is persisted and shared, so the page
  /// chrome, the viewport and the header button all read the same value.
  PlayerLayoutMode get _layoutMode => ref.read(playerLayoutModeProvider);

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
  late final AnitingRepository _repository;
  late final ProviderContainer _providerContainer;
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
  final ValueNotifier<PerformanceStats?> _performanceStatsNotifier =
      ValueNotifier<PerformanceStats?>(null);
  StreamSubscription<PerformanceStats>? _statsSub;

  // Torrent progress overlay
  bool _isTorrentProgressVisible = false;

  // Viewport fit mode
  PlayerFitMode _fitMode = PlayerFitMode.contain;

  // Controls UI visibility
  bool _areControlsVisible = true;
  bool _isInteractingWithVolume = false;
  bool _isMenuOpen = false;
  bool _isPlayerLocked = false;
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
  bool _hasAutoAppliedTracks = false;

  String get _currentVideoKey => PlayerTrackMatcher.makeVideoKey(
    mediaId: widget.mediaId,
    episodeNumber: _currentEpisodeNumber,
    videoUrl: _currentVideoUrl,
  );

  void _applySavedOrPreferredTracks(
    List<UiTrack> audioList,
    List<UiTrack> subList,
  ) {
    final pref = ref
        .read(trackPreferencesProvider.notifier)
        .getPreference(_currentVideoKey);

    final targetAudio = PlayerTrackMatcher.matchAudioTrack(
      audioList: audioList,
      preference: pref,
    );
    if (targetAudio != null && targetAudio.id != _selectedAudioTrackId) {
      _selectAudioTrack(targetAudio);
    }

    final subResult = PlayerTrackMatcher.matchSubtitleTrack(
      subList: subList,
      preference: pref,
      currentSelectedSubtitleId: _selectedSubtitleTrackId,
      appLanguage: ref.read(appLanguageProvider),
    );
    if (subResult.shouldChange) {
      _selectSubtitleTrack(subResult.track);
    }
  }

  // Delegated getters to modular services
  bool get _isFullscreen => _windowManager.isFullscreen;
  bool get _isTransitioningOrientation =>
      _windowManager.isTransitioningOrientation;
  bool get _isExiting => _windowManager.isExiting;
  bool get _isResolvingSources => _sourceController.isResolvingSources;
  List<OnlinestreamVideoSource> get _availableSources =>
      _sourceController.availableSources;
  OnlinestreamVideoSource? get _activeSource => _sourceController.activeSource;
  String? get _sourceResolutionError => _sourceController.sourceResolutionError;
  bool get _isLoadingNextEpisode => _sourceController.isLoadingNextEpisode;

  /// External libraries and TMDB detail pages have no local comments thread.
  bool get _showComments =>
      !(widget.hideComments ||
          widget.isMediaServerMedia ||
          widget.isTmdbMedia ||
          (widget.initialAnimeDetails?.isTmdb ?? false) ||
          (_animeDetails?.isTmdb ?? false));

  /// Episode that is currently playing when the video comes straight from a
  /// media server. Used to report progress back to the right item.
  PlayerDirectEpisode? get _currentDirectEpisode {
    final episodes = widget.directEpisodes;
    if (episodes == null || episodes.isEmpty) return null;
    final number = _currentEpisodeNumber;
    if (number == null) return episodes.first;
    return episodes.where((episode) => episode.number == number).firstOrNull ??
        episodes.first;
  }

  /// Where the current video comes from. Only online streams expose switchable
  /// providers/servers, so the playback card renders differently for local files
  /// and torrent streams.
  PlayerPlaybackOrigin get _playbackOrigin {
    if (widget.isMediaServerMedia) {
      return PlayerPlaybackOrigin.mediaServer;
    }
    if (_isCurrentLocalFile ||
        _currentVideoUrl.contains('/api/v1/mediastream')) {
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
    // TMDB media uses its own season episodes; the AniList onlinestream
    // episode endpoint would query an unrelated anime with the same id.
    if (_isTmdbPlayback) return;
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
      (_animeDetails?.totalEpisodes == 1 &&
          (_animeDetails?.episodes.length ?? 0) <= 1);

  bool get _hasNextEpisode => PlayerEpisodeResolver.hasNextEpisode(
    isMovie: _isMovie,
    directEpisodes: widget.directEpisodes,
    currentEpisodeNumber: _currentEpisodeNumber,
    animeDetails: _animeDetails,
    aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
    onlineStreamProvider: _currentOnlineStreamProvider,
    onlineEpisodes: _onlineEpisodes,
    isCurrentLocalFile: _isCurrentLocalFile,
  );

  bool get _hasPreviousEpisode => PlayerEpisodeResolver.hasPreviousEpisode(
    isMovie: _isMovie,
    directEpisodes: widget.directEpisodes,
    currentEpisodeNumber: _currentEpisodeNumber,
  );

  String? get _effectiveCharacterImage =>
      _animeDetails?.mainCharacterImage ??
      widget.initialAnimeDetails?.mainCharacterImage;

  String? get _effectiveCoverImage =>
      _animeDetails?.coverImage ?? widget.initialAnimeDetails?.coverImage;

  String? get _effectiveLoadingBackground =>
      widget.resolvedLoadingBannerUrl ??
      _animeDetails?.bannerImage ??
      widget.initialAnimeDetails?.bannerImage ??
      _aniZipData?.fanartUrl ??
      _animeDetails?.coverImage ??
      widget.initialAnimeDetails?.coverImage;

  String? get _effectiveLoadingLogo =>
      widget.resolvedLoadingLogoUrl ??
      _aniZipData?.clearlogoUrl ??
      _animeDetails?.aniZipData?.clearlogoUrl;

  bool get _isTmdbPlayback =>
      widget.isTmdbMedia || (_animeDetails?.isTmdb ?? false);

  bool _sourcePickerShown = false;

  String? get _currentEpisodeImage {
    final epNum = _currentEpisodeNumber ?? 1;
    final detailsEp = _animeDetails?.episodes
        .where((e) => e.episodeNumber == epNum)
        .firstOrNull;
    return detailsEp?.image ??
        _aniZipData?.getEpisode(epNum)?.image ??
        _effectiveCoverImage;
  }

  /// Shows the in-player source picker shortly after entering a TMDB episode.
  Future<void> _openSourcePickerOnEnter() async {
    if (_sourcePickerShown || _isPlayerDisposed) return;
    _sourcePickerShown = true;
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted || _isPlayerDisposed) return;
    await _showSourcePicker();
  }

  /// Provider tabs + sources picker. Selecting a source starts playback.
  Future<void> _showSourcePicker() async {
    final l10n = ref.read(translationsProvider);

    List<OnlinestreamProvider> providers = const [];
    try {
      providers =
          (await ref
                  .read(repositoryProvider)
                  .getOnlinestreamProviders(forceRefresh: true))
              .where((p) => _isTmdbPlayback ? p.supportsTmdb : true)
              .toList();
    } catch (_) {}

    if (!mounted) return;
    if (providers.isEmpty) {
      AppToast.warning(l10n.noOnlineExtensionsInstalled, context: context);
      return;
    }

    final initialProviderId =
        providers.any((p) => p.id == _currentOnlineStreamProvider)
        ? _currentOnlineStreamProvider
        : providers.first.id;

    await showPlayerSourcePicker(
      context,
      title: widget.title,
      episodeTitle: _currentEpisodeTitle ?? widget.episodeTitle ?? widget.title,
      imageUrl: _currentEpisodeImage,
      providers: providers,
      initialProviderId: initialProviderId,
      loadSources: (providerId) async {
        final sources = await _sourceController.fetchSourcesForProvider(
          providerId,
        );
        _sourceController.setAvailableSources(sources);
        if (mounted && _currentOnlineStreamProvider != providerId) {
          setState(() => _currentOnlineStreamProvider = providerId);
        }
        return sources;
      },
      onSourceSelected: (provider, source) async {
        if (!mounted) return;
        if (_currentOnlineStreamProvider != provider.id) {
          setState(() => _currentOnlineStreamProvider = provider.id);
        }
        await _sourceController.selectSource(source);
      },
    );
  }

  /// Loads TMDB metadata + season episodes for the player.
  ///
  /// The detail page already provides most of the metadata through
  /// [VideoPlayerScreen.initialAnimeDetails]; this only fills the gaps (e.g.
  /// when resuming from "Continue watching") and builds the season episode list
  /// used by the rail, next-episode logic and episode picker.
  Future<void> _fetchTmdbDetails() async {
    final mediaId = widget.mediaId;
    if (mediaId == null) return;

    final l10n = ref.read(translationsProvider);
    final lang = ref.read(appLanguageProvider) == AppLanguage.es
        ? 'es-ES'
        : 'en-US';
    final mediaType = (widget.tmdbMediaType ?? _animeDetails?.format ?? 'tv')
        .toLowerCase();
    final isMovie =
        mediaType == 'movie' ||
        (_animeDetails?.format?.toUpperCase() == 'MOVIE');
    final season = widget.tmdbSeason ?? 1;

    var details = _animeDetails;
    var tmdbEpisodes = const <AnimeEpisode>[];

    if (details == null && mounted) {
      setState(() => _isLoadingDetails = true);
    }

    try {
      final tmdb = ref.read(tmdbServiceProvider);
      if (details == null) {
        final tmdbDetails = await tmdb.getShowDetails(
          mediaId,
          language: lang,
          isMovie: isMovie,
        );
        details = tmdbDetails?.toAnimeDetails();
      }

      if (!isMovie) {
        final eps = await tmdb.getSeasonEpisodes(
          mediaId,
          season,
          language: lang,
        );
        tmdbEpisodes = eps
            .map(
              (e) => AnimeEpisode(
                episodeNumber: e.episodeNumber,
                title: e.name.isNotEmpty
                    ? e.name
                    : l10n.episodeNumber(e.episodeNumber),
                description: e.overview,
                image: e.stillUrl,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('[VideoPlayerScreen] Error loading TMDB metadata: $e');
    }

    if (!mounted) return;

    setState(() {
      if (details != null) {
        _animeDetails = tmdbEpisodes.isNotEmpty
            ? details.copyWith(
                episodes: tmdbEpisodes,
                totalEpisodes: tmdbEpisodes.length,
              )
            : details;
      }
      _isLoadingDetails = false;

      // Keep the header title in sync with the TMDB episode title.
      final epNum = _currentEpisodeNumber ?? 1;
      final match = tmdbEpisodes
          .where((e) => e.episodeNumber == epNum)
          .firstOrNull;
      if (match != null &&
          match.title.trim().isNotEmpty &&
          !PlayerEpisodeHeader.isGenericTitle(match.title, epNum)) {
        _currentEpisodeTitle = match.title;
      }
    });
  }

  Future<void> _fetchAnimeDetails() async {
    if (widget.mediaId != null) {
      if (_isTmdbPlayback) {
        await _fetchTmdbDetails();
        return;
      }
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
          final aniZip =
              (results[1] as AniZipData?) ?? details?.aniZipData ?? _aniZipData;
          setState(() {
            _animeDetails = details ?? _animeDetails;
            _aniZipData = aniZip;
            _isLoadingDetails = false;

            // Harmonize current episode title with canonical AniZip / anime details
            final epNum = _currentEpisodeNumber ?? 1;
            final eps = details?.episodes;
            final detailsTitle = eps
                ?.where((e) => e.episodeNumber == epNum)
                .firstOrNull
                ?.title;
            final canonical =
                aniZip?.getEpisode(epNum)?.displayTitle ?? detailsTitle;
            if (canonical != null &&
                canonical.trim().isNotEmpty &&
                !PlayerEpisodeHeader.isGenericTitle(canonical, epNum)) {
              _currentEpisodeTitle = canonical;
            }
          });

          // Auto-update active session with main character image once details load
          final currentSession = ref.read(lastSessionProvider);
          if (currentSession != null &&
              currentSession.mediaId == widget.mediaId) {
            final mc = _effectiveCharacterImage;
            final cover = _effectiveCoverImage;
            if (mc != null || cover != null) {
              ref
                  .read(lastSessionProvider.notifier)
                  .saveSession(
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
    _initPlayerState();
    _initCoordinator();
    final winInit = _initWindowManager();
    _initProgressManager();
    _initSourceController();
    _initPostFrame(winInit);
  }

  void _initPlayerState() {
    _torrentStreamNotifier = ref.read(torrentStreamStatusProvider.notifier);
    _repository = ref.read(repositoryProvider);
    _providerContainer = ProviderScope.containerOf(context, listen: false);
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
    _aniZipData =
        widget.initialAniZipData ?? widget.initialAnimeDetails?.aniZipData;

    _fetchAnimeDetails();
    if (widget.mediaId != null && _currentOnlineStreamProvider != null) {
      _fetchOnlineEpisodes();
    }
  }

  void _initCoordinator() {
    final preferredEngine = ref.read(playerEngineProvider);
    final useExo =
        Platform.isAndroid && preferredEngine == PlayerEngine.exoplayer;

    _coordinator = PlayerPlaybackCoordinator(
      isUsingExoPlayer: useExo,
      shaderService: _shaderService,
      l10n: ref.read(translationsProvider),
      smoothMotion: ref.read(playerSmoothMotionProvider),
      onPosition: (pos) {
        if (_isExiting) return;
        _position = pos;
        _positionNotifier.value = pos;
        _publishLiveProgress();
        final canSkip =
            _activeChapter != null && _activeChapter!.isSkippable(pos);
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
        if (_isExiting) return;
        if (_duration != dur && mounted) {
          setState(() => _duration = dur);
          _loadChapters();
          _publishLiveProgress(force: true);
          if (Platform.isLinux) {
            MprisService.instance.updateMetadata(
              title:
                  _currentEpisodeTitle ?? widget.episodeTitle ?? widget.title,
              artist: widget.title,
              album: widget.title,
              artUrl: _effectiveCoverImage,
              duration: dur,
            );
          }
        }
      },
      onBuffer: (buf) {
        if (_isExiting) return;
        final effectiveBuf = _playbackOrigin == PlayerPlaybackOrigin.local
            ? Duration.zero
            : buf;
        _buffer = effectiveBuf;
        _bufferNotifier.value = effectiveBuf;
      },
      onPlaying: (playing) {
        final wasStarted = _hasStartedPlayback;
        final wasSeeking = _isSeeking;
        _isPlaying = playing;
        _isPlayingNotifier.value = playing;
        if (playing) {
          _hasStartedPlayback = true;
          _isSeeking = false;
          _isPreparingEngine = false;
          _prepareTimeout?.cancel();
          _prepareTimeout = null;
        }
        if (mounted && playing && (!wasStarted || wasSeeking)) {
          setState(() {});
        }
        if (!playing) {
          if (!_isExiting) {
            _progressManager.scheduleSaveProgress();
            _publishLiveProgress(force: true);
          }
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
        if (_isExiting) return;
        if (mounted) {
          setState(() {
            _isBuffering = buffering;
            if (!buffering) _isSeeking = false;
          });
        }
      },
      onEnded: () {
        _isPlaying = false;
        _isPlayingNotifier.value = false;
      },
      onTracks: (audio, subs, selectedAudio, selectedSub) {
        if (!mounted || _isExiting) return;
        setState(() {
          _audioTracks = audio;
          _subtitleTracks = subs;
          _selectedAudioTrackId = selectedAudio;
          _selectedSubtitleTrackId = selectedSub;
        });
        _loadChapters();

        if (!_hasAutoAppliedTracks && (audio.isNotEmpty || subs.isNotEmpty)) {
          _hasAutoAppliedTracks = true;
          _applySavedOrPreferredTracks(audio, subs);
        }
      },
      onCues: (text) {
        if (_isExiting) return;
        if (mounted && _currentSubtitleText != text) {
          setState(() => _currentSubtitleText = text);
        }
      },
      onFallbackToMediaKit: (reason, fallbackPos) {
        if (!mounted || _isExiting) return;
        // media_kit paints into a Flutter texture again, so the root background
        // must come back to keep the route opaque.
        ref.read(nativeVideoSurfaceActiveProvider.notifier).setActive(false);
        setState(() {
          _isBuffering = true;
          _fallbackNotice = ref
              .read(translationsProvider)
              .switchingToMediaKitNotice;
        });
        _fallbackNoticeTimer?.cancel();
        _fallbackNoticeTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _fallbackNotice = null);
        });
        _initStatsService();
      },
      onChapters: (chs) {
        if (_isExiting) return;
        if (mounted && chs.isNotEmpty) {
          setState(() => _chapters = chs);
        }
      },
      buildProxyUrl: (url, headers) {
        final proxyEnabled = ref.read(onlineStreamProxyProvider);
        if (!proxyEnabled) return url;
        final client = ref.read(apiClientProvider);
        return client.buildVideoProxyUrl(url, headers: headers);
      },
    );
    _coordinator.applySubtitleStyle(ref.read(subtitleStylePreferencesProvider));

    ref.listenManual(subtitleStylePreferencesProvider, (_, next) {
      _coordinator.applySubtitleStyle(next);
      if (mounted) setState(() {});
    });
  }

  PlayerWindowInit _initWindowManager() {
    _windowManager = PlayerWindowManager(
      isTv: _isTvActive,
      ref: ref,
      coordinator: _coordinator,
    );
    return _windowManager.initWindow();
  }

  Duration? _getSavedProgress([int? epNumber]) {
    final ep = epNumber ?? _currentEpisodeNumber;
    if (widget.mediaId != null && ep != null) {
      final progress = ref
          .read(playbackProgressPreferencesProvider.notifier)
          .getProgress(widget.mediaId!, ep);
      if (progress != null && progress.positionMs > 0) {
        final fraction = progress.durationMs > 0
            ? progress.positionMs / progress.durationMs
            : 0.0;
        if (fraction < 0.95) {
          return Duration(milliseconds: progress.positionMs);
        }
      }
    }
    return null;
  }

  void _initProgressManager() {
    _progressManager = PlayerProgressManager(
      repository: ref.read(repositoryProvider),
      lastSessionNotifier: ref.read(lastSessionProvider.notifier),
      playbackProgressNotifier: ref.read(
        playbackProgressPreferencesProvider.notifier,
      ),
      animePlaybackSourceNotifier: ref.read(
        animePlaybackSourceProvider.notifier,
      ),
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
      getTmdbMediaType: () => widget.tmdbMediaType,
      getTmdbSeason: () => widget.tmdbSeason,
      getTmdbEnglishTitle: () => widget.tmdbEnglishTitle,
      getTmdbYear: () => widget.tmdbYear,
      getEpisodeThumbnail: () {
        final ep = _aniZipData?.getEpisode(_currentEpisodeNumber ?? 1);
        return ep?.image ?? _effectiveCoverImage;
      },
      onLocalWatchRecorded: () {
        // Period flicker intentionally avoided: this fires on every periodic
        // progress write (and on exit). The local offline entry is already
        // persisted by the progress manager, and the detail page reads its
        // progress from it; the Continue Watching list is updated optimistically
        // before the player closes and refreshed silently afterwards. Invalidating
        // the whole library collection here reloaded the feed behind the detail
        // page every ~20s and caused the post-exit lag spike.
      },
      onProgressSynced: () {
        // Only the real AniList/library progress change needs a collection
        // refresh (the latch in PlayerProgressManager guarantees this runs once
        // per episode). Continue Watching is handled by the exit flow and
        // recommendations do not depend on episode progress.
        if (mounted && !_isPlayerDisposed) {
          try {
            ref.invalidate(animeCollectionProvider);
          } catch (_) {}
        }
      },
    );
  }

  void _initSourceController() {
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
        return pos ?? _getSavedProgress();
      },
      getSavedProgress: (epNum) => _getSavedProgress(epNum),
      getHasNextEpisode: () => _hasNextEpisode,
      onUpdateUi: () {
        if (mounted && !_isPlayerDisposed) setState(() {});
      },
      onSourceActivated: _onSourceActivated,
      onShowEpisodePicker: () {
        if (!mounted || widget.mediaId == null) return;
        if (_isTmdbPlayback) {
          if (_railEpisodes.isNotEmpty) _openEpisodesSheet();
          return;
        }
        AnimeDetailsModalSheet.show(
          context: context,
          mediaId: widget.mediaId!,
          animeDetails: _animeDetails,
        );
      },
      getIsTmdb: () => widget.isTmdbMedia || (_animeDetails?.isTmdb ?? false),
      getTmdbMediaType: () => widget.tmdbMediaType,
      getTmdbSeason: () => widget.tmdbSeason,
      getTmdbEnglishTitle: () => widget.tmdbEnglishTitle,
      getTmdbYear: () => widget.tmdbYear,
      getDirectEpisodes: () => widget.directEpisodes,
    );
  }

  void _initPostFrame(PlayerWindowInit winInit) {
    final isOnline =
        !widget.isLocalFile &&
        (widget.onlineStreamProvider != null ||
            _currentOnlineStreamProvider != null);
    final resolvedStartPosition = widget.startPosition ?? _getSavedProgress();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isPlayerDisposed) return;
      ref.read(isVideoPlayerActiveProvider.notifier).setActive(true);
      if (Platform.isAndroid && _coordinator.isUsingExoPlayer) {
        ref.read(nativeVideoSurfaceActiveProvider.notifier).setActive(true);
      }
      _focusNode.requestFocus();
      _startHideTimer();
      _initBrightness();

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

      // Creating media_kit's native player is the most expensive part of
      // entering the screen. Let the route transition finish first (the
      // loading artwork is already visible), so the opening fade stays smooth
      // instead of being interrupted by native player creation.
      _engineStartTimer?.cancel();
      _engineStartTimer = Timer(const Duration(milliseconds: 220), () {
        if (!mounted || _isPlayerDisposed) return;

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

        _prepareTimeout?.cancel();
        _prepareTimeout = Timer(const Duration(seconds: 4), () {
          if (!mounted || !_isPreparingEngine) return;
          setState(() => _isPreparingEngine = false);
        });

        _progressManager.startTracking(initialPosition: resolvedStartPosition);
        if (widget.mediaId != null) {
          final isLocal =
              _isCurrentLocalFile ||
              _currentVideoUrl.contains('/api/v1/mediastream');
          final isTorrent =
              _currentVideoUrl.contains('torrentstream') ||
              (_currentVideoSource?.toLowerCase().contains('torrent') ?? false);
          final sourceType = isLocal
              ? 'local'
              : (isTorrent ? 'torrent' : 'online');
          ref
              .read(animePlaybackSourceProvider.notifier)
              .saveSource(
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
        _sourceController.schedulePrefetchNextEpisode();

        if (_currentVideoUrl.isEmpty && _currentOnlineStreamProvider != null) {
          if (_isTmdbPlayback) {
            _openSourcePickerOnEnter();
          } else {
            _sourceController.resolveInitialSources();
          }
        } else if (_currentOnlineStreamProvider != null) {
          _sourceController.fetchAvailableSourcesInBackground(
            currentVideoUrl: _currentVideoUrl,
          );
        }
      });
    });
  }

  static const _nativeChannel = MethodChannel(
    'com.anyyting.aniting/exo_player',
  );

  Future<void> _initBrightness() async {
    if (!Platform.isAndroid) return;
    try {
      final current = await _nativeChannel.invokeMethod<double>(
        'getBrightness',
      );
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
      mediaKitService: _coordinator.mediaKitService,
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
      _hasAutoAppliedTracks = false;
    });

    _clearLiveProgress();
    _seekFeedbackTimer?.cancel();
    _progressManager.resetEpisodeLatch();
    _progressManager.savePlaybackProgress();
  }

  void _onEpisodeTransitionStarted(int targetEpNum, String targetEpTitle) {
    _initialStartPosition = null;
    _hasAutoAppliedTracks = false;
    _progressManager.savePlaybackProgress();
    _progressManager.syncAnimeProgressIfNeeded();
    _clearLiveProgress();
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
    try {
      ref.read(isVideoPlayerActiveProvider.notifier).setActive(false);
      ref.read(nativeVideoSurfaceActiveProvider.notifier).setActive(false);
    } catch (_) {}
    _sourceController.dispose();
    _progressManager.dispose();
    try {
      _clearLiveProgress();
    } catch (_) {}

    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fallbackNoticeTimer?.cancel();
    _seekLoadingTimer?.cancel();
    _engineStartTimer?.cancel();
    _prepareTimeout?.cancel();

    _statsSub?.cancel();
    _statsService?.dispose();

    _coordinator.dispose();

    final isTorrent =
        _currentVideoUrl.contains('torrentstream') ||
        widget.videoUrl.contains('torrentstream') ||
        _hasActiveTorrentStream;
    if (isTorrent && _pauseTorrentStreamOnExit) {
      _repository.pauseTorrentStream();
    }

    try {
      _torrentStreamNotifier.reset();
    } catch (_) {}

    _windowManager.dispose(
      onCustomDispose: () {
        try {
          widget.onPlaybackStopped?.call(
            _currentDirectEpisode?.sourceId,
            _position,
            _duration,
          );
        } catch (_) {}
        widget.onDispose?.call();
      },
    );

    if (Platform.isLinux) {
      MprisService.instance.reset();
    }

    // The silent Continue Watching refresh is sequenced by _handleExit after
    // the continuity PATCH, so the feed never shows a live jump on arrival.

    _isPlayingNotifier.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    // Stop pending periodic writes and UI timers before the closing animation;
    // the final flush is scheduled by the window manager after the route is
    // gone.
    _progressManager.cancelPendingWrites();
    _hideTimer?.cancel();
    _seekFeedbackTimer?.cancel();
    _fallbackNoticeTimer?.cancel();
    _seekLoadingTimer?.cancel();

    // Pre-apply the new episode/position while the player still covers the
    // feed. The feed rebuilds behind the closing transition, so it is already
    // correct when revealed (no live "jump" on arrival).
    _applyContinueWatchingOptimistic();
    _progressManager.savePlaybackProgress(force: true);
    try {
      _providerContainer.read(episodeResumeAlignmentProvider.notifier).request();
    } catch (_) {}

    await _windowManager.handleExit(
      context: context,
      onSaveProgress: () async {
        _progressManager.savePlaybackProgress();
      },
      onUpdateUi: () {
        if (mounted) setState(() {});
      },
    );
    _refreshContinueWatchingAfterExit();
  }

  /// Updates the in-memory Continue Watching list before the route closes.
  void _applyContinueWatchingOptimistic() {
    final mediaId = widget.mediaId;
    final episode = _currentEpisodeNumber;
    if (mediaId == null || mediaId <= 0 || episode == null || episode < 1) {
      return;
    }
    try {
      final aniZipEp = _aniZipData?.getEpisode(episode);
      _providerContainer
          .read(continueWatchingProvider.notifier)
          .applyLocalProgress(
            mediaId: mediaId,
            episodeNumber: episode,
            progress: _animeDetails?.progress,
            episodeTitle: _currentEpisodeTitle,
            episodeThumbnail: aniZipEp?.image,
            totalEpisodes: _animeDetails?.totalEpisodes,
          );
    } catch (_) {}
  }

  /// Waits for the continuity PATCH, then refreshes the feed silently.
  Future<void> _refreshContinueWatchingAfterExit() async {
    try {
      await _progressManager.lastContinuityUpdate;
    } catch (_) {}
    try {
      await _providerContainer
          .read(continueWatchingProvider.notifier)
          .refreshFromServer();
    } catch (_) {}
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (_isInteractingWithVolume || _isMenuOpen) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying && !_isInteractingWithVolume && !_isMenuOpen) {
        setState(() => _areControlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (_isTransitioningOrientation || _isPlayerLocked) return;
    setState(() => _areControlsVisible = !_areControlsVisible);
    if (_areControlsVisible) {
      _startHideTimer();
    }
  }

  void _togglePlayerLock() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isPlayerLocked = !_isPlayerLocked;
      if (_isPlayerLocked) {
        _areControlsVisible = false;
        _hideTimer?.cancel();
      } else {
        _areControlsVisible = true;
        _startHideTimer();
      }
    });
  }

  void _onMouseEnter() {
    if (!mounted || _isPlayerLocked) return;
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
    if (!mounted || _isPlayerLocked) return;
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
    if (_isMenuOpen) {
      return;
    }
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

  bool _isEditingText() {
    final ctx = FocusManager.instance.primaryFocus?.context;
    if (ctx == null) return false;
    return ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_isEditingText()) return KeyEventResult.ignored;
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
        : (target > _duration && _duration > Duration.zero
              ? _duration
              : target);

    _position = clamped;
    _positionNotifier.value = clamped;
    _markSeeking();
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
    _publishLiveProgress(force: true);
    _markSeeking();
    _coordinator.seek(target);
    _startHideTimer();
  }

  void _markSeeking() {
    _seekLoadingTimer?.cancel();
    if (!mounted) return;
    setState(() => _isSeeking = true);
    _seekLoadingTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _isSeeking = false);
    });
  }

  void _playOrPause() {
    final shouldPlay = !_isPlaying;
    // Optimistic UI: flip the control right away so the tap responds
    // instantly, then let the player stream confirm the real state.
    _isPlaying = shouldPlay;
    _isPlayingNotifier.value = shouldPlay;
    if (shouldPlay) {
      _coordinator.play();
    } else {
      _coordinator.pause();
    }
    _startHideTimer();
  }

  /// Pushes the real-time position to [livePlaybackProgressProvider] so the
  /// episode rail's cards follow the video smoothly. Throttled to ~4 Hz;
  /// [force] bypasses the throttle (pause, seek, episode change).
  void _publishLiveProgress({bool force = false}) {
    if (_isExiting || _isPlayerDisposed) return;
    final mediaId = widget.mediaId;
    final episode = _currentEpisodeNumber;
    if (mediaId == null || mediaId <= 0 || episode == null || episode < 1) {
      return;
    }
    final durationMs = _duration.inMilliseconds;
    final positionMs = _position.inMilliseconds;
    if (durationMs <= 0) return;

    final bucket = positionMs ~/ _liveProgressBucketMs;
    if (!force && bucket == _liveProgressBucket) return;
    _liveProgressBucket = bucket;

    ref
        .read(livePlaybackProgressProvider.notifier)
        .update(
          mediaId: mediaId,
          episodeNumber: episode,
          positionMs: positionMs,
          durationMs: durationMs,
        );
  }

  void _clearLiveProgress() {
    _liveProgressBucket = -1;
    ref.read(livePlaybackProgressProvider.notifier).clear();
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
      _audioTracks = _audioTracks
          .map((t) => t.copyWith(selected: t.id == track.id))
          .toList();
    });
    _coordinator.selectAudioTrack(track);
    ref
        .read(trackPreferencesProvider.notifier)
        .saveAudioTrack(
          _currentVideoKey,
          id: track.id,
          language: track.language,
        );
  }

  void _selectSubtitleTrack(UiTrack? track) {
    setState(() {
      _selectedSubtitleTrackId = track?.id;
      _currentSubtitleText = '';
      _subtitleTracks = _subtitleTracks
          .map((t) => t.copyWith(selected: t.id == track?.id))
          .toList();
    });
    _coordinator.selectSubtitleTrack(track, _currentExternalSubtitles);
    ref
        .read(trackPreferencesProvider.notifier)
        .saveSubtitleTrack(
          _currentVideoKey,
          id: track?.id,
          language: track?.language,
        );
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
    ref
        .read(torrentProgressOverlayEnabledProvider.notifier)
        .setEnabled(visible);
  }

  void _toggleFullscreen() {
    _windowManager.toggleFullscreen(
      onUpdateUi: () {
        if (mounted) {
          if ((_isFullscreen || _isTvActive) &&
              _layoutMode != PlayerLayoutMode.normal) {
            ref
                .read(playerLayoutModeProvider.notifier)
                .setMode(PlayerLayoutMode.normal);
          }
          setState(() {});
        }
      },
      onOrientationTransitionStarted: () {
        _areControlsVisible = false;
      },
    );
  }

  /// Cycles normal → wide → cinema. Exits fullscreen first so the page chrome
  /// is available again.
  void _cycleLayoutMode() {
    if (_isFullscreen) {
      _toggleFullscreen();
    }
    ref.read(playerLayoutModeProvider.notifier).cycle();
  }

  /// Cached so parent rebuilds (hover, controls visibility, progress ticks)
  /// reuse the exact same widget instance. Recreating it re-created the render
  /// layers every time, which made the glow flash for a frame on hover.
  Widget? _ambientHaloWidget;

  /// Halo painted around the video in normal mode (soft edges).
  Widget? _buildAmbientHalo() {
    final service = _coordinator.mediaKitService;
    if (service == null || _coordinator.isUsingExoPlayer) return null;
    if (!_hasStartedPlayback || _isLoadingNextEpisode || _isExiting) {
      return null;
    }
    return _ambientHaloWidget ??= AmbientVideoGlow(
      controller: service.videoController,
      scrimOpacity: 0,
      softEdges: true,
      // Flutter rasterises the blur at device resolution, so this is effectively
      // in screen pixels. Anything below ~35 leaves the frame recognisable.
      blurSigma: 55,
      opacity: 0.85,
    );
  }

  /// Cached side-bar backdrop for fullscreen / wide / cinema.
  Widget? _ambientBackdropWidget;
  PlayerFitMode? _ambientBackdropFitMode;

  Widget? _buildAmbientBackdrop() {
    final service = _coordinator.mediaKitService;
    if (service == null || _coordinator.isUsingExoPlayer) return null;
    if (!_hasStartedPlayback || _isLoadingNextEpisode || _isExiting) {
      return null;
    }
    if (_ambientBackdropWidget == null ||
        _ambientBackdropFitMode != _fitMode) {
      _ambientBackdropFitMode = _fitMode;
      _ambientBackdropWidget = AmbientVideoSideGlow(
        controller: service.videoController,
        fitMode: _fitMode,
        scrimOpacity: 0.35,
        blurSigma: 55,
        opacity: 0.9,
      );
    }
    return _ambientBackdropWidget;
  }

  void _openEpisodesSheet() {
    PlayerEpisodesSheet.show(
      context: context,
      animeTitle: widget.title,
      mediaId: widget.mediaId,
      episodes: _railEpisodes,
      aniZipData: _aniZipData ?? _animeDetails?.aniZipData,
      currentEpisodeNumber: _currentEpisodeNumber,
      isMovie: _isMovie,
      onSelectEpisode: (n) {
        if (n == _currentEpisodeNumber) return;
        _sourceController.playEpisode(
          targetEpNum: n,
          onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
        );
      },
    );
  }

  /// Captures the current video frame as image bytes for comments.
  Future<Uint8List?> _captureFrame() async {
    final service = _coordinator.mediaKitService;
    if (service == null) return null;

    // Prefer a software screenshot so hardware decoding doesn't break it.
    try {
      final platform = service.player.platform;
      if (platform is NativePlayer) {
        await platform.setProperty('screenshot-sw', 'yes');
      }
    } catch (_) {}

    try {
      final bytes = await service.player.screenshot(format: 'image/jpeg');
      if (bytes != null && bytes.isNotEmpty) return bytes;
    } catch (_) {}

    // Fallback: capture the rendered video widget layer.
    try {
      final boundary = _videoCaptureKey.currentContext?.findRenderObject();
      if (boundary is RenderRepaintBoundary) {
        final image = await boundary.toImage(pixelRatio: 1.5);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      }
    } catch (_) {}

    return null;
  }

  /// Episode list for the desktop right rail (falls back to 1..total).
  List<AnimeEpisode> get _railEpisodes =>
      PlayerEpisodeResolver.buildRailEpisodes(
        animeDetails: _animeDetails,
        episodeNumberLabel: (epNum) =>
            ref.read(translationsProvider).episodeNumber(epNum),
      );

  String? _getVideoSourceLabel() {
    if (_currentVideoSource != null && _currentVideoSource!.isNotEmpty) {
      return _currentVideoSource;
    }
    if (widget.videoSource != null && widget.videoSource!.isNotEmpty) {
      return widget.videoSource;
    }
    if (_currentVideoUrl.startsWith('http://') ||
        _currentVideoUrl.startsWith('https://')) {
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
      isSidePanelCollapsed: _layoutMode == PlayerLayoutMode.cinema,
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
    final layoutMode = ref.read(playerLayoutModeProvider);
    final needsTitleBarInset =
        isDesktop &&
        !isFullscreen &&
        (layoutMode == PlayerLayoutMode.wide ||
            layoutMode == PlayerLayoutMode.cinema);
    // In the normal desktop page the soft halo is painted by
    // [PlayerDesktopLayout] around the video. Everywhere else (fullscreen,
    // wide, cinema, mobile) the blurred frame sits behind the video so the
    // letterbox bars take its colours.
    final useAmbientBackdrop =
        ref.read(playerAmbientGlowProvider) &&
        (!isDesktop || isFullscreen || layoutMode != PlayerLayoutMode.normal);

    return PlayerViewport(
      isUsingExoPlayer: _coordinator.isUsingExoPlayer,
      mediaKitPlayerService: _coordinator.mediaKitService,
      ambientBackdrop: useAmbientBackdrop ? _buildAmbientBackdrop() : null,
      fitMode: _fitMode,
      selectedSubtitleTrackId: _selectedSubtitleTrackId,
      currentSubtitleText: _currentSubtitleText,
      areControlsVisible: _areControlsVisible,
      isTransitioningOrientation: _isTransitioningOrientation,
      isExiting: _isExiting,
      isPlayerLocked: _isPlayerLocked,
      onTogglePlayerLock: _togglePlayerLock,
      topUiInset: needsTitleBarInset ? DesktopTitleBar.height : 0,
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
          if (_isMouseInside && !_isMenuOpen) {
            _startHideTimer();
          } else if (!_isMouseInside && !_isMenuOpen) {
            if (_areControlsVisible) {
              setState(() => _areControlsVisible = false);
            }
          }
        }
      },
      onMenuOpenChanged: (open) {
        _isMenuOpen = open;
        if (open) {
          _hideTimer?.cancel();
          if (!_areControlsVisible) {
            setState(() => _areControlsVisible = true);
          }
        } else {
          if (_isMouseInside) {
            _startHideTimer();
          }
        }
      },
      audioTracks: _audioTracks,
      subtitleTracks: _subtitleTracks,
      selectedAudioTrackId: _selectedAudioTrackId,
      onAudioTrackSelected: _selectAudioTrack,
      onSubtitleTrackSelected: _selectSubtitleTrack,
      brightness: _brightness,
      onBrightnessChanged: _setBrightness,
      isBuffering: _isBuffering,
      isLoadingNextEpisode: _isLoadingNextEpisode || _isResolvingSources,
      showLoadingOverlay:
          !_hasStartedPlayback &&
          !_isSeeking &&
          (_isPreparingEngine ||
              _isBuffering ||
              _isLoadingNextEpisode ||
              _isResolvingSources),
      loadingMessage: _isPreparingEngine
          ? ref.read(translationsProvider).loadingVideo
          : switch (_playbackOrigin) {
              PlayerPlaybackOrigin.online =>
                _isBuffering
                    ? ref.read(translationsProvider).bufferingVideo
                    : ref.read(translationsProvider).loadingVideo,
              PlayerPlaybackOrigin.torrent =>
                ref.read(translationsProvider).downloadingMetadata,
              PlayerPlaybackOrigin.mediaServer =>
                ref.read(translationsProvider).bufferingVideo,
              PlayerPlaybackOrigin.local => '',
            },
      loadingTitle:
          _currentEpisodeTitle ??
          (_currentEpisodeNumber != null
              ? ref
                    .read(translationsProvider)
                    .episodeNumber(_currentEpisodeNumber!)
              : widget.title),
      loadingBackgroundImage: _effectiveLoadingBackground,
      loadingLogoImage: _effectiveLoadingLogo,
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
      onToggleTheaterMode: (isDesktop && !isFullscreen)
          ? _cycleLayoutMode
          : null,
      isTheaterMode: _layoutMode == PlayerLayoutMode.cinema,
      layoutMode: _layoutMode,
      // In wide mode the page header is gone, so the video overlay owns the
      // "episodes" button for bringing a hidden rail back.
      onShowEpisodes: !ref.watch(playerEpisodesRailVisibleProvider)
          ? () => ref
                .read(playerEpisodesRailVisibleProvider.notifier)
                .setVisible(true)
          : null,
      captureKey: _videoCaptureKey,
      positionNotifier: _positionNotifier,
      bufferNotifier: _bufferNotifier,
      duration: _duration,
      isPlaying: _isPlayingNotifier,
      hasNextEpisode: _hasNextEpisode && !_isLoadingNextEpisode,
      onNextEpisode: (_hasNextEpisode && !_isLoadingNextEpisode)
          ? () => _sourceController.playEpisode(
              targetEpNum: (_currentEpisodeNumber ?? 1) + 1,
              onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
            )
          : null,
      onPreviousEpisode: (_hasPreviousEpisode && !_isLoadingNextEpisode)
          ? () => _sourceController.playEpisode(
              targetEpNum: (_currentEpisodeNumber ?? 1) - 1,
              onEpisodeTransitionStarted: _onEpisodeTransitionStarted,
            )
          : null,
    );
  }

  Widget _buildDesktopPageHeader(BuildContext context) {
    return PlayerDesktopHeader(title: widget.title, onBack: _handleExit);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    final isFullscreen = _isFullscreen || _isTvActive;
    final layoutMode = ref.watch(playerLayoutModeProvider);
    final ambientGlowEnabled = ref.watch(playerAmbientGlowProvider);
    final showEpisodeRail = ref.watch(playerEpisodesRailVisibleProvider);

    // Keep dispose() safe: cache the values it needs while the widget is alive.
    _hasActiveTorrentStream = ref.watch(torrentStreamStatusProvider) != null;
    _pauseTorrentStreamOnExit = ref
        .watch(streamingPreferencesProvider)
        .pauseTorrentStreamOnExit;

    final mq = MediaQuery.of(context);
    final isPhysicalLandscape = mq.orientation == Orientation.landscape;

    // Mobile orientation stabilization:
    // When returning from fullscreen to screen corta (embedded portrait), ignore intermediate landscape
    // frames where device rotation is still animating. Rendering fullscreen player viewport until
    // physical portrait orientation actually arrives prevents the 16:9 AspectRatio Column from
    // overflowing the landscape display bounds and violently disrupting controls layout.
    final bool effectiveFullscreen =
        isFullscreen || (!isDesktop && isPhysicalLandscape);

    // Keep Android ExoPlayer surface layout perfectly synchronized with Flutter's container
    if (Platform.isAndroid && _coordinator.isUsingExoPlayer) {
      _windowManager.updateExoSurfaceBounds(
        context,
        effectiveFullscreen: effectiveFullscreen,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _windowManager.updateExoSurfaceBounds(
            context,
            effectiveFullscreen: effectiveFullscreen,
          );
        }
      });
    }

    // media_kit renders into Flutter's texture, so the route must stay opaque.
    // ExoPlayer instead renders to a native SurfaceView placed *behind* the
    // Flutter window: an opaque route would cover the video completely, so the
    // route must be transparent while the native engine is active.
    final usesNativeVideoSurface =
        Platform.isAndroid && _coordinator.isUsingExoPlayer;
    final scaffoldBg = usesNativeVideoSurface
        ? Colors.transparent
        : theme.colorScheme.surface;

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
                    cursor:
                        (isDesktop &&
                            effectiveFullscreen &&
                            !_areControlsVisible &&
                            _isMouseInside)
                        ? SystemMouseCursors.none
                        : SystemMouseCursors.basic,
                    onEnter: (isDesktop && effectiveFullscreen)
                        ? (_) => _onMouseEnter()
                        : null,
                    onHover: (isDesktop && effectiveFullscreen)
                        ? (_) => _onMouseMove()
                        : null,
                    onExit: (isDesktop && effectiveFullscreen)
                        ? (_) => _onMouseExit()
                        : null,
                    child: isDesktop
                        ? (effectiveFullscreen
                              ? _buildPlayerViewport(
                                  context,
                                  isFullscreen: true,
                                  isDesktop: true,
                                )
                              : PlayerDesktopLayout(
                                  layoutMode: layoutMode,
                                  showEpisodeRail: showEpisodeRail,
                                  ambientHalo:
                                      ambientGlowEnabled &&
                                          layoutMode == PlayerLayoutMode.normal
                                      ? _buildAmbientHalo()
                                      : null,
                                  pageHeader: _buildDesktopPageHeader(context),
                                  viewport: _buildPlayerViewport(
                                    context,
                                    isFullscreen: false,
                                    isDesktop: true,
                                  ),
                                  watchContent: PlayerWatchContent(
                                    mediaId: widget.mediaId,
                                    animeTitle: widget.title,
                                    episodeNumber: _currentEpisodeNumber,
                                    episodeTitle: _currentEpisodeTitle,
                                    animeDetails: _animeDetails,
                                    aniZipData:
                                        _aniZipData ??
                                        _animeDetails?.aniZipData,
                                    chapters: _chapters,
                                    activeChapter: _activeChapter,
                                    onSeekToChapter: _seekTo,
                                    showComments: _showComments,
                                    positionNotifier: _positionNotifier,
                                    captureFrame:
                                        _coordinator.mediaKitService != null
                                        ? _captureFrame
                                        : null,
                                    headerTrailing: PlayerHeaderControls(
                                      showSource: _playbackOrigin.isSwitchable,
                                      sources: _availableSources,
                                      activeSource: _activeSource,
                                      isResolvingSources: _isResolvingSources,
                                      providerName:
                                          _currentOnlineStreamProvider,
                                      isDubbed:
                                          _currentOnlineStreamDubbed ?? false,
                                      isTorrentStream:
                                          _hasActiveTorrentStream ||
                                          (_activeSource?.isTorrent ?? false) ||
                                          _currentVideoUrl.contains(
                                            'torrentstream',
                                          ),
                                      onToggleDubbed: _toggleOnlineStreamDubbed,
                                      onReloadSources: () => _sourceController
                                          .resolveInitialSources(
                                            preservePosition: true,
                                          ),
                                      onSelectSource:
                                          _sourceController.selectSource,
                                      onSelectProvider:
                                          _switchOnlineStreamProvider,
                                    ),
                                  ),
                                  episodesRail: _isMovie
                                      ? PlayerMovieRail(details: _animeDetails)
                                      : PlayerEpisodesRail(
                                          animeTitle: widget.title,
                                          mediaId: widget.mediaId,
                                          episodes: _railEpisodes,
                                          aniZipData:
                                              _aniZipData ??
                                              _animeDetails?.aniZipData,
                                          currentEpisodeNumber:
                                              _currentEpisodeNumber,
                                          isMovie: _isMovie,
                                          independentScroll: true,
                                          onHide: () => ref
                                              .read(
                                                playerEpisodesRailVisibleProvider
                                                    .notifier,
                                              )
                                              .setVisible(false),
                                          onSelectEpisode: (n) {
                                            if (n == _currentEpisodeNumber) {
                                              return;
                                            }
                                            _sourceController.playEpisode(
                                              targetEpNum: n,
                                              onEpisodeTransitionStarted:
                                                  _onEpisodeTransitionStarted,
                                            );
                                          },
                                        ),
                                  onShowEpisodes:
                                      (!showEpisodeRail ||
                                          (!_isMovie &&
                                              _railEpisodes.isNotEmpty))
                                      ? () {
                                          if (!showEpisodeRail) {
                                            ref
                                                .read(
                                                  playerEpisodesRailVisibleProvider
                                                      .notifier,
                                                )
                                                .setVisible(true);
                                            return;
                                          }
                                          _openEpisodesSheet();
                                        }
                                      : null,
                                  hideCursorOnVideo:
                                      !_areControlsVisible && _isMouseInside,
                                  onVideoEnter: _onMouseEnter,
                                  onVideoHover: _onMouseMove,
                                  onVideoExit: _onMouseExit,
                                ))
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
                                    aniZipData:
                                        _aniZipData ??
                                        _animeDetails?.aniZipData,
                                    isLoading: _isLoadingDetails,
                                    isDesktop: false,
                                    chapters: _chapters,
                                    activeChapter: _activeChapter,
                                    onSeekToChapter: _seekTo,
                                    hasNextEpisode: _hasNextEpisode,
                                    onPlayNextEpisode:
                                        (_hasNextEpisode &&
                                            !_isLoadingNextEpisode)
                                        ? () => _sourceController.playEpisode(
                                            targetEpNum:
                                                (_currentEpisodeNumber ?? 1) +
                                                1,
                                            onEpisodeTransitionStarted:
                                                _onEpisodeTransitionStarted,
                                          )
                                        : null,
                                    onPlayPreviousEpisode:
                                        (_hasPreviousEpisode &&
                                            !_isLoadingNextEpisode)
                                        ? () => _sourceController.playEpisode(
                                            targetEpNum:
                                                (_currentEpisodeNumber ?? 1) -
                                                1,
                                            onEpisodeTransitionStarted:
                                                _onEpisodeTransitionStarted,
                                          )
                                        : null,
                                    sourceController: _sourceController,
                                    playbackOrigin: _playbackOrigin,
                                    showComments: _showComments,
                                    isResolvingSources: _isResolvingSources,
                                    availableSources: _availableSources,
                                    activeSource: _activeSource,
                                    sourceResolutionError:
                                        _sourceResolutionError,
                                    onlineStreamProvider:
                                        _currentOnlineStreamProvider,
                                    isDubbed:
                                        _currentOnlineStreamDubbed ?? false,
                                    onToggleDubbed: _toggleOnlineStreamDubbed,
                                    onReloadSources: () =>
                                        _sourceController.resolveInitialSources(
                                          preservePosition: true,
                                        ),
                                    onSelectSource:
                                        _sourceController.selectSource,
                                    onSelectProvider:
                                        _switchOnlineStreamProvider,
                                  ),
                                )),
                  ),
                ),
        ),
      ),
    );
  }
}
