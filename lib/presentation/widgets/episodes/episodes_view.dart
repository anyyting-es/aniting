import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/preferences/playback_progress_preferences_provider.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/episode_item.dart';
import 'package:aniting/data/models/tmdb_models.dart';
import 'package:aniting/presentation/providers/episodes_provider.dart';
import 'package:aniting/presentation/widgets/episodes/episode_card.dart';

/// Universal Episodes View supporting Grid and List layouts,
/// season filtering (for TMDB TV Series), source filters, and pagination.
class EpisodesView extends ConsumerStatefulWidget {
  final int mediaId;
  final bool isTmdb;
  final bool isHorizontal;
  final AnimeDetails? animeDetails;
  final AniZipData? aniZipData;
  final TmdbShowDetails? tmdbDetails;
  final void Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  })?
  onOpenTorrentSelector;

  const EpisodesView({
    super.key,
    required this.mediaId,
    this.isTmdb = false,
    this.isHorizontal = false,
    this.animeDetails,
    this.aniZipData,
    this.tmdbDetails,
    this.onOpenTorrentSelector,
  });

  @override
  ConsumerState<EpisodesView> createState() => _EpisodesViewState();
}

class _EpisodesViewState extends ConsumerState<EpisodesView> {
  final ScrollController _horizontalScrollController = ScrollController();
  bool _hasAutoScrolled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerLoad();
    });
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EpisodesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaId != widget.mediaId) {
      _hasAutoScrolled = false;
    }
    if (oldWidget.mediaId != widget.mediaId ||
        oldWidget.animeDetails != widget.animeDetails ||
        oldWidget.aniZipData != widget.aniZipData ||
        oldWidget.tmdbDetails != widget.tmdbDetails) {
      _triggerLoad();
    }
  }

  void _scheduleAutoScrollToTarget(
    List<dynamic> episodes,
    Map<String, EpisodePlaybackProgress> playbackMap,
  ) {
    if (_hasAutoScrolled || episodes.isEmpty || !widget.isHorizontal) return;

    final mediaProgress = playbackMap[widget.mediaId.toString()];
    int targetNumber = 1;

    if (mediaProgress != null &&
        mediaProgress.durationMs > 0 &&
        mediaProgress.positionMs > 0) {
      final fraction = mediaProgress.positionMs / mediaProgress.durationMs;
      if (fraction > 0.02 && fraction < 0.95) {
        targetNumber = mediaProgress.episodeNumber;
      } else if (fraction >= 0.95) {
        targetNumber = mediaProgress.episodeNumber + 1;
      }
    }

    final totalCount = episodes.length;
    if (targetNumber > totalCount) {
      targetNumber = 1;
    }

    int targetIndex = episodes.indexWhere((e) {
      final num =
          (e is Map ? e['episode_number'] : (e as dynamic).number) as int?;
      return num == targetNumber;
    });

    if (targetIndex < 0) {
      targetIndex = 0;
    }

    _hasAutoScrolled = true;
    if (targetIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_horizontalScrollController.hasClients) return;
        const cardWidth = 365.0;
        const separatorWidth = 18.0;
        const step = cardWidth + separatorWidth;
        final targetOffset = targetIndex * step;
        final maxOffset = _horizontalScrollController.position.maxScrollExtent;
        final finalOffset = targetOffset.clamp(0.0, maxOffset);

        if (finalOffset > 0 &&
            mounted &&
            _horizontalScrollController.hasClients) {
          _horizontalScrollController.animateTo(
            finalOffset,
            duration: const Duration(milliseconds: 650),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _triggerLoad() {
    final args = EpisodesArgs(
      mediaId: widget.mediaId,
      isTmdb: widget.isTmdb,
      mediaType: _tmdbMediaType,
    );
    ref
        .read(episodesControllerProvider(args).notifier)
        .load(
          animeDetails: widget.animeDetails,
          aniZipData: widget.aniZipData,
          tmdbDetails: widget.tmdbDetails,
        );
  }

  /// TMDB movies and shows share the same numeric id space, so the media type
  /// must travel with every request.
  String get _tmdbMediaType {
    if (widget.tmdbDetails?.isMovie == true) return 'movie';
    final format = (widget.animeDetails?.format ?? '').toUpperCase();
    return format == 'MOVIE' ? 'movie' : 'tv';
  }

  /// Starts playback. The player itself shows the source picker for TMDB.
  void _handleEpisodeTap(
    BuildContext context,
    EpisodesNotifier controller,
    EpisodeItem episode,
  ) {
    controller.playEpisode(context, episode);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final args = EpisodesArgs(
      mediaId: widget.mediaId,
      isTmdb: widget.isTmdb,
      mediaType: _tmdbMediaType,
    );
    final state = ref.watch(episodesControllerProvider(args));
    final controller = ref.read(episodesControllerProvider(args).notifier);

    final episodes = widget.isHorizontal
        ? state.visibleEpisodes
        : state.pagedEpisodes;

    final isDark = theme.brightness == Brightness.dark;

    final Widget content;
    if (state.isLoading && episodes.isEmpty) {
      content = const Padding(
        key: ValueKey('episodes_loading'),
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (episodes.isEmpty) {
      content = Center(
        key: const ValueKey('episodes_empty'),
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
      );
    } else {
      content = KeyedSubtree(
        key: ValueKey(
          'episodes_${state.selectedSeason}_${state.isGridView}_${state.isSortAscending}',
        ),
        child: widget.isHorizontal
            ? _buildHorizontalView(context, episodes, controller)
            : state.isGridView
                ? _buildGridView(context, episodes, controller)
                : _buildListView(context, episodes, controller),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Header: Episodes Title ───
        Text(
          l10n.episodes,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),

        // ─── Controls & Season Bar ───
        _buildControlsHeader(context, theme, l10n, state, controller),
        const SizedBox(height: 12),

        // ─── Episodes Content ───
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final slide = Tween<Offset>(
              begin: const Offset(0.03, 0),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: slide, child: child),
            );
          },
          child: content,
        ),

        // ─── Pagination ───
        if (!widget.isHorizontal && state.totalPages > 1) ...[
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
                  child: M3EButton(
                    onPressed: () => controller.selectSeason(season),
                    style: isSelected
                        ? M3EButtonStyle.filled
                        : M3EButtonStyle.outlined,
                    size: M3EButtonSize.sm,
                    shape: M3EButtonShape.round,
                    child: Text(
                      season == 0
                          ? l10n.specials
                          : '${l10n.season} $season',
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        if (state.seasons.length > 1) const SizedBox(height: 8),

        // Layout and sort controls. All/Unwatched filters are intentionally
        // omitted: TMDB episodes mirror the Anime episode list behaviour.
        Row(
          children: [
            const Spacer(),

            if (!widget.isHorizontal) ...[
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
                tooltip: state.isGridView
                    ? l10n.switchToList
                    : l10n.switchToGrid,
                icon: Icon(
                  state.isGridView
                      ? AppIcons.list(iconPack)
                      : AppIcons.grid(iconPack),
                  size: 18,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(width: 4),
            ],

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

  Widget _buildHorizontalView(
    BuildContext context,
    List<EpisodeItem> episodes,
    EpisodesNotifier controller,
  ) {
    final playbackMap = ref.watch(playbackProgressPreferencesProvider);
    _scheduleAutoScrollToTarget(episodes, playbackMap);

    return SizedBox(
      height: 272,
      child: ListView.separated(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: episodes.length,
        separatorBuilder: (_, _) => const SizedBox(width: 18),
        itemBuilder: (context, index) {
          final ep = episodes[index];
          return SizedBox(
            width: 365,
            child: EpisodeCard(
              mediaId: widget.mediaId,
              episode: ep,
              isGridView: true,
              onTap: () => _handleEpisodeTap(context, controller, ep),
              onOpenTorrent: widget.onOpenTorrentSelector != null
                  ? () => widget.onOpenTorrentSelector!(
                      episodeNumber: ep.number,
                      episodeTitle: 'EP ${ep.number}. ${ep.title}',
                      aniDBEpisode: ep.aniDBEpisode,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<EpisodeItem> episodes,
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
              onTap: () => _handleEpisodeTap(context, controller, ep),
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
    List<EpisodeItem> episodes,
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
          onTap: () => _handleEpisodeTap(context, controller, ep),
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
