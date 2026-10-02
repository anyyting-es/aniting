import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/preferences/episode_view_mode_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/episode_item_widget.dart';

class AniZipEpisodeListView extends ConsumerStatefulWidget {
  final AniZipData? aniZipData;
  final List<AnimeEpisode> fallbackEpisodes;
  final AnimeDetails? animeDetails;
  final bool isLoading;
  final int progress;
  final VoidCallback? onRetry;
  final void Function(AniZipEpisode episode)? onPlayEpisode;
  final void Function(AniZipEpisode episode)? onTapEpisode;
  final void Function(AnimeEpisode episode)? onPlayFallbackEpisode;
  final EpisodeViewMode? viewMode;
  final VoidCallback? onToggleViewMode;

  const AniZipEpisodeListView({
    super.key,
    required this.aniZipData,
    this.fallbackEpisodes = const [],
    this.animeDetails,
    this.isLoading = false,
    this.progress = 0,
    this.onRetry,
    this.onPlayEpisode,
    this.onTapEpisode,
    this.onPlayFallbackEpisode,
    this.viewMode,
    this.onToggleViewMode,
  });

  @override
  ConsumerState<AniZipEpisodeListView> createState() => _AniZipEpisodeListViewState();
}

class _AniZipEpisodeListViewState extends ConsumerState<AniZipEpisodeListView> {
  static const int _listPageSize = 24;
  int _currentListPage = 0;
  int _fallbackListPage = 0;
  bool _isAscending = true;
  String _searchQuery = '';
  bool _isSearchVisible = false;
  final TextEditingController _searchController = TextEditingController();
  EpisodeViewMode _localViewMode = EpisodeViewMode.list;

