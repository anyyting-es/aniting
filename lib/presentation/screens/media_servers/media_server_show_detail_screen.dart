import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/media_servers/models/media_server_config.dart';
import 'package:aniting/core/media_servers/models/media_server_item.dart';
import 'package:aniting/core/media_servers/providers/media_server_content_provider.dart';
import 'package:aniting/core/media_servers/services/media_server_player_helper.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_detail_back_button.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_detail_desktop_layout.dart';

/// Detail page for a show hosted on Plex/Jellyfin.
///
/// It follows the same visual language as the anime detail page and lists the
/// seasons/episodes returned by the media server directly; tapping one plays
/// it through the server.
class MediaServerShowDetailScreen extends ConsumerStatefulWidget {
  final MediaServerItem show;
  final MediaServerConfig server;

  const MediaServerShowDetailScreen({
    super.key,
    required this.show,
    required this.server,
  });

  @override
  ConsumerState<MediaServerShowDetailScreen> createState() =>
      _MediaServerShowDetailScreenState();
}

class _MediaServerShowDetailScreenState
    extends ConsumerState<MediaServerShowDetailScreen> {
  int _selectedSeason = 1;

  /// Falls back to a TMDB clear logo when the media server has no logo asset
  /// for this item (Plex in particular only ships logos for some shows).
  String? _tmdbLogoUrl;
  bool _isResolvingLogo = false;

  @override
  void initState() {
    super.initState();
    final hasServerLogo =
        widget.show.logoUrl != null && widget.show.logoUrl!.isNotEmpty;
    final ids = widget.show.externalIds;
    if (!hasServerLogo &&
        ids != null &&
        (ids['tmdb'] != null || ids['tvdb'] != null)) {
      final cached = ref
          .read(tmdbServiceProvider)
          .getCachedLogoUrl(
            tmdbId: int.tryParse(ids['tmdb'] ?? ''),
            tvdbId: int.tryParse(ids['tvdb'] ?? ''),
            isMovie: widget.show.type == MediaServerItemType.movie,
            language: ref.read(appLanguageProvider).code,
          );
      if (cached != null) {
        _tmdbLogoUrl = cached;
      } else {
        _isResolvingLogo = true;
        _resolveLogo();
      }
    }
  }

  Future<void> _resolveLogo() async {
    final ids = widget.show.externalIds;
    if (ids == null) return;
    try {
      final appLanguage = ref.read(appLanguageProvider).code;
      final url = await ref
          .read(tmdbServiceProvider)
          .getLogo(
            tmdbId: int.tryParse(ids['tmdb'] ?? ''),
            tvdbId: int.tryParse(ids['tvdb'] ?? ''),
            isMovie: widget.show.type == MediaServerItemType.movie,
            language: appLanguage,
          );
      if (!mounted) return;
      setState(() {
        _tmdbLogoUrl = url;
        _isResolvingLogo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isResolvingLogo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final episodesAsync =
        ref.watch(mediaServerShowEpisodesProvider(widget.show.id));

    if (MediaQuery.sizeOf(context).width >= 900) {
      return _buildDesktop(context, theme, l10n, episodesAsync);
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: Center(
              child: AnimeDetailBackButton(
                color: Colors.white,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.show.backdropUrl != null ||
                      widget.show.thumbUrl != null)
                    CachedNetworkImage(
                      imageUrl:
                          widget.show.backdropUrl ?? widget.show.thumbUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 1600,
                      filterQuality: FilterQuality.medium,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    )
                  else
                    ColoredBox(color: theme.colorScheme.surfaceContainerHighest),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.35),
                          Colors.transparent,
                          theme.scaffoldBackgroundColor.withValues(alpha: 0.65),
                          theme.scaffoldBackgroundColor,
                        ],
                        stops: const [0.0, 0.35, 0.82, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _buildHeader(context, theme, l10n)),
          episodesAsync.when(
            loading: () => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: M3ELoadingIndicator(
                  variant: M3ELoadingIndicatorVariant.contained,
                  size: 40,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: Text(err.toString())),
            ),
            data: (episodes) {
              if (episodes.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text(l10n.mediaServerNoItems)),
                );
              }

              final seasons = <int>{};
              for (final ep in episodes) {
                seasons.add(ep.seasonNumber ?? 1);
              }
              final sortedSeasons = seasons.toList()..sort();
              if (!sortedSeasons.contains(_selectedSeason) &&
                  sortedSeasons.isNotEmpty) {
                _selectedSeason = sortedSeasons.first;
              }

              final seasonEpisodes = episodes
                  .where((ep) => (ep.seasonNumber ?? 1) == _selectedSeason)
                  .toList()
                ..sort((a, b) =>
                    (a.episodeNumber ?? 0).compareTo(b.episodeNumber ?? 0));

              return SliverMainAxisGroup(
                slivers: [
                  if (sortedSeasons.length > 1)
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 46,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: sortedSeasons.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final season = sortedSeasons[index];
                            final isSelected = season == _selectedSeason;
                            return _SeasonChip(
                              label: '${l10n.season} $season',
                              isSelected: isSelected,
                              onTap: () =>
                                  setState(() => _selectedSeason = season),
                            );
                          },
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                    sliver: SliverList.separated(
                      itemCount: seasonEpisodes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final ep = seasonEpisodes[index];
                        return _EpisodeCard(
                          episode: ep,
                          fallbackImage: widget.show.thumbUrl,
                          server: widget.server,
                          show: widget.show,
                          allEpisodes: episodes,
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktop(
    BuildContext context,
    ThemeData theme,
    AppTranslations l10n,
    AsyncValue<List<MediaServerItem>> episodesAsync,
  ) {
    final show = widget.show;
    final episodes = episodesAsync.asData?.value ?? const <MediaServerItem>[];
    final mediaId = -((show.id.hashCode & 0x7fffffff) + 1);
    final isMovie = show.type == MediaServerItemType.movie;

    final details = AnimeDetails(
      id: mediaId,
      title: show.title,
      coverImage: show.thumbUrl,
      bannerImage: show.backdropUrl,
      description: show.overview,
      totalEpisodes: show.episodeCount ?? episodes.length,
      genres: show.genres,
      format: isMovie ? 'MOVIE' : 'TV',
      score: show.rating,
      seasonYear: show.year,
      studio: show.studio,
      isTmdb: false,
    );

    return AnimeDetailDesktopLayout(
      mediaId: mediaId,
      details: details,
      aniZipData: null,
      resolvedLogoUrl: widget.show.logoUrl ?? _tmdbLogoUrl,
      isLogoPending: _isResolvingLogo,
      resolvedBannerUrl: show.backdropUrl ?? show.thumbUrl,
      isLoading: episodesAsync.isLoading,
      isLoadingAniZip: episodesAsync.isLoading,
      isLocalMode: false,
      hasLocalFiles: false,
      currentTab: AnimeDetailTab.online,
      onToggleLocalMode: () {},
      onTabChanged: (_) {},
      onOpenEditEntryModal: (_) {},
      onRetryAniZip: () async {},
      onOpenTorrentSelector:
          ({
            required int episodeNumber,
            required String episodeTitle,
            String? aniDBEpisode,
            bool isDownloadMode = false,
            List<int>? initialSelectedEpisodes,
          }) async {},
      onOpenDetailsModal: () {},
      mediaServerShow: show,
      mediaServerServer: widget.server,
      mediaServerEpisodes: episodes,
    );
  }
  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    AppTranslations l10n,
  ) {
    final show = widget.show;
    final rating = show.rating;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 112,
              height: 166,
              child: show.thumbUrl != null
                  ? CachedNetworkImage(
                      imageUrl: show.thumbUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 500,
                      filterQuality: FilterQuality.medium,
                      errorWidget: (_, _, _) => ColoredBox(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.movie_rounded,
                          color: theme.colorScheme.outline,
                          size: 30,
                        ),
                      ),
                    )
                  : ColoredBox(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.movie_rounded,
                        color: theme.colorScheme.outline,
                        size: 30,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  show.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (rating != null && rating > 0)
                      _MetaChip(
                        label: rating > 10
                            ? (rating / 10).toStringAsFixed(1)
                            : rating.toStringAsFixed(1),
                        icon: Icons.star_outline_rounded,
                        accent: true,
                      ),
                    if (show.year != null)
                      _MetaChip(label: '${show.year}'),
                    _MetaChip(label: widget.server.name),
                  ],
                ),
                if (show.overview != null && show.overview!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    show.overview!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      height: 1.4,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeasonChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SeasonChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.14)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.45)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
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

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool accent;

  const _MetaChip({required this.label, this.icon, this.accent = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        accent ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: accent
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeCard extends StatefulWidget {
  final MediaServerItem episode;
  final String? fallbackImage;
  final MediaServerConfig server;
  final MediaServerItem? show;
  final List<MediaServerItem>? allEpisodes;

  const _EpisodeCard({
    required this.episode,
    required this.server,
    this.fallbackImage,
    this.show,
    this.allEpisodes,
  });

  @override
  State<_EpisodeCard> createState() => _EpisodeCardState();
}

class _EpisodeCardState extends State<_EpisodeCard> {
  bool _isHovered = false;

  String? get _durationLabel {
    final ms = widget.episode.durationMs;
    if (ms == null || ms <= 0) return null;
    final minutes = (ms / 60000).round();
    return '$minutes min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final image = widget.episode.thumbUrl ?? widget.fallbackImage;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => MediaServerPlayerHelper.playDirect(
          context: context,
          item: widget.episode,
          server: widget.server,
          show: widget.show,
          showEpisodes: widget.allEpisodes,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? theme.colorScheme.primary.withValues(alpha: 0.35)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 132,
                  height: 74,
                  child: image != null
                      ? CachedNetworkImage(
                          imageUrl: image,
                          fit: BoxFit.cover,
                          memCacheWidth: 600,
                          filterQuality: FilterQuality.medium,
                          errorWidget: (_, _, _) => _placeholder(theme),
                        )
                      : _placeholder(theme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.episode.episodeNumber ?? '?'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.episode.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (_durationLabel != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _durationLabel!,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.play_circle_fill_rounded,
                size: 30,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.movie_rounded,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }
}