import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';

/// Episode heading (number + title), series title and compact metadata row.
/// Extracted so the desktop watch column and the mobile info panel share it.
class PlayerEpisodeHeader extends ConsumerWidget {
  final String animeTitle;
  final int? episodeNumber;
  final String? episodeTitle;
  final AnimeDetails? animeDetails;
  final AniZipData? aniZipData;
  final VoidCallback? onTitleTap;

  const PlayerEpisodeHeader({
    super.key,
    required this.animeTitle,
    this.episodeNumber,
    this.episodeTitle,
    this.animeDetails,
    this.aniZipData,
    this.onTitleTap,
  });

  static bool isGenericTitle(String? title, int epNum) {
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
    return RegExp(r'^(episode|episodio|ep\.?|e)\s*\d+$', caseSensitive: false)
        .hasMatch(clean);
  }

  static String cleanDescription(String? text) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);

    final episodes = animeDetails?.episodes ?? const <AnimeEpisode>[];
    final currentEpNum = episodeNumber ?? 1;
    final totalEps = animeDetails?.totalEpisodes;
    final isMovie = animeDetails?.format?.toUpperCase() == 'MOVIE' ||
        (totalEps == 1 && episodes.length <= 1);

    final aniZip = aniZipData ?? animeDetails?.aniZipData;
    final currentAniZipEp = aniZip?.getEpisode(currentEpNum);
    final currentDetailsEp = episodes.where((e) => e.episodeNumber == currentEpNum).firstOrNull;

    final String? currentEpRawTitle;
    if (currentAniZipEp != null &&
        !isGenericTitle(currentAniZipEp.displayTitle, currentEpNum)) {
      currentEpRawTitle = currentAniZipEp.displayTitle;
    } else if (currentDetailsEp != null &&
        !isGenericTitle(currentDetailsEp.title, currentEpNum)) {
      currentEpRawTitle = currentDetailsEp.title;
    } else if (episodeTitle != null && !isGenericTitle(episodeTitle, currentEpNum)) {
      currentEpRawTitle = episodeTitle;
    } else {
      currentEpRawTitle = currentAniZipEp?.displayTitle ?? currentDetailsEp?.title ?? episodeTitle;
    }

    final String currentEpHeading;
    if (isMovie) {
      final clean = (currentEpRawTitle != null && currentEpRawTitle.isNotEmpty)
          ? currentEpRawTitle
              .replaceFirst(
                RegExp(
                  r'^(episodio|episode|ep\.?)\s*' +
                      currentEpNum.toString() +
                      r'\s*[\-•:]?\s*',
                  caseSensitive: false,
                ),
                '',
              )
              .trim()
          : '';
      if (clean.isNotEmpty && clean.toLowerCase() != 'complete movie') {
        currentEpHeading = '${l10n.formatMovie} • $clean';
      } else {
        currentEpHeading = l10n.formatMovie;
      }
    } else if (currentEpRawTitle != null &&
        currentEpRawTitle.isNotEmpty &&
        !isGenericTitle(currentEpRawTitle, currentEpNum)) {
      final cleanTitle = currentEpRawTitle
          .replaceFirst(
            RegExp(
              r'^(episodio|episode|ep\.?)\s*' +
                  currentEpNum.toString() +
                  r'\s*[\-•:]?\s*',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
      currentEpHeading =
          cleanTitle.isNotEmpty ? 'EP $currentEpNum • $cleanTitle' : 'EP $currentEpNum';
    } else {
      currentEpHeading = 'EP $currentEpNum';
    }

    final ratingScore = currentAniZipEp?.rating != null
        ? currentAniZipEp!.rating
        : (animeDetails?.score != null && animeDetails!.score! > 0
            ? '${animeDetails!.score!.toStringAsFixed(0)}%'
            : null);
    final episodeDuration = currentAniZipEp?.formattedDuration;
    final episodeAirDate = currentAniZipEp?.formattedAirDate;

    final animeTitleText = Text(
      animeTitle,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          currentEpHeading,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        if (onTitleTap != null)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              onTap: onTitleTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: animeTitleText,
              ),
            ),
          )
        else
          animeTitleText,
        if (ratingScore != null || episodeDuration != null || episodeAirDate != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              if (ratingScore != null) ...[
                Icon(AppIcons.star(iconPack), size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 4),
                Text(
                  ratingScore,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (episodeDuration != null) ...[
                Icon(AppIcons.clock(iconPack), size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  episodeDuration,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (episodeAirDate != null) ...[
                Icon(AppIcons.calendar(iconPack), size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  episodeAirDate,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}
