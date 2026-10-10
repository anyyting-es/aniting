import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/banner_blur_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/presentation/widgets/anizip_episode_list.dart';
import 'package:seanime_app/presentation/widgets/local_library_view.dart';
import 'package:seanime_app/presentation/widgets/online_stream_view.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:seanime_app/core/preferences/anime_favorites_provider.dart';

import 'mobile/anime_detail_mode_popup.dart';
import 'mobile/anime_detail_source_popup.dart';
import 'tmdb/tmdb_episodes_view.dart';

enum AnimeDetailTab { online, torrent }

class AnimeDetailMobileLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final bool isLoading;
  final bool isLoadingAniZip;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final AnimeDetailTab currentTab;
  final ScrollController scrollController;
  final AnimationController bannerAnimController;
  final Animation<double> bannerScaleAnimation;
  final Animation<double> bannerTranslateAnimation;

  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;
  final void Function(String title) onOpenEditEntryModal;
  final Future<void> Function() onRetryAniZip;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  }) onOpenTorrentSelector;
  final VoidCallback onOpenDetailsModal;

  const AnimeDetailMobileLayout({
    super.key,
    required this.mediaId,
    this.initialEntry,
    required this.details,
    required this.aniZipData,
    required this.isLoading,
    required this.isLoadingAniZip,
    required this.isLocalMode,
    required this.hasLocalFiles,
    required this.currentTab,
    required this.scrollController,
    required this.bannerAnimController,
    required this.bannerScaleAnimation,
    required this.bannerTranslateAnimation,
    required this.onToggleLocalMode,
    required this.onTabChanged,
    required this.onOpenEditEntryModal,
    required this.onRetryAniZip,
    required this.onOpenTorrentSelector,
    required this.onOpenDetailsModal,
  });

  @override
  ConsumerState<AnimeDetailMobileLayout> createState() =>
      _AnimeDetailMobileLayoutState();
}

