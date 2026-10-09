import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/streaming_preferences_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/video_player_screen.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';

import 'desktop/desktop_action_bar.dart';
import 'desktop/desktop_characters_tab.dart';
import 'desktop/desktop_episodes_tab.dart';
import 'desktop/desktop_header.dart';
import 'desktop/desktop_hero_banner.dart';
import 'desktop/desktop_recommendations_tab.dart';
import 'desktop/desktop_relations_tab.dart';
import 'desktop/desktop_sidebar.dart';

class AnimeDetailDesktopLayout extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeEntry? initialEntry;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final bool isLoading;
  final bool isLoadingAniZip;
  final bool isLocalMode;
  final bool hasLocalFiles;
  final AnimeDetailTab currentTab;

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

  const AnimeDetailDesktopLayout({
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
    required this.onToggleLocalMode,
    required this.onTabChanged,
    required this.onOpenEditEntryModal,
    required this.onRetryAniZip,
    required this.onOpenTorrentSelector,
    required this.onOpenDetailsModal,
  });

  @override
  ConsumerState<AnimeDetailDesktopLayout> createState() =>
      _AnimeDetailDesktopLayoutState();
}

class _AnimeDetailDesktopLayoutState
    extends ConsumerState<AnimeDetailDesktopLayout> {
  static const String _prefLastProviderKey = 'last_selected_online_provider';
  final ScrollController _scrollController = SmoothScrollController();
  final ValueNotifier<double> _scrollProgressNotifier = ValueNotifier<double>(0.0);

  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  bool _isDubbed = false;
  List<OnlinestreamEpisode> _onlineEpisodes = [];
  bool _isLoadingOnlineEpisodes = false;
  final int? _loadingEpisodeNumber = null;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    final repo = ref.read(repositoryProvider);
    final cachedProviders = repo.getCachedOnlinestreamProviders();
    if (cachedProviders != null && cachedProviders.isNotEmpty) {
      _providers = cachedProviders;
      _selectedProvider = cachedProviders.first;
      final cachedEps = repo.getCachedOnlinestreamEpisodes(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        dubbed: _isDubbed,
      );
      if (cachedEps != null && cachedEps.isNotEmpty) {
        _onlineEpisodes = cachedEps;
        _isLoadingOnlineEpisodes = false;
      }
    }

    _loadOnlineProviders();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    final progress = (offset / 200.0).clamp(0.0, 1.0);
    if ((progress - _scrollProgressNotifier.value).abs() > 0.02 ||
        (offset <= 0 && _scrollProgressNotifier.value > 0) ||
        (offset >= 200 && _scrollProgressNotifier.value < 1.0)) {
      _scrollProgressNotifier.value = progress;
    }
  }

  @override
  void didUpdateWidget(covariant AnimeDetailDesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentTab != oldWidget.currentTab &&
        widget.currentTab == AnimeDetailTab.online &&
        _onlineEpisodes.isEmpty &&
        !_isLoadingOnlineEpisodes) {
      _loadOnlineEpisodes();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollProgressNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadOnlineProviders() async {
    final repo = ref.read(repositoryProvider);
    try {
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
        if (_selectedProvider != null) {
          _loadOnlineEpisodes();
        }
      }
    } catch (_) {}
  }

  Future<void> _loadOnlineEpisodes() async {
    if (_selectedProvider == null) return;
    final repo = ref.read(repositoryProvider);
    final cached = repo.getCachedOnlinestreamEpisodes(
      mediaId: widget.mediaId,
      provider: _selectedProvider!.id,
      dubbed: _isDubbed,
    );
    if (cached != null && cached.isNotEmpty && _onlineEpisodes.isEmpty) {
      setState(() {
        _onlineEpisodes = cached;
        _isLoadingOnlineEpisodes = false;
      });
    } else if (_onlineEpisodes.isEmpty) {
      setState(() {
        _isLoadingOnlineEpisodes = true;
      });
    }
    try {
      final list = await repo.getOnlinestreamEpisodes(
        mediaId: widget.mediaId,
        provider: _selectedProvider!.id,
        dubbed: _isDubbed,
      );
      if (mounted) {
        setState(() {
          _onlineEpisodes = list;
          _isLoadingOnlineEpisodes = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading online episodes: $e');
      if (mounted) {
        setState(() {
          _isLoadingOnlineEpisodes = false;
        });
      }
    }
  }

  void _playOnlineEpisode(int epNum, String epTitle) {
    if (_selectedProvider == null) return;
    final titleLang = ref.read(titleLanguageProvider);
    final mediaTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
    final providerName = _selectedProvider?.name ?? 'Online';

    Navigator.of(context, rootNavigator: true).push(
      VideoPlayerScreen.route(
        mediaId: widget.mediaId,
        videoUrl: '',
        title: mediaTitle,
        episodeTitle: epTitle,
        episodeNumber: epNum,
        videoSource: providerName,
        onlineStreamProvider: _selectedProvider?.id,
        onlineStreamDubbed: _isDubbed,
        onlineStreamServer: null,
        animeDetails: widget.details,
        aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
      ),
    );
  }

  void _onEpisodeClicked(DesktopEpisodeItemData ep) {
    if (widget.isLocalMode || ep.isDownloaded) {
      final serverManager = ref.read(serverManagerProvider);
      final l10n = ref.read(translationsProvider);
      final titleLang = ref.read(titleLanguageProvider);
      final animeTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
      final streamUrl = ep.localFilePath != null && ep.localFilePath!.isNotEmpty
          ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(ep.localFilePath!)}'
          : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${ep.number}';
      final fileName = ep.localFilePath != null && ep.localFilePath!.isNotEmpty
          ? ep.localFilePath!.split(RegExp(r'[/\\]')).last
          : null;
      final sourceDesc = fileName != null ? 'Local • $fileName' : l10n.localLibrary;

      Navigator.of(context, rootNavigator: true).push(
        VideoPlayerScreen.route(
          mediaId: widget.mediaId,
          videoUrl: streamUrl,
          title: animeTitle,
          episodeTitle: ep.title,
          episodeNumber: ep.number,
          videoSource: sourceDesc,
          isLocalFile: true,
          animeDetails: widget.details,
          aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
        ),
      );
      return;
    }

    if (widget.currentTab == AnimeDetailTab.torrent) {
      widget.onOpenTorrentSelector(
        episodeNumber: ep.number,
        episodeTitle: ep.title,
        aniDBEpisode: ep.aniDBEpisode,
      );
    } else {
      _playOnlineEpisode(ep.number, ep.title);
    }
  }

  Future<void> _handlePlayNext(int progress) async {
    final nextEp = progress > 0 ? progress + 1 : 1;
    final l10n = ref.read(translationsProvider);

    // 1. FAST-PATH: If file exists on PC in local library, stream directly from disk (0ms)
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
        final streamUrl = localEp.localFilePath != null && localEp.localFilePath!.isNotEmpty
            ? 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream/file?path=${Uri.encodeComponent(localEp.localFilePath!)}'
            : 'http://${serverManager.host}:${serverManager.port}/api/v1/mediastream?mediaId=${widget.mediaId}&episodeNumber=${localEp.episodeNumber}';
        final fileName = localEp.localFilePath?.split(RegExp(r'[/\\]')).last;

        Navigator.of(context, rootNavigator: true).push(
          VideoPlayerScreen.route(
            mediaId: widget.mediaId,
            videoUrl: streamUrl,
            title: animeTitle,
            episodeTitle: localEp.displayTitle.isNotEmpty ? localEp.displayTitle : l10n.episodeNumber(nextEp),
            episodeNumber: nextEp,
            videoSource: fileName != null ? 'Local • $fileName' : l10n.localLibrary,
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
      _playOnlineEpisode(nextEp, l10n.episodeNumber(nextEp));
    }
  }

  String _cleanHtml(String? html) {
    if (html == null) return '';
    return html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'</?i>'), '')
        .replaceAll(RegExp(r'</?b>'), '')
        .replaceAll(RegExp(r'</?p>'), '\n\n')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&#039;'), "'")
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final streamingPrefs = ref.watch(streamingPreferencesProvider);
    final torrentEnabled = streamingPrefs.torrentStreamingEnabled;
    final onlineEnabled = streamingPrefs.onlineStreamingEnabled;

    final title = widget.details?.displayTitle(titleLang) ??
        widget.initialEntry?.displayTitle(titleLang) ??
        (widget.details?.title.isNotEmpty == true &&
                widget.details?.title != l10n.noTitle
            ? widget.details!.title
            : null) ??
        widget.initialEntry?.title ??
        l10n.loading;

    final coverUrl =
        widget.initialEntry?.coverImage ?? widget.details?.coverImage;
    final hasRealBanner = (widget.details?.bannerImage != null &&
            widget.details!.bannerImage!.isNotEmpty) ||
        (widget.initialEntry?.bannerImage != null &&
            widget.initialEntry!.bannerImage!.isNotEmpty);
    final bannerUrl = hasRealBanner
        ? (widget.details?.bannerImage ?? widget.initialEntry?.bannerImage)
        : coverUrl;
    final isBlurredCover = !hasRealBanner && coverUrl != null;

    final score = widget.details?.score ?? widget.initialEntry?.score;
    final format = widget.details?.format ?? widget.initialEntry?.format ?? 'TV';
    final status = widget.details?.status ?? widget.initialEntry?.status;

    final year = widget.details?.seasonYear ??
        widget.details?.rawMedia?['startDate']?['year'];
    final season = widget.details?.season;
    final seasonYearStr = (season != null && year != null)
        ? '${l10n.formatSeason(season)} $year'.toUpperCase()
        : (year != null ? '$year' : '');

    final raw = widget.details?.rawMedia ?? {};
    final startDateMap = raw['startDate'] as Map?;
    final startMonth = startDateMap?['month'] as int?;
    final startYear = (startDateMap?['year'] as int?) ?? year;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthName = (startMonth != null && startMonth >= 1 && startMonth <= 12) ? months[startMonth - 1] : null;
    final dateStr = (monthName != null && startYear != null) ? '$monthName $startYear' : (startYear != null ? '$startYear' : '');
    final seasonStr = season != null ? l10n.formatSeason(season) : null;
    final dateSeasonStr = (dateStr.isNotEmpty && seasonStr != null)
        ? '$dateStr - $seasonStr'
        : (dateStr.isNotEmpty ? dateStr : seasonYearStr);

    final romaji = widget.details?.romajiTitle;
    final english = widget.details?.englishTitle;
    final native = widget.details?.nativeTitle;
    final subtitle = (romaji != null && romaji.isNotEmpty && romaji != title)
        ? romaji
        : ((english != null && english.isNotEmpty && english != title)
            ? english
            : ((native != null && native.isNotEmpty && native != title) ? native : null));

    final liveCollectionEntry = ref.watch(animeCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );

    final userStatus = liveCollectionEntry?.status ?? widget.details?.userStatus;

    final trailer = raw['trailer'] as Map<String, dynamic>?;
    final trailerId = trailer?['id'] as String?;
    final trailerSite = trailer?['site'] as String?;
    final hasTrailer = trailerId != null && trailerId.isNotEmpty;
    final idMal = raw['idMal'] as int?;

    final duration = raw['duration'] as int?;
    final totalEpisodes = widget.details?.totalEpisodes ?? widget.initialEntry?.totalEpisodes;
    final studio = widget.details?.studio ?? '';

    final progress = liveCollectionEntry?.progress ??
        widget.details?.progress ??
        widget.initialEntry?.progress ??
        0;

    final description = _cleanHtml(widget.details?.description);

    final charactersEdges = widget.details?.characters.isNotEmpty == true
        ? widget.details!.characters
        : ((raw['characters']?['edges'] as List?) ?? []);
    final relationsEdges = widget.details?.relations.isNotEmpty == true
        ? widget.details!.relations
        : ((raw['relations']?['edges'] as List?) ?? []);
    final recommendationsEdges = widget.details?.recommendations.isNotEmpty == true
        ? widget.details!.recommendations
        : ((raw['recommendations']?['edges'] as List?) ?? []);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── 1. Panoramic Top Hero Backdrop ───
          ValueListenableBuilder<double>(
            valueListenable: _scrollProgressNotifier,
            builder: (context, scrollProgress, _) {
              return DesktopHeroBanner(
                bannerUrl: bannerUrl,
                isBlurredCover: isBlurredCover,
                scrollProgress: scrollProgress,
                scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
              );
            },
          ),

          // ─── 2. Main Scrollable Container (Full width, minimal side margins) ───
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 64),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    Padding(
                      padding: const EdgeInsets.only(top: 42, bottom: 24),
                      child: IconButton(
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                          hoverColor: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.surfaceContainerHighest,
                          highlightColor: isDark ? Colors.white.withValues(alpha: 0.18) : theme.colorScheme.surfaceContainerHigh,
                        ),
                        icon: Icon(
                          AppIcons.arrowLeft(iconPack),
                          color: bannerUrl != null ? Colors.white : (isDark ? Colors.white : theme.colorScheme.onSurface),
                          size: 22,
                          shadows: bannerUrl != null
                              ? const [
                                  Shadow(
                                    color: Colors.black54,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // ─── Top Poster & Metadata Section ───
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left: Cover Poster Only (Clean, no bottom metadata pushing layout down)
                        DesktopSidebar(
                          coverUrl: coverUrl,
                        ),

                        const SizedBox(width: 32),

                        // Right: Title, Badges (Format, Status, Score, Studio) & Synopsis
                        Expanded(
                          child: DesktopHeader(
                            seasonYearStr: seasonYearStr,
                            dateSeasonStr: dateSeasonStr,
                            title: title,
                            subtitle: subtitle,
                            genres: widget.details?.genres ?? [],
                            description: description,
                            format: format,
                            status: status,
                            userStatus: userStatus,
                            progress: progress,
                            score: score,
                            studio: studio,
                            totalEpisodes: totalEpisodes,
                            duration: duration,
                            onEditStatus: () => widget.onOpenEditEntryModal(title),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ─── Action Bar (Play, Edit, Share, Trailer, Links & Online/Torrent Toggle) ───
                    DesktopActionBar(
                      mediaId: widget.mediaId,
                      title: title,
                      progress: progress,
                      idMal: idMal,
                      trailerId: trailerId,
                      trailerSite: trailerSite,
                      hasTrailer: hasTrailer,
                      currentTab: widget.currentTab,
                      onlineEnabled: onlineEnabled,
                      torrentEnabled: torrentEnabled,
                      onPlayNext: () => _handlePlayNext(progress),
                      onOpenEditEntryModal: widget.onOpenEditEntryModal,
                      onTabChanged: widget.onTabChanged,
                      onDownload: () {
                        final totalEps = widget.details?.totalEpisodes ?? widget.initialEntry?.totalEpisodes;
                        final nextEp = (progress + 1).clamp(1, totalEps ?? (progress + 1));
                        final defaultEpTitle = l10n.episodeNumber(nextEp);
                        widget.onOpenTorrentSelector(
                          episodeNumber: nextEp,
                          episodeTitle: defaultEpTitle,
                        );
                      },
                    ),

                    const SizedBox(height: 28),

                    // ─── Episodes Section (Full Width, without redundant header title) ───
                    DesktopEpisodesTab(
                      mediaId: widget.mediaId,
                      details: widget.details,
                      aniZipData: widget.aniZipData,
                      isLoadingAniZip: widget.isLoadingAniZip,
                      progress: progress,
                      isLocalMode: widget.isLocalMode,
                      currentTab: widget.currentTab,
                      providers: _providers,
                      selectedProvider: _selectedProvider,
                      isDubbed: _isDubbed,
                      onlineEpisodes: _onlineEpisodes,
                      isLoadingOnlineEpisodes: _isLoadingOnlineEpisodes,
                      loadingEpisodeNumber: _loadingEpisodeNumber,
                      fallbackCoverImage: coverUrl,
                      onProviderChanged: (p) {
                        if (p != null) {
                          setState(() => _selectedProvider = p);
                          SharedPreferences.getInstance().then(
                              (prefs) => prefs.setString(_prefLastProviderKey, p.id));
                          _loadOnlineEpisodes();
                        }
                      },
                      onToggleDubbed: () {
                        setState(() => _isDubbed = !_isDubbed);
                        _loadOnlineEpisodes();
                      },
                      onEpisodeClicked: _onEpisodeClicked,
                      onToggleLocalMode: widget.onToggleLocalMode,
                      onTabChanged: widget.onTabChanged,
                      onOpenTorrentSelector: widget.onOpenTorrentSelector,
                    ),

                    // ─── Relations Section (Full Width) ───
                    if (relationsEdges.isNotEmpty || widget.isLoading) ...[
                      const SizedBox(height: 48),
                      _DesktopSectionHeader(
                        title: l10n.relations,
                        icon: Icons.account_tree_outlined,
                      ),
                      const SizedBox(height: 18),
                      DesktopRelationsTab(
                        relations: relationsEdges,
                        isLoading: widget.isLoading,
                      ),
                    ],

                    // ─── Recommendations Section ("Te podría gustar") (Full Width) ───
                    if (recommendationsEdges.isNotEmpty || widget.isLoading) ...[
                      const SizedBox(height: 48),
                      _DesktopSectionHeader(
                        title: l10n.recommendations,
                        icon: Icons.auto_awesome_rounded,
                      ),
                      const SizedBox(height: 18),
                      DesktopRecommendationsTab(
                        recommendations: recommendationsEdges,
                        isLoading: widget.isLoading,
                      ),
                    ],

                    // ─── Characters Section (Full Width) ───
                    if (charactersEdges.isNotEmpty || widget.isLoading) ...[
                      const SizedBox(height: 48),
                      _DesktopSectionHeader(
                        title: l10n.characters,
                        icon: Icons.people_outline_rounded,
                      ),
                      const SizedBox(height: 18),
                      DesktopCharactersTab(
                        characters: charactersEdges,
                        isLoading: widget.isLoading,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
  }
}

class _DesktopSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;

  const _DesktopSectionHeader({
    required this.title,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 20,
            color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
        ],
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
