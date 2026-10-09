import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/section_visibility_provider.dart';
import 'package:seanime_app/presentation/widgets/catalog_search/catalog_filter_dropdown.dart';
import 'package:seanime_app/presentation/widgets/discover_filter_sheet.dart';

/// Panel lateral de filtros espacioso y legible (320px de ancho).
/// Posee fuentes y controles cómodos (14.5px, botones de 48px), alineados a la jerarquía visual de la app.
class CatalogFilterSidebar extends ConsumerWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final DiscoverFilterState filterState;
  final ValueChanged<DiscoverFilterState> onFilterChanged;
  final VoidCallback onReset;

  const CatalogFilterSidebar({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.filterState,
    required this.onFilterChanged,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final isAnime = filterState.mediaType == 'ANIME';
    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);

    return Container(
      width: 320,
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Buscador de título integrado al tema con mayor tamaño y legibilidad
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                width: 0.8,
              ),
            ),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: theme.colorScheme.onSurfaceVariant,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      )
                    : null,
                hintText: l10n.titleSearchPlaceholder,
                hintStyle: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                border: InputBorder.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 2. Tipo de medio (Anime / Manga)
          if (animeEnabled && mangaEnabled)
            CatalogFilterDropdown<String>(
              label: isAnime ? l10n.anime : l10n.manga,
              selectedValue: filterState.mediaType,
              items: [
                CatalogFilterDropdownItem(value: 'ANIME', label: l10n.anime),
                CatalogFilterDropdownItem(value: 'MANGA', label: l10n.manga),
              ],
              onChanged: (val) {
                onFilterChanged(
                  filterState.copyWith(
                    mediaType: val,
                    season: () => val == 'MANGA' ? null : filterState.season,
                  ),
                );
              },
            ),

          if (animeEnabled && mangaEnabled) const SizedBox(height: 12),

          // 3. Orden (Sort)
          CatalogFilterDropdown<String>(
            icon: Icons.swap_vert_rounded,
            label: _getSortLabel(filterState.sort, l10n),
            selectedValue: filterState.sort,
            items: [
              CatalogFilterDropdownItem(value: 'SCORE_DESC', label: l10n.highestScore),
              CatalogFilterDropdownItem(value: 'POPULARITY_DESC', label: l10n.sortPopularity),
              CatalogFilterDropdownItem(value: 'TRENDING_DESC', label: l10n.sortTrending),
              CatalogFilterDropdownItem(value: 'START_DATE_DESC', label: l10n.sortStartDate),
            ],
            onChanged: (val) => onFilterChanged(filterState.copyWith(sort: val)),
          ),

          const SizedBox(height: 12),

          // 4. Géneros (All genres)
          CatalogFilterDropdown<String?>(
            icon: Icons.grid_view_rounded,
            label: filterState.selectedGenres.isNotEmpty
                ? _getGenreName(filterState.selectedGenres.first, isSpanish)
                : l10n.allGenres,
            selectedValue: filterState.selectedGenres.isNotEmpty
                ? filterState.selectedGenres.first
                : null,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.allGenres),
              ...kOfficialGenresData.map(
                (g) => CatalogFilterDropdownItem(
                  value: g['key']!,
                  label: isSpanish ? g['es']! : g['en']!,
                ),
              ),
            ],
            onChanged: (val) {
              onFilterChanged(
                filterState.copyWith(
                  selectedGenres: val != null ? {val} : const {},
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 5. Etiquetas (All tags)
          CatalogFilterDropdown<String?>(
            icon: Icons.sell_outlined,
            label: filterState.selectedTags.isNotEmpty
                ? _getTagName(filterState.selectedTags.first, isSpanish)
                : l10n.allTags,
            selectedValue: filterState.selectedTags.isNotEmpty
                ? filterState.selectedTags.first
                : null,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.allTags),
              ...kPopularTagsData.map(
                (t) => CatalogFilterDropdownItem(
                  value: t['key']!,
                  label: isSpanish ? t['es']! : t['en']!,
                ),
              ),
            ],
            onChanged: (val) {
              onFilterChanged(
                filterState.copyWith(
                  selectedTags: val != null ? {val} : const {},
                ),
              );
            },
          ),

          const SizedBox(height: 12),

          // 6. Formatos (All formats)
          CatalogFilterDropdown<String?>(
            icon: Icons.tv_rounded,
            label: filterState.format != null
                ? l10n.formatFormat(filterState.format!)
                : l10n.allFormats,
            selectedValue: filterState.format,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.allFormats),
              if (isAnime) ...[
                CatalogFilterDropdownItem(value: 'TV', label: l10n.formatTv),
                CatalogFilterDropdownItem(value: 'MOVIE', label: l10n.formatMovie),
                CatalogFilterDropdownItem(value: 'TV_SHORT', label: l10n.formatTvShort),
                CatalogFilterDropdownItem(value: 'SPECIAL', label: l10n.formatSpecial),
                CatalogFilterDropdownItem(value: 'OVA', label: l10n.formatOva),
                CatalogFilterDropdownItem(value: 'ONA', label: l10n.formatOna),
              ] else ...[
                CatalogFilterDropdownItem(value: 'MANGA', label: l10n.formatManga),
                CatalogFilterDropdownItem(value: 'NOVEL', label: l10n.formatNovel),
                CatalogFilterDropdownItem(value: 'ONE_SHOT', label: l10n.formatOneShot),
              ],
            ],
            onChanged: (val) {
              onFilterChanged(filterState.copyWith(format: () => val));
            },
          ),

          if (isAnime) const SizedBox(height: 12),

          // 7. Temporadas (All seasons) - Solo anime
          if (isAnime)
            CatalogFilterDropdown<String?>(
              icon: Icons.explore_outlined,
              label: filterState.season != null
                  ? l10n.formatSeason(filterState.season)
                  : l10n.allSeasons,
              selectedValue: filterState.season,
              items: [
                CatalogFilterDropdownItem(value: null, label: l10n.allSeasons),
                CatalogFilterDropdownItem(value: 'WINTER', label: l10n.seasonWinter),
                CatalogFilterDropdownItem(value: 'SPRING', label: l10n.seasonSpring),
                CatalogFilterDropdownItem(value: 'SUMMER', label: l10n.seasonSummer),
                CatalogFilterDropdownItem(value: 'FALL', label: l10n.seasonFall),
              ],
              onChanged: (val) {
                onFilterChanged(filterState.copyWith(season: () => val));
              },
            ),

          const SizedBox(height: 12),

          // 8. Año (Timeless)
          CatalogFilterDropdown<int?>(
            icon: Icons.calendar_today_outlined,
            label: filterState.year != null
                ? '${filterState.year}'
                : l10n.timelessYear,
            selectedValue: filterState.year,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.timelessYear),
              ...[2026, 2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005, 2000, 1995].map(
                (y) => CatalogFilterDropdownItem(value: y, label: '$y'),
              ),
            ],
            onChanged: (val) {
              onFilterChanged(filterState.copyWith(year: () => val));
            },
          ),

          const SizedBox(height: 12),

          // 9. Estados (All statuses)
          CatalogFilterDropdown<String?>(
            icon: Icons.sensors_rounded,
            label: filterState.status != null
                ? l10n.formatStatus(filterState.status)
                : l10n.allStatuses,
            selectedValue: filterState.status,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.allStatuses),
              CatalogFilterDropdownItem(value: 'RELEASING', label: l10n.statusReleasing),
              CatalogFilterDropdownItem(value: 'FINISHED', label: l10n.statusFinished),
              CatalogFilterDropdownItem(value: 'NOT_YET_RELEASED', label: l10n.statusNotYetReleased),
              CatalogFilterDropdownItem(value: 'CANCELLED', label: l10n.statusCancelled),
            ],
            onChanged: (val) {
              onFilterChanged(filterState.copyWith(status: () => val));
            },
          ),

          const SizedBox(height: 12),

          // 10. Puntuación (All scores)
          CatalogFilterDropdown<int?>(
            icon: Icons.star_outline_rounded,
            label: filterState.minScore != null
                ? '${filterState.minScore}%+'
                : l10n.allScores,
            selectedValue: filterState.minScore,
            items: [
              CatalogFilterDropdownItem(value: null, label: l10n.allScores),
              const CatalogFilterDropdownItem(value: 90, label: '90%+'),
              const CatalogFilterDropdownItem(value: 80, label: '80%+'),
              const CatalogFilterDropdownItem(value: 70, label: '70%+'),
              const CatalogFilterDropdownItem(value: 60, label: '60%+'),
            ],
            onChanged: (val) {
              onFilterChanged(filterState.copyWith(minScore: () => val));
            },
          ),

          const SizedBox(height: 16),

          // 11. Adult toggle (+18)
          Row(
            children: [
              SizedBox(
                height: 28,
                width: 44,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: filterState.isAdult,
                    activeColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      onFilterChanged(filterState.copyWith(isAdult: val));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.adultContent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 12. Botón Papelera / Reset
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: l10n.clearFilters,
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 22,
                color: filterState.hasActiveFilters || searchController.text.isNotEmpty
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
              onPressed: filterState.hasActiveFilters || searchController.text.isNotEmpty
                  ? onReset
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel(String sort, AppTranslations l10n) {
    switch (sort) {
      case 'SCORE_DESC':
        return l10n.highestScore;
      case 'POPULARITY_DESC':
        return l10n.sortPopularity;
      case 'TRENDING_DESC':
        return l10n.sortTrending;
      case 'START_DATE_DESC':
        return l10n.sortStartDate;
      default:
        return l10n.sortTrending;
    }
  }

  String _getGenreName(String key, bool isSpanish) {
    final match = kOfficialGenresData.firstWhere(
      (g) => g['key'] == key,
      orElse: () => {'key': key, 'es': key, 'en': key},
    );
    return isSpanish ? match['es']! : match['en']!;
  }

  String _getTagName(String key, bool isSpanish) {
    final match = kPopularTagsData.firstWhere(
      (t) => t['key'] == key,
      orElse: () => {'key': key, 'es': key, 'en': key},
    );
    return isSpanish ? match['es']! : match['en']!;
  }
}
