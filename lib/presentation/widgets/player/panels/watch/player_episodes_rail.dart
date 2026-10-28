import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/episode_item.dart';
import 'package:seanime_app/presentation/widgets/episodes/episode_card.dart';

/// Right-side "Episodes" rail for the desktop player. Episodes only, borderless
/// and with smooth scrolling. The currently playing episode is always revealed.
class PlayerEpisodesRail extends ConsumerStatefulWidget {
  final String animeTitle;
  final int? mediaId;
  final List<AnimeEpisode> episodes;
  final AniZipData? aniZipData;
  final int? currentEpisodeNumber;
  final bool isMovie;
  final ValueChanged<int> onSelectEpisode;

  const PlayerEpisodesRail({
    super.key,
    required this.animeTitle,
    this.mediaId,
    required this.episodes,
    this.aniZipData,
    this.currentEpisodeNumber,
    this.isMovie = false,
    required this.onSelectEpisode,
  });

  @override
  ConsumerState<PlayerEpisodesRail> createState() => _PlayerEpisodesRailState();
}

class _PlayerEpisodesRailState extends ConsumerState<PlayerEpisodesRail> {
  /// Approximate pitch of a list card (16:9 thumbnail at 220px + paddings).
  static const double _itemPitch = 148.0;

  final ScrollController _scrollController =
      SmoothScrollController(smoothingFactor: 16.0);
  final GlobalKey _activeItemKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _revealActiveEpisode(animate: false),
    );
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodesRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisodeNumber != widget.currentEpisodeNumber ||
        oldWidget.episodes.length != widget.episodes.length) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealActiveEpisode(animate: true),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  EpisodeItem _toItem(AnimeEpisode ep) {
    final aniZip = widget.aniZipData;
    return EpisodeItem.fromAniZip(
      ep.episodeNumber,
      aniZip?.getEpisode(ep.episodeNumber),
      fallbackTitle: ep.title,
      fallbackImage: ep.image,
    );
  }

  int get _activeIndex => widget.episodes.indexWhere(
        (e) => e.episodeNumber == widget.currentEpisodeNumber,
      );

  /// Scrolls the rail so the episode being watched is always on screen.
  void _revealActiveEpisode({required bool animate}) {
    if (!mounted || !_scrollController.hasClients) return;
    final index = _activeIndex;
    if (index < 0) return;

    final position = _scrollController.position;
    final centered =
        index * _itemPitch - (position.viewportDimension - _itemPitch) / 2;
    final target = centered.clamp(0.0, position.maxScrollExtent);

    if (animate) {
      _scrollController
          .animateTo(
            target,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          )
          .whenComplete(_fineTuneActive);
    } else {
      _scrollController.jumpTo(target);
      WidgetsBinding.instance.addPostFrameCallback((_) => _fineTuneActive());
    }
  }

  /// Corrects the estimated offset using the real geometry of the active card.
  void _fineTuneActive() {
    if (!mounted) return;
    final ctx = _activeItemKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    if (widget.isMovie || widget.episodes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            widget.isMovie ? widget.animeTitle : l10n.noEpisodesFound,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 12),
          child: Row(
            children: [
              Icon(
                AppIcons.tv(iconPack),
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.episodes} (${widget.episodes.length})',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            cacheExtent: 1200,
            padding: const EdgeInsets.fromLTRB(0, 0, 4, 24),
            itemCount: widget.episodes.length,
            itemBuilder: (context, index) {
              final ep = widget.episodes[index];
              final isActive = ep.episodeNumber == widget.currentEpisodeNumber;
              final card = Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: EpisodeCard(
                  mediaId: widget.mediaId,
                  episode: _toItem(ep),
                  fallbackImageUrl: ep.image,
                  isGridView: false,
                  listThumbnailWidth: 220,
                  isActive: isActive,
                  onTap: () => widget.onSelectEpisode(ep.episodeNumber),
                ),
              );
              if (!isActive) return card;
              return KeyedSubtree(key: _activeItemKey, child: card);
            },
          ),
        ),
      ],
    );
  }
}
