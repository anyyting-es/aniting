import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';
import 'package:seanime_app/core/preferences/continue_watching_sort_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/custom_route_transitions.dart';
import 'package:seanime_app/presentation/screens/airing_calendar_screen.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';
import 'package:seanime_app/core/server/server_manager.dart';

class FeedScreen extends ConsumerStatefulWidget {
  final VoidCallback? onOpenSearch;
  final VoidCallback? onOpenSettings;

  const FeedScreen({
    super.key,
    this.onOpenSearch,
    this.onOpenSettings,
  });

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  // Memoization fields
  List<AnimeEntry>? _lastTrending;
  List<AnimeEntry>? _lastPopular;
  List<AnimeEntry>? _lastRecent;
  List<AnimeEntry>? _cachedMixedList;

  List<AnimeEntry>? _lastContinueWatchingInput;
  ContinueWatchingSortMode? _lastSortMode;
  List<AnimeEntry>? _cachedSortedContinueWatching;

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<AnimeEntry> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;

  // Infinite scroll pagination state
  int _popularPage = 1;
  final List<AnimeEntry> _extraPopular = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;

  // Tracks whether the feed has completed its first meaningful load.
  // Prevents skeleton from flashing during pull-to-refresh.
  bool _hasCompletedInitialLoad = false;

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
      final results = await repo.searchAnime(trimmed);
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
    final results = await repo.getPopularAnime(page: nextPage, perPage: 12);

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

  void _openDetail(BuildContext context, AnimeEntry entry) {
    AnimeDetailScreen.navigate(
      context,
      mediaId: entry.mediaId,
      initialEntry: entry,
    );
  }

  List<AnimeEntry> _getSortedContinueWatching(
    List<AnimeEntry> entries,
    ContinueWatchingSortMode mode,
    TitleLanguage titleLang,
  ) {
    if (identical(_lastContinueWatchingInput, entries) &&
        _lastSortMode == mode &&
        _cachedSortedContinueWatching != null) {
      return _cachedSortedContinueWatching!;
    }
    _lastContinueWatchingInput = entries;
    _lastSortMode = mode;
    _cachedSortedContinueWatching = _sortContinueWatching(entries, mode, titleLang);
    return _cachedSortedContinueWatching!;
  }

  List<AnimeEntry> _sortContinueWatching(
    List<AnimeEntry> entries,
    ContinueWatchingSortMode mode,
    TitleLanguage titleLang,
  ) {
    final list = List<AnimeEntry>.from(entries);
    switch (mode) {
      case ContinueWatchingSortMode.recent:
        list.sort((a, b) {
          final aTime = a.effectiveTimestamp;
          final bTime = b.effectiveTimestamp;
          if (aTime != bTime) return bTime.compareTo(aTime);
          final aDate = a.airDate != null ? DateTime.tryParse(a.airDate!) : null;
          final bDate = b.airDate != null ? DateTime.tryParse(b.airDate!) : null;
          if (aDate != null && bDate != null) {
            final cmp = bDate.compareTo(aDate);
            if (cmp != 0) return cmp;
          }
          return a.displayTitle(titleLang).compareTo(b.displayTitle(titleLang));
        });
        break;
      case ContinueWatchingSortMode.airDateDesc:
        list.sort((a, b) {
          final aDate = a.airDate != null ? DateTime.tryParse(a.airDate!) : null;
          final bDate = b.airDate != null ? DateTime.tryParse(b.airDate!) : null;
          if (aDate != null && bDate != null) {
            final cmp = bDate.compareTo(aDate);
            if (cmp != 0) return cmp;
          } else if (aDate != null) {
            return -1;
          } else if (bDate != null) {
            return 1;
          }
          final aTime = a.effectiveTimestamp;
          final bTime = b.effectiveTimestamp;
          if (aTime != bTime) return bTime.compareTo(aTime);
          return a.displayTitle(titleLang).compareTo(b.displayTitle(titleLang));
        });
        break;
      case ContinueWatchingSortMode.airDateAsc:
        list.sort((a, b) {
          final aDate = a.airDate != null ? DateTime.tryParse(a.airDate!) : null;
          final bDate = b.airDate != null ? DateTime.tryParse(b.airDate!) : null;
          if (aDate != null && bDate != null) {
            final cmp = aDate.compareTo(bDate);
            if (cmp != 0) return cmp;
          } else if (aDate != null) {
            return -1;
          } else if (bDate != null) {
            return 1;
          }
          return a.displayTitle(titleLang).compareTo(b.displayTitle(titleLang));
        });
        break;
      case ContinueWatchingSortMode.episodeDesc:
        list.sort((a, b) {
          final aEp = a.episodeNumber ?? a.progress;
          final bEp = b.episodeNumber ?? b.progress;
          if (aEp != bEp) return bEp.compareTo(aEp);
          return a.displayTitle(titleLang).compareTo(b.displayTitle(titleLang));
        });
        break;
      case ContinueWatchingSortMode.episodeAsc:
        list.sort((a, b) {
          final aEp = a.episodeNumber ?? a.progress;
          final bEp = b.episodeNumber ?? b.progress;
          if (aEp != bEp) return aEp.compareTo(bEp);
          return a.displayTitle(titleLang).compareTo(b.displayTitle(titleLang));
        });
        break;
      case ContinueWatchingSortMode.title:
        list.sort((a, b) {
          final aTitle = a.displayTitle(titleLang).toLowerCase();
          final bTitle = b.displayTitle(titleLang).toLowerCase();
          return aTitle.compareTo(bTitle);
        });
        break;
    }
    return list;
  }

