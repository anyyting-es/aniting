import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/catalog_search/catalog_filter_sidebar.dart';
import 'package:seanime_app/presentation/widgets/compact_search_bar.dart';
import 'package:seanime_app/presentation/widgets/discover_filter_sheet.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';

/// Vista principal del catálogo y búsqueda avanzada.
/// En pantallas anchas (Desktop/Tablet) presenta el diseño split-column con el botón
/// "Discover series", título destacado, barra lateral de filtros (270px) y el grid
/// oficial de AnimeCard / MangaCard de la app (con proporciones estándar y respetando el tema).
class CatalogSearchView extends ConsumerWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final DiscoverFilterState filterState;
  final ValueChanged<DiscoverFilterState> onFilterChanged;
  final VoidCallback onResetFilters;
  final VoidCallback onBack;
  final VoidCallback onOpenFilterSheet;
  final List<AnimeEntry> animeResults;
  final List<MangaEntry> mangaResults;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final VoidCallback onLoadMore;

  const CatalogSearchView({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.filterState,
    required this.onFilterChanged,
    required this.onResetFilters,
    required this.onBack,
    required this.onOpenFilterSheet,
    required this.animeResults,
    required this.mangaResults,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.onLoadMore,
  });

  String _getHeaderTitle(AppTranslations l10n) {
    if (searchController.text.trim().isNotEmpty) {
      return searchController.text.trim();
    }
    switch (filterState.sort) {
      case 'SCORE_DESC':
        return l10n.highestRatedShows;
      case 'POPULARITY_DESC':
        return l10n.sortPopularity;
      case 'TRENDING_DESC':
        return l10n.sortTrending;
      case 'START_DATE_DESC':
        return l10n.sortStartDate;
      default:
        return l10n.discoverSeries;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 720;
    final isAnime = filterState.mediaType == 'ANIME';
    final isShows = filterState.mediaType == 'SHOWS';
    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);
    final totalItems = (isAnime || isShows) ? animeResults.length : mangaResults.length;
    final headerTitle = _getHeaderTitle(l10n);

    String searchHint = '${l10n.search} anime...';
    if (isShows) {
      searchHint = '${l10n.search} shows...';
    } else if (!isAnime) {
      searchHint = '${l10n.search} manga...';
    }

    if (!isDesktop) {
      // Versión Mobile compacta
      final topPadding = MediaQuery.of(context).padding.top;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 6, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: CompactSearchBar(
                    controller: searchController,
                    focusNode: searchFocusNode,
                    hintText: searchHint,
                    isSearching: true,
                    onChanged: onSearchChanged,
                    onBack: onBack,
                    onClear: onResetFilters,
                  ),
                ),
                const SizedBox(width: 8),
                Badge(
                  isLabelVisible: filterState.hasActiveFilters,
                  label: Text('${filterState.activeFilterCount}'),
                  child: IconButton.filledTonal(
                    tooltip: l10n.filters,
                    icon: Icon(
                      filterState.hasActiveFilters
                          ? AppIcons.sliders(iconPack)
                          : AppIcons.filter(iconPack),
                      color: filterState.hasActiveFilters ? theme.colorScheme.primary : null,
                    ),
                    onPressed: onOpenFilterSheet,
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
                  selected: filterState.mediaType,
                  showAnime: animeEnabled,
                  showShows: showsEnabled,
                  showManga: mangaEnabled,
                  onSelected: (val) {
                    onFilterChanged(filterState.copyWith(
                      mediaType: val,
                      season: () => (val == 'MANGA' || val == 'SHOWS') ? null : filterState.season,
                    ));
                  },
                ),
                const Spacer(),
                if (filterState.hasActiveFilters)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: Text(l10n.clearFilters, style: const TextStyle(fontSize: 12)),
                    onPressed: onResetFilters,
                  ),
              ],
            ),
          ),
          Expanded(
            child: _buildGridContent(
              context: context,
              theme: theme,
              l10n: l10n,
              iconPack: iconPack,
              isDesktop: false,
              isAnime: isAnime,
              totalItems: totalItems,
            ),
          ),
        ],
      );
    }

    // Versión Desktop/Tablet completa
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2. Título de sección (ej. "Highest rated shows")
          Text(
            headerTitle,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
              letterSpacing: -0.4,
            ),
          ),

          const SizedBox(height: 18),

          // 3. Layout de dos columnas: Filtros a la izquierda + Grid a la derecha
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: Barra lateral de filtros
                SingleChildScrollView(
                  child: CatalogFilterSidebar(
                    searchController: searchController,
                    onSearchChanged: onSearchChanged,
                    filterState: filterState,
                    onFilterChanged: onFilterChanged,
                    onReset: onResetFilters,
                  ),
                ),

                // Columna derecha: Grid de resultados con AnimeCard / MangaCard oficiales
                Expanded(
                  child: _buildGridContent(
                    context: context,
                    theme: theme,
                    l10n: l10n,
                    iconPack: iconPack,
                    isDesktop: true,
                    isAnime: isAnime,
                    totalItems: totalItems,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridContent({
    required BuildContext context,
    required ThemeData theme,
    required AppTranslations l10n,
    required AppIconPack iconPack,
    required bool isDesktop,
    required bool isAnime,
    required int totalItems,
  }) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (totalItems == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              AppIcons.searchOff(iconPack),
              size: 52,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.noResultsFound,
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: Icon(AppIcons.clearAll(iconPack), size: 16),
              label: Text(l10n.clearFilters),
              onPressed: onResetFilters,
            ),
          ],
        ),
      );
    }

    // Grid usando proporciones estándar de la app (maxCrossAxisExtent: 200–220, childAspectRatio: 0.53–0.58)
    return GridView.builder(
      clipBehavior: Clip.none,
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 4 : 16,
        isDesktop ? 0 : 8,
        isDesktop ? 12 : 16,
        90,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isDesktop ? 200 : 150,
        childAspectRatio: 0.53,
        crossAxisSpacing: isDesktop ? 16 : 10,
        mainAxisSpacing: isDesktop ? 20 : 14,
      ),
      itemCount: totalItems + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= totalItems) {
          onLoadMore();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (isAnime || filterState.mediaType == 'SHOWS') {
          final anime = animeResults[index];
          return AnimeCard(
            entry: anime,
            onTap: () {
              AnimeDetailScreen.navigate(
                context,
                mediaId: anime.mediaId,
                initialEntry: anime,
              );
            },
          );
        } else {
          final manga = mangaResults[index];
          return MangaCard(
            entry: manga,
            onTap: () {
              MangaDetailScreen.navigate(
                context,
                mediaId: manga.mediaId,
                initialEntry: manga,
              );
            },
          );
        }
      },
    );
  }
}
