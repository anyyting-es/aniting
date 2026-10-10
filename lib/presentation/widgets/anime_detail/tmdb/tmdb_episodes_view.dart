import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/tmdb_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

import 'tmdb_episode_card.dart';
import 'tmdb_season_selector.dart';

class TmdbEpisodesView extends ConsumerStatefulWidget {
  final int tmdbId;
  final bool isMovie;
  final String? fallbackCoverImage;
  final bool isMobile;

  const TmdbEpisodesView({
    super.key,
    required this.tmdbId,
    this.isMovie = false,
    this.fallbackCoverImage,
    this.isMobile = false,
  });

  @override
  ConsumerState<TmdbEpisodesView> createState() => _TmdbEpisodesViewState();
}

class _TmdbEpisodesViewState extends ConsumerState<TmdbEpisodesView> {
  TmdbShowDetails? _details;
  bool _isLoadingDetails = true;
  bool _isLoadingEpisodes = false;
  int _selectedSeasonNumber = 1;
  List<TmdbEpisode> _episodes = [];
  bool _isGridView = true;
  bool _isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadShowDetails();
  }

  Future<void> _loadShowDetails() async {
    setState(() => _isLoadingDetails = true);
    final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
    final lang = isSpanish ? 'es-ES' : 'en-US';
    final tmdbService = ref.read(tmdbServiceProvider);

    final details = await tmdbService.getShowDetails(
      widget.tmdbId,
      language: lang,
      isMovie: widget.isMovie,
    );

    if (!mounted) return;

    if (details != null) {
      int initialSeason = 1;
      if (!details.isMovie && details.seasons.isNotEmpty) {
        if (!details.seasons.any((s) => s.seasonNumber == 1)) {
          initialSeason = details.seasons.first.seasonNumber;
        }
      }

      setState(() {
        _details = details;
        _selectedSeasonNumber = initialSeason;
        _isLoadingDetails = false;
      });

      if (details.isMovie) {
        // Create 1 synthetic episode for the movie
        setState(() {
          _episodes = [
            TmdbEpisode(
              id: details.id,
              name: details.name,
              episodeNumber: 1,
              seasonNumber: 1,
              overview: details.overview,
              stillPath: details.backdropPath ?? details.posterPath,
              airDate: details.firstAirDate,
              voteAverage: details.voteAverage,
              runtime: details.runtime,
            ),
          ];
        });
      } else {
        _loadSeasonEpisodes(initialSeason);
      }
    } else {
      setState(() => _isLoadingDetails = false);
    }
  }

  Future<void> _loadSeasonEpisodes(int seasonNumber) async {
    setState(() => _isLoadingEpisodes = true);
    final isSpanish = ref.read(appLanguageProvider) == AppLanguage.es;
    final lang = isSpanish ? 'es-ES' : 'en-US';
    final tmdbService = ref.read(tmdbServiceProvider);

    final list = await tmdbService.getSeasonEpisodes(
      widget.tmdbId,
      seasonNumber,
      language: lang,
    );

    if (!mounted) return;
    setState(() {
      _episodes = list;
      _isLoadingEpisodes = false;
    });
  }

  void _onSeasonSelected(int seasonNumber) {
    if (_selectedSeasonNumber == seasonNumber) return;
    setState(() {
      _selectedSeasonNumber = seasonNumber;
    });
    _loadSeasonEpisodes(seasonNumber);
  }

  void _showComingSoonNotice(BuildContext context, dynamic l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.streamingComingSoon)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);

    if (_isLoadingDetails) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    final details = _details;
    if (details == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30),
          child: Text(
            l10n.noEpisodesFound,
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 14,
            ),
          ),
        ),
      );
    }

    // Sort episodes
    final sortedEpisodes = List<TmdbEpisode>.from(_episodes);
    if (!_isSortAscending) {
      sortedEpisodes.sort((a, b) => b.episodeNumber.compareTo(a.episodeNumber));
    } else {
      sortedEpisodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));
    }

    final iconPack = ref.watch(iconPackProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ─── Header Controls: Season Selector & View Mode Buttons ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TmdbSeasonSelector(
                seasons: details.seasons,
                selectedSeasonNumber: _selectedSeasonNumber,
                onSeasonSelected: _onSeasonSelected,
                isMovie: details.isMovie,
              ),
            ),
            const SizedBox(width: 8),

            // Toggle Grid / List View
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView ? l10n.switchToList : l10n.switchToGrid,
              icon: Icon(
                _isGridView ? AppIcons.list(iconPack) : AppIcons.grid(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 4),

            // Toggle Sort Ascending / Descending
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              onPressed: () => setState(() {
                _isSortAscending = !_isSortAscending;
              }),
              tooltip: _isSortAscending ? l10n.orderAsc : l10n.orderDesc,
              icon: Icon(
                AppIcons.swapVert(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Episodes Content ───
        if (_isLoadingEpisodes)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.colorScheme.primary,
              ),
            ),
          )
        else if (sortedEpisodes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Text(
                l10n.noEpisodesFound,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
          )
        else if (_isGridView)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = widget.isMobile
                  ? (constraints.maxWidth > 600
                      ? 3
                      : (constraints.maxWidth > 420 ? 2 : 1))
                  : (constraints.maxWidth / 320).floor().clamp(2, 5);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedEpisodes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: widget.isMobile ? (crossAxisCount == 1 ? 1.4 : 1.15) : 1.28,
                  crossAxisSpacing: widget.isMobile ? 14 : 20,
                  mainAxisSpacing: widget.isMobile ? 14 : 22,
                ),
                itemBuilder: (context, index) {
                  final ep = sortedEpisodes[index];
                  return TmdbEpisodeCard(
                    episode: ep,
                    fallbackImageUrl: details.backdropUrl ?? widget.fallbackCoverImage,
                    isGridView: true,
                    onTap: () => _showComingSoonNotice(context, l10n),
                  );
                },
              );
            },
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 1200;
              final crossAxisCount = widget.isMobile ? 1 : (isWide ? 2 : 1);

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedEpisodes.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 154,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 18,
                ),
                itemBuilder: (context, index) {
                  final ep = sortedEpisodes[index];
                  return TmdbEpisodeCard(
                    episode: ep,
                    fallbackImageUrl: details.backdropUrl ?? widget.fallbackCoverImage,
                    isGridView: false,
                    onTap: () => _showComingSoonNotice(context, l10n),
                  );
                },
              );
            },
          ),
      ],
    );
  }
}
