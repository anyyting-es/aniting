import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/continue_watching_sort_provider.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/continue_watching_card.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

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

  // Sorting memoization
  List<AnimeEntry>? _lastContinueWatchingInput;
  ContinueWatchingSortMode? _lastSortMode;
  List<AnimeEntry>? _cachedSortedContinueWatching;

  // In-page search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<AnimeEntry> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;

  // Initial load barrier
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

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final scrolled = _scrollController.position.pixels > 10;
    if (scrolled != _isScrolledNotifier.value) {
      _isScrolledNotifier.value = scrolled;
    }
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

  @override
  Widget build(BuildContext context) {
    final serverState = ref.watch(serverNotifierProvider);
    final theme = Theme.of(context);
    final continueWatchingSort = ref.watch(continueWatchingSortProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    // Full User Library Providers
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

    // Cache / Readiness check for user library
    final hasUserCachedData = (continueWatchingAsync.value?.isNotEmpty ?? false) ||
        (collectionAsync.value?.isNotEmpty ?? false);
    final isServerUnavailable = serverState.state == ServerState.stopped || serverState.state == ServerState.error;

    final isUserFeedReady = !isLoggedIn ||
        hasUserCachedData ||
        (continueWatchingAsync.hasValue &&
            collectionAsync.hasValue &&
            !continueWatchingAsync.isLoading &&
            !collectionAsync.isLoading);

    if (!_hasCompletedInitialLoad) {
      if (hasUserCachedData || isServerUnavailable || (serverState.isOnline && isUserFeedReady)) {
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
                      SliverToBoxAdapter(
                        child: _FeedLoadingSkeleton(
                          continueCardWidth: continueCardWidth,
                          continueListHeight: continueListHeight,
                          carouselHeight: carouselHeight,
                          cardSpacing: carouselSpacing,
                          animeCardWidth: animeCardWidth,
                        ),
                      ),
                    ] else ...[
                      // ─── 1. Seguir Viendo (Continue Watching with Local Playback Progress) ───
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

                      // ─── 2. Viendo Actualmente (Currently Watching) ───
                      ..._buildWatchingSlivers(
                        collectionAsync: collectionAsync,
                        l10n: l10n,
                        theme: theme,
                        isDesktop: isDesktop,
                      ),

                      // ─── 3. Secuelas que te has perdido (Complete Missed Sequels List) ───
                      missedSequelsAsync.when(
                        data: (missed) {
                          if (missed.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                          return SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(title: '${l10n.missedSequels} (${missed.length})'),
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

                      // ─── 4. Te podría gustar (Recomendaciones del Usuario) ───
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
}

class _FeedLoadingSkeleton extends StatefulWidget {
  final double continueCardWidth;
  final double continueListHeight;
  final double carouselHeight;
  final double cardSpacing;
  final double animeCardWidth;

  const _FeedLoadingSkeleton({
    required this.continueCardWidth,
    required this.continueListHeight,
    required this.carouselHeight,
    required this.cardSpacing,
    required this.animeCardWidth,
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
            // Continue Watching skeleton
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

            // Currently Watching skeleton
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