  List<AnimeEntry> _getMixedList({
    required List<AnimeEntry> trending,
    required List<AnimeEntry> popular,
    required List<AnimeEntry> recent,
    required List<AnimeEntry> extraPopular,
  }) {
    if (identical(_lastTrending, trending) &&
        identical(_lastPopular, popular) &&
        identical(_lastRecent, recent) &&
        _cachedMixedList != null) {
      // Still need to append extraPopular if it changed
      if (extraPopular.isEmpty) return _cachedMixedList!;
    }
    _lastTrending = trending;
    _lastPopular = popular;
    _lastRecent = recent;
    _cachedMixedList = _buildMixedList(
      trending: trending,
      popular: popular,
      recent: recent,
      extraPopular: extraPopular,
    );
    return _cachedMixedList!;
  }

  List<AnimeEntry> _buildMixedList({
    required List<AnimeEntry> trending,
    required List<AnimeEntry> popular,
    required List<AnimeEntry> recent,
    required List<AnimeEntry> extraPopular,
  }) {
    final seen = <int>{};
    final result = <AnimeEntry>[];
    final maxLen = [trending.length, popular.length, recent.length].reduce((a, b) => a > b ? a : b);

    for (int i = 0; i < maxLen; i++) {
      if (i < popular.length && seen.add(popular[i].mediaId)) {
        result.add(popular[i]);
      }
      if (i < trending.length && seen.add(trending[i].mediaId)) {
        result.add(trending[i]);
      }
      if (i < recent.length && seen.add(recent[i].mediaId)) {
        result.add(recent[i]);
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
    final serverState = ref.watch(serverNotifierProvider);
    final theme = Theme.of(context);
    final continueWatchingSort = ref.watch(continueWatchingSortProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final trendingAsync = ref.watch(trendingAnimeProvider);
    final popularAsync = ref.watch(popularAnimeProvider);
    final recentAsync = ref.watch(recentAnimeProvider);
    final continueWatchingAsync = ref.watch(continueWatchingProvider);
    final collectionAsync = ref.watch(animeCollectionProvider);
    final missedSequelsAsync = ref.watch(missedSequelsProvider);
    final recommendationsAsync = ref.watch(recommendationsProvider);

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 720;
    final continueCardWidth = isDesktop ? 300.0 : (screenWidth * 0.70).clamp(250.0, 275.0);
    final continueCardHeight = (continueCardWidth / (16 / 9)) + 48.0;
    final continueListHeight = continueCardHeight + 8.0;

    final animeCardWidth = isDesktop ? 180.0 : 125.0;
    final carouselHeight = isDesktop ? 320.0 : 238.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;
    final topPadding = MediaQuery.of(context).padding.top;
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;

    // Determine if we already have valid data ready (from synchronous instant cache or network)
    final hasUserCachedData = (continueWatchingAsync.value?.isNotEmpty ?? false) ||
        (collectionAsync.value?.isNotEmpty ?? false);
    final hasPublicCachedData = (trendingAsync.value?.isNotEmpty ?? false) ||
        (popularAsync.value?.isNotEmpty ?? false);

    final isServerUnavailable = serverState.state == ServerState.stopped || serverState.state == ServerState.error;

    // Both continueWatching and collection must have resolved when logged in
    final isUserFeedReady = !isLoggedIn ||
        hasUserCachedData ||
        (continueWatchingAsync.hasValue &&
            collectionAsync.hasValue &&
            !continueWatchingAsync.isLoading &&
            !collectionAsync.isLoading);

    // Public feed (trending / popular) must have resolved
    final isPublicFeedReady = hasPublicCachedData ||
        (trendingAsync.hasValue && !trendingAsync.isLoading) ||
        (popularAsync.hasValue && !popularAsync.isLoading);

    if (!_hasCompletedInitialLoad) {
      if (hasUserCachedData || (hasPublicCachedData && !isLoggedIn)) {
        // Instant synchronous render from cache: no skeleton flash or jumps
        _hasCompletedInitialLoad = true;
      } else if (isServerUnavailable) {
        _hasCompletedInitialLoad = true;
      } else if (serverState.isOnline && isUserFeedReady && isPublicFeedReady) {
        _hasCompletedInitialLoad = true;
      }
    }

    final showFeedSkeleton = !_hasCompletedInitialLoad;

    return PopScope(
      canPop: !_isSearching && _searchController.text.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && (_isSearching || _searchController.text.isNotEmpty)) {
          _exitSearch();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            RefreshIndicator(
              edgeOffset: topPadding + 60,
              onRefresh: () async {
                setState(() {
                  _popularPage = 1;
                  _extraPopular.clear();
                  _hasMore = true;
                });
                ref.invalidate(trendingAnimeProvider);
                ref.invalidate(popularAnimeProvider);
                ref.invalidate(recentAnimeProvider);
                ref.invalidate(continueWatchingProvider);
                ref.invalidate(animeCollectionProvider);
                ref.invalidate(missedSequelsProvider);
                ref.invalidate(recommendationsProvider);
              },
              child: CustomScrollView(
                controller: _scrollController,
                cacheExtent: 500,
                slivers: [
                  if (serverState.state == ServerState.stopped || serverState.state == ServerState.error) ...[
                    SliverToBoxAdapter(
                      child: SizedBox(height: topPadding + 10),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                AppIcons.serverOff(iconPack),
                                size: 60,
                                color: theme.colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                l10n.serverNotConnected,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                l10n.serverNotConnectedDesc,
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => ref.read(serverNotifierProvider.notifier).startLocal(),
                                icon: Icon(AppIcons.play(iconPack)),
                                label: Text(l10n.startServer),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: SizedBox(height: isDesktop ? 40.0 : (topPadding + 6)),
                  ),
                        SliverToBoxAdapter(
                          key: const ValueKey('anime_feed_search_bar_sliver'),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: CompactSearchBar(
                              key: const ValueKey('anime_feed_compact_search_bar'),
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              hintText: '${l10n.search} anime...',
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
                                        Icons.search_off_rounded,
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
                                      return AnimeCard(
                                        entry: item,
                                        onTap: () => _openDetail(context, item),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                        ] else ...[
                          if (showFeedSkeleton) ...[
                            // Unified skeleton while server connects or primary data loads
                            SliverToBoxAdapter(
                              child: _FeedLoadingSkeleton(
                                continueCardWidth: continueCardWidth,
                                continueListHeight: continueListHeight,
                                carouselHeight: carouselHeight,
                                cardSpacing: carouselSpacing,
                                animeCardWidth: animeCardWidth,
                                isLoggedIn: isLoggedIn,
                              ),
                            ),
                          ] else ...[
                           // 1. Seguir Viendo (Continue Watching Episodes)
                           continueWatchingAsync.when(
                            data: (entries) {
                              if (entries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                              final sortedEntries = _getSortedContinueWatching(entries, continueWatchingSort, titleLang);
                              return SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      title: l10n.continueWatching,
                                      trailing: SizedBox(
                                        width: 36,
                                        height: 36,
                                        child: PopupMenuButton<ContinueWatchingSortMode>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 175),
                                          icon: Icon(
                                            AppIcons.sort(iconPack),
                                            size: 20,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                          tooltip: '',
                                          onSelected: (mode) {
                                            ref.read(continueWatchingSortProvider.notifier).setSortMode(mode);
                                          },
                                          itemBuilder: (context) => [
                                            for (final mode in ContinueWatchingSortMode.values)
                                              PopupMenuItem(
                                                value: mode,
                                                height: 38,
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      mode == continueWatchingSort
                                                          ? AppIcons.radioChecked(iconPack)
                                                          : AppIcons.radioUnchecked(iconPack),
                                                      size: 16,
                                                      color: mode == continueWatchingSort
                                                          ? theme.colorScheme.primary
                                                          : theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Text(
                                                      mode.localizedLabel(l10n),
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight: mode == continueWatchingSort
                                                            ? FontWeight.bold
                                                            : FontWeight.normal,
                                                        color: mode == continueWatchingSort
                                                            ? theme.colorScheme.primary
                                                            : null,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                     SizedBox(
                                       height: continueListHeight,
                                       child: ListView.separated(
                                         scrollDirection: Axis.horizontal,
                                         cacheExtent: 350,
                                         padding: const EdgeInsets.symmetric(horizontal: 16),
                                         itemCount: sortedEntries.length,
                                         separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                         itemBuilder: (context, index) {
                                           final item = sortedEntries[index];
                                           return ContinueWatchingCard(
                                             entry: item,
                                             width: continueCardWidth,
                                             height: continueCardHeight,
                                             onTap: () => _openDetail(context, item),
                                           );
                                         },
                                       ),
                                     ),
                                     const SizedBox(height: 24),
                                   ],
                                 ),
                               );
                             },
                             loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                             error: (e, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                           ),

                           // 2. Viendo Actualmente (Currently Watching - Carousel)
                           ..._buildWatchingSlivers(
                             collectionAsync: collectionAsync,
                             l10n: l10n,
                             theme: theme,
                             isDesktop: isDesktop,
                           ),

                           // 3. Secuelas que te perdiste (Missed Anime Sequels)
                           missedSequelsAsync.when(
                             data: (missed) {
                               if (missed.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                               return SliverToBoxAdapter(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      _SectionHeader(title: l10n.missedSequels),
                                      SizedBox(
                                        height: carouselHeight,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          cacheExtent: 350,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: missed.length,
                                          separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                          itemBuilder: (context, index) {
                                            final item = missed[index];
                                            return AnimeCard(
                                              entry: item,
                                              width: animeCardWidth,
                                              onTap: () => _openDetail(context, item),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                              error: (error, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            ),

                           // 4. Te podría gustar (Recomendaciones)
                           recommendationsAsync.when(
                             data: (recs) {
                               if (recs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                               return SliverToBoxAdapter(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      _SectionHeader(title: l10n.recommendations),
                                      SizedBox(
                                        height: carouselHeight,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          cacheExtent: 350,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: recs.length,
                                          separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                          itemBuilder: (context, index) {
                                            final item = recs[index];
                                            return AnimeCard(
                                              entry: item,
                                              width: animeCardWidth,
                                              onTap: () => _openDetail(context, item),
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                    ],
                                  ),
                                );
                              },
                              loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                              error: (error, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            ),

                           // 5. En Tendencia (Trending Anime)
                           trendingAsync.when(
                             data: (entries) {
                               if (entries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                               return SliverToBoxAdapter(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      _SectionHeader(
                                        title: l10n.trendingAnime,
                                        trailing: TextButton.icon(
                                          onPressed: () {
                                            Navigator.push(
                                              context,
                                              SlideRightToLeftPageRoute(
                                                child: const AiringCalendarScreen(),
                                              ),
                                            );
                                          },
                                          icon: Icon(AppIcons.calendar(iconPack), size: 15),
                                          label: Text(
                                            l10n.airingCalendar,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                          ),
                                          style: TextButton.styleFrom(
                                            foregroundColor: theme.colorScheme.primary,
                                            visualDensity: VisualDensity.compact,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        height: carouselHeight,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          cacheExtent: 350,
                                          padding: const EdgeInsets.symmetric(horizontal: 16),
                                          itemCount: entries.length,
                                          separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                          itemBuilder: (context, index) {
                                            final item = entries[index];
                                            return AnimeCard(
                                              entry: item,
                                              width: animeCardWidth,
                                              onTap: () => _openDetail(context, item),
                                            );
                                          },
                                        ),
                                      ),const SizedBox(height: 24),
                                   ],
                                 ),
                               );
                             },
                             loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                             error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                           ),

                           // 6. Descubrir Anime with Virtualized Infinite Scrolling
                           ..._buildDiscoverSlivers(
                             trendingAsync: trendingAsync,
                             popularAsync: popularAsync,
                             recentAsync: recentAsync,
                             extraPopular: _extraPopular,
                             isLoadingMore: _isLoadingMore,
                             hasMore: _hasMore,
                             l10n: l10n,
                             theme: theme,
                             isDesktop: isDesktop,
                          ),
                          ], // end skeleton else
                        ],
                      ],
                    ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _isScrolledNotifier,
              builder: (context, isScrolled, _) => TopStatusBarGlass(isVisible: isScrolled),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildWatchingSlivers({
    required AsyncValue<List<AnimeEntry>> collectionAsync,
    required AppTranslations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    final allCollection = collectionAsync.value ?? [];
    final watching = allCollection
        .where((e) => e.status.toUpperCase() == 'CURRENT' || e.status.toUpperCase() == 'WATCHING')
        .toList();
    if (watching.isEmpty) return const [];

    final animeCardWidth = isDesktop ? 180.0 : 125.0;
    final carouselHeight = isDesktop ? 320.0 : 238.0;
    final carouselSpacing = isDesktop ? 14.0 : 10.0;

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: '${l10n.currentlyWatching} (${watching.length})'),
            SizedBox(
              height: carouselHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                cacheExtent: 350,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: watching.length,
                separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                itemBuilder: (context, index) {
                  final item = watching[index];
                  return AnimeCard(
                    entry: item,
                    width: animeCardWidth,
                    onTap: () => _openDetail(context, item),
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

  List<Widget> _buildDiscoverSlivers({
    required AsyncValue<List<AnimeEntry>> trendingAsync,
    required AsyncValue<List<AnimeEntry>> popularAsync,
    required AsyncValue<List<AnimeEntry>> recentAsync,
    required List<AnimeEntry> extraPopular,
    required bool isLoadingMore,
    required bool hasMore,
    required AppTranslations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    final trending = trendingAsync.value ?? [];
    final popular = popularAsync.value ?? [];
    final recent = recentAsync.value ?? [];

    if (trending.isEmpty && popular.isEmpty && recent.isEmpty) {
      if (trendingAsync.isLoading || popularAsync.isLoading || recentAsync.isLoading) {
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
      recent: recent,
      extraPopular: extraPopular,
    );

    return [
      SliverToBoxAdapter(
        child: _SectionHeader(title: l10n.discoverAnime),
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
                return AnimeCard(
                  entry: item,
                  onTap: () => _openDetail(context, item),
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

/// Animated shimmer skeleton that reserves the correct vertical space for feed
/// sections while data loads. Prevents layout jumps by occupying the same height
/// that real content will use.
class _FeedLoadingSkeleton extends StatefulWidget {
  final double continueCardWidth;
  final double continueListHeight;
  final double carouselHeight;
  final double cardSpacing;
  final double animeCardWidth;
  final bool isLoggedIn;

  const _FeedLoadingSkeleton({
    required this.continueCardWidth,
    required this.continueListHeight,
    required this.carouselHeight,
    required this.cardSpacing,
    required this.animeCardWidth,
    this.isLoggedIn = false,
  });

  @override
  State<_FeedLoadingSkeleton> createState() => _FeedLoadingSkeletonState();
}

class _FeedLoadingSkeletonState extends State<_FeedLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.surfaceContainerHighest;
    final borderRadius = BorderRadius.circular(10);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isLoggedIn) ...[
              // ── Section 1: "Continue Watching" skeleton ──
              _buildShimmerHeader(color, 1.0),
              SizedBox(
                height: widget.continueListHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildShimmerBox(
                      widget.continueCardWidth,
                      widget.continueListHeight - 8,
                      color,
                      1.0,
                      borderRadius,
                    ),
                    SizedBox(width: widget.cardSpacing),
                    _buildShimmerBox(
                      widget.continueCardWidth,
                      widget.continueListHeight - 8,
                      color,
                      1.0,
                      borderRadius,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Section 2: "Currently Watching" skeleton ──
              _buildShimmerHeader(color, 1.0),
              SizedBox(
                height: widget.carouselHeight,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: List.generate(
                    4,
                    (i) => Padding(
                      padding: EdgeInsets.only(right: widget.cardSpacing),
                      child: _buildShimmerBox(
                        widget.animeCardWidth,
                        widget.carouselHeight,
                        color,
                        1.0,
                        borderRadius,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Section 3: Trending skeleton ──
            _buildShimmerHeader(color, 1.0),
            SizedBox(
              height: widget.carouselHeight,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: List.generate(
                  4,
                  (i) => Padding(
                    padding: EdgeInsets.only(right: widget.cardSpacing),
                    child: _buildShimmerBox(
                      widget.animeCardWidth,
                      widget.carouselHeight,
                      color,
                      1.0,
                      borderRadius,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
        builder: (context, child) {
          final opacity = 0.18 + (_controller.value * 0.28);
          return Opacity(
            opacity: opacity,
            child: child,
          );
        },
      ),
    );
  }

  Widget _buildShimmerHeader(Color color, double opacity) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 8),
      child: SizedBox(
        height: 36,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 150,
            height: 16,
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerBox(
    double width,
    double height,
    Color color,
    double opacity,
    BorderRadius borderRadius,
  ) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        borderRadius: borderRadius,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

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
            ?trailing,
          ],
        ),
      ),
    );
  }
}
