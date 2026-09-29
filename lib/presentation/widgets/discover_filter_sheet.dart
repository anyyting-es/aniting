import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

const List<Map<String, String>> kOfficialGenresData = [
  {'key': 'Action', 'es': 'Acción', 'en': 'Action'},
  {'key': 'Adventure', 'es': 'Aventura', 'en': 'Adventure'},
  {'key': 'Comedy', 'es': 'Comedia', 'en': 'Comedy'},
  {'key': 'Drama', 'es': 'Drama', 'en': 'Drama'},
  {'key': 'Ecchi', 'es': 'Ecchi', 'en': 'Ecchi'},
  {'key': 'Fantasy', 'es': 'Fantasía', 'en': 'Fantasy'},
  {'key': 'Horror', 'es': 'Terror', 'en': 'Horror'},
  {'key': 'Mahou Shoujo', 'es': 'Magical Girl', 'en': 'Mahou Shoujo'},
  {'key': 'Mecha', 'es': 'Mecha', 'en': 'Mecha'},
  {'key': 'Music', 'es': 'Música', 'en': 'Music'},
  {'key': 'Mystery', 'es': 'Misterio', 'en': 'Mystery'},
  {'key': 'Psychological', 'es': 'Psicológico', 'en': 'Psychological'},
  {'key': 'Romance', 'es': 'Romance', 'en': 'Romance'},
  {'key': 'Sci-Fi', 'es': 'Ciencia Ficción', 'en': 'Sci-Fi'},
  {'key': 'Slice of Life', 'es': 'Vida Cotidiana', 'en': 'Slice of Life'},
  {'key': 'Sports', 'es': 'Deportes', 'en': 'Sports'},
  {'key': 'Supernatural', 'es': 'Sobrenatural', 'en': 'Supernatural'},
  {'key': 'Thriller', 'es': 'Suspenso', 'en': 'Thriller'},
];

const List<Map<String, String>> kPopularTagsData = [
  {'key': 'Isekai', 'es': 'Isekai', 'en': 'Isekai'},
  {'key': 'Time Travel', 'es': 'Viajes en el Tiempo', 'en': 'Time Travel'},
  {'key': 'Reincarnation', 'es': 'Reencarnación', 'en': 'Reincarnation'},
  {'key': 'School', 'es': 'Escolar', 'en': 'School'},
  {'key': 'Super Power', 'es': 'Superpoderes', 'en': 'Super Power'},
  {'key': 'Magic', 'es': 'Magia', 'en': 'Magic'},
  {'key': 'Military', 'es': 'Militar', 'en': 'Military'},
  {'key': 'Martial Arts', 'es': 'Artes Marciales', 'en': 'Martial Arts'},
  {'key': 'Historical', 'es': 'Histórico', 'en': 'Historical'},
  {'key': 'Harem', 'es': 'Harem', 'en': 'Harem'},
  {'key': 'Cyberpunk', 'es': 'Cyberpunk', 'en': 'Cyberpunk'},
  {'key': 'Post-Apocalyptic', 'es': 'Post-Apocalíptico', 'en': 'Post-Apocalyptic'},
  {'key': 'Vampire', 'es': 'Vampiros', 'en': 'Vampire'},
  {'key': 'Demons', 'es': 'Demonios', 'en': 'Demons'},
  {'key': 'Survival', 'es': 'Supervivencia', 'en': 'Survival'},
  {'key': 'Detective', 'es': 'Detectives', 'en': 'Detective'},
  {'key': 'Space', 'es': 'Espacio', 'en': 'Space'},
  {'key': 'Gore', 'es': 'Gore', 'en': 'Gore'},
  {'key': 'Shounen', 'es': 'Shonen', 'en': 'Shounen'},
  {'key': 'Seinen', 'es': 'Seinen', 'en': 'Seinen'},
  {'key': 'Shoujo', 'es': 'Shoujo', 'en': 'Shoujo'},
  {'key': 'Josei', 'es': 'Josei', 'en': 'Josei'},
];

class DiscoverFilterState {
  final String mediaType; // 'ANIME' or 'MANGA'
  final Set<String> selectedGenres;
  final Set<String> selectedTags;
  final int? year;
  final String? season; // 'WINTER', 'SPRING', 'SUMMER', 'FALL'
  final String? format;
  final String? status;
  final String sort; // 'TRENDING_DESC', 'POPULARITY_DESC', 'SCORE_DESC', 'START_DATE_DESC'

  const DiscoverFilterState({
    this.mediaType = 'ANIME',
    this.selectedGenres = const {},
    this.selectedTags = const {},
    this.year,
    this.season,
    this.format,
    this.status,
    this.sort = 'TRENDING_DESC',
  });

  bool get hasActiveFilters =>
      selectedGenres.isNotEmpty ||
      selectedTags.isNotEmpty ||
      year != null ||
      season != null ||
      format != null ||
      status != null ||
      sort != 'TRENDING_DESC';

