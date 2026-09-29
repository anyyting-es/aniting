import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/continue_reading_card.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/server_status_banner.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

class MangaFeedScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenSettings;

  const MangaFeedScreen({
    super.key,
    this.onOpenSearch,
    this.onOpenSettings,
  });

  @override
  ConsumerState<MangaFeedScreen> createState() => _MangaFeedScreenState();
}

class _MangaFeedScreenState extends ConsumerState<MangaFeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<MangaEntry> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;

  // Infinite scroll pagination state
  int _popularPage = 1;
  final List<MangaEntry> _extraPopular = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _isScrolledNotifier.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _isSearching = false;
        _isSearchLoading = false;
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
    });

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final repo = ref.read(repositoryProvider);
      final results = await repo.searchManga(trimmed);
      if (mounted && _searchController.text.trim() == trimmed) {
        setState(() {
          _searchResults = results;
          _isSearchLoading = false;
        });
      }
    });
  }

  void _exitSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearching = false;
      _isSearchLoading = false;
      _searchResults = [];
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final scrolled = _scrollController.position.pixels > 10;
    if (scrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = scrolled;
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= 350 && !_isLoadingMore && _hasMore) {
      _loadMorePopular();
    }
  }

  Future<void> _loadMorePopular() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _popularPage + 1;
    final repo = ref.read(repositoryProvider);
    final results = await repo.getPopularManga(page: nextPage, perPage: 12);

    if (mounted) {
      setState(() {
        _popularPage = nextPage;
        _isLoadingMore = false;
        if (results.isEmpty) {
          _hasMore = false;
        } else {
          _extraPopular.addAll(results);
          if (results.length < 12) {
            _hasMore = false;
          }
        }
      });
    }
  }

  List<MangaEntry>? _cachedMixedList;
  List<MangaEntry>? _lastTrending;
  List<MangaEntry>? _lastPopular;
  int _lastExtraPopularLength = -1;

  List<MangaEntry> _getMixedList({
    required List<MangaEntry> trending,
    required List<MangaEntry> popular,
    required List<MangaEntry> extraPopular,
  }) {
    if (_cachedMixedList != null &&
        identical(_lastTrending, trending) &&
        identical(_lastPopular, popular) &&
        _lastExtraPopularLength == extraPopular.length) {
      return _cachedMixedList!;
    }
    _lastTrending = trending;
    _lastPopular = popular;
    _lastExtraPopularLength = extraPopular.length;
    _cachedMixedList = _buildMixedList(
      trending: trending,
      popular: popular,
      extraPopular: extraPopular,
    );
    return _cachedMixedList!;
  }

  List<MangaEntry> _buildMixedList({
    required List<MangaEntry> trending,
    required List<MangaEntry> popular,
    required List<MangaEntry> extraPopular,
  }) {
    final seen = <int>{};
    final result = <MangaEntry>[];
    final maxLen = [trending.length, popular.length].reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < maxLen; i++) {
      if (i < popular.length && seen.add(popular[i].mediaId)) {
        result.add(popular[i]);
      }
      if (i < trending.length && seen.add(trending[i].mediaId)) {
        result.add(trending[i]);
      }
    }

    for (final item in extraPopular) {
      if (seen.add(item.mediaId)) {
        result.add(item);
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final serverState = ref.watch(serverNotifierProvider);

    final continueReadingAsync = ref.watch(continueReadingMangaProvider);
    final trendingMangaAsync = ref.watch(trendingMangaProvider);
    final popularMangaAsync = ref.watch(popularMangaProvider);
    final mangaCollectionAsync = ref.watch(mangaCollectionProvider);

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final mangaCardWidth = isDesktop ? 180.0 : 125.0;
    final carouselHeight = isDesktop ? 320.0 : 238.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: PopScope(
        canPop: !_isSearching,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _isSearching) {
            _exitSearch();
          }
        },
        child: Stack(
          children: [
            !serverState.isOnline
                ? CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: SizedBox(height: topPadding + 10),
                      ),
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: ServerStatusBanner(
                              onOpenSettings: widget.onOpenSettings ?? () {},
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      setState(() {
                        _popularPage = 1;
                        _extraPopular.clear();
                        _hasMore = true;
                      });
                      ref.invalidate(mangaCollectionProvider);
                      ref.invalidate(continueReadingMangaProvider);
                      ref.invalidate(trendingMangaProvider);
                      ref.invalidate(popularMangaProvider);
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      cacheExtent: 500,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: topPadding + 6),
                        ),
                        SliverToBoxAdapter(
                          key: const ValueKey('manga_feed_search_bar_sliver'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: CompactSearchBar(
                              key: const ValueKey('manga_feed_compact_search_bar'),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              hintText: '${l10n.search} manga...',
                              isSearching: _isSearching,
                              onChanged: _onSearchChanged,
                              onSubmitted: (val) => _onSearchChanged(val),
                              onBack: _exitSearch,
                              onClear: _exitSearch,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 8),
                        ),
                        if (_isSearching) ...[
                          if (_isSearchLoading)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            )
                          else if (_searchResults.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        AppIcons.searchOff(iconPack),
                                        size: 48,
                                        color: theme.colorScheme.outline,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '${l10n.noResultsFor} "${_searchController.text.trim()}"',
                                        style: TextStyle(
                                          color: theme.colorScheme.onSurfaceVariant,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverLayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.crossAxisExtent <= 32.0) {
                                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                                }
                                return SliverPadding(
                                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                                  sliver: SliverGrid.builder(
                                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                                      maxCrossAxisExtent: isDesktop ? 210 : 135,
                                      childAspectRatio: isDesktop ? 0.58 : 0.52,
                                      crossAxisSpacing: isDesktop ? 14 : 10,
                                      mainAxisSpacing: isDesktop ? 20 : 14,
                                    ),
                                    itemCount: _searchResults.length,
                                    itemBuilder: (context, index) {
                                      final item = _searchResults[index];
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
                                    },
                                  ),
                                );
                              },
                            ),
                        ] else ...[
                        // ─── 1. Seguir Leyendo (Continue Reading) ───
                  ..._buildContinueReadingSlivers(
                    continueReadingAsync: continueReadingAsync,
                    l10n: l10n,
                    theme: theme,
                    isDesktop: isDesktop,
                  ),

                  // ─── 2. Mangas Completados (Completed Manga) ───
                  mangaCollectionAsync.when(
                    data: (collection) {
                      final completed = collection
                          .where((e) => e.status.toUpperCase() == 'COMPLETED')
                          .toList();
                      if (completed.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: '${l10n.completedManga} (${completed.length})'),
                            SizedBox(
                              height: carouselHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                cacheExtent: 350,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: completed.length,
                                separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                itemBuilder: (context, index) {
                                  return MangaCard(entry: completed[index], width: mangaCardWidth);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  // ─── 3. Manga en Tendencia (Trending Manga) ───
                  trendingMangaAsync.when(
                    data: (items) {
                      if (items.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                      return SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SectionHeader(title: l10n.trendingManga),
                            SizedBox(
                              height: carouselHeight,
                              child: ListView.separated(
                                scrollDirection: Axis.horizontal,
                                cacheExtent: 350,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                itemCount: items.length,
                                separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                itemBuilder: (context, index) {
                                  return MangaCard(entry: items[index], width: mangaCardWidth);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
                    loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                  ),

                  // ─── 4. Descubrir Manga (Discover Manga with Virtualized Infinite Scrolling) ───
                  ..._buildDiscoverMangaSlivers(
                    trendingAsync: trendingMangaAsync,
                    popularAsync: popularMangaAsync,
                    extraPopular: _extraPopular,
                    isLoadingMore: _isLoadingMore,
                    hasMore: _hasMore,
                    l10n: l10n,
                    theme: theme,
                    isDesktop: isDesktop,
                  ),
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

  List<Widget> _buildContinueReadingSlivers({
    required AsyncValue<List<MangaEntry>> continueReadingAsync,
    required AppTranslations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    final items = continueReadingAsync.value ?? [];
    if (items.isEmpty) return const [];

    final cardWidth = isDesktop ? 180.0 : 125.0;
    final carouselHeight = isDesktop ? 320.0 : 238.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: l10n.continueReading),
            SizedBox(
              height: carouselHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                cacheExtent: 350,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return SizedBox(
                    width: cardWidth,
                    child: ContinueReadingCard(
                      entry: item,
                      onTap: () {
                        MangaDetailScreen.navigate(
                          context,
                          mediaId: item.mediaId,
                          initialEntry: item,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildDiscoverMangaSlivers({
    required AsyncValue<List<MangaEntry>> trendingAsync,
    required AsyncValue<List<MangaEntry>> popularAsync,
    required List<MangaEntry> extraPopular,
    required bool isLoadingMore,
    required bool hasMore,
    required AppTranslations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    final trending = trendingAsync.value ?? [];
    final popular = popularAsync.value ?? [];

    if (trending.isEmpty && popular.isEmpty && extraPopular.isEmpty) {
      if (trendingAsync.isLoading || popularAsync.isLoading) {
        return const [
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ];
      }
      return const [];
    }

    final mixed = _getMixedList(
      trending: trending,
      popular: popular,
      extraPopular: extraPopular,
    );

    return [
      SliverToBoxAdapter(
        child: _SectionHeader(title: l10n.discoverManga),
      ),
      SliverLayoutBuilder(
        builder: (context, constraints) {
          if (constraints.crossAxisExtent <= 32.0) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid.builder(
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: isDesktop ? 210 : 135,
                childAspectRatio: isDesktop ? 0.58 : 0.52,
                crossAxisSpacing: isDesktop ? 14 : 10,
                mainAxisSpacing: isDesktop ? 20 : 14,
              ),
              itemCount: mixed.length,
              itemBuilder: (context, index) {
                final item = mixed[index];
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
              },
            ),
          );
        },
      ),
      if (isLoadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        )
      else if (!hasMore)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.checkCircle(),
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    l10n.reachedTheEnd,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SliverToBoxAdapter(
        child: SizedBox(height: 90),
      ),
    ];
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
