import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/title_language_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/core/theme/theme_provider.dart';
import 'package:seanime_app/data/models/anime_entry.dart';
import 'package:seanime_app/data/models/manga_entry.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/manga_detail_screen.dart';
import 'package:seanime_app/presentation/widgets/anime_card.dart';
import 'package:seanime_app/presentation/widgets/manga_card.dart';
import 'package:seanime_app/presentation/widgets/media_type_toggle.dart';

/// Modern, high-performance desktop layout for "Mis Listas" (Anime & Manga).
///
/// Features:
/// - Safe desktop top clearance below [DesktopTitleBar.height] (34px) so back button
///   and controls are 100% clickable with 0 drag conflicts.
/// - Integrated media type switcher (Anime / Manga) with instant pill switching.
/// - Real-time title search box for instant desktop filtering.
/// - Status filter pills with live item count badges (Viendo (12), Completados (45), etc.).
/// - Responsive card grid with smooth scrolling and elegant empty states.
class MyListsDesktopLayout extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const MyListsDesktopLayout({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<MyListsDesktopLayout> createState() => _MyListsDesktopLayoutState();
}

class _MyListsDesktopLayoutState extends ConsumerState<MyListsDesktopLayout> {
  late String _selectedMediaType;
  String _selectedAnimeStatus = 'CURRENT';
  String _selectedMangaStatus = 'ALL';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = SmoothTrackingScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedMediaType = widget.initialTabIndex == 1 ? 'MANGA' : 'ANIME';
    _searchController.addListener(() {
      final text = _searchController.text.trim();
      if (text != _searchQuery) {
        setState(() => _searchQuery = text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);
    final titleLang = ref.watch(titleLanguageProvider);
    final colors = theme.extension<AppThemeColors>() ??
        AppThemeColors.fromPalette(ref.watch(themeProvider.select((s) => s.currentPalette)));

    final animeAsync = ref.watch(animeCollectionProvider);
    final mangaAsync = ref.watch(mangaCollectionProvider);

    final isAnime = _selectedMediaType == 'ANIME';
    final allAnime = animeAsync.value ?? [];
    final allManga = mangaAsync.value ?? [];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1600),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 1. Sleek Desktop Header (Offset below 34px DesktopTitleBar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(36, 42, 36, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Back button, Title, MediaTypeToggle, Search & Refresh
                      Row(
                        children: [
                          // Modern Back Button
                          IconButton(
                            style: IconButton.styleFrom(
                              padding: const EdgeInsets.all(8),
                              hoverColor: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest,
                              highlightColor: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : theme.colorScheme.surfaceContainerHigh,
                            ),
                            icon: Icon(
                              AppIcons.arrowLeft(iconPack),
                              color: isDark ? Colors.white : theme.colorScheme.onSurface,
                              size: 22,
                            ),
                            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 12),

                          // Screen Title
                          Text(
                            l10n.myLists,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Media Type Switcher (Anime / Manga pills)
                          MediaTypeToggle(
                            selected: _selectedMediaType,
                            onSelected: (val) {
                              setState(() {
                                _selectedMediaType = val;
                                _searchController.clear();
                              });
                            },
                          ),

                          const Spacer(),

                          // Quick Search Input
                          SizedBox(
                            width: 260,
                            height: 38,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 13),
                              decoration: InputDecoration(
                                hintText: l10n.filterByTitle,
                                hintStyle: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary.withValues(alpha: 0.7),
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  size: 18,
                                  color: colors.textSecondary.withValues(alpha: 0.7),
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16),
                                        padding: EdgeInsets.zero,
                                        onPressed: () => _searchController.clear(),
                                      )
                                    : null,
                                filled: true,
                                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(19),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(19),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(19),
                                  borderSide: BorderSide(
                                    color: theme.colorScheme.primary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Refresh Action Button
                          IconButton(
                            icon: const Icon(Icons.refresh_rounded, size: 20),
                            tooltip: l10n.refresh,
                            style: IconButton.styleFrom(
                              hoverColor: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                            onPressed: () {
                              ref.invalidate(animeCollectionProvider);
                              ref.invalidate(mangaCollectionProvider);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Status Filter Pills Bar with Live Counters
                      _buildStatusPills(
                        isAnime: isAnime,
                        allAnime: allAnime,
                        allManga: allManga,
                        l10n: l10n,
                        theme: theme,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Responsive Card Grid / States
              if (isAnime)
                ..._buildAnimeGrid(
                  context: context,
                  asyncVal: animeAsync,
                  searchQuery: _searchQuery,
                  titleLang: titleLang,
                  l10n: l10n,
                  theme: theme,
                )
              else
                ..._buildMangaGrid(
                  context: context,
                  asyncVal: mangaAsync,
                  searchQuery: _searchQuery,
                  titleLang: titleLang,
                  l10n: l10n,
                  theme: theme,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPills({
    required bool isAnime,
    required List<AnimeEntry> allAnime,
    required List<MangaEntry> allManga,
    required dynamic l10n,
    required ThemeData theme,
    required bool isDark,
  }) {
    if (isAnime) {
      // Calculate counts
      int currentCount = 0, completedCount = 0, planningCount = 0, droppedCount = 0, pausedCount = 0;
      for (final e in allAnime) {
        switch (e.status) {
          case 'CURRENT' || 'WATCHING':
            currentCount++;
          case 'COMPLETED':
            completedCount++;
          case 'PLANNING':
            planningCount++;
          case 'DROPPED':
            droppedCount++;
          case 'PAUSED':
            pausedCount++;
        }
      }

      final items = [
        (key: 'CURRENT', label: l10n.statusWatching, count: currentCount),
        (key: 'COMPLETED', label: l10n.statusCompleted, count: completedCount),
        (key: 'PLANNING', label: l10n.statusPlanning, count: planningCount),
        (key: 'PAUSED', label: l10n.statusPaused, count: pausedCount),
        (key: 'DROPPED', label: l10n.statusDropped, count: droppedCount),
        (key: 'ALL', label: l10n.statusAll, count: allAnime.length),
      ];

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = _selectedAnimeStatus == item.key;
          return _StatusPillChip(
            label: item.label,
            count: item.count,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedAnimeStatus = item.key),
            theme: theme,
            isDark: isDark,
          );
        }).toList(),
      );
    } else {
      // Manga counts
      int readingCount = 0, completedCount = 0, planningCount = 0;
      for (final e in allManga) {
        switch (e.status) {
          case 'CURRENT' || 'READING':
            readingCount++;
          case 'COMPLETED':
            completedCount++;
          case 'PLANNING':
            planningCount++;
        }
      }

      final items = [
        (key: 'ALL', label: l10n.statusAll, count: allManga.length),
        (key: 'CURRENT', label: l10n.reading, count: readingCount),
        (key: 'COMPLETED', label: l10n.statusCompleted, count: completedCount),
        (key: 'PLANNING', label: l10n.statusPlanning, count: planningCount),
      ];

      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((item) {
          final isSelected = _selectedMangaStatus == item.key;
          return _StatusPillChip(
            label: item.label,
            count: item.count,
            isSelected: isSelected,
            onTap: () => setState(() => _selectedMangaStatus = item.key),
            theme: theme,
            isDark: isDark,
          );
        }).toList(),
      );
    }
  }

  List<Widget> _buildAnimeGrid({
    required BuildContext context,
    required AsyncValue<List<AnimeEntry>> asyncVal,
    required String searchQuery,
    required dynamic titleLang,
    required dynamic l10n,
    required ThemeData theme,
  }) {
    return asyncVal.when(
      data: (entries) {
        final filtered = entries.where((e) {
          // Status filter
          if (_selectedAnimeStatus != 'ALL') {
            if (_selectedAnimeStatus == 'CURRENT') {
              if (e.status != 'CURRENT' && e.status != 'WATCHING') return false;
            } else if (e.status != _selectedAnimeStatus) {
              return false;
            }
          }
          // Search query filter
          if (searchQuery.isNotEmpty) {
            final title = e.displayTitle(titleLang).toLowerCase();
            if (!title.contains(searchQuery.toLowerCase())) return false;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: Icons.movie_outlined,
                message: searchQuery.isNotEmpty
                    ? l10n.noResultsFound
                    : (entries.isEmpty ? l10n.emptyLibraryLocal : l10n.emptyLibraryCategory),
                onRefresh: () => ref.invalidate(animeCollectionProvider),
                l10n: l10n,
                theme: theme,
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(36, 12, 36, 48),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.53,
                crossAxisSpacing: 16,
                mainAxisSpacing: 22,
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
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('${l10n.error}: $err')),
        ),
      ],
    );
  }

  List<Widget> _buildMangaGrid({
    required BuildContext context,
    required AsyncValue<List<MangaEntry>> asyncVal,
    required String searchQuery,
    required dynamic titleLang,
    required dynamic l10n,
    required ThemeData theme,
  }) {
    return asyncVal.when(
      data: (entries) {
        final filtered = entries.where((e) {
          // Status filter
          if (_selectedMangaStatus != 'ALL') {
            if (_selectedMangaStatus == 'CURRENT') {
              if (e.status != 'CURRENT' && e.status != 'READING') return false;
            } else if (e.status != _selectedMangaStatus) {
              return false;
            }
          }
          // Search query filter
          if (searchQuery.isNotEmpty) {
            final title = e.displayTitle(titleLang).toLowerCase();
            if (!title.contains(searchQuery.toLowerCase())) return false;
          }
          return true;
        }).toList();

        if (filtered.isEmpty) {
          return [
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildEmptyState(
                icon: Icons.menu_book_rounded,
                message: searchQuery.isNotEmpty
                    ? l10n.noResultsFound
                    : l10n.emptyLibraryCategory,
                onRefresh: () => ref.invalidate(mangaCollectionProvider),
                l10n: l10n,
                theme: theme,
              ),
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(36, 12, 36, 48),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 0.53,
                crossAxisSpacing: 16,
                mainAxisSpacing: 22,
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
      error: (err, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: Text('${l10n.error}: $err')),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required VoidCallback onRefresh,
    required dynamic l10n,
    required ThemeData theme,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(l10n.refresh),
          ),
        ],
      ),
    );
  }
}

/// Custom desktop status filter chip with count badge and hover feedback.
class _StatusPillChip extends StatefulWidget {
  final String label;
  final int count;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final bool isDark;

  const _StatusPillChip({
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    required this.isDark,
  });

  @override
  State<_StatusPillChip> createState() => _StatusPillChipState();
}

class _StatusPillChipState extends State<_StatusPillChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final primary = widget.theme.colorScheme.primary;
    final onPrimary = widget.theme.colorScheme.onPrimary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? primary
                : (_isHovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : widget.theme.colorScheme.surfaceContainerHighest)
                    : widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? primary
                  : widget.theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected
                      ? onPrimary
                      : (widget.isDark ? Colors.white : widget.theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(width: 6),
              // Count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? onPrimary.withValues(alpha: 0.22)
                      : (widget.isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : widget.theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.count}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.isSelected
                        ? onPrimary
                        : widget.theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
