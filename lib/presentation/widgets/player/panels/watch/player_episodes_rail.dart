import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/preferences/player_desktop_view_provider.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/episode_item.dart';
import 'package:aniting/presentation/widgets/episodes/episode_card.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episode_header.dart';
import 'package:aniting/presentation/widgets/player/panels/watch/player_episodes_compact_grid.dart';

/// Episode list rendered inside the desktop watch page. When
/// [independentScroll] is true it owns a vertical scroll area (so wheeling over
/// the rail does not scroll the page) and the active episode is revealed
/// inside that area. In the sheet it keeps the historical behaviour where the
/// sheet itself scrolls.
class PlayerEpisodesRail extends ConsumerStatefulWidget {
  final String animeTitle;
  final int? mediaId;
  final List<AnimeEpisode> episodes;
  final AniZipData? aniZipData;
  final int? currentEpisodeNumber;
  final bool isMovie;
  final ValueChanged<int> onSelectEpisode;

  /// Gives the rail its own bounded scroll area.
  final bool independentScroll;

  /// Hides the rail entirely (the page then opens it from the header again).
  final VoidCallback? onHide;

  const PlayerEpisodesRail({
    super.key,
    required this.animeTitle,
    this.mediaId,
    required this.episodes,
    this.aniZipData,
    this.currentEpisodeNumber,
    this.isMovie = false,
    required this.onSelectEpisode,
    this.independentScroll = false,
    this.onHide,
  });

  @override
  ConsumerState<PlayerEpisodesRail> createState() => _PlayerEpisodesRailState();
}

class _PlayerEpisodesRailState extends ConsumerState<PlayerEpisodesRail> {
  final GlobalKey _activeItemKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  bool _userIsScrolling = false;
  bool _isAutoScrolling = false;
  DateTime? _lastUserScrollAt;

  // Cards are cached so rebuilds of the parent page (buffering, subtitles,
  // controls visibility, play/pause, etc.) do not rebuild every episode card.
  List<Widget>? _cards;
  List<AnimeEpisode>? _cardsEpisodes;
  int? _cardsCurrentEpisode;
  AniZipData? _cardsAniZipData;
  int? _cardsMediaId;
  bool _cardsIsMovie = false;
  double _cardsThumbWidth = 0;
  double _cardsTitleFont = 0;
  int _cardsSynopsisLines = 4;

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

