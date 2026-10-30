import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/presentation/widgets/episodes/episode_progress_resolver.dart';

/// Compact episode selector used by the desktop rail: numbered tiles with no
/// artwork, so a whole season fits on screen at a glance.
class PlayerEpisodesCompactGrid extends StatelessWidget {
  final int? mediaId;
  final List<AnimeEpisode> episodes;
  final int? currentEpisodeNumber;
  final ValueChanged<int> onSelectEpisode;

  const PlayerEpisodesCompactGrid({
    super.key,
    required this.mediaId,
    required this.episodes,
    this.currentEpisodeNumber,
    required this.onSelectEpisode,
  });

  static const double _minTileWidth = 62;
  static const double _tileAspectRatio = 1.45;
  static const double _spacing = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth + _spacing) / (_minTileWidth + _spacing))
                .floor()
                .clamp(2, 10);

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: _tileAspectRatio,
          ),
          itemCount: episodes.length,
          itemBuilder: (context, index) {
            final episode = episodes[index];
            return _CompactEpisodeTile(
              mediaId: mediaId,
              episode: episode,
              isActive: episode.episodeNumber == currentEpisodeNumber,
              onTap: () => onSelectEpisode(episode.episodeNumber),
            );
          },
        );
      },
    );
  }
}

class _CompactEpisodeTile extends ConsumerStatefulWidget {
  final int? mediaId;
  final AnimeEpisode episode;
  final bool isActive;
  final VoidCallback onTap;

  const _CompactEpisodeTile({
    required this.mediaId,
    required this.episode,
    required this.isActive,
    required this.onTap,
  });

  @override
  ConsumerState<_CompactEpisodeTile> createState() =>
      _CompactEpisodeTileState();
}

class _CompactEpisodeTileState extends ConsumerState<_CompactEpisodeTile> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isActive = widget.isActive;
    final fraction = resolveEpisodeProgressFraction(
      ref,
      mediaId: widget.mediaId,
      episodeNumber: widget.episode.episodeNumber,
      episodeProgress: 0,
    );
    final isWatched = (fraction ?? 0) >= 0.95;

    final foreground = isActive
        ? scheme.onPrimaryContainer
        : isWatched
        ? scheme.onSurfaceVariant
        : scheme.onSurface;

    final background = isActive
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(
            alpha: _hovering ? 0.44 : (isWatched ? 0.18 : 0.32),
          );

    return Tooltip(
      message: widget.episode.title,
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedScale(
          scale: _hovering && !isActive ? 1.045 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isActive
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(
                        alpha: _hovering ? 0.8 : 0.4,
                      ),
                width: isActive ? 1.5 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                hoverColor: Colors.transparent,
                splashColor: scheme.onSurface.withValues(alpha: 0.06),
                child: Stack(
                  children: [
                    Center(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 180),
                        style: TextStyle(
                          fontSize: _hovering ? 16 : 15,
                          fontWeight: isActive
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: foreground,
                        ),
                        child: Text('${widget.episode.episodeNumber}'),
                      ),
                    ),
                    if (fraction != null && fraction > 0)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: fraction),
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOut,
                          builder: (context, value, _) => LinearProgressIndicator(
                            value: value,
                            minHeight: 2.5,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isActive
                                  ? scheme.primary
                                  : scheme.primary.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
