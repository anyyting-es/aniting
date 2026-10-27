import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/preferences/layout_mode_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/tmdb_preferences_provider.dart';
import 'package:seanime_app/data/services/tmdb_service.dart';
import 'package:seanime_app/data/services/tmdb_mapping_service.dart';
import 'package:seanime_app/data/services/custom_anime_assets_service.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart';
import 'package:seanime_app/presentation/widgets/anime_detail/anime_detail_mobile_layout.dart';
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

  static SharedPreferences? _cachedPrefs;
  static void setCachedPrefs(SharedPreferences prefs) => _cachedPrefs = prefs;

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
  /// The final resolved logo URL – set once when all data is ready, never changed.
  String? _resolvedLogoUrl;
  /// The final resolved banner/backdrop URL – set once, never changed.
  String? _resolvedBannerUrl;
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
        _isLoading = true;
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
          if (widget.initialLocalMode) {
            _isLocalMode = true;
          }
        }
      }

      if (!_hasLocalFiles) {
        final history = ref.read(downloadHistoryProvider);
        if (history.any((item) =>
            item.mediaId == widget.mediaId &&
            item.filePath != null &&
            item.filePath!.isNotEmpty)) {
          _hasLocalFiles = true;
          if (widget.initialLocalMode) {
            _isLocalMode = true;
          }
        }
      }

      // Synchronously restore saved mode from memory cache on frame 0
      final prefs = AnimeDetailScreen._cachedPrefs;
      if (prefs != null) {
        final perMediaSaved = prefs.getString('$_prefModePrefix${widget.mediaId}');
        final globalSaved = prefs.getString(_prefGlobalLastMode);
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
        } else if (widget.initialLocalMode) {
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
      }

      // Pre-populate details and aniZip from repository cache for fast-data,
      // but keep _isLoading = true until TMDB assets and fallbacks are completely resolved.
      final cachedDetails = repo.getCachedAnimeDetails(widget.mediaId);
      if (cachedDetails != null) {
        _details = cachedDetails;
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
          genres: widget.initialEntry!.genres,
          season: widget.initialEntry!.season,
          seasonYear: widget.initialEntry!.year,
        );
      }
      _isLoading = true;

      final customAssets = CustomAnimeAssetsService.getAssets(widget.mediaId);
      if (customAssets != null) {
        if (customAssets.logo != null && customAssets.logo!.isNotEmpty) {
          _resolvedLogoUrl = customAssets.logo;
        }
        if (customAssets.background != null && customAssets.background!.isNotEmpty) {
          _resolvedBannerUrl = customAssets.background;
        }
      }

      final cachedAniZip = repo.getCachedAniZipData(widget.mediaId);
      if (cachedAniZip != null) {
        _aniZipData = cachedAniZip;
        _isLoadingAniZip = false;
        final mapping = TmdbMappingService.getMapping(widget.mediaId);
        final isTmdbMedia = widget.isTmdb ?? widget.initialEntry?.isTmdb ?? false;
        final parsedTmdb = int.tryParse(cachedAniZip.mappings?.themoviedbId ?? '');
        final tvdb = (mapping?.tvdbId != null && mapping!.tvdbId > 0)
            ? mapping.tvdbId
            : cachedAniZip.mappings?.thetvdbId;
        final tmdbId = mapping?.tmdbId ?? parsedTmdb ?? (isTmdbMedia ? widget.mediaId : null);
        if ((_resolvedLogoUrl == null || _resolvedBannerUrl == null) && (tmdbId != null || tvdb != null)) {
          final isMovie = mapping?.isMovie ??
              ((widget.initialEntry?.format?.toUpperCase() == 'MOVIE') ||
                  (cachedDetails?.format?.toUpperCase() == 'MOVIE'));
          final currentLang = ref.read(appLanguageProvider).code;
          final cachedAssets = TmdbService.getCachedAssets(
            tmdbId ?? 0,
            isMovie,
            tvdbId: tvdb,
            language: currentLang,
          );
          if (_resolvedLogoUrl == null && cachedAssets?.logoUrl != null && cachedAssets!.logoUrl!.isNotEmpty) {
            _resolvedLogoUrl = cachedAssets.logoUrl;
          }
          if (_resolvedBannerUrl == null && cachedAssets?.backdropUrl != null && cachedAssets!.backdropUrl!.isNotEmpty) {
            _resolvedBannerUrl = cachedAssets.backdropUrl;
          }
        }
      }
    }

    _restoreSavedMode();
    _loadDetails();
  }

  Future<void> _restoreSavedMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      AnimeDetailScreen._cachedPrefs = prefs;
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
          } else if (widget.initialLocalMode) {
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
      final results = await Future.wait([
        tmdbService.getShowDetails(
          widget.mediaId,
          language: lang,
          isMovie: isMovie,
        ),
        tmdbService.getMediaAssets(
          tmdbId: widget.mediaId,
          isMovie: isMovie,
          language: lang,
        ),
      ]);
      final showDetails = results[0] as TmdbShowDetails?;
      final assets = results[1] as TmdbMediaAssets?;

      String? logo = assets?.logoUrl;
      String? banner = assets?.backdropUrl;
      banner ??= showDetails?.backdropPath != null ? 'https://image.tmdb.org/t/p/w1280${showDetails!.backdropPath}' : null;
      banner ??= showDetails?.posterPath != null ? 'https://image.tmdb.org/t/p/w500${showDetails!.posterPath}' : null;

      if (!mounted) return;
      if (logo != null && logo.isNotEmpty) {
        try {
          if (!logo.toLowerCase().contains('.svg')) {
            await precacheImage(CachedNetworkImageProvider(logo), context);
          }
        } catch (_) {}
      }
      if (!mounted) return;
      if (banner != null && banner.isNotEmpty) {
        try {
          await precacheImage(CachedNetworkImageProvider(banner), context);
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
          if (showDetails != null) {
            _details = showDetails.toAnimeDetails();
          }
          if (logo != null && logo.isNotEmpty) _resolvedLogoUrl = logo;
          if (banner != null && banner.isNotEmpty) _resolvedBannerUrl = banner;
          _isLoading = false;
          _isLoadingAniZip = false;
        });
      return;
    }
    final repo = ref.read(repositoryProvider);

    AnimeDetails? details = _details;

    // Fetch details, aniZip, and library entry in parallel to avoid staggered state updates
    final results = await Future.wait([
      repo.getAnimeDetails(
        widget.mediaId,
        initialEntry: widget.initialEntry,
      ),
      _aniZipData != null
          ? Future.value(_aniZipData)
          : repo.getAniZipData(widget.mediaId).catchError((_) => null),
      repo.getAnimeLibraryEntry(widget.mediaId).catchError((_) => null),
    ]);

    final fetchedDetails = results[0] as AnimeDetails?;
    final aniZip = results[1] as AniZipData?;
    final libEntry = results[2] as LibraryEntryDetails?;

    if (fetchedDetails != null) {
      details = fetchedDetails;
    }

    final effectiveAniZip = aniZip ?? details?.aniZipData;
    final mapping = TmdbMappingService.getMapping(widget.mediaId);
    final isMovie = mapping?.isMovie ??
        ((details?.format?.toUpperCase() == 'MOVIE') ||
            (widget.initialEntry?.format?.toUpperCase() == 'MOVIE'));
    final parsedTmdbId = int.tryParse(effectiveAniZip?.mappings?.themoviedbId ?? '');
    final tvdbId = (mapping?.tvdbId != null && mapping!.tvdbId > 0)
        ? mapping.tvdbId
        : effectiveAniZip?.mappings?.thetvdbId;
    final effectiveTmdbId = mapping?.tmdbId ?? parsedTmdbId ?? (isTmdb ? widget.mediaId : null);

    if (parsedTmdbId != null && parsedTmdbId > 0) {
      TmdbMappingService.registerMapping(
        anilistId: widget.mediaId,
        tmdbId: parsedTmdbId,
        isMovie: isMovie,
        tvdbId: tvdbId ?? 0,
      );
    }

    String? resolvedLogo;
    String? resolvedBanner;

    // 0. Curated Local MiniDB assets (highest priority, season-accurate)
    final customAssets = CustomAnimeAssetsService.getAssets(widget.mediaId);
    if (customAssets != null) {
      if (customAssets.logo != null && customAssets.logo!.isNotEmpty) {
        resolvedLogo = customAssets.logo;
      }
      if (customAssets.background != null && customAssets.background!.isNotEmpty) {
        resolvedBanner = customAssets.background;
      }
    }

    // Resolve TMDB assets (logo + backdrop) if not already resolved by custom database
    if ((resolvedLogo == null || resolvedBanner == null) && (effectiveTmdbId != null || tvdbId != null)) {
      try {
        final apiKey = ref.read(tmdbApiKeyProvider);
        final currentLang = ref.read(appLanguageProvider).code;
        final tmdbService = TmdbService(apiKey: apiKey);
        final assets = await tmdbService.getMediaAssets(
          tmdbId: effectiveTmdbId,
          tvdbId: tvdbId,
          isMovie: isMovie,
          language: currentLang,
        );
        if (assets != null) {
          if (resolvedLogo == null && assets.logoUrl != null && assets.logoUrl!.isNotEmpty) {
            resolvedLogo = assets.logoUrl;
          }
          if (resolvedBanner == null && assets.backdropUrl != null && assets.backdropUrl!.isNotEmpty) {
            resolvedBanner = assets.backdropUrl;
          }
        }
      } catch (_) {}
    }

    // Fallback logo: AniZip clearlogo (only for non-TMDB anime)
    resolvedLogo ??= effectiveAniZip?.clearlogoUrl;

    // Fallback banner: AniZip fanart → banner → AniList banner → cover
    if (resolvedBanner == null) {
      final isTmdbEntry = details?.isTmdb ?? widget.initialEntry?.isTmdb ?? false;
      if (!isTmdbEntry) {
        final fanart = effectiveAniZip?.fanartUrl;
        final azBanner = effectiveAniZip?.bannerUrl;
        if (fanart != null && fanart.isNotEmpty) {
          resolvedBanner = fanart;
        } else if (azBanner != null && azBanner.isNotEmpty) {
          resolvedBanner = azBanner;
        }
      }
      resolvedBanner ??= details?.bannerImage ?? widget.initialEntry?.bannerImage;
      resolvedBanner ??= details?.coverImage ?? widget.initialEntry?.coverImage;
    }

    final hasDownloadedFiles = libEntry != null &&
        (libEntry.hasLibraryData ||
            libEntry.episodes.any((e) => e.isDownloaded));

    if (!mounted) return;
    if (resolvedLogo != null && resolvedLogo.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(resolvedLogo), context);
      } catch (_) {}
    }
    if (!mounted) return;
    if (resolvedBanner != null && resolvedBanner.isNotEmpty) {
      try {
        await precacheImage(CachedNetworkImageProvider(resolvedBanner), context);
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
        _details = details;
        _aniZipData = aniZip ?? details?.aniZipData;
        _resolvedLogoUrl = resolvedLogo;
        _resolvedBannerUrl = resolvedBanner;
        _isLoading = false;
        _isLoadingAniZip = false;
        if (hasDownloadedFiles) {
          _hasLocalFiles = true;
        }
      });
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
    bool isDownloadMode = false,
    List<int>? initialSelectedEpisodes,
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
                isDownloadMode: isDownloadMode,
                initialSelectedEpisodes: initialSelectedEpisodes,
              ),
            ),
          )
        : showGlassSheet<TorrentStreamLaunchInfo>(
            context: context,
            showGrabber: true,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            builder: (ctx) => TorrentSelectorSheet(
              mediaId: widget.mediaId,
              episodeNumber: episodeNumber,
              episodeTitle: episodeTitle,
              animeDetails: _details,
              aniDBEpisode: aniDBEpisode,
              isSheet: true,
              isDownloadMode: isDownloadMode,
              initialSelectedEpisodes: initialSelectedEpisodes,
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
            final repo = ref.read(repositoryProvider);
            final hexColor = _details?.coverColor ??
                widget.initialEntry?.coverColor ??
                repo.getCachedAnimeDetails(widget.mediaId)?.coverColor ??
                ref.read(animeCollectionProvider).asData?.value
                    .where((e) => e.mediaId == widget.mediaId)
                    .firstOrNull
                    ?.coverColor;
            final animeAccentColor = parseHexColor(hexColor) ?? effectiveTheme.colorScheme.primary;

            return ColoredBox(
              color: effectiveTheme.scaffoldBackgroundColor,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                reverseDuration: const Duration(milliseconds: 380),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
                child: _isLoading
                    ? _buildLoadingGate(effectiveTheme, animeAccentColor)
                    : _buildContent(effectiveLayout, effectiveHasLocal),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingGate(ThemeData effectiveTheme, Color animeAccentColor) {
    final repo = ref.read(repositoryProvider);
    final posterUrl = widget.initialEntry?.coverImage ??
        _details?.coverImage ??
        repo.getCachedAnimeDetails(widget.mediaId)?.coverImage ??
        ref.read(animeCollectionProvider).asData?.value
            .where((e) => e.mediaId == widget.mediaId)
            .firstOrNull
            ?.coverImage;

    final isDark = effectiveTheme.brightness == Brightness.dark;

    return Scaffold(
      key: const ValueKey('anime_loading_gate'),
      backgroundColor: effectiveTheme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ─── 1. Full-screen Blurred Poster Backdrop ───
          if (posterUrl != null && posterUrl.isNotEmpty)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 45.0, sigmaY: 45.0),
                child: Transform.scale(
                  scale: 1.15, // Prevents edge blur vignetting
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: Duration.zero,
                    errorWidget: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),

          // ─── 2. Darkness & Tint Overlay for Contrast ───
          Positioned.fill(
            child: Container(
              color: (isDark ? Colors.black : effectiveTheme.scaffoldBackgroundColor)
                  .withValues(alpha: isDark ? 0.65 : 0.50),
            ),
          ),

          // ─── 3. Center Spinner with AniList dynamic anime theme color ───
          Center(
            child: M3ELoadingIndicator(
              variant: M3ELoadingIndicatorVariant.contained,
              size: 52,
              color: animeAccentColor,
            ),
          ),

          // ─── 4. Top-Left Back Button (Always allow exiting during load) ───
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 24,
            child: Focus(
              skipTraversal: true,
              canRequestFocus: false,
              descendantsAreFocusable: false,
              child: M3EIconButton(
                variant: M3EIconButtonVariant.tonal,
                size: M3EIconButtonSize.sm,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: Icon(
                  AppIcons.arrowLeft(ref.watch(iconPackProvider)),
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.maybePop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(LayoutMode effectiveLayout, bool effectiveHasLocal) {
    switch (effectiveLayout) {
      case LayoutMode.desktop:
      case LayoutMode.tv:
        return KeyedSubtree(
          key: const ValueKey('anime_detail_content_desktop'),
          child: AnimeDetailDesktopLayout(
            mediaId: widget.mediaId,
            initialEntry: widget.initialEntry,
            heroTag: widget.heroTag,
            details: _details,
            aniZipData: _aniZipData,
            resolvedLogoUrl: _resolvedLogoUrl,
            resolvedBannerUrl: _resolvedBannerUrl,
            isLoading: false,
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
          ),
        );

      case LayoutMode.auto:
      case LayoutMode.mobile:
        return Scaffold(
          key: const ValueKey('anime_detail_content_mobile'),
          extendBodyBehindAppBar: true,
          body: AnimeDetailMobileLayout(
            mediaId: widget.mediaId,
            initialEntry: widget.initialEntry,
            heroTag: widget.heroTag,
            details: _details,
            aniZipData: _aniZipData,
            isLoading: false,
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
  }
}
