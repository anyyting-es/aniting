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
import 'package:seanime_app/presentation/widgets/catalog_search/catalog_search_view.dart';
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
        minScore: _filterState.minScore,
        isAdult: _filterState.isAdult,
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
        minScore: _filterState.minScore,
        isAdult: _filterState.isAdult,
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


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final isAnime = _filterState.mediaType == 'ANIME';
    final titleLang = ref.watch(titleLanguageProvider);

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

    if (_showSearchBar) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _exitSearch();
          }
        },
        child: Scaffold(
          body: SafeArea(
            bottom: false,
            child: CatalogSearchView(
              searchController: _searchController,
              searchFocusNode: _searchFocusNode,
              onSearchChanged: _onSearchChanged,
              filterState: _filterState,
              onFilterChanged: (newState) {
                setState(() => _filterState = newState);
                _fetchResults(reset: true);
              },
              onResetFilters: _clearAllFilters,
              onBack: _exitSearch,
              onOpenFilterSheet: _openFilterSheet,
              animeResults: _animeResults,
              mangaResults: _mangaResults,
              isLoading: _isLoading,
              isLoadingMore: _isLoadingMore,
              hasMore: _hasMore,
              onLoadMore: _loadMore,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
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
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                if ((isAnime && (featuredAnimeConfig == null || featuredAnimeConfig.items.isEmpty) && (trendingAnimeAsync == null || trendingAnimeAsync.isLoading)) ||
                    (!isAnime && (trendingMangaAsync == null || trendingMangaAsync.isLoading)))
                  const SliverToBoxAdapter(
                    child: ExploreSkeleton(),
                  )
                else if (isAnime)
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
                              setState(() {
                                _isSearchExpanded = true;
                                if (!_filterState.hasActiveFilters) {
                                  _filterState = _filterState.copyWith(sort: 'SCORE_DESC');
                                }
                              });
                              _searchFocusNode.requestFocus();
                              if (_animeResults.isEmpty && _mangaResults.isEmpty && !_isLoading) {
                                _fetchResults(reset: true);
                              }
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
    );
  }
}


