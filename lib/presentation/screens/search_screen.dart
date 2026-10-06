import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/widgets/explore_skeleton.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/genre_detail_screen.dart';
import 'package:seanime_app/presentation/screens/genres_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/discover_filter_sheet.dart';
import 'package:seanime_app/presentation/widgets/explore_hero_carousel.dart';
import 'package:seanime_app/data/services/explore_carousel_service.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = SmoothScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);
  bool _isSearchExpanded = false;
  Timer? _debounce;

  late DiscoverFilterState _filterState;

  final List<AnimeEntry> _animeResults = [];
  final List<MangaEntry> _mangaResults = [];
  int _currentPage = 1;
  int _searchRequestId = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get _isSearchingOrFiltering =>
      _searchController.text.trim().isNotEmpty || _filterState.hasActiveFilters;

  bool get _showSearchBar => _isSearchExpanded || _isSearchingOrFiltering;

  @override
  void initState() {
    super.initState();
    final animeEnabled = ref.read(animeSectionEnabledProvider);
    _filterState = DiscoverFilterState(mediaType: animeEnabled ? 'ANIME' : 'MANGA');
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _debounce?.cancel();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  void _exitSearch() {
    _debounce?.cancel();
    setState(() {
      _isSearchExpanded = false;
      _searchController.clear();
      _animeResults.clear();
      _mangaResults.clear();
      _isLoading = false;
    });
    _searchFocusNode.unfocus();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final scrolled = _scrollController.position.pixels > 10;
      if (scrolled != _isScrolledNotifier.value) {
        _isScrolledNotifier.value = scrolled;
      }
    }
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 150 &&
        _scrollController.position.pixels >= maxScroll - 400 &&
        !_isLoading &&
        !_isLoadingMore &&
        _hasMore &&
        _isSearchingOrFiltering) {
      _loadMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_isSearchingOrFiltering) {
        _fetchResults(reset: true);
      } else {
        setState(() {
          _animeResults.clear();
          _mangaResults.clear();
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _fetchResults({bool reset = true}) async {
    final requestId = ++_searchRequestId;

    if (reset) {
      setState(() {
        _isLoading = true;
        _isLoadingMore = false;
        _currentPage = 1;
        _hasMore = true;
        _animeResults.clear();
        _mangaResults.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final repo = ref.read(repositoryProvider);
    final pageToFetch = reset ? 1 : _currentPage;
    final query = _searchController.text.trim();

    if (_filterState.mediaType == 'ANIME') {
      final results = await repo.discoverAnime(
        search: query.isNotEmpty ? query : null,
        genres: _filterState.selectedGenres.isNotEmpty ? _filterState.selectedGenres.toList() : null,
        tags: _filterState.selectedTags.isNotEmpty ? _filterState.selectedTags.toList() : null,
        season: _filterState.season,
        year: _filterState.year,
        format: _filterState.format,
        status: _filterState.status,
        sort: _filterState.sort,
        page: pageToFetch,
        perPage: 24,
      );

      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _currentPage = pageToFetch + 1;
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            final existingIds = _animeResults.map((e) => e.mediaId).toSet();
            final unique = results.where((e) => !existingIds.contains(e.mediaId)).toList();
            _animeResults.addAll(unique);
            if (results.length < 24) _hasMore = false;
          }
        });
      }
    } else {
      final results = await repo.discoverManga(
        search: query.isNotEmpty ? query : null,
        genres: _filterState.selectedGenres.isNotEmpty ? _filterState.selectedGenres.toList() : null,
        tags: _filterState.selectedTags.isNotEmpty ? _filterState.selectedTags.toList() : null,
        year: _filterState.year,
        format: _filterState.format,
        status: _filterState.status,
        sort: _filterState.sort,
        page: pageToFetch,
        perPage: 24,
      );

      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _currentPage = pageToFetch + 1;
          if (results.isEmpty) {
            _hasMore = false;
          } else {
            final existingIds = _mangaResults.map((e) => e.id).toSet();
            final unique = results.where((e) => !existingIds.contains(e.id)).toList();
            _mangaResults.addAll(unique);
            if (results.length < 24) _hasMore = false;
          }
        });
      }
    }
  }

  void _loadMore() {
    _fetchResults(reset: false);
  }

  void _openFilterSheet() async {
    final updated = await DiscoverFilterSheet.show(
      context,
      current: _filterState,
    );

    if (updated != null && mounted) {
      setState(() => _filterState = updated);
      if (_isSearchingOrFiltering) {
        _fetchResults(reset: true);
      } else {
        setState(() {
          _animeResults.clear();
          _mangaResults.clear();
        });
      }
    }
  }

  void _setMediaType(String newType) {
    if (_filterState.mediaType == newType) return;
    setState(() {
      _filterState = _filterState.copyWith(
        mediaType: newType,
        season: () => newType == 'MANGA' ? null : _filterState.season,
      );
    });

    if (_isSearchingOrFiltering) {
      _fetchResults(reset: true);
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filterState = _filterState.clear();
      _searchController.clear();
      _animeResults.clear();
      _mangaResults.clear();
      _isLoading = false;
    });
  }

  Widget _buildCuratedAnimeSection({
    required String title,
    String? genreKey,
    VoidCallback? onSeeMoreTap,
    required List<AnimeEntry> entries,
    bool isLoading = false,
    required ThemeData theme,
    required AppTranslations l10n,
  }) {
    if (entries.isEmpty && !isLoading) return const SizedBox.shrink();

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final cardWidth = isDesktop ? 180.0 : 135.0;
    final carouselHeight = isDesktop ? 320.0 : 252.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: onSeeMoreTap ?? () {
                  if (genreKey != null) {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(
                        child: GenreDetailScreen(
                          genre: genreKey,
                          displayGenreName: title,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        l10n.seeMore,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(AppIcons.chevronRight(), size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading && entries.isEmpty)
          const CuratedSectionRowSkeleton(isAnimated: true)
        else
          SizedBox(
            height: carouselHeight + 16,
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              cacheExtent: 350,
              itemCount: entries.length,
              separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return AnimeCard(
                  entry: entry,
                  width: cardWidth,
                  onTap: () {
                    AnimeDetailScreen.navigate(
                      context,
                      mediaId: entry.mediaId,
                      initialEntry: entry,
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildCuratedMangaSection({
    required String title,
    String? genreKey,
    VoidCallback? onSeeMoreTap,
    required List<MangaEntry> entries,
    bool isLoading = false,
    required ThemeData theme,
    required AppTranslations l10n,
  }) {
    if (entries.isEmpty && !isLoading) return const SizedBox.shrink();

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final cardWidth = isDesktop ? 180.0 : 135.0;
    final carouselHeight = isDesktop ? 320.0 : 252.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              InkWell(
                onTap: onSeeMoreTap ?? () {
                  if (genreKey != null) {
                    Navigator.push(
                      context,
                      SlideRightToLeftPageRoute(
                        child: GenreDetailScreen(
                          genre: genreKey,
                          displayGenreName: title,
                        ),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        l10n.seeMore,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(AppIcons.chevronRight(), size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (isLoading && entries.isEmpty)
          const CuratedSectionRowSkeleton(isAnimated: true)
        else
          SizedBox(
            height: carouselHeight + 16,
            child: ListView.separated(
              clipBehavior: Clip.none,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              cacheExtent: 350,
              itemCount: entries.length,
              separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return MangaCard(
                  entry: entry,
                  width: cardWidth,
                  onTap: () {
                    MangaDetailScreen.navigate(
                      context,
                      mediaId: entry.mediaId,
                      initialEntry: entry,
                    );
                  },
                );
              },
            ),
          ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActiveFilterChips(ThemeData theme, AppTranslations l10n, bool isSpanish) {
    if (!_filterState.hasActiveFilters) return const SizedBox.shrink();

    final chips = <Widget>[];

    // Genres
    for (final g in _filterState.selectedGenres) {
      final match = kOfficialGenresData.firstWhere((item) => item['key'] == g, orElse: () => {'key': g, 'es': g, 'en': g});
      final name = isSpanish ? match['es']! : match['en']!;
      chips.add(
        InputChip(
          label: Text(name),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            final next = Set<String>.from(_filterState.selectedGenres)..remove(g);
            setState(() => _filterState = _filterState.copyWith(selectedGenres: next));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Tags
    for (final t in _filterState.selectedTags) {
      final match = kPopularTagsData.firstWhere((item) => item['key'] == t, orElse: () => {'key': t, 'es': t, 'en': t});
      final name = isSpanish ? match['es']! : match['en']!;
      chips.add(
        InputChip(
          label: Text(name),
          selectedColor: theme.colorScheme.tertiaryContainer,
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            final next = Set<String>.from(_filterState.selectedTags)..remove(t);
            setState(() => _filterState = _filterState.copyWith(selectedTags: next));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Year
    if (_filterState.year != null) {
      chips.add(
        InputChip(
          label: Text('${_filterState.year}'),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _filterState = _filterState.copyWith(year: () => null));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Season
    if (_filterState.season != null) {
      chips.add(
        InputChip(
          label: Text(l10n.formatSeason(_filterState.season)),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _filterState = _filterState.copyWith(season: () => null));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Format
    if (_filterState.format != null) {
      chips.add(
        InputChip(
          label: Text(_filterState.format!),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _filterState = _filterState.copyWith(format: () => null));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Status
    if (_filterState.status != null) {
      chips.add(
        InputChip(
          label: Text(l10n.formatStatus(_filterState.status)),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _filterState = _filterState.copyWith(status: () => null));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    // Sort
    if (_filterState.sort != 'TRENDING_DESC') {
      chips.add(
        InputChip(
          label: Text(_filterState.sort == 'SCORE_DESC'
              ? l10n.sortScore
              : _filterState.sort == 'POPULARITY_DESC'
                  ? l10n.sortPopularity
                  : l10n.sortStartDate),
          visualDensity: VisualDensity.compact,
          onDeleted: () {
            setState(() => _filterState = _filterState.copyWith(sort: 'TRENDING_DESC'));
            _fetchResults(reset: true);
          },
        ),
      );
    }

    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 6),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          ...chips.map((c) => Padding(padding: const EdgeInsets.only(right: 6), child: c)),
          ActionChip(
            label: Text(l10n.clearFilters, style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
            avatar: Icon(AppIcons.close(), size: 14, color: theme.colorScheme.error),
            visualDensity: VisualDensity.compact,
            onPressed: _clearAllFilters,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final isAnime = _filterState.mediaType == 'ANIME';
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final titleLang = ref.watch(titleLanguageProvider);
    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);

    // Trending & Featured providers for Explore Hero Carousel
    final featuredAnimeConfig = isAnime ? ref.watch(exploreCarouselNotifierProvider) : null;
    final trendingAnimeAsync = isAnime ? ref.watch(trendingAnimeProvider) : null;
    final trendingMangaAsync = !isAnime ? ref.watch(trendingMangaProvider) : null;

    // Curated providers for Anime
    final romanceAnimeAsync = isAnime && !_showSearchBar ? ref.watch(curatedRomanceAnimeProvider) : null;
    final actionAnimeAsync = isAnime && !_showSearchBar ? ref.watch(curatedActionAnimeProvider) : null;
    final comedyAnimeAsync = isAnime && !_showSearchBar ? ref.watch(curatedComedyAnimeProvider) : null;

    // Curated providers for Manga
    final romanceMangaAsync = !isAnime && !_showSearchBar ? ref.watch(curatedRomanceMangaProvider) : null;
    final actionMangaAsync = !isAnime && !_showSearchBar ? ref.watch(curatedActionMangaProvider) : null;
    final comedyMangaAsync = !isAnime && !_showSearchBar ? ref.watch(curatedComedyMangaProvider) : null;

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: PopScope(
        canPop: !_showSearchBar,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _showSearchBar) {
            _exitSearch();
          }
        },
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () async {
                if (_isSearchingOrFiltering) {
                  await _fetchResults(reset: true);
                } else {
                  if (isAnime) {
                    ref.invalidate(trendingAnimeProvider);
                    ref.invalidate(curatedRomanceAnimeProvider);
                    ref.invalidate(curatedActionAnimeProvider);
                    ref.invalidate(curatedComedyAnimeProvider);
                    ref.read(exploreCarouselNotifierProvider.notifier).refresh();
                  } else {
                    ref.invalidate(trendingMangaProvider);
                    ref.invalidate(curatedRomanceMangaProvider);
                    ref.invalidate(curatedActionMangaProvider);
                    ref.invalidate(curatedComedyMangaProvider);
                  }
                }
              },
              child: CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    if (_showSearchBar) ...[
                      // Active Search Bar with Back Button & Filter
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.fromLTRB(16, isDesktop ? 40.0 : (topPadding + 6), 16, 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CompactSearchBar(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      hintText: isAnime ? '${l10n.search} anime...' : '${l10n.search} manga...',
                                      isSearching: true,
                                      onChanged: _onSearchChanged,
                                      onSubmitted: (_) {
                                        _debounce?.cancel();
                                        _fetchResults(reset: true);
                                      },
                                      onBack: _exitSearch,
                                      onClear: _exitSearch,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Badge(
                                    isLabelVisible: _filterState.hasActiveFilters,
                                    label: Text('${_filterState.activeFilterCount}'),
                                    child: IconButton.filledTonal(
                                      tooltip: l10n.filters,
                                      icon: Icon(
                                        _filterState.hasActiveFilters ? AppIcons.sliders(iconPack) : AppIcons.filter(iconPack),
                                        color: _filterState.hasActiveFilters ? theme.colorScheme.primary : null,
                                      ),
                                      onPressed: _openFilterSheet,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Row(
                                children: [
                                  MediaTypeToggle(
                                    selected: _filterState.mediaType,
                                    onSelected: _setMediaType,
                                    showAnime: animeEnabled,
                                    showManga: mangaEnabled,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Active Filters Chips Row
                            _buildActiveFilterChips(theme, l10n, isSpanish),
                          ],
                        ),
                      ),

                      // Content Slivers for Search Mode
                      if (_isLoading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (isAnime ? _animeResults.isEmpty : _mangaResults.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(AppIcons.searchOff(iconPack), size: 56, color: theme.colorScheme.outline),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.noResultsFound,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  icon: Icon(AppIcons.clearAll(iconPack), size: 18),
                                  label: Text(l10n.clearFilters),
                                  onPressed: _clearAllFilters,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                          sliver: SliverGrid.builder(
                            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: isDesktop ? 210 : 135,
                              childAspectRatio: isDesktop ? 0.58 : 0.52,
                              crossAxisSpacing: isDesktop ? 14 : 10,
                              mainAxisSpacing: isDesktop ? 20 : 14,
                            ),
                            itemCount: (isAnime ? _animeResults.length : _mangaResults.length) +
                                (_hasMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              final totalItems = isAnime ? _animeResults.length : _mangaResults.length;

                              if (index >= totalItems) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: CircularProgressIndicator(strokeWidth: 2.5),
                                  ),
                                );
                              }

                              if (isAnime) {
                                final item = _animeResults[index];
                                return AnimeCard(
                                  entry: item,
                                  onTap: () {
                                    AnimeDetailScreen.navigate(
                                      context,
                                      mediaId: item.mediaId,
                                      initialEntry: item,
                                    );
                                  },
                                );
                              } else {
                                final item = _mangaResults[index];
                                return MangaCard(
                                  entry: item,
                                  onTap: () {
                                    MangaDetailScreen.navigate(
                                      context,
                                      mediaId: item.mediaId,
                                      initialEntry: item,
                                    );
                                  },
                                );
                              }
                            },
                          ),
                        ),
                    ] else ...[
                      // Discover & Curated Explore Mode Slivers
                      if ((isAnime && (featuredAnimeConfig == null || featuredAnimeConfig.items.isEmpty) && (trendingAnimeAsync == null || trendingAnimeAsync.isLoading)) ||
                          (!isAnime && (trendingMangaAsync == null || trendingMangaAsync.isLoading)))
                        const SliverToBoxAdapter(
                          child: ExploreSkeleton(),
                        )
                      else ...[
                        // 1. Full-bleed Hero Carousel at the very top (Edge to Edge, extends behind status bar)
                        if (isAnime)
                          Builder(builder: (context) {
                            final config = featuredAnimeConfig;
                            final List<ExploreCarouselItem> carouselItems;
                            if (config != null && config.items.isNotEmpty) {
                              carouselItems = config.items
                                  .map((e) => ExploreCarouselItem.fromFeatured(e, context))
                                  .toList();
                            } else if (trendingAnimeAsync != null && trendingAnimeAsync.asData != null) {
                              final items = trendingAnimeAsync.asData!.value;
                              if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                              carouselItems = items
                                  .take(6)
                                  .map((e) => ExploreCarouselItem.fromAnime(e, context, titleLang))
                                  .toList();
                            } else {
                              return const SliverToBoxAdapter(child: SizedBox.shrink());
                            }
                            return SliverToBoxAdapter(
                              child: ExploreHeroCarousel(
                                key: ValueKey('explore_hero_anime_v${config?.version ?? 0}_${carouselItems.length}'),
                                items: carouselItems,
                              ),
                            );
                          })
                        else if (!isAnime)
                          Builder(builder: (context) {
                            final trendingItems = trendingMangaAsync?.asData?.value ?? [];
                            final popularItems = ref.watch(popularMangaProvider).asData?.value ?? [];
                            final items = trendingItems.isNotEmpty ? trendingItems : popularItems;
                            if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                            final carouselItems = items
                                .take(6)
                                .map((e) => ExploreCarouselItem.fromManga(e, context, titleLang))
                                .toList();
                            return SliverToBoxAdapter(
                              child: ExploreHeroCarousel(
                                key: ValueKey('explore_hero_manga_${carouselItems.length}'),
                                items: carouselItems,
                              ),
                            );
                          }),

                      // 2. Header Bar positioned below Carousel (MediaTypeToggle & Action Icons)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                          child: Row(
                            children: [
                              // Non-wrapping Media Type Toggle (Anime / Manga)
                              MediaTypeToggle(
                                selected: _filterState.mediaType,
                                onSelected: _setMediaType,
                              ),
                              const Spacer(),
                              // Search Icon Button
                              IconButton(
                                tooltip: l10n.search,
                                icon: Icon(AppIcons.search(iconPack)),
                                onPressed: () {
                                  setState(() => _isSearchExpanded = true);
                                  _searchFocusNode.requestFocus();
                                },
                              ),
                              // Filter Sheet Trigger Button
                              Badge(
                                isLabelVisible: _filterState.hasActiveFilters,
                                label: Text('${_filterState.activeFilterCount}'),
                                child: IconButton(
                                  tooltip: l10n.filters,
                                  icon: Icon(
                                    _filterState.hasActiveFilters ? AppIcons.sliders(iconPack) : AppIcons.filter(iconPack),
                                    color: _filterState.hasActiveFilters ? theme.colorScheme.primary : null,
                                  ),
                                  onPressed: _openFilterSheet,
                                ),
                              ),
                              IconButton(
                                tooltip: l10n.genresTitle,
                                icon: Icon(AppIcons.category(iconPack), size: 20),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    SlideRightToLeftPageRoute(child: const GenresScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3. Popular Genres Chips Row
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 12),
                          child: SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: kAppGenres.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final g = kAppGenres[i];
                                final displayName = isSpanish ? g.nameEs : g.nameEn;

                                return ActionChip(
                                  avatar: Icon(g.icon, size: 14, color: theme.colorScheme.primary),
                                  label: Text(displayName),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      SlideRightToLeftPageRoute(
                                        child: GenreDetailScreen(
                                          genre: g.key,
                                          displayGenreName: displayName,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ),
                      ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 6),
                      ),

                      if (isAnime) ...[
                        SliverToBoxAdapter(
                          child: _buildCuratedAnimeSection(
                            title: isSpanish ? 'En tendencia ahora' : 'Trending Now',
                            onSeeMoreTap: () {
                              setState(() {
                                _filterState = _filterState.copyWith(sort: 'TRENDING_DESC');
                                _isSearchExpanded = true;
                              });
                              _fetchResults(reset: true);
                            },
                            entries: trendingAnimeAsync?.asData?.value ?? [], isLoading: trendingAnimeAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedAnimeSection(
                            title: isSpanish ? 'Romance en tendencia' : 'Trending Romance',
                            genreKey: 'Romance',
                            entries: romanceAnimeAsync?.asData?.value ?? [], isLoading: romanceAnimeAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedAnimeSection(
                            title: isSpanish ? 'Acción en tendencia' : 'Trending Action',
                            genreKey: 'Action',
                            entries: actionAnimeAsync?.asData?.value ?? [], isLoading: actionAnimeAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedAnimeSection(
                            title: isSpanish ? 'Comedia en tendencia' : 'Trending Comedy',
                            genreKey: 'Comedy',
                            entries: comedyAnimeAsync?.asData?.value ?? [], isLoading: comedyAnimeAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                      ] else ...[
                        SliverToBoxAdapter(
                          child: _buildCuratedMangaSection(
                            title: isSpanish ? 'En tendencia ahora' : 'Trending Now',
                            onSeeMoreTap: () {
                              setState(() {
                                _filterState = _filterState.copyWith(sort: 'TRENDING_DESC');
                                _isSearchExpanded = true;
                              });
                              _fetchResults(reset: true);
                            },
                            entries: trendingMangaAsync?.asData?.value ?? [], isLoading: trendingMangaAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedMangaSection(
                            title: isSpanish ? 'Romance en tendencia' : 'Trending Romance',
                            genreKey: 'Romance',
                            entries: romanceMangaAsync?.asData?.value ?? [], isLoading: romanceMangaAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedMangaSection(
                            title: isSpanish ? 'Acción en tendencia' : 'Trending Action',
                            genreKey: 'Action',
                            entries: actionMangaAsync?.asData?.value ?? [], isLoading: actionMangaAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: _buildCuratedMangaSection(
                            title: isSpanish ? 'Comedia en tendencia' : 'Trending Comedy',
                            genreKey: 'Comedy',
                            entries: comedyMangaAsync?.asData?.value ?? [], isLoading: comedyMangaAsync?.isLoading ?? false, theme: theme,
                            l10n: l10n,
                          ),
                        ),
                      ],

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 90),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ValueListenableBuilder<bool>(
              valueListenable: _isScrolledNotifier,
              builder: (context, isScrolled, child) {
                return TopStatusBarGlass(isVisible: isScrolled);
              },
            ),
          ],
        ),
      ),
    );
  }
}