  @override
  void didUpdateWidget(covariant AniZipEpisodeListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.aniZipData != oldWidget.aniZipData ||
        widget.fallbackEpisodes != oldWidget.fallbackEpisodes) {
      _currentListPage = 0;
      _fallbackListPage = 0;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Determines if an AniZip episode has already aired
  bool _hasEpisodeAired(AniZipEpisode ep) {
    // 1. If airDate is explicitly in the future, it hasn't aired
    if (ep.airDate != null && ep.airDate!.isNotEmpty) {
      final dt = DateTime.tryParse(ep.airDate!);
      if (dt != null) {
        // Buffer of 4 hours to account for timezone differences on the release day
        if (dt.isAfter(DateTime.now().add(const Duration(hours: 4)))) {
          return false;
        }
      }
    }

    // 2. Check AniList nextAiringEpisode from rawMedia
    final nextAiring = widget.animeDetails?.rawMedia?['nextAiringEpisode'];
    if (nextAiring is Map<String, dynamic>) {
      final nextEpNum = nextAiring['episode'] as int?;
      if (nextEpNum != null && ep.episodeNumber >= nextEpNum) {
        return false;
      }
    }

    // 3. If anime status is NOT_YET_RELEASED, none have aired
    final status = widget.animeDetails?.status?.toUpperCase();
    if (status == 'NOT_YET_RELEASED') {
      return false;
    }

    // 4. If status is RELEASING, and episode has no airDate AND no image,
    // it's an unreleased future episode stub in AniZip
    if (status == 'RELEASING') {
      if ((ep.airDate == null || ep.airDate!.isEmpty) &&
          (ep.image == null || ep.image!.isEmpty)) {
        return false;
      }
    }

    return true;
  }

  List<AniZipEpisode> _getFilteredAniZipEpisodes(String langCode) {
    if (widget.aniZipData == null) return [];

    // Only main episodes, no specials
    List<AniZipEpisode> list = widget.aniZipData!.mainEpisodes;
    if (list.isEmpty) {
      list = widget.aniZipData!.episodes;
    }

    // Filter out unreleased episodes
    list = list.where(_hasEpisodeAired).toList();

    // Apply search filter
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim().toLowerCase();
      list = list.where((ep) {
        final epNumMatch = ep.episodeNumber.toString() == q || ep.episode.toLowerCase() == q;
        final titleMatch = ep.displayTitleForLang(langCode).toLowerCase().contains(q) ||
            (ep.originalTitle != null && ep.originalTitle!.toLowerCase().contains(q));
        final descMatch = ep.synopsis != null && ep.synopsis!.toLowerCase().contains(q);
        return epNumMatch || titleMatch || descMatch;
      }).toList();
    }

    // Sort order
    if (!_isAscending) {
      list = list.reversed.toList();
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final appLang = ref.watch(appLanguageProvider);
    final langCode = appLang.code;
    final hasAniZip = widget.aniZipData != null && widget.aniZipData!.episodes.isNotEmpty;
    final fallbackImage = widget.animeDetails?.bannerImage ?? widget.animeDetails?.coverImage;
    final viewMode = widget.viewMode ?? _localViewMode;

    // Loading State
    if (widget.isLoading) {
      return _buildLoadingState(theme, l10n);
    }

    // Main AniZip episode view
    if (hasAniZip) {
      final filteredEpisodes = _getFilteredAniZipEpisodes(langCode);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Title, Count, ViewMode toggle, Search & Sort
          Row(
            children: [
              Text(
                l10n.episodes,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '• ${filteredEpisodes.length} ${l10n.availableCount}',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // View mode toggle button (List vs Grid)
              IconButton(
                icon: Icon(
                  viewMode == EpisodeViewMode.grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: viewMode == EpisodeViewMode.grid ? l10n.switchToList : l10n.switchToGrid,
                onPressed: () {
                  if (widget.onToggleViewMode != null) {
                    widget.onToggleViewMode!();
                  } else {
                    setState(() {
                      _localViewMode = _localViewMode == EpisodeViewMode.list
                          ? EpisodeViewMode.grid
                          : EpisodeViewMode.list;
                    });
                  }
                },
              ),
              // Search toggle button
              IconButton(
                icon: Icon(
                  _isSearchVisible ? Icons.search_off_rounded : Icons.search_rounded,
                  size: 20,
                  color: _isSearchVisible ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: l10n.searchEpisode,
                onPressed: () {
                  setState(() {
                    _isSearchVisible = !_isSearchVisible;
                    if (!_isSearchVisible) {
                      _searchQuery = '';
                      _searchController.clear();
                      _currentListPage = 0;
                      _fallbackListPage = 0;
                    }
                  });
                },
              ),
              // Sort order toggle button
              IconButton(
                icon: Icon(
                  _isAscending ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: _isAscending ? l10n.sort1toN : l10n.sortNto1,
                onPressed: () {
                  setState(() {
                    _isAscending = !_isAscending;
                    _currentListPage = 0;
                    _fallbackListPage = 0;
                  });
                },
              ),
            ],
          ),

          // Search Field (collapsible)
          if (_isSearchVisible) ...[
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: l10n.searchEpisodePlaceholder,
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _currentListPage = 0;
                            _fallbackListPage = 0;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  _currentListPage = 0;
                  _fallbackListPage = 0;
                });
              },
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 2),

          // Episodes List or Empty Search
          if (filteredEpisodes.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
              ),
              child: Center(
                child: Text(
                  _searchQuery.isNotEmpty
                      ? '${l10n.noEpisodesFoundMatching} "$_searchQuery".'
                      : l10n.noAiredEpisodesAvailable,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ),
            )
          else if (viewMode == EpisodeViewMode.grid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: filteredEpisodes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final ep = filteredEpisodes[index];
                return EpisodeGridItem(
                  episodeNumber: ep.episodeNumber,
                  title: ep.displayTitleForLang(langCode),
                  originalTitle: ep.originalTitle,
                  duration: ep.formattedDuration,
                  synopsis: ep.synopsis,
                  image: ep.image,
                  fallbackImage: fallbackImage,
                  airDate: ep.formattedAirDate,
                  rating: ep.rating,
                  badgeText: ep.isSpecial ? ep.episodeBadge : null,
                  isWatched: widget.progress >= ep.episodeNumber && ep.episodeNumber > 0,
                  onTap: () {
                    if (widget.onTapEpisode != null) {
                      widget.onTapEpisode!(ep);
                    } else if (widget.onPlayEpisode != null) {
                      widget.onPlayEpisode!(ep);
                    }
                  },
                  onPlay: () {
                    if (widget.onPlayEpisode != null) {
                      widget.onPlayEpisode!(ep);
                    }
                  },
                );
              },
            )
          else ...[
            Builder(
              builder: (context) {
                final totalEpisodes = filteredEpisodes.length;
                final totalPages = (totalEpisodes / _listPageSize).ceil();
                final page = _currentListPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                final start = page * _listPageSize;
                final end = (start + _listPageSize).clamp(0, totalEpisodes);
                final pagedEpisodes = totalEpisodes > 0 ? filteredEpisodes.sublist(start, end) : <AniZipEpisode>[];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: pagedEpisodes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ep = pagedEpisodes[index];
                        return EpisodeListItem(
                          episodeNumber: ep.episodeNumber,
                          title: ep.displayTitleForLang(langCode),
                          originalTitle: ep.originalTitle,
                          duration: ep.formattedDuration,
                          synopsis: ep.synopsis,
                          image: ep.image,
                          fallbackImage: fallbackImage,
                          airDate: ep.formattedAirDate,
                          rating: ep.rating,
                          badgeText: ep.isSpecial ? ep.episodeBadge : null,
                          isWatched: widget.progress >= ep.episodeNumber && ep.episodeNumber > 0,
                          onTap: () {
                            if (widget.onTapEpisode != null) {
                              widget.onTapEpisode!(ep);
                            } else if (widget.onPlayEpisode != null) {
                              widget.onPlayEpisode!(ep);
                            }
                          },
                          onPlay: () {
                            if (widget.onPlayEpisode != null) {
                              widget.onPlayEpisode!(ep);
                            }
                          },
                        );
                      },
                    ),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: page > 0
                                ? () => setState(() => _currentListPage = page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: Text(l10n.previousPage),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${page + 1} / $totalPages',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: page < totalPages - 1
                                ? () => setState(() => _currentListPage = page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: Text('${l10n.nextPage} ($_listPageSize ep)'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      );
    }

    // Fallback: Local Seanime episodes if available
    if (widget.fallbackEpisodes.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Episodios',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(
                '${widget.fallbackEpisodes.length} disponibles',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (viewMode == EpisodeViewMode.grid)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: widget.fallbackEpisodes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.35,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final ep = widget.fallbackEpisodes[index];
                return EpisodeGridItem(
                  episodeNumber: ep.episodeNumber,
                  title: ep.title,
                  synopsis: ep.description,
                  image: ep.image,
                  fallbackImage: fallbackImage,
                  isWatched: widget.progress >= ep.episodeNumber && ep.episodeNumber > 0,
                  onTap: () {
                    if (widget.onPlayFallbackEpisode != null) {
                      widget.onPlayFallbackEpisode!(ep);
                    }
                  },
                );
              },
            )
          else ...[
            Builder(
              builder: (context) {
                final totalEpisodes = widget.fallbackEpisodes.length;
                final totalPages = (totalEpisodes / _listPageSize).ceil();
                final page = _fallbackListPage.clamp(0, totalPages > 0 ? totalPages - 1 : 0);
                final start = page * _listPageSize;
                final end = (start + _listPageSize).clamp(0, totalEpisodes);
                final pagedEpisodes = totalEpisodes > 0 ? widget.fallbackEpisodes.sublist(start, end) : <AnimeEpisode>[];

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: pagedEpisodes.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ep = pagedEpisodes[index];
                        return EpisodeListItem(
                          episodeNumber: ep.episodeNumber,
                          title: ep.title,
                          synopsis: ep.description,
                          image: ep.image,
                          fallbackImage: fallbackImage,
                          isWatched: widget.progress >= ep.episodeNumber && ep.episodeNumber > 0,
                          onTap: () {
                            if (widget.onPlayFallbackEpisode != null) {
                              widget.onPlayFallbackEpisode!(ep);
                            }
                          },
                          onPlay: () {
                            if (widget.onPlayFallbackEpisode != null) {
                              widget.onPlayFallbackEpisode!(ep);
                            }
                          },
                        );
                      },
                    ),
                    if (totalPages > 1) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: page > 0
                                ? () => setState(() => _fallbackListPage = page - 1)
                                : null,
                            icon: const Icon(Icons.chevron_left_rounded, size: 18),
                            label: Text(l10n.previousPage),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${page + 1} / $totalPages',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: page < totalPages - 1
                                ? () => setState(() => _fallbackListPage = page + 1)
                                : null,
                            icon: const Icon(Icons.chevron_right_rounded, size: 18),
                            label: Text('${l10n.nextPage} ($_listPageSize ep)'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ],
      );
    }

    // Empty state with retry AniZip
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.noEpisodesAniZipOrLocal,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noEpisodesAniZipDesc,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          if (widget.onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l10n.retryAniZip),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular((context.themeColors.borderRadius * 0.75).clamp(0.0, 14.0))),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingState(ThemeData theme, AppTranslations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              l10n.episodes,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (int i = 0; i < 4; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              height: 94,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(context.themeColors.borderRadius),
              ),
              child: Row(
                children: [
                  Container(
                    width: 132,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.horizontal(left: Radius.circular(context.themeColors.borderRadius)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 140,
                          height: 14,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 90,
                          height: 10,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
