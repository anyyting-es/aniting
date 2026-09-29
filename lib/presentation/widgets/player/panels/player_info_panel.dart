import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/presentation/widgets/anime_details_modal_sheet.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/panels/next_episode_card.dart';

/// Clean, modular information panel for YouTube-style watch page and desktop side drawer.
/// Displays current episode details, synopsis, MKV chapters, and next/prev episode navigation.
class PlayerInfoPanel extends ConsumerStatefulWidget {
  final int? mediaId;
  final String animeTitle;
  final int? episodeNumber;
  final String? episodeTitle;
  final AnimeDetails? animeDetails;
  final AniZipData? aniZipData;
  final bool isLoading;
  final bool isDesktop;
  final VoidCallback? onCollapse;
  final List<PlayerChapter> chapters;
  final PlayerChapter? activeChapter;
  final ValueChanged<Duration> onSeekToChapter;
  final VoidCallback? onPlayNextEpisode;
  final VoidCallback? onPlayPreviousEpisode;

  const PlayerInfoPanel({
    super.key,
    this.mediaId,
    required this.animeTitle,
    this.episodeNumber,
    this.episodeTitle,
    this.animeDetails,
    this.aniZipData,
    this.isLoading = false,
    this.isDesktop = false,
    this.onCollapse,
    this.chapters = const [],
    this.activeChapter,
    required this.onSeekToChapter,
    this.onPlayNextEpisode,
    this.onPlayPreviousEpisode,
  });

  @override
  ConsumerState<PlayerInfoPanel> createState() => _PlayerInfoPanelState();
}

class _PlayerInfoPanelState extends ConsumerState<PlayerInfoPanel> {
  bool _isSynopsisExpanded = false;

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _cleanDescription(String? text) {
    if (text == null) return '';
    return text
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .trim();
  }

