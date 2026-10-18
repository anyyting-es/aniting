import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_tv_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_details_modal_sheet.dart';
import 'package:seanime_app/presentation/widgets/edit_entry_modal.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector_sheet.dart';

export 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart'
    show AnimeDetailTab;

class AnimeDetailScreen extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final bool initialLocalMode;
  final bool? isTmdb;
  final Object? heroTag;

  const AnimeDetailScreen({
    super.key,
    required this.mediaId,
    this.initialEntry,
    this.initialLocalMode = false,
    this.isTmdb,
    this.heroTag,
  });

  /// Opens the AnimeDetailScreen with a smooth, cinematic transition.
  static Future<T?> navigate<T>(
    BuildContext context, {
    required int mediaId,
    AnimeEntry? initialEntry,
    bool initialLocalMode = false,
    bool? isTmdb,
    Object? heroTag,
  }) {
    final resolvedIsTmdb = isTmdb ?? (initialEntry?.isTmdb ?? false);
    return Navigator.push<T>(
      context,
      SmoothPageRoute(
        child: AnimeDetailScreen(
          mediaId: mediaId,
          initialEntry: initialEntry,
          initialLocalMode: initialLocalMode,
          isTmdb: resolvedIsTmdb,
          heroTag: heroTag,
        ),
      ),
    );
  }

  @override
  ConsumerState<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends ConsumerState<AnimeDetailScreen> {
  AnimeDetails? _details;
  AniZipData? _aniZipData;
  bool _isLoading = true;
  bool _isLoadingAniZip = true;
  bool _isLocalMode = false;
  bool _hasLocalFiles = false;
  bool _userManuallyChangedMode = false;
  AnimeDetailTab _currentTab = AnimeDetailTab.online;

  bool get isTmdb => widget.isTmdb ?? (widget.initialEntry?.isTmdb ?? false);

  static const _prefModePrefix = 'pref_anime_detail_mode_';
  static const _prefGlobalLastMode = 'pref_anime_detail_last_mode';

  final ScrollController _scrollController = SmoothScrollController();

  @override
  void initState() {
    super.initState();
    if (isTmdb) {
      _hasLocalFiles = false;
      _isLocalMode = false;
      _isLoadingAniZip = false;
      if (widget.initialEntry != null) {
        _details = AnimeDetails(
          id: widget.mediaId,
          title: widget.initialEntry!.title,
          englishTitle: widget.initialEntry!.englishTitle,
          romajiTitle: widget.initialEntry!.romajiTitle,
          nativeTitle: widget.initialEntry!.nativeTitle,
          coverImage: widget.initialEntry!.coverImage,
          coverColor: widget.initialEntry!.coverColor,
          bannerImage: widget.initialEntry!.bannerImage,
          description: widget.initialEntry!.description,
          totalEpisodes: widget.initialEntry!.totalEpisodes,
          format: widget.initialEntry!.format,
          score: widget.initialEntry!.score,
          status: widget.initialEntry!.status,
          isTmdb: true,
        );
        _isLoading = false;
      }
    } else {
      final initialHasLocal = widget.initialLocalMode ||
          (widget.initialEntry?.hasLocalFiles ?? false) ||
          ((widget.initialEntry?.mainFileCount ?? 0) > 0);
      _hasLocalFiles = initialHasLocal;
      if (widget.initialLocalMode || initialHasLocal) {
        _isLocalMode = true;
      }

      final repo = ref.read(repositoryProvider);

      // Fast checks: downloadedAnimeProvider, animeCollectionProvider, animeLibraryEntryProvider caches
      if (!_hasLocalFiles) {
        final downloadedAnime =
            ref.read(downloadedAnimeProvider).asData?.value ?? [];
        if (downloadedAnime.any((e) => e.mediaId == widget.mediaId)) {
          _hasLocalFiles = true;
          _isLocalMode = true;
        }
      }
      if (!_hasLocalFiles) {
        final collection = ref.read(animeCollectionProvider).asData?.value ?? [];
        final collEntry =
            collection.where((e) => e.mediaId == widget.mediaId).firstOrNull;
        if (collEntry != null &&
            (collEntry.hasLocalFiles || collEntry.mainFileCount > 0)) {
          _hasLocalFiles = true;
          _isLocalMode = true;
        }
      }
      if (!_hasLocalFiles) {
        final libEntryCache =
            repo.getCachedAnimeLibraryEntry(widget.mediaId) ??
            ref.read(animeLibraryEntryProvider(widget.mediaId)).asData?.value;
        if (libEntryCache != null &&
            (libEntryCache.hasLibraryData ||
                libEntryCache.episodes.any((e) => e.isDownloaded))) {
          _hasLocalFiles = true;
          _isLocalMode = true;
        }
      }

      // Pre-populate details and aniZip on frame 0 from repository in-memory cache or initialEntry
      final cachedDetails = repo.getCachedAnimeDetails(widget.mediaId);
      if (cachedDetails != null) {
        _details = cachedDetails;
        _isLoading = false;
      } else if (widget.initialEntry != null) {
        _details = AnimeDetails(
          id: widget.mediaId,
          title: widget.initialEntry!.title,
          englishTitle: widget.initialEntry!.englishTitle,
          romajiTitle: widget.initialEntry!.romajiTitle,
          nativeTitle: widget.initialEntry!.nativeTitle,
          coverImage: widget.initialEntry!.coverImage,
          coverColor: widget.initialEntry!.coverColor,
          bannerImage: widget.initialEntry!.bannerImage,
          description: widget.initialEntry!.description,
          totalEpisodes: widget.initialEntry!.totalEpisodes,
          format: widget.initialEntry!.format,
          score: widget.initialEntry!.score,
          status: widget.initialEntry!.status,
        );
        _isLoading = false;
      }

      final cachedAniZip = repo.getCachedAniZipData(widget.mediaId);
      if (cachedAniZip != null) {
        _aniZipData = cachedAniZip;
        _isLoadingAniZip = false;
      }
    }

    _restoreSavedMode();
    _loadDetails();
  }

  Future<void> _restoreSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final perMediaSaved = prefs.getString('$_prefModePrefix${widget.mediaId}');
      final globalSaved = prefs.getString(_prefGlobalLastMode);

      if (mounted) {
        setState(() {
          if (perMediaSaved != null) {
            _userManuallyChangedMode = true;
            if (perMediaSaved == 'local' && (_hasLocalFiles || widget.initialLocalMode)) {
              _isLocalMode = true;
            } else if (perMediaSaved == 'torrent') {
              _isLocalMode = false;
              _currentTab = AnimeDetailTab.torrent;
            } else if (perMediaSaved == 'online') {
              _isLocalMode = false;
              _currentTab = AnimeDetailTab.online;
            }
          } else if (_hasLocalFiles || widget.initialLocalMode) {
            _isLocalMode = true;
          } else if (globalSaved != null) {
            if (globalSaved == 'torrent') {
              _isLocalMode = false;
              _currentTab = AnimeDetailTab.torrent;
            } else if (globalSaved == 'online') {
              _isLocalMode = false;
              _currentTab = AnimeDetailTab.online;
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _saveMode(String mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefModePrefix${widget.mediaId}', mode);
      await prefs.setString(_prefGlobalLastMode, mode);
    } catch (_) {}
  }

  void _selectMode(String mode) {
    setState(() {
      _userManuallyChangedMode = true;
      if (mode == 'local') {
        _isLocalMode = true;
      } else if (mode == 'torrent') {
        _isLocalMode = false;
        _currentTab = AnimeDetailTab.torrent;
      } else if (mode == 'online') {
        _isLocalMode = false;
        _currentTab = AnimeDetailTab.online;
      }
    });
    _saveMode(mode);
  }

  void _changeTab(AnimeDetailTab tab) {
    setState(() {
      _userManuallyChangedMode = true;
      _isLocalMode = false;
      _currentTab = tab;
    });
    _saveMode(tab == AnimeDetailTab.torrent ? 'torrent' : 'online');
  }

  void _toggleLocalMode() {
    setState(() {
      _userManuallyChangedMode = true;
      _isLocalMode = !_isLocalMode;
    });
    final mode = _isLocalMode
        ? 'local'
        : (_currentTab == AnimeDetailTab.torrent ? 'torrent' : 'online');
    _saveMode(mode);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    if (isTmdb) {
      final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
      final lang = isSpanish ? 'es-ES' : 'en-US';
      final isMovie = (widget.initialEntry?.format == 'MOVIE') || (_details?.format == 'MOVIE');
      final tmdbService = ref.read(tmdbServiceProvider);
      final showDetails = await tmdbService.getShowDetails(
        widget.mediaId,
        language: lang,
        isMovie: isMovie,
      );
      if (mounted) {
        setState(() {
          if (showDetails != null) {
            _details = showDetails.toAnimeDetails();
          }
          _isLoading = false;
          _isLoadingAniZip = false;
        });
      }
      return;
    }
    final repo = ref.read(repositoryProvider);

    AnimeDetails? details = _details ??
        (widget.initialEntry != null
            ? AnimeDetails(
                id: widget.mediaId,
                title: widget.initialEntry!.title,
                englishTitle: widget.initialEntry!.englishTitle,
                romajiTitle: widget.initialEntry!.romajiTitle,
                nativeTitle: widget.initialEntry!.nativeTitle,
                coverImage: widget.initialEntry!.coverImage,
                coverColor: widget.initialEntry!.coverColor,
                bannerImage: widget.initialEntry!.bannerImage,
                description: widget.initialEntry!.description,
                totalEpisodes: widget.initialEntry!.totalEpisodes,
                format: widget.initialEntry!.format,
                score: widget.initialEntry!.score,
                status: widget.initialEntry!.status,
              )
            : null);

    final fetchedDetails = await repo.getAnimeDetails(
      widget.mediaId,
      initialEntry: widget.initialEntry,
    );
    if (fetchedDetails != null) {
      details = fetchedDetails;
    }

    // Check local files in library
    final libEntry = await repo.getAnimeLibraryEntry(widget.mediaId);
    final hasDownloadedFiles = libEntry != null &&
        (libEntry.hasLibraryData ||
            libEntry.episodes.any((e) => e.isDownloaded));

    if (mounted) {
      setState(() {
        _details = details;
        _isLoading = false;
        if (hasDownloadedFiles) {
          _hasLocalFiles = true;
          if (!_userManuallyChangedMode) {
            _isLocalMode = true;
          }
        }
      });
    }

    if (_aniZipData == null) {
      final aniZip = await repo.getAniZipData(widget.mediaId);
      if (mounted) {
        setState(() {
          _aniZipData = aniZip;
          _isLoadingAniZip = false;
        });
      }
    }
  }

  Future<void> _retryAniZip() async {
    setState(() {
      _isLoadingAniZip = true;
    });
    final repo = ref.read(repositoryProvider);
    final aniZip = await repo.getAniZipData(widget.mediaId);
    if (mounted) {
      setState(() {
        _aniZipData = aniZip;
        _isLoadingAniZip = false;
      });
    }
  }

  void _openEditEntryModal(String title) {
    if (isTmdb) return;
    final liveEntry = ref.read(animeCollectionProvider).whenOrNull(
          data: (entries) => entries
              .where((e) => e.mediaId == widget.mediaId)
              .firstOrNull,
        );
    final entry = liveEntry ?? widget.initialEntry;

    final progress = entry?.progress ?? _details?.progress ?? 0;
    final status = entry?.status ?? _details?.userStatus ?? _details?.status;
    final score = _details?.userScore ?? entry?.score;
    final totalEps = _details?.totalEpisodes ?? entry?.totalEpisodes;
    final isEntryInList = entry != null || _details?.progress != null;

    EditEntryModal.show(
      context: context,
      mediaId: widget.mediaId,
      title: title,
      type: 'anime',
      initialStatus: status,
      initialScore: score,
      initialProgress: progress,
      totalCount: totalEps,
      isEntryInList: isEntryInList,
    ).then((updated) {
      if (updated == true && mounted) {
        ref.invalidate(animeCollectionProvider);
        ref.invalidate(continueWatchingProvider);
        _loadDetails();
      }
    });
  }

  void _openDetailsModal() {
    AnimeDetailsModalSheet.show(
      context: context,
      mediaId: widget.mediaId,
      animeDetails: _details,
    );
  }

  Future<void> _openTorrentSelector({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 768;
    final launchInfo = await (isDesktop
        ? showDialog<TorrentStreamLaunchInfo>(
            context: context,
            useRootNavigator: true,
            barrierColor: Colors.black.withValues(alpha: 0.75),
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: TorrentSelectorSheet(
                mediaId: widget.mediaId,
                episodeNumber: episodeNumber,
                episodeTitle: episodeTitle,
                animeDetails: _details,
                aniDBEpisode: aniDBEpisode,
              ),
            ),
          )
        : showGlassSheet<TorrentStreamLaunchInfo>(
            context: context,
            showGrabber: true,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.60,
            ),
            builder: (ctx) => TorrentSelectorSheet(
              mediaId: widget.mediaId,
              episodeNumber: episodeNumber,
              episodeTitle: episodeTitle,
              animeDetails: _details,
              aniDBEpisode: aniDBEpisode,
              isSheet: true,
            ),
          ));

    if (launchInfo != null && mounted) {
      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: launchInfo.mediaId,
          videoUrl: launchInfo.videoUrl,
          title: launchInfo.title,
          episodeTitle: launchInfo.episodeTitle,
          episodeNumber: launchInfo.episodeNumber,
          videoSource: launchInfo.videoSource,
          onDispose: launchInfo.onDispose,
          animeDetails: _details,
          aniZipData: _details?.aniZipData,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeSettings = ref.watch(themeProvider);
    final hexColor = _details?.coverColor ?? widget.initialEntry?.coverColor;

    final baseTheme = Theme.of(context);
    ThemeData effectiveTheme = baseTheme;
    if (themeSettings.animeDynamicTheme && hexColor != null) {
      final parsedColor = parseHexColor(hexColor);
      if (parsedColor != null) {
        final isDark = baseTheme.brightness == Brightness.dark;
        final isOled = themeSettings.isOled && isDark;
        final colorScheme = ColorScheme.fromSeed(
          seedColor: parsedColor,
          brightness: baseTheme.brightness,
          surface: isOled ? Colors.black : null,
        );
        effectiveTheme = baseTheme.copyWith(
          colorScheme: colorScheme,
          scaffoldBackgroundColor: isOled ? Colors.black : colorScheme.surface,
        );
      }
    }

    final layoutPref = ref.watch(layoutModeProvider);
    final effectiveLayout = LayoutModeNotifier.resolve(context, layoutPref);

    final libraryEntryAsync = ref.watch(animeLibraryEntryProvider(widget.mediaId));
    final hasLibFiles = libraryEntryAsync.asData?.value != null &&
        (libraryEntryAsync.asData!.value!.hasLibraryData ||
            libraryEntryAsync.asData!.value!.episodes.any((e) => e.isDownloaded));
    final effectiveHasLocal = _hasLocalFiles || hasLibFiles;

    if (hasLibFiles && !_hasLocalFiles) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasLocalFiles = true;
            if (!_userManuallyChangedMode) {
              _isLocalMode = true;
            }
          });
        }
      });
    }

    return Theme(
      data: effectiveTheme,
      child: M3ETheme(
        data: effectiveTheme.brightness == Brightness.dark
            ? M3EThemeData.dark(seedColor: effectiveTheme.colorScheme.primary)
            : M3EThemeData.light(seedColor: effectiveTheme.colorScheme.primary),
        child: Builder(
        builder: (context) {
          switch (effectiveLayout) {
            case LayoutMode.desktop:
              return AnimeDetailDesktopLayout(
                mediaId: widget.mediaId,
                initialEntry: widget.initialEntry,
                heroTag: widget.heroTag,
                details: _details,
                aniZipData: _aniZipData,
                isLoading: _isLoading,
                isLoadingAniZip: _isLoadingAniZip,
                isLocalMode: _isLocalMode,
                hasLocalFiles: effectiveHasLocal,
                currentTab: _currentTab,
                onToggleLocalMode: _toggleLocalMode,
                onTabChanged: _changeTab,
                onModeChanged: _selectMode,
                onOpenEditEntryModal: _openEditEntryModal,
                onRetryAniZip: _retryAniZip,
                onOpenTorrentSelector: _openTorrentSelector,
                onOpenDetailsModal: _openDetailsModal,
              );

            case LayoutMode.tv:
              return AnimeDetailTvLayout(
                mediaId: widget.mediaId,
                initialEntry: widget.initialEntry,
                details: _details,
                aniZipData: _aniZipData,
                isLoading: _isLoading,
                isLoadingAniZip: _isLoadingAniZip,
                isLocalMode: _isLocalMode,
                hasLocalFiles: effectiveHasLocal,
                currentTab: _currentTab,
                onToggleLocalMode: _toggleLocalMode,
                onTabChanged: _changeTab,
                onOpenEditEntryModal: _openEditEntryModal,
                onRetryAniZip: _retryAniZip,
                onOpenTorrentSelector: _openTorrentSelector,
                onOpenDetailsModal: _openDetailsModal,
              );

            case LayoutMode.auto:
            case LayoutMode.mobile:
              return Scaffold(
                extendBodyBehindAppBar: true,
                body: AnimeDetailMobileLayout(
                  mediaId: widget.mediaId,
                  initialEntry: widget.initialEntry,
                  heroTag: widget.heroTag,
                  details: _details,
                  aniZipData: _aniZipData,
                  isLoading: _isLoading,
                  isLoadingAniZip: _isLoadingAniZip,
                  isLocalMode: _isLocalMode,
                  hasLocalFiles: effectiveHasLocal,
                  currentTab: _currentTab,
                  scrollController: _scrollController,
                  onToggleLocalMode: _toggleLocalMode,
                  onTabChanged: _changeTab,
                  onOpenEditEntryModal: _openEditEntryModal,
                  onRetryAniZip: _retryAniZip,
                  onOpenTorrentSelector: _openTorrentSelector,
                  onOpenDetailsModal: _openDetailsModal,
                ),
              );
          }
        },
      ),
      ),
    );
  }
}
