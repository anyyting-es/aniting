import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
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

import 'desktop/desktop_action_bar.dart';
import 'desktop/desktop_characters_tab.dart';
import 'desktop/desktop_episodes_tab.dart';
import 'desktop/desktop_header.dart';
import 'desktop/desktop_hero_banner.dart';
import 'desktop/desktop_recommendations_tab.dart';
import 'desktop/desktop_relations_tab.dart';
import 'desktop/desktop_sidebar.dart';
import 'desktop/desktop_tab_button.dart';

enum DesktopDetailTab {
  episodes,
  characters,
  related,
  recommendations,
}

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
  DesktopDetailTab _selectedTab = DesktopDetailTab.episodes;
  final ScrollController _scrollController = ScrollController();
  double _scrollOffset = 0.0;

  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  bool _isDubbed = false;
  List<OnlinestreamEpisode> _onlineEpisodes = [];
  bool _isLoadingOnlineEpisodes = false;
  int? _loadingEpisodeNumber;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadOnlineProviders();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.offset;
    if ((offset - _scrollOffset).abs() > 3 ||
        (offset <= 0 && _scrollOffset > 0) ||
        (offset >= 250 && _scrollOffset < 250)) {
      setState(() {
        _scrollOffset = offset.clamp(0.0, 500.0);
      });
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
    setState(() {
      _isLoadingOnlineEpisodes = true;
      _onlineEpisodes = [];
    });
    final repo = ref.read(repositoryProvider);
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

  void _launchSource(OnlinestreamVideoSource chosenSource, int epNum, String epTitle) {
    final titleLang = ref.read(titleLanguageProvider);
    final mediaTitle = widget.details?.displayTitle(titleLang) ?? 'Anime';
    final providerName = _selectedProvider?.name ?? 'Online';
    final serverPart = chosenSource.server.isNotEmpty ? ' • ${chosenSource.server.toUpperCase()}' : '';
    final qualityPart = chosenSource.quality.isNotEmpty ? ' (${chosenSource.quality})' : '';
    final sourceDesc = '$providerName$serverPart$qualityPart';

    Navigator.of(context, rootNavigator: true).push(
      VideoPlayerScreen.route(
        mediaId: widget.mediaId,
        videoUrl: chosenSource.url,
        title: mediaTitle,
        episodeTitle: epTitle,
        episodeNumber: epNum,
        videoSource: sourceDesc,
        headers: chosenSource.headers,
        mimeType: chosenSource.isHls ? 'application/x-mpegURL' : null,
        externalSubtitles: chosenSource.subtitles,
        onlineStreamProvider: _selectedProvider?.id,
        onlineStreamDubbed: _isDubbed,
        onlineStreamServer: chosenSource.server,
        animeDetails: widget.details,
        aniZipData: widget.aniZipData ?? widget.details?.aniZipData,
      ),
    );
  }

  void _showSourcePickerModal(List<OnlinestreamVideoSource> sources, int epNum, String epTitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.read(translationsProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1B1E24) : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.settings_input_composite_rounded,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.selectServerQuality,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Episodio $epNum: $epTitle',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: () => Navigator.pop(dialogCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: sources.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final src = sources[i];
                        final serverName = src.server.isNotEmpty ? src.server.toUpperCase() : l10n.server;
                        final qualityText = src.quality.isNotEmpty ? src.quality : 'Auto';
                        return InkWell(
                          onTap: () {
                            Navigator.pop(dialogCtx);
                            _launchSource(src, epNum, epTitle);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF22262E)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    color: theme.colorScheme.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        serverName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${l10n.quality}: $qualityText',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right, size: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _playOnlineEpisode(int epNum, String epTitle) async {
    if (_selectedProvider == null) return;
    setState(() => _loadingEpisodeNumber = epNum);
    final repo = ref.read(repositoryProvider);
    try {
      final sources = await repo.getOnlinestreamSource(
        mediaId: widget.mediaId,
        episodeNumber: epNum,
        provider: _selectedProvider!.id,
        dubbed: _isDubbed,
      );
      if (!mounted) return;
      setState(() => _loadingEpisodeNumber = null);
      if (sources.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se encontraron fuentes de video para el episodio $epNum'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      if (sources.length == 1) {
        _launchSource(sources.first, epNum, epTitle);
      } else {
        _showSourcePickerModal(sources, epNum, epTitle);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEpisodeNumber = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar stream: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _onEpisodeClicked(DesktopEpisodeItemData ep) {
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
        final l10n = ref.read(translationsProvider);
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
            episodeTitle: localEp.displayTitle.isNotEmpty ? localEp.displayTitle : 'Episodio $nextEp',
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
        episodeTitle: 'Episodio $nextEp',
      );
    } else {
      _playOnlineEpisode(nextEp, 'Episodio $nextEp');
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
        widget.details?.coverImage ?? widget.initialEntry?.coverImage;
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
    final trailer = raw['trailer'] as Map<String, dynamic>?;
    final trailerId = trailer?['id'] as String?;
    final trailerSite = trailer?['site'] as String?;
    final hasTrailer = trailerId != null && trailerId.isNotEmpty;
    final idMal = raw['idMal'] as int?;

    final startDateMap = raw['startDate'] as Map<String, dynamic>?;
    final endDateMap = raw['endDate'] as Map<String, dynamic>?;
    String airedStr = '';
    if (startDateMap != null && startDateMap['year'] != null) {
      final sM = startDateMap['month'] ?? 1;
      final sD = startDateMap['day'] ?? 1;
      final sY = startDateMap['year'];
      final startFormatted = '$sM/$sD/$sY';
      if (endDateMap != null && endDateMap['year'] != null) {
        final eM = endDateMap['month'] ?? 1;
        final eD = endDateMap['day'] ?? 1;
        final eY = endDateMap['year'];
        airedStr = '$startFormatted - $eM/$eD/$eY';
      } else {
        airedStr = startFormatted;
      }
    }

    final liveCollectionEntry = ref.watch(animeCollectionProvider).whenOrNull(
          data: (entries) =>
              entries.where((e) => e.mediaId == widget.mediaId).firstOrNull,
        );
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

    final scrollProgress = (_scrollOffset / 200.0).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // ─── 1. Panoramic Top Hero Backdrop (clean, uncovered, with full blur fallback & deeper darkness) ───
          DesktopHeroBanner(
            bannerUrl: bannerUrl,
            isBlurredCover: isBlurredCover,
            scrollProgress: scrollProgress,
            scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
          ),

          // ─── 2. Main Scrollable Container (Wider Max-Width: 1580px, Generous Side Margins) ───
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1580),
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button (clears top title bar and provides clean spacing to poster)
                    Padding(
                      padding: const EdgeInsets.only(top: 42, bottom: 24),
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withValues(alpha: 0.55),
                          padding: const EdgeInsets.all(8),
                        ),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),

                    // Two Columns
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Sidebar (Enlarged poster, trailer moved to action bar)
                        DesktopSidebar(
                          coverUrl: coverUrl,
                          format: format,
                          status: status,
                          airedStr: airedStr,
                          seasonYearStr: seasonYearStr,
                          score: score,
                          studio: widget.details?.studio ?? '',
                        ),

                        const SizedBox(width: 32),

                        // Right Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header & Action Bar bottom-aligned with poster (360px)
                              ConstrainedBox(
                                constraints: const BoxConstraints(minHeight: 360),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    DesktopHeader(
                                      seasonYearStr: seasonYearStr,
                                      title: title,
                                      genres: widget.details?.genres ?? [],
                                      description: description,
                                    ),
                                    DesktopActionBar(
                                      mediaId: widget.mediaId,
                                      title: title,
                                      progress: progress,
                                      idMal: idMal,
                                      trailerId: trailerId,
                                      trailerSite: trailerSite,
                                      hasTrailer: hasTrailer,
                                      currentTab: widget.currentTab,
                                      isLocalMode: widget.isLocalMode,
                                      onlineEnabled: onlineEnabled,
                                      torrentEnabled: torrentEnabled,
                                      onPlayNext: () => _handlePlayNext(progress),
                                      onOpenEditEntryModal: widget.onOpenEditEntryModal,
                                      onToggleLocalMode: widget.onToggleLocalMode,
                                      onTabChanged: widget.onTabChanged,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Desktop Sub-Navigation Tab Bar
                              Row(
                                children: [
                                  DesktopTabButton(
                                    label: 'Episodes',
                                    isSelected: _selectedTab == DesktopDetailTab.episodes,
                                    onTap: () => setState(() => _selectedTab = DesktopDetailTab.episodes),
                                  ),
                                  const SizedBox(width: 24),
                                  DesktopTabButton(
                                    label: 'Characters',
                                    isSelected: _selectedTab == DesktopDetailTab.characters,
                                    onTap: () => setState(() => _selectedTab = DesktopDetailTab.characters),
                                  ),
                                  const SizedBox(width: 24),
                                  DesktopTabButton(
                                    label: 'Related',
                                    isSelected: _selectedTab == DesktopDetailTab.related,
                                    onTap: () => setState(() => _selectedTab = DesktopDetailTab.related),
                                  ),
                                  const SizedBox(width: 24),
                                  DesktopTabButton(
                                    label: 'More like this',
                                    isSelected: _selectedTab == DesktopDetailTab.recommendations,
                                    onTap: () => setState(() => _selectedTab = DesktopDetailTab.recommendations),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Active Tab Content
                              if (_selectedTab == DesktopDetailTab.episodes)
                                DesktopEpisodesTab(
                                  mediaId: widget.mediaId,
                                  details: widget.details,
                                  aniZipData: widget.aniZipData,
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
                                )
                              else if (_selectedTab == DesktopDetailTab.characters)
                                DesktopCharactersTab(
                                  characters: charactersEdges,
                                  isLoading: widget.isLoading,
                                )
                              else if (_selectedTab == DesktopDetailTab.related)
                                DesktopRelationsTab(
                                  relations: relationsEdges,
                                  isLoading: widget.isLoading,
                                )
                              else if (_selectedTab == DesktopDetailTab.recommendations)
                                DesktopRecommendationsTab(
                                  recommendations: recommendationsEdges,
                                  isLoading: widget.isLoading,
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
          ),
        ],
      ),
    );
  }
}
