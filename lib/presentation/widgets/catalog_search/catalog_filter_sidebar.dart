import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/preferences/section_visibility_provider.dart';
import 'package:aniting/presentation/widgets/discover_filter_sheet.dart';

/// Compact filter panel for catalog search.
///
/// The title search uses Liquid Glass (`g1455`); every other filter is a
/// Material 3 Expressive dropdown. Multi-select filters (genres, tags) keep
/// their picks as removable chips inside the field.
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
    final isShows = filterState.mediaType == 'SHOWS';
    final animeEnabled = ref.watch(animeSectionEnabledProvider);
    final showsEnabled = ref.watch(showsSectionEnabledProvider);
    final mangaEnabled = ref.watch(mangaSectionEnabledProvider);

    String mediaTypeLabel = l10n.anime;
    if (isShows) {
      mediaTypeLabel = l10n.shows;
    } else if (!isAnime) {
      mediaTypeLabel = l10n.manga;
    }

    final activeMediaCount =
        (animeEnabled ? 1 : 0) + (showsEnabled ? 1 : 0) + (mangaEnabled ? 1 : 0);
    final canReset =
        filterState.hasActiveFilters || searchController.text.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search — Material Design TextField with animated floating label
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: searchController,
          builder: (context, value, _) {
            return TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              cursorColor: theme.colorScheme.primary,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: l10n.titleSearchPlaceholder,
                labelStyle: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                ),
                floatingLabelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
                floatingLabelBehavior: FloatingLabelBehavior.auto,
                prefixIcon: Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                suffixIcon: value.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: theme.colorScheme.onSurfaceVariant,
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged('');
                        },
                      ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.primary,
                    width: 1.8,
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 10),

        // Media type
        if (activeMediaCount > 1) ...[
          _singleDropdown<String>(
            hintText: mediaTypeLabel,
            items: [
              if (animeEnabled)
                M3EDropdownItem(
                  label: l10n.anime,
                  value: 'ANIME',
                  selected: filterState.mediaType == 'ANIME',
                ),
              if (showsEnabled)
                M3EDropdownItem(
                  label: l10n.shows,
                  value: 'SHOWS',
                  selected: filterState.mediaType == 'SHOWS',
                ),
              if (mangaEnabled)
                M3EDropdownItem(
                  label: l10n.manga,
                  value: 'MANGA',
                  selected: filterState.mediaType == 'MANGA',
                ),
            ],
            onChanged: (val) {
              if (val == null) return;
              onFilterChanged(
                filterState.copyWith(
                  mediaType: val,
                  season: () => (val == 'MANGA' || val == 'SHOWS')
                      ? null
                      : filterState.season,
                ),
              );
            },
            showClear: false,
          ),
          const SizedBox(height: 8),
        ],

        // Genres (accumulative)
        _multiDropdown<String>(
          hintText: l10n.allGenres,
          searchEnabled: true,
          searchHint: l10n.search,
          items: [
            for (final genre in kOfficialGenresData)
              M3EDropdownItem(
                label: isSpanish ? genre['es']! : genre['en']!,
                value: genre['key']!,
                selected: filterState.selectedGenres.contains(genre['key']),
              ),
          ],
          onChanged: (values) {
            onFilterChanged(filterState.copyWith(selectedGenres: values));
          },
        ),
        const SizedBox(height: 8),

        // Tags (accumulative)
        _multiDropdown<String>(
          hintText: l10n.allTags,
          searchEnabled: true,
          searchHint: l10n.search,
          items: [
            for (final tag in kPopularTagsData)
              M3EDropdownItem(
                label: isSpanish ? tag['es']! : tag['en']!,
                value: tag['key']!,
                selected: filterState.selectedTags.contains(tag['key']),
              ),
          ],
          onChanged: (values) {
            onFilterChanged(filterState.copyWith(selectedTags: values));
          },
        ),
        const SizedBox(height: 8),

        // Format
        _singleDropdown<String>(
          hintText: l10n.allFormats,
          items: [
            if (isAnime) ...[
              M3EDropdownItem(
                label: l10n.formatTv,
                value: 'TV',
                selected: filterState.format == 'TV',
              ),
              M3EDropdownItem(
                label: l10n.formatMovie,
                value: 'MOVIE',
                selected: filterState.format == 'MOVIE',
              ),
              M3EDropdownItem(
                label: l10n.formatTvShort,
                value: 'TV_SHORT',
                selected: filterState.format == 'TV_SHORT',
              ),
              M3EDropdownItem(
                label: l10n.formatSpecial,
                value: 'SPECIAL',
                selected: filterState.format == 'SPECIAL',
              ),
              M3EDropdownItem(
                label: l10n.formatOva,
                value: 'OVA',
                selected: filterState.format == 'OVA',
              ),
              M3EDropdownItem(
                label: l10n.formatOna,
                value: 'ONA',
                selected: filterState.format == 'ONA',
              ),
            ] else if (isShows) ...[
              M3EDropdownItem(
                label: l10n.formatTv,
                value: 'TV',
                selected: filterState.format == 'TV',
              ),
              M3EDropdownItem(
                label: l10n.formatMovie,
                value: 'MOVIE',
                selected: filterState.format == 'MOVIE',
              ),
            ] else ...[
              M3EDropdownItem(
                label: l10n.formatManga,
                value: 'MANGA',
                selected: filterState.format == 'MANGA',
              ),
              M3EDropdownItem(
                label: l10n.formatNovel,
                value: 'NOVEL',
                selected: filterState.format == 'NOVEL',
              ),
              M3EDropdownItem(
                label: l10n.formatOneShot,
                value: 'ONE_SHOT',
                selected: filterState.format == 'ONE_SHOT',
              ),
            ],
          ],
          onChanged: (val) {
            onFilterChanged(filterState.copyWith(format: () => val));
          },
        ),

        // Season (anime only)
        if (isAnime) ...[
          const SizedBox(height: 8),
          _singleDropdown<String>(
            hintText: l10n.allSeasons,
            items: [
              M3EDropdownItem(
                label: l10n.seasonWinter,
                value: 'WINTER',
                selected: filterState.season == 'WINTER',
              ),
              M3EDropdownItem(
                label: l10n.seasonSpring,
                value: 'SPRING',
                selected: filterState.season == 'SPRING',
              ),
              M3EDropdownItem(
                label: l10n.seasonSummer,
                value: 'SUMMER',
                selected: filterState.season == 'SUMMER',
              ),
              M3EDropdownItem(
                label: l10n.seasonFall,
                value: 'FALL',
                selected: filterState.season == 'FALL',
              ),
            ],
            onChanged: (val) {
              onFilterChanged(filterState.copyWith(season: () => val));
            },
          ),
        ],
        const SizedBox(height: 8),

        // Year
        _singleDropdown<int>(
          hintText: l10n.timelessYear,
          items: [
            for (final year in const [
              2026, 2025, 2024, 2023, 2022, 2021, 2020,
              2019, 2018, 2015, 2010, 2005, 2000, 1995,
            ])
              M3EDropdownItem(
                label: '$year',
                value: year,
                selected: filterState.year == year,
              ),
          ],
          onChanged: (val) {
            onFilterChanged(filterState.copyWith(year: () => val));
          },
        ),
        const SizedBox(height: 8),

        // Status
        _singleDropdown<String>(
          hintText: l10n.allStatuses,
          items: [
            M3EDropdownItem(
              label: l10n.statusReleasing,
              value: 'RELEASING',
              selected: filterState.status == 'RELEASING',
            ),
            M3EDropdownItem(
              label: l10n.statusFinished,
              value: 'FINISHED',
              selected: filterState.status == 'FINISHED',
            ),
            M3EDropdownItem(
              label: l10n.statusNotYetReleased,
              value: 'NOT_YET_RELEASED',
              selected: filterState.status == 'NOT_YET_RELEASED',
            ),
            M3EDropdownItem(
              label: l10n.statusCancelled,
              value: 'CANCELLED',
              selected: filterState.status == 'CANCELLED',
            ),
          ],
          onChanged: (val) {
            onFilterChanged(filterState.copyWith(status: () => val));
          },
        ),
        const SizedBox(height: 8),

        // Score
        _singleDropdown<int>(
          hintText: l10n.allScores,
          items: [
            for (final score in const [90, 80, 70, 60])
              M3EDropdownItem(
                label: '$score%+',
                value: score,
                selected: filterState.minScore == score,
              ),
          ],
          onChanged: (val) {
            onFilterChanged(filterState.copyWith(minScore: () => val));
          },
        ),
        const SizedBox(height: 12),

        // Adult content
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.adultContent,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            M3ESwitch(
              value: filterState.isAdult,
              onChanged: (val) {
                onFilterChanged(filterState.copyWith(isAdult: val));
              },
              semanticLabel: l10n.adultContent,
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Clear filters
        Align(
          alignment: Alignment.centerLeft,
          child: M3EButton.icon(
            onPressed: canReset ? onReset : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(l10n.clearFilters),
            style: M3EButtonStyle.tonal,
            size: M3EButtonSize.sm,
          ),
        ),
      ],
    );
  }

  M3EDropdownMenu<T> _singleDropdown<T>({
    required String hintText,
    required List<M3EDropdownItem<T>> items,
    required ValueChanged<T?> onChanged,
    bool showClear = true,
    bool searchEnabled = false,
  }) {
    return M3EDropdownMenu<T>(
      items: items,
      singleSelect: true,
      searchEnabled: searchEnabled,
      containerRadius: 18,
      fieldStyle: M3EDropdownFieldStyle(
        hintText: hintText,
        showArrow: true,
        showClearIcon: showClear,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        borderRadius: BorderRadius.circular(14),
      ),
      dropdownStyle: const M3EDropdownPanelStyle(
        expandDirection: M3EDropdownExpandDirection.auto,
        maxHeight: 300,
      ),
      onSelectionChanged: (selection) {
        onChanged(selection.isEmpty ? null : selection.first.value);
      },
    );
  }

  M3EDropdownMenu<T> _multiDropdown<T>({
    required String hintText,
    required List<M3EDropdownItem<T>> items,
    required ValueChanged<Set<T>> onChanged,
    bool searchEnabled = false,
    String? searchHint,
  }) {
    return M3EDropdownMenu<T>(
      items: items,
      singleSelect: false,
      searchEnabled: searchEnabled,
      containerRadius: 18,
      fieldStyle: M3EDropdownFieldStyle(
        hintText: hintText,
        showArrow: true,
        showClearIcon: true,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        borderRadius: BorderRadius.circular(14),
      ),
      dropdownStyle: const M3EDropdownPanelStyle(
        expandDirection: M3EDropdownExpandDirection.auto,
        maxHeight: 300,
      ),
      searchStyle: M3EDropdownSearchStyle(
        hintText: searchHint ?? 'Search…',
      ),
      onSelectionChanged: (selection) {
        onChanged(selection.map((item) => item.value).toSet());
      },
    );
  }
}
