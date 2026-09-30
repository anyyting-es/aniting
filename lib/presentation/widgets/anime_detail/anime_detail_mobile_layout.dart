import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
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

import 'mobile/anime_detail_mode_popup.dart';
import 'mobile/anime_detail_source_popup.dart';

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

  @override
  void initState() {
    super.initState();
    _loadSavedProvider();
  }

  Future<void> _loadSavedProvider() async {
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
                : 'Episodio $nextEp',
            episodeNumber: nextEp,
            videoSource: fileName != null
                ? 'Local • $fileName'
                : 'Biblioteca Local',
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
        episodeTitle: 'Episodio $nextEp',
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
          episodeTitle: 'Episodio $nextEp',
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

  String _formatPlayButtonLabel(int progress, int? totalEpisodes) {
    if (progress > 0 && totalEpisodes != null && progress >= totalEpisodes) {
      return 'Ver de nuevo';
    }
    if (progress > 0) {
      return 'Continuar Ep. ${progress + 1}';
    }
    return 'Comenzar a ver';
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
    final providerName = _selectedProvider?.name ?? 'Fuente';

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
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DUB',
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber,
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

  Widget _buildAniListStatusChip(ThemeData theme, String title, String progressText, String watchStatusText) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => widget.onOpenEditEntryModal(title),
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
              Icon(Icons.bookmark_border_rounded, size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                watchStatusText.isNotEmpty ? '$watchStatusText • $progressText' : 'Editar lista',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
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

    final coverUrl = widget.details?.coverImage ?? widget.initialEntry?.coverImage;
    final bannerUrl =
        widget.details?.bannerImage ?? widget.initialEntry?.bannerImage ?? coverUrl;
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
      dateParts.add('Ep. $nextEpNum pronto');
    }
    final dateSeasonStatus = dateParts.join(' • ');

    final genresList = widget.details?.genres ?? [];
    final genresString = genresList.take(3).join('  ');

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
          child: ClipRect(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [widget.bannerAnimController, widget.scrollController]),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (bannerUrl != null)
                      CachedNetworkImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        memCacheWidth: 1080,
                        errorWidget: (context, url, error) =>
                            Container(color: theme.colorScheme.surfaceContainer),
                      )
                    else
                      Container(color: theme.colorScheme.surfaceContainer),

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
                  ],
                ),
                builder: (context, child) {
                  final scrollOffset = widget.scrollController.hasClients
                      ? widget.scrollController.offset.clamp(0.0, double.infinity)
                      : 0.0;
                  final ambientScale =
                      1.0 + (widget.bannerScaleAnimation.value * 0.05);
                  final ambientTranslateY = widget.bannerTranslateAnimation.value;
                  final parallaxTranslateY =
                      scrollOffset > 0 ? -scrollOffset * 0.35 : 0.0;
                  final totalTranslateY = ambientTranslateY + parallaxTranslateY;

                  return Transform.translate(
                    offset: Offset(0, totalTranslateY),
                    child: Transform.scale(
                      scale: ambientScale,
                      alignment: Alignment.topCenter,
                      child: child,
                    ),
                  );
                },
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
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: Colors.white, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      tooltip: widget.isLocalMode
                          ? l10n.exitLocalMode
                          : l10n.enterLocalMode,
                      icon: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: widget.isLocalMode
                                  ? theme.colorScheme.primaryContainer
                                  : Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                              border: widget.isLocalMode
                                  ? Border.all(
                                      color: theme.colorScheme.primary,
                                      width: 1.5)
                                  : null,
                            ),
                            child: Icon(
                              widget.isLocalMode
                                  ? Icons.folder_rounded
                                  : Icons.folder_outlined,
                              color: widget.isLocalMode
                                  ? theme.colorScheme.primary
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                          if (widget.hasLocalFiles && !widget.isLocalMode)
                            Positioned(
                              right: 0,
                              top: 0,
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
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
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

                                    Row(
                                      children: [
                                        InkWell(
                                          onTap: () =>
                                              widget.onOpenEditEntryModal(title),
                                          borderRadius: BorderRadius.circular(
                                              (colors.borderRadius * 0.5)
                                                  .clamp(0.0, 8.0)),
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? Colors.white
                                                      .withValues(alpha: 0.1)
                                                  : theme.colorScheme
                                                      .primaryContainer
                                                      .withValues(alpha: 0.6),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      (colors.borderRadius * 0.5)
                                                          .clamp(0.0, 8.0)),
                                              border: Border.all(
                                                color: isDark
                                                    ? Colors.white
                                                        .withValues(alpha: 0.2)
                                                    : theme.colorScheme
                                                        .outlineVariant
                                                        .withValues(alpha: 0.5),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.edit_note_rounded,
                                              size: 15,
                                              color: isDark
                                                  ? Colors.white
                                                  : theme.colorScheme.primary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () =>
                                              widget.onOpenEditEntryModal(title),
                                          behavior: HitTestBehavior.opaque,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                progressText,
                                                style: TextStyle(
                                                  color: titleColor,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
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
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Primary Action: Continuar viendo / Comenzar ("Primerito")
                        SizedBox(
                          width: double.infinity,
                          height: 41,
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
                            onPressed: () => _handlePlayNext(progress),
                            icon: const Icon(Icons.play_arrow_rounded, size: 21),
                            label: Text(
                              _formatPlayButtonLabel(progress, totalEps),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),

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
                              const SizedBox(width: 8),
                              _buildAniListStatusChip(theme, title, progressText, watchStatusText),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Episodes Content (Clean, direct & without clunky middle tab bar)
                        if (widget.isLocalMode)
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
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onTapEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onPlayFallbackEpisode: (ep) {
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
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onTapEpisode: (ep) {
                              widget.onOpenTorrentSelector(
                                episodeNumber: ep.episodeNumber,
                                episodeTitle: ep.displayTitle,
                                aniDBEpisode: ep.episode,
                              );
                            },
                            onPlayFallbackEpisode: (ep) {
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
