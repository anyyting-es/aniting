import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/local_file_item.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/local_library_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';
import 'package:seanime_app/presentation/screens/settings/widgets/local_library/local_library_match_dialog.dart';

class LocalLibraryShowsSection extends ConsumerStatefulWidget {
  final LocalLibraryState state;

  const LocalLibraryShowsSection({super.key, required this.state});

  @override
  ConsumerState<LocalLibraryShowsSection> createState() =>
      _LocalLibraryShowsSectionState();
}

class _LocalLibraryShowsSectionState
    extends ConsumerState<LocalLibraryShowsSection> {
  /// Se renderizan como máximo esta cantidad de tarjetas a la vez. Con
  /// bibliotecas grandes, construir cientos de tarjetas (cada una con su
  /// póster y su petición a TMDB) en un solo frame provocaba tirones.
  static const int _pageSize = 24;

  final TextEditingController _searchController = TextEditingController();
  String _filterType = 'all'; // 'all', 'anime', 'tv', 'movie'
  String _searchQuery = '';
  int _visibleCount = _pageSize;

  void _resetPagination() => _visibleCount = _pageSize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LocalMatchedShowItem> get _filteredShows {
    final query = _searchQuery.toLowerCase().trim();
    return widget.state.matchedShows.where((s) {
      if (_filterType != 'all' && s.type != _filterType) {
        return false;
      }
      if (query.isNotEmpty) {
        final matchesTitle = s.title.toLowerCase().contains(query);
        final matchesFolder = s.folderPath.toLowerCase().contains(query);
        return matchesTitle || matchesFolder;
      }
      return true;
    }).toList();
  }

  void _showUnmatchConfirmDialog(
    BuildContext context,
    LocalMatchedShowItem item,
  ) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: theme.colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          l10n.unmatchShowConfirmTitle,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        content: Text(
          l10n.unmatchShowConfirmMessage(item.title),
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 13.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final ok = await ref
                  .read(localLibraryProvider.notifier)
                  .unmatchShowItem(item);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.unmatchShowSuccess),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text(l10n.unmatchAction),
          ),
        ],
      ),
    );
  }

  void _openFixMatchDialog(BuildContext context, LocalMatchedShowItem item) {
    final groupFiles = item.localFilePaths.map((p) {
      final name = p.split(RegExp(r'[/\\]')).last;
      return LocalFileItem(
        path: p,
        name: name,
        mediaId: item.isTmdb ? 0 : item.id,
        folderPath: item.folderPath,
        folderName: item.folderPath.split(RegExp(r'[/\\]')).last,
        parsedTitle: item.title,
      );
    }).toList();

    final group = UnmatchedFolderGroup(
      folderPath: item.folderPath,
      folderName: item.folderPath.split(RegExp(r'[/\\]')).last,
      guessedTitle: item.title,
      files: groupFiles,
      isTmdb: item.isTmdb,
    );

    LocalLibraryMatchDialog.show(context, group);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final filtered = _filteredShows;
    final visible = filtered.length > _visibleCount
        ? filtered.sublist(0, _visibleCount)
        : filtered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.35,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.collections_bookmark_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.localShowsSectionTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
              if (widget.state.matchedShows.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${widget.state.matchedShows.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.localShowsSectionSubtitle,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),

          // Search and Filters
          if (widget.state.matchedShows.isNotEmpty) ...[
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _resetPagination();
              }),
              decoration: InputDecoration(
                hintText: l10n.searchLocalShowsHint,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _resetPagination();
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label:
                        '${l10n.filterAll} (${widget.state.matchedShows.length})',
                    isSelected: _filterType == 'all',
                    onTap: () => setState(() {
                      _filterType = 'all';
                      _resetPagination();
                    }),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '${l10n.filterAnime} (${widget.state.animeCount})',
                    isSelected: _filterType == 'anime',
                    onTap: () => setState(() {
                      _filterType = 'anime';
                      _resetPagination();
                    }),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '${l10n.filterTv} (${widget.state.tvShowsCount})',
                    isSelected: _filterType == 'tv',
                    onTap: () => setState(() {
                      _filterType = 'tv';
                      _resetPagination();
                    }),
                  ),
                  const SizedBox(width: 6),
                  _FilterChip(
                    label: '${l10n.filterMovie} (${widget.state.moviesCount})',
                    isSelected: _filterType == 'movie',
                    onTap: () => setState(() {
                      _filterType = 'movie';
                      _resetPagination();
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Content List
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 36,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.noLocalShowsFound,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visible.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = visible[i];
                return _LocalMatchedShowCard(
                  item: item,
                  onUnmatch: () => _showUnmatchConfirmDialog(context, item),
                  onFixMatch: () => _openFixMatchDialog(context, item),
                  onTap: () {
                    AnimeDetailScreen.navigate(
                      context,
                      mediaId: item.id,
                      isTmdb: item.isTmdb,
                    );
                  },
                );
              },
            ),
            if (filtered.length > _visibleCount) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _visibleCount += _pageSize),
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: Text(
                    '${l10n.seeMore} (${filtered.length - _visibleCount})',
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LocalMatchedShowCard extends ConsumerWidget {
  final LocalMatchedShowItem item;
  final VoidCallback onUnmatch;
  final VoidCallback onFixMatch;
  final VoidCallback onTap;

  const _LocalMatchedShowCard({
    required this.item,
    required this.onUnmatch,
    required this.onFixMatch,
    required this.onTap,
  });

  /// Miniatura de la tarjeta. El póster de TMDB se resuelve con un provider
  /// memoizado por id: antes se creaba un `FutureBuilder` nuevo en cada
  /// rebuild, lo que relanzaba la petición (y un microframe) por cada tarjeta.
  Widget _buildThumbnail(WidgetRef ref, IconData typeIcon, Color typeColor) {
    final fallback = Icon(typeIcon, color: typeColor, size: 24);

    final cover = item.coverImage;
    if (cover != null && cover.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cover,
        fit: BoxFit.cover,
        errorWidget: (ctx, err, stack) => fallback,
      );
    }

    if (item.isTmdb) {
      final poster = ref
          .watch(
            tmdbShowPosterProvider((
              id: item.id,
              isMovie: item.type == 'movie',
            )),
          )
          .asData?.value;
      if (poster != null && poster.isNotEmpty) {
        return CachedNetworkImage(
          imageUrl: poster,
          fit: BoxFit.cover,
          errorWidget: (c, e, s) => fallback,
        );
      }
    }

    return fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    Color typeColor;
    String typeLabel;
    IconData typeIcon;
    switch (item.type) {
      case 'tv':
        typeColor = const Color(0xFF6366F1);
        typeLabel = l10n.folderTypeTv;
        typeIcon = Icons.tv_rounded;
        break;
      case 'movie':
        typeColor = const Color(0xFFEC4899);
        typeLabel = l10n.folderTypeMovie;
        typeIcon = Icons.movie_creation_outlined;
        break;
      case 'anime':
      default:
        typeColor = theme.colorScheme.primary;
        typeLabel = l10n.folderTypeAnime;
        typeIcon = Icons.animation_rounded;
        break;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail / Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 48,
                    height: 68,
                    color: theme.colorScheme.surfaceContainerHighest,
                    child: _buildThumbnail(ref, typeIcon, typeColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(typeIcon, size: 10, color: typeColor),
                                const SizedBox(width: 3),
                                Text(
                                  typeLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: typeColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${item.episodeCount} eps',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.folderPath.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          item.folderPath,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Card Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onUnmatch,
                  icon: const Icon(Icons.link_off_rounded, size: 15),
                  label: Text(l10n.unmatchAction),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 6),
                FilledButton.tonalIcon(
                  onPressed: onFixMatch,
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  label: Text(l10n.fixMatchAction),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