  bool _isGenericTitle(String? title, int epNum) {
    if (title == null || title.trim().isEmpty) return true;
    final clean = title.trim().toLowerCase();
    if (clean == 'episodio $epNum' ||
        clean == 'episode $epNum' ||
        clean == 'ep. $epNum' ||
        clean == 'ep $epNum' ||
        clean == 'ep.$epNum' ||
        clean == '$epNum') {
      return true;
    }
    return RegExp(r'^(episode|episodio|ep\.?|e)\s*\d+$', caseSensitive: false).hasMatch(clean);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    final episodes = widget.animeDetails?.episodes ?? [];
    final currentEpNum = widget.episodeNumber ?? 1;
    final totalEps = widget.animeDetails?.totalEpisodes;
    final isMovie = widget.animeDetails?.format?.toUpperCase() == 'MOVIE' ||
        (totalEps == 1 && episodes.length <= 1);

    final aniZip = widget.aniZipData ?? widget.animeDetails?.aniZipData;
    final currentAniZipEp = aniZip?.getEpisode(currentEpNum);
    final nextEpNum = currentEpNum + 1;
    final nextAniZipEp = isMovie ? null : aniZip?.getEpisode(nextEpNum);
    final prevAniZipEp = isMovie ? null : aniZip?.getEpisode(currentEpNum - 1);

    AnimeEpisode? nextEp;
    AnimeEpisode? prevEp;

    if (!isMovie && episodes.isNotEmpty) {
      for (final ep in episodes) {
        if (ep.episodeNumber == nextEpNum) {
          nextEp = ep;
        } else if (ep.episodeNumber == currentEpNum - 1) {
          prevEp = ep;
        }
      }
      if (nextEp == null) {
        final idx = episodes.indexWhere((e) => e.episodeNumber == currentEpNum);
        if (idx != -1 && idx + 1 < episodes.length) {
          nextEp = episodes[idx + 1];
        }
        if (idx > 0) {
          prevEp = episodes[idx - 1];
        }
      }
    }

    // Determine next episode title: prioritize AniZip official title over generic placeholders
    final String nextEpTitle;
    if (nextAniZipEp != null && !_isGenericTitle(nextAniZipEp.displayTitle, nextEpNum)) {
      nextEpTitle = nextAniZipEp.displayTitle;
    } else if (nextEp != null && !_isGenericTitle(nextEp.title, nextEpNum)) {
      nextEpTitle = nextEp.title;
    } else if (nextAniZipEp != null && nextAniZipEp.displayTitle.isNotEmpty) {
      nextEpTitle = nextAniZipEp.displayTitle;
    } else if (nextEp != null && nextEp.title.isNotEmpty) {
      nextEpTitle = nextEp.title;
    } else {
      nextEpTitle = 'Episodio $nextEpNum';
    }

    if (!isMovie && nextEp == null && currentEpNum > 0) {
      if (totalEps == null || nextEpNum <= totalEps) {
        if (nextAniZipEp != null || episodes.isEmpty) {
          final nextImg = nextAniZipEp?.image ??
              widget.animeDetails?.bannerImage ??
              widget.animeDetails?.coverImage;
          nextEp = AnimeEpisode(
            episodeNumber: nextEpNum,
            title: nextEpTitle,
            image: nextImg,
            description: nextAniZipEp?.synopsis,
          );
        }
      }
    }

    if (!isMovie && prevEp == null && currentEpNum > 1) {
      prevEp = AnimeEpisode(
        episodeNumber: currentEpNum - 1,
        title: prevAniZipEp?.displayTitle ?? 'Episodio ${currentEpNum - 1}',
      );
    }

    // Current Episode Info: Episode title & number (prioritize AniZip if title is generic)
    final String? currentEpRawTitle;
    if (widget.episodeTitle != null && !_isGenericTitle(widget.episodeTitle, currentEpNum)) {
      currentEpRawTitle = widget.episodeTitle;
    } else if (currentAniZipEp != null && !_isGenericTitle(currentAniZipEp.displayTitle, currentEpNum)) {
      currentEpRawTitle = currentAniZipEp.displayTitle;
    } else {
      currentEpRawTitle = widget.episodeTitle ?? currentAniZipEp?.displayTitle;
    }

    final String currentEpHeading;
    if (isMovie) {
      final clean = (currentEpRawTitle != null && currentEpRawTitle.isNotEmpty)
          ? currentEpRawTitle
              .replaceFirst(RegExp(r'^(episodio|episode|ep\.?)\s*' + currentEpNum.toString() + r'\s*[\-•:]?\s*', caseSensitive: false), '')
              .trim()
          : '';
      if (clean.isNotEmpty && clean.toLowerCase() != 'complete movie') {
        currentEpHeading = '${l10n.formatMovie} • $clean';
      } else {
        currentEpHeading = l10n.formatMovie;
      }
    } else if (currentEpRawTitle != null && currentEpRawTitle.isNotEmpty && !_isGenericTitle(currentEpRawTitle, currentEpNum)) {
      final cleanTitle = currentEpRawTitle
          .replaceFirst(RegExp(r'^(episodio|episode|ep\.?)\s*' + currentEpNum.toString() + r'\s*[\-•:]?\s*', caseSensitive: false), '')
          .trim();
      if (cleanTitle.isNotEmpty) {
        currentEpHeading = 'EP $currentEpNum • $cleanTitle';
      } else {
        currentEpHeading = 'EP $currentEpNum';
      }
    } else {
      currentEpHeading = 'EP $currentEpNum';
    }

    // Rating & Metadata (using App Theme Colors)
    final ratingScore = currentAniZipEp?.rating != null
        ? currentAniZipEp!.rating
        : (widget.animeDetails?.score != null && widget.animeDetails!.score! > 0
            ? '${widget.animeDetails!.score!.toStringAsFixed(0)}%'
            : null);
    final episodeDuration = currentAniZipEp?.formattedDuration;
    final episodeAirDate = currentAniZipEp?.formattedAirDate;

    // Episode Synopsis (prefer episode synopsis, fallback to series)
    final episodeSynopsis = currentAniZipEp?.synopsis ??
        (episodes.isNotEmpty
            ? episodes
                .cast<AnimeEpisode?>()
                .firstWhere(
                  (e) => e?.episodeNumber == currentEpNum,
                  orElse: () => null,
                )
                ?.description
            : null);
    final effectiveSynopsis = (episodeSynopsis != null && episodeSynopsis.trim().isNotEmpty)
        ? episodeSynopsis.trim()
        : _cleanDescription(widget.animeDetails?.description);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: widget.isDesktop
            ? Border(
                left: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.15),
                  width: 1,
                ),
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Desktop panel header with close button
          if (widget.isDesktop)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Icon(AppIcons.info(iconPack), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Información',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onCollapse != null)
                    IconButton(
                      icon: Icon(AppIcons.close(iconPack), size: 20),
                      tooltip: 'Colapsar panel',
                      onPressed: widget.onCollapse,
                    ),
                ],
              ),
            ),

          if (widget.isLoading)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: Colors.transparent,
              color: theme.colorScheme.primary,
            ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // 1. Current Episode Title & Number FIRST (Prominent)
                Text(
                  currentEpHeading,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 3),

                // 2. Anime Title BELOW episode title
                Text(
                  widget.animeTitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    fontSize: 13.5,
                  ),
                ),

                // 3. Clean minimal metadata line (rating in app primary color, duration, air date)
                if (ratingScore != null || episodeDuration != null || episodeAirDate != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (ratingScore != null) ...[
                        Icon(AppIcons.star(iconPack), size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          ratingScore,
                          style: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (episodeDuration != null) ...[
                        Icon(AppIcons.clock(iconPack), size: 14, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          episodeDuration,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      if (episodeAirDate != null) ...[
                        Icon(AppIcons.calendar(iconPack), size: 13, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          episodeAirDate,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // 4. Loose Episode Synopsis (no card box, directly on background)
                if (effectiveSynopsis.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final textStyle = theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        height: 1.45,
                      ) ?? const TextStyle(fontSize: 12.5, height: 1.45);

                      final textSpan = TextSpan(
                        text: effectiveSynopsis,
                        style: textStyle,
                      );
                      final textPainter = TextPainter(
                        text: textSpan,
                        textDirection: Directionality.of(context),
                        maxLines: 3,
                      )..layout(maxWidth: constraints.maxWidth);

                      final bool canExpand = textPainter.didExceedMaxLines;

                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: canExpand
                            ? () => setState(() => _isSynopsisExpanded = !_isSynopsisExpanded)
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    l10n.synopsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (canExpand)
                                    Text(
                                      _isSynopsisExpanded ? 'Menos' : 'Más',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                effectiveSynopsis,
                                maxLines: _isSynopsisExpanded ? null : 3,
                                overflow: _isSynopsisExpanded ? null : TextOverflow.ellipsis,
                                style: textStyle,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // 5. MKV Chapters List (if available in current file)
                if (widget.chapters.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(AppIcons.bookmarks(iconPack), size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Capítulos (${widget.chapters.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 52,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.chapters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (context, idx) {
                        final ch = widget.chapters[idx];
                        final isActive = ch == widget.activeChapter;
                        return InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => widget.onSeekToChapter(ch.start),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                  : theme.colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ch.title,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                    color: isActive ? theme.colorScheme.primary : null,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDuration(ch.start),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 6. Next Episode Item (Loose layout like anime details EpisodeListItem)
                if (nextEp != null) ...[
                  Row(
                    children: [
                      Icon(AppIcons.skipNext(iconPack), size: 18, color: theme.colorScheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Siguiente episodio',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  NextEpisodeCard(
                    episode: nextEp,
                    animeTitle: widget.animeTitle,
                    episodeTitle: nextEpTitle,
                    imageUrl: nextAniZipEp?.image ?? nextEp.image,
                    fallbackImageUrl: widget.animeDetails?.bannerImage ?? widget.animeDetails?.coverImage,
                    synopsis: nextAniZipEp?.synopsis ?? nextEp.description,
                    duration: nextAniZipEp?.formattedDuration,
                    onTap: () {
                      if (widget.onPlayNextEpisode != null) {
                        widget.onPlayNextEpisode!();
                      } else if (widget.mediaId != null) {
                        AnimeDetailsModalSheet.show(
                          context: context,
                          mediaId: widget.mediaId!,
                          animeDetails: widget.animeDetails,
                        );
                      }
                    },
                  ),
                ],

                // 7. Previous Episode text button (positioned below Next Episode!)
                if (!isMovie && (prevEp != null || currentEpNum > 1)) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        visualDensity: VisualDensity.compact,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        if (widget.onPlayPreviousEpisode != null) {
                          widget.onPlayPreviousEpisode!();
                        } else if (widget.mediaId != null) {
                          AnimeDetailsModalSheet.show(
                            context: context,
                            mediaId: widget.mediaId!,
                            animeDetails: widget.animeDetails,
                          );
                        }
                      },
                      child: Text(
                        prevEp != null && prevEp.episodeNumber > 0
                            ? '← Episodio anterior: Ep. ${prevEp.episodeNumber}'
                            : '← Episodio anterior',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