class _AnimeDetailMobileLayoutState
    extends ConsumerState<AnimeDetailMobileLayout> {
  static const String _prefLastProviderKey = 'last_selected_online_provider';
  final OnlineStreamViewController _onlineStreamController =
      OnlineStreamViewController();

  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  bool _isDubbed = false;
  bool _isHeaderScrolled = false;

  bool get isTmdb => widget.details?.isTmdb ?? widget.initialEntry?.isTmdb ?? false;
  bool get isMovie =>
      (widget.details?.format == 'MOVIE') || (widget.initialEntry?.format == 'MOVIE');

  @override
  void initState() {
    super.initState();
    _loadSavedProvider();
    widget.scrollController.addListener(_onScrollChanged);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScrollChanged);
    super.dispose();
  }

  void _onScrollChanged() {
    if (!widget.scrollController.hasClients) return;
    final isScrolled = widget.scrollController.offset > 120.0;
    if (isScrolled != _isHeaderScrolled) {
      setState(() => _isHeaderScrolled = isScrolled);
    }
  }

  Future<void> _loadSavedProvider() async {
    if (isTmdb) return;
    try {
      final repo = ref.read(repositoryProvider);
      final list = await repo.getOnlinestreamProviders();
      OnlinestreamProvider? initialProvider;
      if (list.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final savedId = prefs.getString(_prefLastProviderKey);
          if (savedId != null && list.any((p) => p.id == savedId)) {
            initialProvider = list.firstWhere((p) => p.id == savedId);
          }
        } catch (_) {}
        initialProvider ??= list.first;
      }
      if (mounted) {
        setState(() {
          _providers = list;
          _selectedProvider = initialProvider;
        });
      }
    } catch (_) {}
  }

  Future<void> _handlePlayNext(int progress) async {
    final nextEp = progress > 0 ? progress + 1 : 1;
    final l10n = ref.read(translationsProvider);

    // 1. Fast-path: local library file
    try {
      final repo = ref.read(repositoryProvider);
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      final localEp = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
        (e) => e?.episodeNumber == nextEp,
        orElse: () => null,
      );
      if (localEp != null && mounted) {
        final serverManager = ref.read(serverManagerProvider);
        final titleLang = ref.read(titleLanguageProvider);
        final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
        final streamUrl = localEp.localFilePath != null &&
                localEp.localFilePath!.isNotEmpty
            ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
            : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${localEp.episodeNumber}';
        final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;

        Navigator.of(context, rootNavigator: true).push(
          VideoPlayerScreen.route(
            mediaId: widget.mediaId,
            videoUrl: streamUrl,
            title: animeTitle,
            episodeTitle: localEp.displayTitle.isNotEmpty
                ? localEp.displayTitle
                : l10n.episodeNumber(nextEp),
            episodeNumber: nextEp,
            videoSource: fileName != null
                ? 'Local • $fileName'
                : l10n.localLibrary,
            isLocalFile: true,
            animeDetails: widget.details,
            aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
          ),
        );
        return;
      }
    } catch (_) {}

    if (widget.currentTab == AnimeDetailTab.torrent) {
      widget.onOpenTorrentSelector(
        episodeNumber: nextEp,
        episodeTitle: l10n.episodeNumber(nextEp),
      );
    } else {
      if (!mounted) return;
      final titleLang = ref.read(titleLanguageProvider);
      final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
      final providerName = _selectedProvider?.name ?? 'Online';

      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: widget.mediaId,
          videoUrl: '',
          title: animeTitle,
          episodeTitle: l10n.episodeNumber(nextEp),
          episodeNumber: nextEp,
          videoSource: providerName,
          animeDetails: widget.details,
          aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
          onlineStreamProvider: _selectedProvider?.id,
          onlineStreamDubbed: _isDubbed,
          onlineStreamServer: null,
        ),
      );
    }
  }

  Future<void> _playOrOpenTorrent(
    int episodeNumber,
    String episodeTitle, [
    String? aniDBEpisode,
  ]) async {
    final l10n = ref.read(translationsProvider);
    try {
      final repo = ref.read(repositoryProvider);
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      final localEp = entry?.episodes.cast<LibraryEpisode?>().firstWhere(
        (e) => e?.episodeNumber == episodeNumber && (e?.isDownloaded ?? false),
        orElse: () => null,
      );
      if (localEp != null && mounted) {
        final serverManager = ref.read(serverManagerProvider);
        final titleLang = ref.read(titleLanguageProvider);
        final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
        final streamUrl = localEp.localFilePath != null &&
                localEp.localFilePath!.isNotEmpty
            ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
            : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${localEp.episodeNumber}';
        final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;

        Navigator.of(context, rootNavigator: true).push(
          VideoPlayerScreen.route(
            mediaId: widget.mediaId,
            videoUrl: streamUrl,
            title: animeTitle,
            episodeTitle: localEp.displayTitle.isNotEmpty
                ? localEp.displayTitle
                : episodeTitle,
            episodeNumber: episodeNumber,
            videoSource: fileName != null
                ? 'Local • $fileName'
                : l10n.localLibrary,
            isLocalFile: true,
            animeDetails: widget.details,
            aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
          ),
        );
        return;
      }
    } catch (_) {}

    widget.onOpenTorrentSelector(
      episodeNumber: episodeNumber,
      episodeTitle: episodeTitle,
      aniDBEpisode: aniDBEpisode,
    );
  }

  void _openSourceSelector() {
    AnimeDetailSourcePopup.show(
      context: context,
      providers: _providers,
      selectedProvider: _selectedProvider,
      isDubbed: _isDubbed,
      onProviderChanged: (newProv) {
        if (newProv != null) {
          setState(() => _selectedProvider = newProv);
          SharedPreferences.getInstance().then((prefs) {
            prefs.setString(_prefLastProviderKey, newProv.id);
          }).catchError((_) {});
        }
      },
      onToggleDubbed: (isDub) {
        setState(() => _isDubbed = isDub);
      },
      onOpenManualMapping: () {
        _onlineStreamController.openManualMapping(context);
      },
      onRefreshCache: () {
        _onlineStreamController.refresh();
      },
    );
  }

  String _formatPlayButtonLabel(int progress, int? totalEpisodes, AppTranslations l10n) {
    if (progress > 0 && totalEpisodes != null && progress >= totalEpisodes) {
      return l10n.rewatch;
    }
    if (progress > 0) {
      return l10n.continueEpisodeNumbered(progress + 1);
    }
    return l10n.startWatching;
  }

  Future<void> _launchTrailer(String? trailerId, String? trailerSite) async {
    if (trailerId == null || trailerId.isEmpty) return;
    String url = '';
    final site = trailerSite?.toLowerCase();
    if (site == 'youtube' || site == null) {
      url = 'https://www.youtube.com/watch?v=$trailerId';
    } else if (site == 'dailymotion') {
      url = 'https://www.dailymotion.com/video/$trailerId';
    }
    if (url.isNotEmpty) {
      try {
        await launchUrlString(url, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  Widget _buildModeDropdownChip(ThemeData theme, AnimeDetailTab effectiveTab) {
    final isTorrent = !widget.isLocalMode && effectiveTab == AnimeDetailTab.torrent;
    final isLocal = widget.isLocalMode;

    final IconData modeIcon = isLocal
        ? Icons.folder_rounded
        : (isTorrent ? Icons.cloud_download_rounded : Icons.public_rounded);
    final String modeLabel = isLocal
        ? 'Local'
        : (isTorrent ? 'Torrent' : 'Online');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          AnimeDetailModePopup.show(
            context: context,
            currentTab: effectiveTab,
            isLocalMode: widget.isLocalMode,
            hasLocalFiles: widget.hasLocalFiles,
            onTabChanged: widget.onTabChanged,
            onToggleLocalMode: widget.onToggleLocalMode,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(modeIcon, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                modeLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderDropdownChip(ThemeData theme) {
    final providerName = _selectedProvider?.name ?? ref.watch(translationsProvider).source;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openSourceSelector,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                providerName,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              if (_isDubbed) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'DUB',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.75)
        : theme.colorScheme.onSurfaceVariant;
    final titleLang = ref.watch(titleLanguageProvider);
    final streamingPrefs = ref.watch(streamingPreferencesProvider);
    final torrentEnabled = streamingPrefs.torrentStreamingEnabled;
    final onlineEnabled = streamingPrefs.onlineStreamingEnabled;

    final effectiveTab = (widget.currentTab == AnimeDetailTab.online &&
            !onlineEnabled &&
            torrentEnabled)
        ? AnimeDetailTab.torrent
        : (widget.currentTab == AnimeDetailTab.torrent &&
                !torrentEnabled &&
                onlineEnabled)
            ? AnimeDetailTab.online
            : widget.currentTab;

    final title = widget.details?.displayTitle(titleLang) ??
        widget.initialEntry?.displayTitle(titleLang) ??
        (widget.details?.title.isNotEmpty == true &&
                widget.details?.title != l10n.noTitle
            ? widget.details!.title
            : null) ??
        widget.initialEntry?.title ??
        l10n.loading;

    final coverUrl = widget.initialEntry?.coverImage ?? widget.details?.coverImage;
    final hasRealBanner = (widget.details?.bannerImage != null &&
            widget.details!.bannerImage!.isNotEmpty) ||
        (widget.initialEntry?.bannerImage != null &&
            widget.initialEntry!.bannerImage!.isNotEmpty);
    final bannerUrl =
        widget.details?.bannerImage ?? widget.initialEntry?.bannerImage ?? coverUrl;
    final isBlurSetting = ref.watch(bannerBlurProvider);
    final shouldBlur = (!hasRealBanner && coverUrl != null) || isBlurSetting;
    final score = widget.details?.score ?? widget.initialEntry?.score;
    final format = widget.details?.format ?? widget.initialEntry?.format ?? 'TV';
    final episodes = widget.details?.totalEpisodes ?? widget.initialEntry?.totalEpisodes;

    final displayScore = score != null && score > 0
        ? (score > 10 ? (score / 10).toStringAsFixed(1) : score.toStringAsFixed(1))
        : '8.0';

    final year = widget.details?.seasonYear ??
        widget.details?.rawMedia?['startDate']?['year'];
    final season = widget.details?.season;
    final dateParts = <String>[];
    if (year != null && season != null) {
      dateParts.add('${l10n.formatSeason(season)} $year');
    } else if (year != null) {
      dateParts.add('$year');
    } else if (season != null) {
      dateParts.add(l10n.formatSeason(season));
    }
    final nextAiring = widget.details?.rawMedia?['nextAiringEpisode'];
    final nextEpNum = nextAiring?['episode'] ?? widget.initialEntry?.nextAiringEpisodeNumber;
    if (nextEpNum != null) {
      dateParts.add(l10n.episodeSoon(nextEpNum));
    }
    final dateSeasonStatus = dateParts.join(' • ');

    final genresList = widget.details?.genres ?? [];
    final genresString = genresList.take(3).join('  ');

    final rawMedia = widget.details?.rawMedia ?? <String, dynamic>{};
    final trailer = rawMedia['trailer'] as Map<String, dynamic>?;
    final trailerId = trailer?['id'] as String?;
    final trailerSite = trailer?['site'] as String?;
    final hasTrailer = trailerId != null && trailerId.isNotEmpty;

    final isFavorite = ref.watch(animeFavoritesProvider).contains(widget.mediaId);

    final liveCollectionEntry = ref.watch(animeCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
    final progress = liveCollectionEntry?.progress ??
        widget.details?.progress ??
        widget.initialEntry?.progress ??
        0;
    final totalEps = episodes ?? widget.details?.totalEpisodes;
    final progressText = progress > 0
        ? '$progress/${totalEps ?? "?"}'
        : (totalEps != null ? '$totalEps eps' : format);
    final userWatchStatus = liveCollectionEntry?.status ??
        widget.details?.userStatus ??
        widget.initialEntry?.status;
    final watchStatusText =
        l10n.formatWatchStatus(userWatchStatus, progress, totalEps, format);

    return Stack(
      children: [
        // 1. Ambient Background Banner
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          height: 345,
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: ClipRect(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: Listenable.merge(
                      [widget.bannerAnimController, widget.scrollController]),
                  builder: (context, _) {
                    final scrollOffset = widget.scrollController.hasClients
                        ? widget.scrollController.offset.clamp(0.0, double.infinity)
                        : 0.0;
                    final ambientScale =
                        1.0 + (widget.bannerScaleAnimation.value * 0.05);
                    final ambientTranslateY = widget.bannerTranslateAnimation.value;
                    final parallaxTranslateY =
                        scrollOffset > 0 ? -scrollOffset * 0.35 : 0.0;
                    final totalTranslateY = ambientTranslateY + parallaxTranslateY;
                    final scrollDarkening = (scrollOffset / 200.0).clamp(0.0, 1.0);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Parallax Banner Image (strictly clipped to bounds to avoid blur bleed)
                        Transform.translate(
                          offset: Offset(0, totalTranslateY),
                          child: Transform.scale(
                            scale: ambientScale,
                            alignment: Alignment.topCenter,
                            child: bannerUrl != null
                                ? (shouldBlur
                                    ? ClipRect(
                                        child: ImageFiltered(
                                          imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
                                          child: Transform.scale(
                                            scale: 1.25,
                                            child: CachedNetworkImage(
                                              imageUrl: bannerUrl,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              memCacheWidth: 1080,
                                              errorWidget: (context, url, error) =>
                                                  Container(color: theme.colorScheme.surfaceContainer),
                                            ),
                                          ),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: bannerUrl,
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        memCacheWidth: 1080,
                                        errorWidget: (context, url, error) =>
                                            Container(color: theme.colorScheme.surfaceContainer),
                                      ))
                                : Container(color: theme.colorScheme.surfaceContainer),
                          ),
                        ),

                        // Stationary Cinematic Multi-Stop Gradient into Theme Background
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: isDark
                                  ? [
                                      Colors.black.withValues(alpha: 0.65),
                                      Colors.black.withValues(alpha: 0.15),
                                      Colors.black.withValues(alpha: 0.45),
                                      Colors.black.withValues(alpha: 0.85),
                                      theme.scaffoldBackgroundColor
                                          .withValues(alpha: 0.96),
                                      theme.scaffoldBackgroundColor,
                                    ]
                                  : [
                                      Colors.black.withValues(alpha: 0.35),
                                      Colors.white.withValues(alpha: 0.10),
                                      Colors.white.withValues(alpha: 0.50),
                                      Colors.white.withValues(alpha: 0.88),
                                      theme.scaffoldBackgroundColor
                                          .withValues(alpha: 0.96),
                                      theme.scaffoldBackgroundColor,
                                    ],
                              stops: const [0.0, 0.20, 0.45, 0.70, 0.90, 1.0],
                            ),
                          ),
                        ),

                        // Scroll-driven darkening: seamlessly turns into active theme background
                        Container(
                          color: theme.scaffoldBackgroundColor.withValues(alpha: scrollDarkening),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),

        // 2. Foreground Scrollable Content
        Builder(
          builder: (context) {
            final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
            return CustomScrollView(
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: isDark
                        ? Brightness.light
                        : (_isHeaderScrolled ? Brightness.dark : Brightness.light),
                    statusBarBrightness: isDark
                        ? Brightness.dark
                        : (_isHeaderScrolled ? Brightness.light : Brightness.dark),
                    systemNavigationBarColor: theme.scaffoldBackgroundColor,
                    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
                    systemNavigationBarDividerColor: Colors.transparent,
                  ),
                  leading: IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: (isDark || !_isHeaderScrolled)
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                      size: 22,
                      shadows: (isDark || !_isHeaderScrolled)
                          ? const [
                              Shadow(
                                color: Colors.black54,
                                blurRadius: 4,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    if (!isTmdb)
                      IconButton(
                        tooltip: widget.isLocalMode
                            ? l10n.exitLocalMode
                            : l10n.enterLocalMode,
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              widget.isLocalMode
                                  ? Icons.folder_rounded
                                  : Icons.folder_outlined,
                              color: widget.isLocalMode
                                  ? theme.colorScheme.primary
                                  : ((isDark || !_isHeaderScrolled)
                                      ? Colors.white
                                      : theme.colorScheme.onSurface),
                              size: 22,
                              shadows: (isDark || !_isHeaderScrolled)
                                  ? const [
                                      Shadow(
                                        color: Colors.black54,
                                        blurRadius: 4,
                                        offset: Offset(0, 1),
                                      ),
                                    ]
                                  : null,
                            ),
                            if (widget.hasLocalFiles && !widget.isLocalMode)
                              Positioned(
                                right: -1,
                                top: -1,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onPressed: widget.onToggleLocalMode,
                      ),
                    IconButton(
                      tooltip: l10n.animeDetails,
                      icon: Icon(
                        Icons.info_outline_rounded,
                        color: (isDark || !_isHeaderScrolled)
                            ? Colors.white
                            : theme.colorScheme.onSurface,
                        size: 22,
                        shadows: (isDark || !_isHeaderScrolled)
                            ? const [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      onPressed: widget.onOpenDetailsModal,
                    ),
                    const SizedBox(width: 8),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 26, 16, bottomPadding + 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Poster + Header Info Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (coverUrl != null)
                              Container(
                                width: 125,
                                height: 185,
                                decoration: BoxDecoration(
                                  borderRadius:
                                      BorderRadius.circular(colors.borderRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 16,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: CachedNetworkImage(
                                  imageUrl: coverUrl,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 300,
                                  memCacheHeight: 440,
                                ),
                              ),
                            const SizedBox(width: 14),

                            Expanded(
                              child: SizedBox(
                                height: 185,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 19,
                                        color: titleColor,
                                        height: 1.2,
                                        shadows: isDark
                                            ? [
                                                Shadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.8),
                                                  offset: const Offset(0, 1),
                                                  blurRadius: 4,
                                                ),
                                              ]
                                            : null,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),

                                    if (dateSeasonStatus.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_month_rounded,
                                            size: 14,
                                            color: subtitleColor,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              dateSeasonStatus,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                    ],

                                    Row(
                                      children: [
                                        Icon(
                                          Icons.favorite_rounded,
                                          size: 14,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.85)
                                              : theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          displayScore,
                                          style: TextStyle(
                                            color: titleColor,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (genresString.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              genresString,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: subtitleColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 7),

                                    if (progressText.isNotEmpty || watchStatusText.isNotEmpty)
                                      GestureDetector(
                                        onTap: () =>
                                            widget.onOpenEditEntryModal(title),
                                        behavior: HitTestBehavior.opaque,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (progressText.isNotEmpty)
                                              Text(
                                                progressText,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            if (progressText.isNotEmpty && watchStatusText.isNotEmpty)
                                              Text(
                                                '  •  ',
                                                style: TextStyle(
                                                  color: subtitleColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            if (watchStatusText.isNotEmpty)
                                              Text(
                                                watchStatusText,
                                                style: TextStyle(
                                                  color: subtitleColor,
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Primary Action: Continuar viendo / Comenzar ("Primerito") + Trailer, Fav & Edit
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 42,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.colorScheme.primary,
                                    foregroundColor: theme.colorScheme.onPrimary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    elevation: 0,
                                  ),
                                  onPressed: isTmdb
                                      ? () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.info_outline_rounded,
                                                      color: Colors.white, size: 18),
                                                  const SizedBox(width: 8),
                                                  Expanded(child: Text(l10n.streamingComingSoon)),
                                                ],
                                              ),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      : () => _handlePlayNext(progress),
                                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                                  label: Text(
                                    _formatPlayButtonLabel(progress, totalEps, l10n),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (hasTrailer) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                tooltip: l10n.watchTrailer,
                                icon: const Icon(Icons.smart_display_outlined, size: 22),
                                onPressed: () => _launchTrailer(trailerId, trailerSite),
                              ),
                            ],
                            const SizedBox(width: 2),
                            IconButton(
                              tooltip: isFavorite ? l10n.inFavorites : l10n.addToFavorites,
                              icon: Icon(
                                isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                size: 22,
                                color: isFavorite ? Colors.redAccent : theme.colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                final nowFav = ref
                                    .read(animeFavoritesProvider.notifier)
                                    .toggleFavorite(widget.mediaId);
                                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      nowFav ? l10n.addedToFavorites : l10n.removedFromFavorites,
                                    ),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                            ),
                            if (!isTmdb) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: l10n.downloadWithTorrentClient,
                                icon: const Icon(Icons.download_rounded, size: 22),
                                onPressed: () {
                                  final nextEp = (progress + 1).clamp(1, totalEps ?? (progress + 1));
                                  final defaultEpTitle = l10n.episodeNumber(nextEp);
                                  widget.onOpenTorrentSelector(
                                    episodeNumber: nextEp,
                                    episodeTitle: defaultEpTitle,
                                  );
                                },
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: l10n.editInAnilist,
                                icon: const Icon(Icons.edit_outlined, size: 22),
                                onPressed: () => widget.onOpenEditEntryModal(title),
                              ),
                            ],
                          ],
                        ),

                        if (!isTmdb) ...[
                          const SizedBox(height: 10),

                          // Minimalist Dropdown Chips Row
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: [
                                _buildModeDropdownChip(theme, effectiveTab),
                                if (!widget.isLocalMode && effectiveTab == AnimeDetailTab.online) ...[
                                  const SizedBox(width: 8),
                                  _buildProviderDropdownChip(theme),
                                ],
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 18),

                        // Episodes Content (Clean, direct & without clunky middle tab bar)
                        if (isTmdb)
                          TmdbEpisodesView(
                            tmdbId: widget.mediaId,
                            isMovie: isMovie,
                            fallbackCoverImage: coverUrl,
                            isMobile: true,
                          )
                        else if (widget.isLocalMode)
                          LocalLibraryView(
                            mediaId: widget.mediaId,
                            animeDetails: widget.details,
                            progress: progress,
                            onSwitchToTorrent: () {
                              widget.onToggleLocalMode();
                              widget.onTabChanged(AnimeDetailTab.torrent);
                            },
                            onSwitchToOnline: () {
                              widget.onToggleLocalMode();
                              widget.onTabChanged(AnimeDetailTab.online);
                            },
                          )
                        else if (onlineEnabled &&
                            effectiveTab == AnimeDetailTab.online)
                          OnlineStreamView(
                            mediaId: widget.mediaId,
                            animeDetails: widget.details,
                            progress: progress,
                            hideTopBar: true,
                            controller: _onlineStreamController,
                            selectedProvider: _selectedProvider,
                            isDubbed: _isDubbed,
                            onProvidersLoaded: (list) {
                              if (mounted && list.isNotEmpty) {
                                setState(() => _providers = list);
                              }
                            },
                            onProviderChanged: (p) {
                              if (mounted && p != null) {
                                setState(() => _selectedProvider = p);
                              }
                            },
                            onDubbedChanged: (dub) {
                              if (mounted) setState(() => _isDubbed = dub);
                            },
                            onDownloadEpisode: (epNum, epTitle) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: epNum,
                                episodeTitle: epTitle,
                              );
                            },
                          )
                        else if (torrentEnabled &&
                            effectiveTab == AnimeDetailTab.torrent)
                          AniZipEpisodeListView(
                            aniZipData:
                                widget.aniZipData ?? widget.details?.aniZipData,
                            fallbackEpisodes: widget.details?.episodes ?? const [],
                            animeDetails: widget.details,
                            isLoading:
                                widget.isLoading || widget.isLoadingAniZip,
                            progress: progress,
                            onRetry: widget.onRetryAniZip,
                            viewMode: ref.watch(episodeViewModeProvider),
                            onToggleViewMode: () => ref
                                .read(episodeViewModeProvider.notifier)
                                .toggleMode(),
                            onPlayEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.displayTitle,
                                ep.episode,
                              );
                            },
                            onTapEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.displayTitle,
                                ep.episode,
                              );
                            },
                            onPlayFallbackEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.title,
                              );
                            },
                            onDownloadEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onDownloadFallbackEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.title,
                              );
                            },
                          )
                        else if (onlineEnabled)
                          OnlineStreamView(
                            mediaId: widget.mediaId,
                            animeDetails: widget.details,
                            progress: progress,
                            hideTopBar: true,
                            controller: _onlineStreamController,
                            selectedProvider: _selectedProvider,
                            isDubbed: _isDubbed,
                            onDownloadEpisode: (epNum, epTitle) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: epNum,
                                episodeTitle: epTitle,
                              );
                            },
                          )
                        else if (torrentEnabled)
                          AniZipEpisodeListView(
                            aniZipData:
                                widget.aniZipData ?? widget.details?.aniZipData,
                            fallbackEpisodes: widget.details?.episodes ?? const [],
                            animeDetails: widget.details,
                            isLoading:
                                widget.isLoading || widget.isLoadingAniZip,
                            progress: progress,
                            onRetry: widget.onRetryAniZip,
                            viewMode: ref.watch(episodeViewModeProvider),
                            onToggleViewMode: () => ref
                                .read(episodeViewModeProvider.notifier)
                                .toggleMode(),
                            onPlayEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.displayTitle,
                                ep.episode,
                              );
                            },
                            onTapEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.displayTitle,
                                ep.episode,
                              );
                            },
                            onPlayFallbackEpisode: (ep) {
                              _playOrOpenTorrent(
                                ep.episodeNumber,
                                ep.title,
                              );
                            },
                            onDownloadEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onDownloadFallbackEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.title,
                              );
                            },
                          )
                        else
                          const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
