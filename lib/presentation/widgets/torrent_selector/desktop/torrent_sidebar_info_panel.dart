import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';

class TorrentSidebarInfoPanel extends ConsumerWidget {
  final AnimeDetails? animeDetails;
  final int? currentEpisodeNumber;
  final String episodeTitle;
  final List<AnimeTorrentProvider> providers;
  final String? selectedProviderId;
  final bool isLoadingProviders;
  final String selectedQuality;
  final bool isSmartSearch;
  final bool showOnlyBatches;
  final bool searchAcrossProviders;
  final TextEditingController searchController;
  final bool isLoadingTorrents;
  final ValueChanged<int?> onEpisodeChanged;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onSmartSearchChanged;
  final ValueChanged<bool> onBatchToggleChanged;
  final ValueChanged<bool> onSearchAcrossProvidersChanged;
  final VoidCallback onRefresh;

  const TorrentSidebarInfoPanel({
    super.key,
    required this.animeDetails,
    required this.currentEpisodeNumber,
    required this.episodeTitle,
    required this.providers,
    required this.selectedProviderId,
    required this.isLoadingProviders,
    required this.selectedQuality,
    required this.isSmartSearch,
    required this.showOnlyBatches,
    this.searchAcrossProviders = false,
    required this.searchController,
    required this.isLoadingTorrents,
    required this.onEpisodeChanged,
    required this.onProviderChanged,
    required this.onQualityChanged,
    required this.onSmartSearchChanged,
    required this.onBatchToggleChanged,
    required this.onSearchAcrossProvidersChanged,
    required this.onRefresh,
  });

  String? _resolveEpisodeThumbnail() {
    final epNum = currentEpisodeNumber;
    if (epNum != null && animeDetails != null) {
      final anizipEp = animeDetails!.aniZipData?.getEpisode(epNum);
      if (anizipEp?.image != null && anizipEp!.image!.isNotEmpty) {
        return anizipEp.image;
      }
      final ep = animeDetails!.episodes.cast<AnimeEpisode?>().firstWhere(
            (e) => e?.episodeNumber == epNum,
            orElse: () => null,
          );
      if (ep?.image != null && ep!.image!.isNotEmpty) {
        return ep.image;
      }
    }
    return animeDetails?.bannerImage ?? animeDetails?.coverImage;
  }

  int _getTotalEpisodes() {
    if (animeDetails?.episodes.isNotEmpty == true) {
      return animeDetails!.episodes.length;
    }
    return animeDetails?.totalEpisodes ?? math.max(currentEpisodeNumber ?? 12, 12);
  }

