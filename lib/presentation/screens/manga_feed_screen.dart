import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/downloads_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/continue_reading_card.dart';
import 'package:seanime_app/presentation/widgets/feed_empty_state.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/server_status_banner.dart';
import 'package:seanime_app/presentation/widgets/top_status_bar_glass.dart';

import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/core/server/server_manager.dart';
import 'package:seanime_app/data/services/feed_cache_service.dart';
import 'package:seanime_app/data/services/offline_library_service.dart';

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
  final ScrollController _scrollController = SmoothScrollController();
  final ValueNotifier<bool> _isScrolledNotifier = ValueNotifier<bool>(false);

  // In-page search state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<MangaEntry> _searchResults = [];
  bool _isSearching = false;
  bool _isSearchLoading = false;

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

  Future<void> _refresh() async {
    ref.invalidate(continueReadingMangaProvider);
    ref.invalidate(mangaCollectionProvider);
    ref.invalidate(mangaRecommendationsProvider);
    ref.invalidate(downloadedMangaListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final serverState = ref.watch(serverNotifierProvider);

    // Full User Library Manga Providers
    final continueReadingAsync = ref.watch(continueReadingMangaProvider);
    final mangaCollectionAsync = ref.watch(mangaCollectionProvider);
    final mangaRecommendationsAsync = ref.watch(mangaRecommendationsProvider);
    final downloadedMangaAsync = ref.watch(downloadedMangaListProvider);
    final isLoggedIn = serverState.status?.isLoggedIn ?? false;
    final isOffline = !serverState.isOnline || serverState.state == ServerState.error;

    final cachedCr = FeedCacheService.instance.getMangaList(FeedCacheService.kCacheContinueReadingManga);
    final offlineCr = OfflineLibraryService.instance.getContinueReading();
    final continueReadingEntries = continueReadingAsync.value ??
        (continueReadingAsync.isLoading
            ? (cachedCr.isNotEmpty ? cachedCr : (isOffline ? offlineCr : <MangaEntry>[]))
            : (isOffline ? offlineCr : <MangaEntry>[]));

    final hasContinueReading = continueReadingEntries.isNotEmpty;
    final hasCompleted = mangaCollectionAsync.value?.any((e) => e.status.toUpperCase() == 'COMPLETED') ?? false;
    final hasReading = mangaCollectionAsync.value?.any((e) => e.status.toUpperCase() == 'CURRENT' || e.status.toUpperCase() == 'READING') ?? false;
    final hasMangaRecs = mangaRecommendationsAsync.value?.isNotEmpty ?? false;
    final hasDownloadedManga = downloadedMangaAsync.value?.isNotEmpty ?? false;
    final hasAnyMangaContent = hasContinueReading || hasCompleted || hasReading || hasMangaRecs || hasDownloadedManga;

    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final mangaCardWidth = isDesktop ? 180.0 : 135.0;
    final carouselHeight = isDesktop ? 320.0 : 252.0;
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
                      ref.invalidate(continueReadingMangaProvider);
                      ref.invalidate(mangaCollectionProvider);
                      ref.invalidate(mangaRecommendationsProvider);
                    },
                    child: CustomScrollView(
                      controller: _scrollController,
                      cacheExtent: 500,
                      slivers: [
                        SliverToBoxAdapter(
                          child: SizedBox(height: isDesktop ? 40.0 : (topPadding + 6)),
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
                          if (!hasAnyMangaContent) ...[
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: FeedEmptyState(
                                isLoggedIn: isLoggedIn,
                                isManga: true,
                                isOffline: isOffline,
                                onRetry: _refresh,
                                iconPack: iconPack,
                                onExplore: widget.onOpenSearch,
                              ),
                            ),
                          ] else ...[
                            // ─── 1. Seguir Leyendo (Continue Reading) ───
                            ..._buildContinueReadingSlivers(
                              entries: continueReadingEntries,
                              l10n: l10n,
                              theme: theme,
                              isDesktop: isDesktop,
                            ),

                          // ─── 2. Descargas de Manga (Downloaded Manga) ───
                          downloadedMangaAsync.when(
                            data: (downloaded) {
                              if (downloaded.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                              return SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(
                                      title: '${l10n.downloadedMangaSection} (${downloaded.length})',
                                      trailing: TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const DownloadsScreen(initialTabIndex: 1),
                                            ),
                                          );
                                        },
                                        child: Text(
                                          l10n.viewAll,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      height: carouselHeight + 16,
                                      child: ListView.separated(
                                        clipBehavior: Clip.none,
                                        scrollDirection: Axis.horizontal,
                                        cacheExtent: 350,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        itemCount: downloaded.length,
                                        separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                        itemBuilder: (context, index) {
                                          final item = downloaded[index];
                                          return MangaCard(
                                            entry: item,
                                            width: mangaCardWidth,
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
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                          ),

                          // ─── 3. Mangas Completados (Completed Manga) ───
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
                                      height: carouselHeight + 16,
                                      child: ListView.separated(
                                        clipBehavior: Clip.none,
                                        scrollDirection: Axis.horizontal,
                                        cacheExtent: 350,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        itemCount: completed.length,
                                        separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                        itemBuilder: (context, index) {
                                          return MangaCard(entry: completed[index], width: mangaCardWidth);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                          ),

                          // ─── 3. Te podría gustar (Recomendaciones de Manga) ───
                          mangaRecommendationsAsync.when(
                            data: (recs) {
                              if (recs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                              return SliverToBoxAdapter(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _SectionHeader(title: l10n.recommendations),
                                    SizedBox(
                                      height: carouselHeight + 16,
                                      child: ListView.separated(
                                        clipBehavior: Clip.none,
                                        scrollDirection: Axis.horizontal,
                                        cacheExtent: 350,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        itemCount: recs.length,
                                        separatorBuilder: (context, index) => SizedBox(width: carouselSpacing),
                                        itemBuilder: (context, index) {
                                          final item = recs[index];
                                          return MangaCard(
                                            entry: item,
                                            width: mangaCardWidth,
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
                                    ),
                                    const SizedBox(height: 20),
                                  ],
                                ),
                              );
                            },
                            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                            error: (err, stack) => const SliverToBoxAdapter(child: SizedBox.shrink()),
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
    required List<MangaEntry> entries,
    required AppTranslations l10n,
    required ThemeData theme,
    required bool isDesktop,
  }) {
    if (entries.isEmpty) return [];

    final cardWidth = isDesktop ? 180.0 : 130.0;
    final listHeight = isDesktop ? 320.0 : 238.0;
    final spacing = isDesktop ? 14.0 : 10.0;

    return [
      SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: l10n.continueReading),
            SizedBox(
              height: listHeight + 16,
              child: ListView.separated(
                clipBehavior: Clip.none,
                scrollDirection: Axis.horizontal,
                cacheExtent: 350,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: entries.length,
                separatorBuilder: (context, index) => SizedBox(width: spacing),
                itemBuilder: (context, index) {
                  final item = entries[index];
                  return ContinueReadingCard(
                    entry: item,
                    width: cardWidth,
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
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    ];
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
