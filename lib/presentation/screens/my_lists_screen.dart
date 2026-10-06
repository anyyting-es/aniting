import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/desktop_title_bar.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/my_lists/my_lists_desktop_layout.dart';

class MyListsScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MyListsScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MyListsScreen> createState() => _MyListsScreenState();
}

class _MyListsScreenState extends ConsumerState<MyListsScreen> {
  String _selectedAnimeStatus = 'CURRENT';
  String _selectedMangaStatus = 'ALL';

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    if (isDesktop) {
      return MyListsDesktopLayout(initialTabIndex: widget.initialTabIndex);
    }

    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: DesktopSafeAppBar(
          child: AppBar(
            leading: const BackButton(),
            title: Text(
              l10n.myLists,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            bottom: TabBar(
              tabs: [
                Tab(
                  icon: const Icon(Icons.movie_rounded),
                  text: l10n.anime,
                ),
                Tab(
                  icon: const Icon(Icons.menu_book_rounded),
                  text: l10n.manga,
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Anime
            _buildAnimeTab(context, l10n, theme, isDesktop),
            // Tab 2: Manga
            _buildMangaTab(context, l10n, theme, isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimeTab(BuildContext context, dynamic l10n, ThemeData theme, bool isDesktop) {
    final collectionAsync = ref.watch(animeCollectionProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(animeCollectionProvider),
      child: CustomScrollView(
        slivers: [
          // Filter Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: l10n.statusWatching,
                      selected: _selectedAnimeStatus == 'CURRENT',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'CURRENT'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusCompleted,
                      selected: _selectedAnimeStatus == 'COMPLETED',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'COMPLETED'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusPlanning,
                      selected: _selectedAnimeStatus == 'PLANNING',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'PLANNING'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusDropped,
                      selected: _selectedAnimeStatus == 'DROPPED',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'DROPPED'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusPaused,
                      selected: _selectedAnimeStatus == 'PAUSED',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'PAUSED'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusAll,
                      selected: _selectedAnimeStatus == 'ALL',
                      onSelected: () => setState(() => _selectedAnimeStatus = 'ALL'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Grid
          ...collectionAsync.when(
            data: (entries) {
              final filtered = entries.where((e) {
                if (_selectedAnimeStatus == 'ALL') return true;
                if (_selectedAnimeStatus == 'CURRENT') {
                  return e.status == 'CURRENT' || e.status == 'WATCHING';
                }
                return e.status == _selectedAnimeStatus;
              }).toList();

              if (filtered.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.folder_open_rounded, size: 56, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            entries.isEmpty ? l10n.emptyLibraryLocal : l10n.emptyLibraryCategory,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => ref.invalidate(animeCollectionProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }

              return [
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 40),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 210 : 135,
                      childAspectRatio: isDesktop ? 0.58 : 0.52,
                      crossAxisSpacing: isDesktop ? 14 : 10,
                      mainAxisSpacing: isDesktop ? 20 : 14,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
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
                    },
                  ),
                ),
              ];
            },
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (err, stack) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('${l10n.error}: $err')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMangaTab(BuildContext context, dynamic l10n, ThemeData theme, bool isDesktop) {
    final mangaAsync = ref.watch(mangaCollectionProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(mangaCollectionProvider),
      child: CustomScrollView(
        slivers: [
          // Filter Chips for Manga
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      label: l10n.statusAll,
                      selected: _selectedMangaStatus == 'ALL',
                      onSelected: () => setState(() => _selectedMangaStatus = 'ALL'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.reading,
                      selected: _selectedMangaStatus == 'CURRENT',
                      onSelected: () => setState(() => _selectedMangaStatus = 'CURRENT'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusCompleted,
                      selected: _selectedMangaStatus == 'COMPLETED',
                      onSelected: () => setState(() => _selectedMangaStatus = 'COMPLETED'),
                    ),
                    const SizedBox(width: 8),
                    _buildFilterChip(
                      label: l10n.statusPlanning,
                      selected: _selectedMangaStatus == 'PLANNING',
                      onSelected: () => setState(() => _selectedMangaStatus = 'PLANNING'),
                    ),
                  ],
                ),
              ),
            ),
          ),

          ...mangaAsync.when(
            data: (entries) {
              final filtered = entries.where((e) {
                if (_selectedMangaStatus == 'ALL') return true;
                if (_selectedMangaStatus == 'CURRENT') {
                  return e.status == 'CURRENT' || e.status == 'READING';
                }
                return e.status == _selectedMangaStatus;
              }).toList();

              if (filtered.isEmpty) {
                return [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 56, color: theme.colorScheme.outline),
                          const SizedBox(height: 12),
                          Text(
                            l10n.emptyLibraryCategory,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => ref.invalidate(mangaCollectionProvider),
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(l10n.refresh),
                          ),
                        ],
                      ),
                    ),
                  ),
                ];
              }

              return [
                SliverPadding(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 40),
                  sliver: SliverGrid.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: isDesktop ? 210 : 135,
                      childAspectRatio: isDesktop ? 0.58 : 0.52,
                      crossAxisSpacing: isDesktop ? 14 : 10,
                      mainAxisSpacing: isDesktop ? 20 : 14,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
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
                ),
              ];
            },
            loading: () => const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
            error: (err, stack) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('${l10n.error}: $err')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
    );
  }
}