  int get activeFilterCount {
    int count = 0;
    count += selectedGenres.length;
    count += selectedTags.length;
    if (year != null) count++;
    if (season != null) count++;
    if (format != null) count++;
    if (status != null) count++;
    if (sort != 'TRENDING_DESC') count++;
    return count;
  }

  DiscoverFilterState copyWith({
    String? mediaType,
    Set<String>? selectedGenres,
    Set<String>? selectedTags,
    int? Function()? year,
    String? Function()? season,
    String? Function()? format,
    String? Function()? status,
    String? sort,
  }) {
    return DiscoverFilterState(
      mediaType: mediaType ?? this.mediaType,
      selectedGenres: selectedGenres ?? this.selectedGenres,
      selectedTags: selectedTags ?? this.selectedTags,
      year: year != null ? year() : this.year,
      season: season != null ? season() : this.season,
      format: format != null ? format() : this.format,
      status: status != null ? status() : this.status,
      sort: sort ?? this.sort,
    );
  }

  DiscoverFilterState clear() {
    return DiscoverFilterState(
      mediaType: mediaType,
      sort: 'TRENDING_DESC',
    );
  }
}

class DiscoverFilterSheet extends ConsumerStatefulWidget {
  final DiscoverFilterState initialState;
  final ValueChanged<DiscoverFilterState> onApply;

  const DiscoverFilterSheet({
    super.key,
    required this.initialState,
    required this.onApply,
  });