  void _refreshCards(double thumbWidth, double titleFont, int synopsisLines) {
    _cardsThumbWidth = thumbWidth;
    _cardsTitleFont = titleFont;
    _cardsSynopsisLines = synopsisLines;
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealActiveEpisode();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PlayerEpisodesRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    final episodeChanged =
        oldWidget.currentEpisodeNumber != widget.currentEpisodeNumber;
    final episodesBecameAvailable =
        oldWidget.episodes.isEmpty && widget.episodes.isNotEmpty;
    final mediaChanged = oldWidget.mediaId != widget.mediaId;
    if (episodeChanged || episodesBecameAvailable || mediaChanged) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _revealActiveEpisode(),
      );
    }
  }

  /// Brings the active episode into view. With [PlayerEpisodesRail.independentScroll]
  /// only the rail's own scroll position moves, so revealing the episode never
  /// yanks the page away from the video. In the sheet the historical behaviour
  /// (scroll the enclosing scrollable) is kept.
  void _revealActiveEpisode() {
    if (!mounted) return;
    final ctx = _activeItemKey.currentContext;
    if (ctx == null) return;

    if (widget.independentScroll && _scrollController.hasClients) {
      final renderObject = ctx.findRenderObject();
      if (renderObject != null) {
        // Never fight the user: if they are currently wheeling/dragging the
        // rail, or just did, leave the scroll position alone.
        final recentlyScrolled =
            _userIsScrolling ||
            (_lastUserScrollAt != null &&
                DateTime.now().difference(_lastUserScrollAt!) <
                    const Duration(milliseconds: 800));
        if (recentlyScrolled || _isAutoScrolling) return;

        // If the active card is already fully visible, do not move the list.
        // Only reveal when it is actually outside the viewport.
        try {
          final viewport = RenderAbstractViewport.of(renderObject);
          final revealOffset = viewport
              .getOffsetToReveal(renderObject, 0.0)
              .offset;
          final box = renderObject as RenderBox;
          final position = _scrollController.position;
          final fullyVisible =
              revealOffset >= position.pixels - 1 &&
              revealOffset + box.size.height <=
                  position.pixels + position.viewportDimension + 1;
          if (fullyVisible) return;
        } catch (_) {
          // Fall back to ensureVisible if the render tree is not ready.
        }

        _isAutoScrolling = true;
        _scrollController.position
            .ensureVisible(
              renderObject,
              alignment: 0.28,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _isAutoScrolling = false);
        return;
      }
    }

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
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isCompact = ref.watch(playerEpisodeListCompactProvider);

    if (widget.episodes.isEmpty) {
      _cards = null;
      _cardsEpisodes = null;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          l10n.noEpisodesFound,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the card art and typography with the rail width so the list
        // shrinks together with the rest of the page when the window narrows.
        final thumbWidth = (constraints.maxWidth * 0.42).clamp(120.0, 240.0);
        final titleFont = (thumbWidth * 0.073).clamp(12.5, 16.0);
        final synopsisLines = thumbWidth >= 180 ? 4 : 2;

        if (!isCompact && (_cardsAreStale || thumbWidth != _cardsThumbWidth)) {
          _refreshCards(thumbWidth, titleFont, synopsisLines);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l10n.episodes} (${widget.episodes.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _RailHeaderButton(
                    icon: isCompact
                        ? AppIcons.list(iconPack)
                        : AppIcons.grid(iconPack),
                    tooltip: isCompact
                        ? l10n.detailedEpisodeList
                        : l10n.compactEpisodeList,
                    onPressed: () {
                      ref
                          .read(playerEpisodeListCompactProvider.notifier)
                          .toggle();
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _revealActiveEpisode(),
                      );
                    },
                  ),
                  if (widget.onHide != null)
                    _RailHeaderButton(
                      icon: AppIcons.sidebarOutline(iconPack),
                      tooltip: l10n.hideEpisodeList,
                      onPressed: widget.onHide!,
                    ),
                ],
              ),
            ),
            _buildEpisodesList(isCompact),
          ],
        );
      },
    );
  }

  Widget _buildEpisodesList(bool isCompact) {
    final Widget content = isCompact
        ? PlayerEpisodesCompactGrid(
            key: const ValueKey('compact-episodes'),
            mediaId: widget.mediaId,
            episodes: widget.episodes,
            currentEpisodeNumber: widget.currentEpisodeNumber,
            onSelectEpisode: widget.onSelectEpisode,
            activeItemKey: widget.independentScroll ? _activeItemKey : null,
          )
        : Column(
            key: const ValueKey('detailed-episodes'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...?_cards],
          );

    final animated = AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, ?currentChild],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: content,
    );

    if (!widget.independentScroll) return animated;

    return Expanded(
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          if (notification is ScrollStartNotification) {
            if (!_isAutoScrolling) {
              _userIsScrolling = true;
              _lastUserScrollAt = DateTime.now();
            }
          } else if (notification is ScrollUpdateNotification) {
            if (!_isAutoScrolling) {
              _lastUserScrollAt = DateTime.now();
            }
          } else if (notification is ScrollEndNotification) {
            _userIsScrolling = false;
            if (!_isAutoScrolling) {
              _lastUserScrollAt = DateTime.now();
            }
          }
          return false;
        },
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: animated,
          ),
        ),
      ),
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
        listThumbnailWidth: _cardsThumbWidth,
        listTitleFontSize: _cardsTitleFont,
        listSynopsisMaxLines: _cardsSynopsisLines,
        isActive: isActive,
        onTap: () => widget.onSelectEpisode(ep.episodeNumber),
      ),
    );
    if (!isActive) return card;
    return KeyedSubtree(key: _activeItemKey, child: card);
  }
}

/// Small ghost icon button used in the rail header (view toggle / hide rail).
class _RailHeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _RailHeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 18,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        hoverColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        foregroundColor: theme.colorScheme.onSurfaceVariant,
      ),
      icon: Icon(icon),
    );
  }
}
