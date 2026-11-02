import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/anime_preview/anime_preview_popup.dart';
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

  Future<void> _openAnimePreview(BuildContext context, AnimeEntry entry) {
    final heroTag = 'search_anime_${entry.mediaId}';
    final route = PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (pageContext, animation, secondaryAnimation) {
        return AnimePreviewPopup(
          entry: entry,
          heroTag: heroTag,
          onOpenDetails: () {
            Navigator.of(pageContext).pop();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!context.mounted) return;
              AnimeDetailScreen.navigate(
                context,
                mediaId: entry.mediaId,
                initialEntry: entry,
              );
            });
          },
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
    return Navigator.of(context).push(route);
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
                  child: GlassButton(
                    onPressed: onOpenFilterSheet,
                    padding: EdgeInsets.zero,
                    semanticLabel: l10n.filters,
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Icon(
                          filterState.hasActiveFilters
                              ? AppIcons.sliders(iconPack)
                              : AppIcons.filter(iconPack),
                          size: 18,
                          color: filterState.hasActiveFilters
                              ? theme.colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
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
          // 2. Header: Botón Explorar + Título
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              M3EButton(
                onPressed: onBack,
                style: M3EButtonStyle.tonal,
                icon: Icon(AppIcons.explore(iconPack), size: 18),
                label: Text(
                  l10n.navExplore,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  headerTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // 3. Layout de dos columnas: Filtros a la izquierda + Grid a la derecha
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Columna izquierda: filtros Material 3 Expressive
                SizedBox(
                  width: 320,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 24, bottom: 4),
                    child: SingleChildScrollView(
                      child: CatalogFilterSidebar(
                        searchController: searchController,
                        onSearchChanged: onSearchChanged,
                        filterState: filterState,
                        onFilterChanged: onFilterChanged,
                        onReset: onResetFilters,
                      ),
                    ),
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
      return Center(
        child: M3ELoadingIndicator(
          variant: M3ELoadingIndicatorVariant.contained,
          size: 48,
          color: theme.colorScheme.primary,
        ),
      );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const crossSpacingDesktop = 16.0;
        const crossSpacingMobile = 8.0;
        final horizontalPadding = isDesktop ? 16.0 : 20.0;
        final crossSpacing = isDesktop ? crossSpacingDesktop : crossSpacingMobile;
        final availableWidth =
            (constraints.maxWidth - horizontalPadding).clamp(1.0, double.infinity);

        final columns = isDesktop
            ? ((availableWidth + crossSpacing) / (245.0 + crossSpacing))
                .ceil()
                .clamp(1, 8)
                .toInt()
            : 3;
        final cardWidth =
            (availableWidth - crossSpacing * (columns - 1)) / columns;

        // Match the grid cell to the card's real content (poster + 2-line
        // title) so there is no dead space between the title and the next row.
        final compact = cardWidth < 155;
        final cardPadding = compact ? 2.5 : 4.0;
        final gap = compact ? 6.0 : 8.0;
        final titleFontSize = compact ? 13.0 : 14.5;
        final titleLineHeight =
            MediaQuery.textScalerOf(context).scale(titleFontSize) * 1.25;
        final metaLineHeight =
            MediaQuery.textScalerOf(context).scale(compact ? 11.0 : 12.0) * 1.25 + 3;
        final cellHeight = cardPadding * 2 +
            (cardWidth - cardPadding * 2) / 0.72 +
            gap +
            titleLineHeight * 2 +
            metaLineHeight +
            4;
        final aspectRatio = cardWidth / cellHeight;

        return DynMouseScroll(
          smoothingFactor: 22,
          builder: (context, scrollController) {
            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.axis == Axis.vertical &&
                    hasMore &&
                    !isLoadingMore &&
                    notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 400) {
                  onLoadMore();
                }
                return false;
              },
              child: CustomScrollView(
                controller: scrollController,
            clipBehavior: Clip.hardEdge,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? 4 : 10,
                  isDesktop ? 0 : 8,
                  isDesktop ? 12 : 10,
                  0,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    childAspectRatio: aspectRatio,
                    crossAxisSpacing: crossSpacing,
                    mainAxisSpacing: isDesktop ? 10 : 8,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (isAnime || filterState.mediaType == 'SHOWS') {
                        final anime = animeResults[index];
                        final heroTag = 'search_anime_${anime.mediaId}';
                        return AnimeCard(
                          entry: anime,
                          showMetadata: true,
                          animateEntry: false,
                          heroTag: heroTag,
                          onSecondaryTap: () => _openAnimePreview(context, anime),
                          onTap: () {
                            searchFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
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
                          showMetadata: true,
                          onTap: () {
                            searchFocusNode.unfocus();
                            FocusScope.of(context).unfocus();
                            MangaDetailScreen.navigate(
                              context,
                              mediaId: manga.mediaId,
                              initialEntry: manga,
                            );
                          },
                        );
                      }
                    },
                    childCount: totalItems,
                    addAutomaticKeepAlives: false,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 12, 0, 90),
                  child: isLoadingMore
                      ? Center(
                          child: M3ELoadingIndicator(
                            variant: M3ELoadingIndicatorVariant.contained,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        );
          },
        );
      },
    );
  }
}