  static Future<DiscoverFilterState?> show(
    BuildContext context, {
    required DiscoverFilterState current,
  }) {
    return showModalBottomSheet<DiscoverFilterState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DiscoverFilterSheet(
        initialState: current,
        onApply: (newState) => Navigator.pop(ctx, newState),
      ),
    );
  }

  @override
  ConsumerState<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends ConsumerState<DiscoverFilterSheet> {
  late DiscoverFilterState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _toggleGenre(String key) {
    final next = Set<String>.from(_state.selectedGenres);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _state = _state.copyWith(selectedGenres: next));
  }

  void _toggleTag(String key) {
    final next = Set<String>.from(_state.selectedTags);
    if (next.contains(key)) {
      next.remove(key);
    } else {
      next.add(key);
    }
    setState(() => _state = _state.copyWith(selectedTags: next));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isSpanish = ref.watch(appLanguageProvider) == AppLanguage.es;
    final isAnime = _state.mediaType == 'ANIME';

    final sortOptions = [
      {'key': 'TRENDING_DESC', 'label': l10n.sortTrending, 'icon': Icons.local_fire_department_rounded},
      {'key': 'POPULARITY_DESC', 'label': l10n.sortPopularity, 'icon': Icons.favorite_rounded},
      {'key': 'SCORE_DESC', 'label': l10n.sortScore, 'icon': Icons.star_rounded},
      {'key': 'START_DATE_DESC', 'label': l10n.sortStartDate, 'icon': Icons.calendar_today_rounded},
    ];

    final seasons = [
      {'key': 'WINTER', 'label': l10n.seasonWinter, 'icon': Icons.ac_unit_rounded},
      {'key': 'SPRING', 'label': l10n.seasonSpring, 'icon': Icons.local_florist_rounded},
      {'key': 'SUMMER', 'label': l10n.seasonSummer, 'icon': Icons.wb_sunny_rounded},
      {'key': 'FALL', 'label': l10n.seasonFall, 'icon': Icons.eco_rounded},
    ];

    final animeFormats = [
      {'key': 'TV', 'label': l10n.formatTv},
      {'key': 'MOVIE', 'label': l10n.formatMovie},
      {'key': 'OVA', 'label': l10n.formatOva},
      {'key': 'ONA', 'label': l10n.formatOna},
      {'key': 'SPECIAL', 'label': l10n.formatSpecial},
    ];

    final mangaFormats = [
      {'key': 'MANGA', 'label': l10n.formatManga},
      {'key': 'NOVEL', 'label': l10n.formatNovel},
      {'key': 'ONE_SHOT', 'label': l10n.formatOneShot},
    ];

    final statuses = [
      {'key': 'RELEASING', 'label': l10n.statusReleasing},
      {'key': 'FINISHED', 'label': l10n.statusFinished},
      {'key': 'NOT_YET_RELEASED', 'label': l10n.statusNotYetReleased},
      {'key': 'CANCELLED', 'label': l10n.statusCancelled},
      {'key': 'HIATUS', 'label': l10n.statusHiatus},
    ];

    final currentYear = DateTime.now().year;
    final years = List.generate(40, (i) => currentYear + 1 - i);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: theme.colorScheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    l10n.filters,
                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  if (_state.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_state.activeFilterCount}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (_state.hasActiveFilters)
                    TextButton(
                      onPressed: () {
                        setState(() => _state = _state.clear());
                      },
                      child: Text(l10n.clearFilters),
                    ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                children: [
                  // 1. Sort By
                  _buildSectionTitle(l10n.sortBy, theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: sortOptions.map((opt) {
                      final isSelected = _state.sort == opt['key'];
                      return ChoiceChip(
                        avatar: Icon(
                          opt['icon'] as IconData,
                          size: 14,
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                        ),
                        label: Text(opt['label'] as String),
                        selected: isSelected,
                        onSelected: (sel) {
                          if (sel) setState(() => _state = _state.copyWith(sort: opt['key'] as String));
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 2. Official Genres (Multi-select)
                  _buildSectionTitle(l10n.allGenres, theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: kOfficialGenresData.map((g) {
                      final key = g['key']!;
                      final name = isSpanish ? g['es']! : g['en']!;
                      final isSelected = _state.selectedGenres.contains(key);
                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        onSelected: (_) => _toggleGenre(key),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 3. Popular Tags & Themes (Isekai, etc.)
                  _buildSectionTitle(l10n.tagsTitle, theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: kPopularTagsData.map((t) {
                      final key = t['key']!;
                      final name = isSpanish ? t['es']! : t['en']!;
                      final isSelected = _state.selectedTags.contains(key);
                      return FilterChip(
                        label: Text(name),
                        selected: isSelected,
                        selectedColor: theme.colorScheme.tertiaryContainer,
                        checkmarkColor: theme.colorScheme.onTertiaryContainer,
                        onSelected: (_) => _toggleTag(key),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 18),

                  // 4. Season (Anime Only)
                  if (isAnime) ...[
                    _buildSectionTitle(l10n.seasonTitle, theme),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        ChoiceChip(
                          label: Text(l10n.allSeasons),
                          selected: _state.season == null,
                          onSelected: (sel) {
                            if (sel) setState(() => _state = _state.copyWith(season: () => null));
                          },
                        ),
                        ...seasons.map((s) {
                          final isSelected = _state.season == s['key'];
                          return ChoiceChip(
                            avatar: Icon(
                              s['icon'] as IconData,
                              size: 14,
                              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                            ),
                            label: Text(s['label'] as String),
                            selected: isSelected,
                            onSelected: (sel) {
                              setState(() => _state = _state.copyWith(season: () => sel ? s['key'] as String : null));
                            },
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],

                  // 5. Year Filter
                  _buildSectionTitle(l10n.yearTitle, theme),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: years.length + 1,
                      separatorBuilder: (context, index) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          final isSelected = _state.year == null;
                          return ChoiceChip(
                            label: Text(l10n.allYears),
                            selected: isSelected,
                            visualDensity: VisualDensity.compact,
                            onSelected: (sel) {
                              if (sel) setState(() => _state = _state.copyWith(year: () => null));
                            },
                          );
                        }
                        final yr = years[i - 1];
                        final isSelected = _state.year == yr;
                        return ChoiceChip(
                          label: Text(yr.toString()),
                          selected: isSelected,
                          visualDensity: VisualDensity.compact,
                          onSelected: (sel) {
                            setState(() => _state = _state.copyWith(year: () => sel ? yr : null));
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 6. Format
                  _buildSectionTitle(l10n.formatTitle, theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.allFormats),
                        selected: _state.format == null,
                        onSelected: (sel) {
                          if (sel) setState(() => _state = _state.copyWith(format: () => null));
                        },
                      ),
                      ...(isAnime ? animeFormats : mangaFormats).map((f) {
                        final isSelected = _state.format == f['key'];
                        return ChoiceChip(
                          label: Text(f['label'] as String),
                          selected: isSelected,
                          onSelected: (sel) {
                            setState(() => _state = _state.copyWith(format: () => sel ? f['key'] as String : null));
                          },
                        );
                      }),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // 7. Status
                  _buildSectionTitle(l10n.statusTitle, theme),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ChoiceChip(
                        label: Text(l10n.allStatuses),
                        selected: _state.status == null,
                        onSelected: (sel) {
                          if (sel) setState(() => _state = _state.copyWith(status: () => null));
                        },
                      ),
                      ...statuses.map((st) {
                        final isSelected = _state.status == st['key'];
                        return ChoiceChip(
                          label: Text(st['label'] as String),
                          selected: isSelected,
                          onSelected: (sel) {
                            setState(() => _state = _state.copyWith(status: () => sel ? st['key'] as String : null));
                          },
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),

            // Apply Button Bar
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3))),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check_rounded),
                    label: Text(
                      _state.hasActiveFilters
                          ? '${l10n.applyFilters} (${_state.activeFilterCount})'
                          : l10n.applyFilters,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    onPressed: () => widget.onApply(_state),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
