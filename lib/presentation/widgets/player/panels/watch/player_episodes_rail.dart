import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/episode_item.dart';
import 'package:seanime_app/presentation/widgets/episodes/episode_card.dart';
import 'package:seanime_app/presentation/widgets/player/panels/watch/player_episode_header.dart';

/// Episode list rendered inside the desktop watch page. It has no scroll of its
/// own: the whole page scrolls as one, so the list simply grows with the rest of
/// the content and the currently playing episode is revealed when it changes.
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
  final GlobalKey _activeItemKey = GlobalKey();

  // Cards are cached so rebuilds of the parent page (buffering, subtitles,
  // controls visibility, play/pause, etc.) do not rebuild every episode card.
  List<Widget>? _cards;
  List<AnimeEpisode>? _cardsEpisodes;
  int? _cardsCurrentEpisode;
  AniZipData? _cardsAniZipData;
  int? _cardsMediaId;
  bool _cardsIsMovie = false;

  bool get _cardsAreStale {
    if (_cards == null) return true;
    if (widget.currentEpisodeNumber != _cardsCurrentEpisode) return true;
    if (widget.mediaId != _cardsMediaId) return true;
    if (widget.isMovie != _cardsIsMovie) return true;
    if (!identical(widget.aniZipData, _cardsAniZipData)) return true;
    final previous = _cardsEpisodes;
    if (previous == null || previous.length != widget.episodes.length) {
      return true;
    }
    if (!identical(previous, widget.episodes)) {
      for (var i = 0; i < previous.length; i++) {
        if (!identical(previous[i], widget.episodes[i])) return true;
      }
    }
    return false;
  }

  void _refreshCards() {
    _cards = [
      for (var index = 0; index < widget.episodes.length; index++)
        _buildCard(index),
    ];
    _cardsEpisodes = widget.episodes;
    _cardsCurrentEpisode = widget.currentEpisodeNumber;
    _cardsAniZipData = widget.aniZipData;
    _cardsMediaId = widget.mediaId;
    _cardsIsMovie = widget.isMovie;
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodesRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentEpisodeNumber != widget.currentEpisodeNumber) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _revealActiveEpisode());
    }
  }

  /// Brings the active episode into view within the page's single scroll.
  void _revealActiveEpisode() {
    if (!mounted) return;
    final ctx = _activeItemKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.28,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  EpisodeItem _toItem(AnimeEpisode ep) {
    final aniZip = widget.aniZipData;
    var item = EpisodeItem.fromAniZip(
      ep.episodeNumber,
      aniZip?.getEpisode(ep.episodeNumber),
      fallbackTitle: ep.title,
      fallbackImage: ep.image,
    );

    final rawSynopsis = (item.synopsis?.trim().isNotEmpty ?? false)
        ? item.synopsis
        : ep.description;
    if (rawSynopsis != null && rawSynopsis.trim().isNotEmpty) {
      item = item.copyWith(
        synopsis: PlayerEpisodeHeader.cleanDescription(rawSynopsis),
      );
    }
    return item;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);

    if (widget.isMovie || widget.episodes.isEmpty) {
      _cards = null;
      _cardsEpisodes = null;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          widget.isMovie ? widget.animeTitle : l10n.noEpisodesFound,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    if (_cardsAreStale) _refreshCards();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
          child: Text(
            '${l10n.episodes} (${widget.episodes.length})',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ..._cards!,
      ],
    );
  }

  Widget _buildCard(int index) {
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
        listTitleFontSize: 16,
        listSynopsisMaxLines: 4,
        isActive: isActive,
        onTap: () => widget.onSelectEpisode(ep.episodeNumber),
      ),
    );
    if (!isActive) return card;
    return KeyedSubtree(key: _activeItemKey, child: card);
  }
}