  String _resolveEpisodeDuration() {
    final epNum = currentEpisodeNumber;
    if (epNum != null && animeDetails?.aniZipData != null) {
      final anizipEp = animeDetails!.aniZipData!.getEpisode(epNum);
      if (anizipEp?.runtime != null && anizipEp!.runtime! > 0) {
        return '${anizipEp.runtime}m';
      }
    }
    return '24m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final thumbnailUrl = _resolveEpisodeThumbnail();
    final totalEpisodes = _getTotalEpisodes();
    final currentEp = currentEpisodeNumber;
    final displayAnimeTitle = animeDetails?.title ?? episodeTitle;
    final romajiOrTitle = animeDetails?.romajiTitle ?? animeDetails?.title ?? '';

    return Container(
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF10131E) : theme.colorScheme.surfaceContainerLowest).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.07) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        children: [
          // 1. Header: "Select a torrent to stream"
          Text(
            l10n.selectTorrentToStream,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 12),

          // 2. Clean 16:9 Episode Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: thumbnailUrl != null
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      placeholder: (context, url) => Container(
                        color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHigh,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHigh,
                        child: Icon(AppIcons.movie(iconPack), size: 32, color: theme.colorScheme.outline),
                      ),
                    )
                  : Container(
                      color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHigh,
                      child: Icon(AppIcons.movie(iconPack), size: 32, color: theme.colorScheme.outline),
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // 3. Anime / Episode Title
          Text(
            displayAnimeTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              height: 1.25,
              color: theme.colorScheme.onSurface,
            ),
          ),

          const SizedBox(height: 4),

          // Subtitle row: "Episode X / Y" on left, "24m" on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                currentEp != null
                    ? '${l10n.episode} $currentEp / $totalEpisodes'
                    : l10n.batches,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                _resolveEpisodeDuration(),
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),

          // 4. Provider Dropdown
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedProviderId,
                isExpanded: true,
                isDense: true,
                hint: Text(
                  isLoadingProviders ? l10n.loadingProviders : l10n.onlineProvider,
                  style: const TextStyle(fontSize: 12),
                ),
                icon: Icon(AppIcons.chevronDown(iconPack), size: 18),
                dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.allProviders, style: const TextStyle(fontSize: 12)),
                  ),
                  ...providers.map((p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          p.name,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: onProviderChanged,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // 5. Smart search Toggle
          _buildToggleRow(
            title: l10n.smartSearch,
            tooltip: l10n.smartSearch,
            value: isSmartSearch,
            onChanged: onSmartSearchChanged,
            theme: theme,
            iconPack: iconPack,
          ),

          const SizedBox(height: 6),

          // 6. Search across providers Toggle
          _buildToggleRow(
            title: l10n.searchAcrossProviders,
            tooltip: l10n.searchAcrossProviders,
            value: searchAcrossProviders,
            onChanged: onSearchAcrossProvidersChanged,
            theme: theme,
            iconPack: iconPack,
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),

          // 7. Episode number with Stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.episodeNumberLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              // Compact Stepper [ 8 ▲▼ ]
              Container(
                height: 32,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        currentEp != null ? '$currentEp' : '—',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        InkWell(
                          onTap: (currentEp != null && currentEp < totalEpisodes)
                              ? () => onEpisodeChanged(currentEp + 1)
                              : null,
                          child: Icon(
                            AppIcons.arrowDropUp(iconPack),
                            size: 16,
                            color: (currentEp != null && currentEp < totalEpisodes)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                        InkWell(
                          onTap: (currentEp != null && currentEp > 1)
                              ? () => onEpisodeChanged(currentEp - 1)
                              : null,
                          child: Icon(
                            AppIcons.arrowDropDown(iconPack),
                            size: 16,
                            color: (currentEp != null && currentEp > 1)
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 8. Batches Toggle
          _buildToggleRow(
            title: l10n.batches,
            tooltip: l10n.showOnlyBatches,
            value: showOnlyBatches,
            onChanged: onBatchToggleChanged,
            theme: theme,
            iconPack: iconPack,
          ),

          const SizedBox(height: 10),

          // 9. Resolution dropdown row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.resolution,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedQuality,
                    isDense: true,
                    icon: Icon(AppIcons.chevronDown(iconPack), size: 16),
                    dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                    items: [
                      DropdownMenuItem<String>(
                        value: 'Todos',
                        child: Text(l10n.filterAll, style: const TextStyle(fontSize: 12)),
                      ),
                      ...['1080p', '720p', '2160p / 4K', '480p'].map(
                        (q) => DropdownMenuItem<String>(
                          value: q,
                          child: Text(q, style: const TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) onQualityChanged(val);
                    },
                  ),
                ),
              ),
            ],
          ),



          const SizedBox(height: 14),

          // 11. Refine the title search bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppIcons.search(iconPack),
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: romajiOrTitle.isNotEmpty
                          ? '${l10n.refineTitleHint} ($romajiOrTitle)'
                          : l10n.refineTitleHint,
                      hintStyle: TextStyle(
                        fontSize: 11.5,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => onRefresh(),
                  ),
                ),
                if (searchController.text.isNotEmpty)
                  InkWell(
                    onTap: () {
                      searchController.clear();
                      onRefresh();
                    },
                    child: Icon(
                      AppIcons.close(iconPack),
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String tooltip,
    required bool value,
    required ValueChanged<bool> onChanged,
    required ThemeData theme,
    required AppIconPack iconPack,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip,
              child: Icon(
                AppIcons.info(iconPack),
                size: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}
