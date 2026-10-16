import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/presentation/providers/episodes_provider.dart';
import 'package:seanime_app/presentation/widgets/episodes/episode_card.dart';

/// Universal Episodes View supporting Grid and List layouts,
/// season filtering (for TMDB TV Series), source filters, and pagination.
class EpisodesView extends ConsumerStatefulWidget {
  final int mediaId;
  final bool isTmdb;
  final AnimeDetails? animeDetails;
  final AniZipData? aniZipData;
  final TmdbShowDetails? tmdbDetails;
  final void Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  })? onOpenTorrentSelector;

  const EpisodesView({
    super.key,
    required this.mediaId,
    this.isTmdb = false,
    this.animeDetails,
    this.aniZipData,
    this.tmdbDetails,
    this.onOpenTorrentSelector,
  });

  @override
  ConsumerState<EpisodesView> createState() => _EpisodesViewState();
}

class _EpisodesViewState extends ConsumerState<EpisodesView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerLoad();
    });
  }

  @override
  void didUpdateWidget(covariant EpisodesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.animeDetails != widget.animeDetails ||
        oldWidget.aniZipData != widget.aniZipData ||
        oldWidget.tmdbDetails != widget.tmdbDetails) {
      _triggerLoad();
    }
  }

  void _triggerLoad() {
    final args = EpisodesArgs(mediaId: widget.mediaId, isTmdb: widget.isTmdb);
    ref.read(episodesControllerProvider(args).notifier).load(
          animeDetails: widget.animeDetails,
          aniZipData: widget.aniZipData,
          tmdbDetails: widget.tmdbDetails,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final args = EpisodesArgs(mediaId: widget.mediaId, isTmdb: widget.isTmdb);
    final state = ref.watch(episodesControllerProvider(args));
    final controller = ref.read(episodesControllerProvider(args).notifier);

    if (state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    final episodes = state.pagedEpisodes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Controls & Season Bar ───
        _buildControlsHeader(context, theme, l10n, state, controller),
        const SizedBox(height: 12),

        // ─── Episodes Content ───
        if (episodes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                l10n.noEpisodesFound,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 14,
                ),
              ),
            ),
          )
        else if (state.isGridView)
          _buildGridView(context, episodes, controller)
        else
          _buildListView(context, episodes, controller),

        // ─── Pagination ───
        if (state.totalPages > 1) ...[
          const SizedBox(height: 20),
          _buildPaginationBar(context, theme, state, controller, iconPack),
        ],
      ],
    );
  }

  Widget _buildControlsHeader(
    BuildContext context,
    ThemeData theme,
    dynamic l10n,
    EpisodesState state,
    EpisodesNotifier controller,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final iconPack = ref.watch(iconPackProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Seasons Selector (for TMDB TV Series)
        if (state.seasons.length > 1)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: state.seasons.map((season) {
                final isSelected = state.selectedSeason == season;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    label: Text('${l10n.season} $season'),
                    onSelected: (_) => controller.selectSeason(season),
                  ),
                );
              }).toList(),
            ),
          ),

        if (state.seasons.length > 1) const SizedBox(height: 8),

        // Filters, Sort, and Grid/List toggle Row
        Row(
          children: [
            // Filter: All / Local / Unwatched
            FilterChip(
              selected: state.filter == EpisodeFilterType.all,
              label: Text(l10n.all),
              onSelected: (_) => controller.setFilter(EpisodeFilterType.all),
            ),
            const SizedBox(width: 6),
            if (state.hasLocalFiles) ...[
              FilterChip(
                selected: state.filter == EpisodeFilterType.localOnly,
                avatar: Icon(AppIcons.folder(iconPack), size: 14),
                label: Text(l10n.local),
                onSelected: (_) => controller.setFilter(EpisodeFilterType.localOnly),
              ),
              const SizedBox(width: 6),
            ],
            FilterChip(
              selected: state.filter == EpisodeFilterType.unwatched,
              label: Text(l10n.unwatched),
              onSelected: (_) => controller.setFilter(EpisodeFilterType.unwatched),
            ),

            const Spacer(),

            // Grid / List View toggle
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              onPressed: controller.toggleLayout,
              tooltip: state.isGridView ? l10n.switchToList : l10n.switchToGrid,
              icon: Icon(
                state.isGridView ? AppIcons.list(iconPack) : AppIcons.grid(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),

            // Sort direction button
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              onPressed: controller.toggleSort,
              tooltip: state.isSortAscending ? l10n.orderAsc : l10n.orderDesc,
              icon: Icon(
                AppIcons.swapVert(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<dynamic> episodes,
    EpisodesNotifier controller,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Responsive columns: 2 columns on mobile, 3-4 on tablet, 4-6 on desktop
        final crossAxisCount = (width / 260).floor().clamp(2, 6);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: episodes.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
            childAspectRatio: 1.18,
          ),
          itemBuilder: (context, index) {
            final ep = episodes[index];
            return EpisodeCard(
              mediaId: widget.mediaId,
              episode: ep,
              isGridView: true,
              onTap: () => controller.playEpisode(context, ep),
              onOpenTorrent: widget.onOpenTorrentSelector != null
                  ? () => widget.onOpenTorrentSelector!(
                        episodeNumber: ep.number,
                        episodeTitle: 'EP ${ep.number}. ${ep.title}',
                        aniDBEpisode: ep.aniDBEpisode,
                      )
                  : null,
            );
          },
        );
      },
    );
  }

  Widget _buildListView(
    BuildContext context,
    List<dynamic> episodes,
    EpisodesNotifier controller,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: episodes.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (context, index) {
        final ep = episodes[index];
        return EpisodeCard(
          mediaId: widget.mediaId,
          episode: ep,
          isGridView: false,
          onTap: () => controller.playEpisode(context, ep),
          onOpenTorrent: widget.onOpenTorrentSelector != null
              ? () => widget.onOpenTorrentSelector!(
                    episodeNumber: ep.number,
                    episodeTitle: 'EP ${ep.number}. ${ep.title}',
                    aniDBEpisode: ep.aniDBEpisode,
                  )
              : null,
        );
      },
    );
  }

  Widget _buildPaginationBar(
    BuildContext context,
    ThemeData theme,
    EpisodesState state,
    EpisodesNotifier controller,
    AppIconPack iconPack,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(AppIcons.chevronLeft(iconPack)),
          onPressed: state.currentPage > 0
              ? () => controller.setPage(state.currentPage - 1)
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          '${state.currentPage + 1} / ${state.totalPages}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(AppIcons.chevronRight(iconPack)),
          onPressed: state.currentPage < state.totalPages - 1
              ? () => controller.setPage(state.currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
