import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_file_card.dart';

class TorrentSelectorMobileView extends ConsumerWidget {
  final AnimeDetails? animeDetails;
  final int? currentEpisodeNumber;
  final String episodeTitle;
  final List<AnimeTorrentProvider> providers;
  final String? selectedProviderId;
  final bool isLoadingProviders;
  final List<TorrentItem> filteredTorrents;
  final List<TorrentItem> allTorrents;
  final bool isLoadingTorrents;
  final String? errorMessage;
  final String selectedQuality;
  final bool isSmartSearch;
  final bool showOnlyBatches;
  final TextEditingController searchController;
  final String? startingTorrentName;
  final ValueChanged<int?> onEpisodeChanged;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onSmartSearchChanged;
  final ValueChanged<bool> onBatchToggleChanged;
  final VoidCallback onRefresh;
  final void Function(TorrentItem) onTorrentTap;
  final void Function(TorrentItem) onDownloadTorrent;
  final void Function(TorrentItem) onExternalPlayer;
  final VoidCallback onClose;

  const TorrentSelectorMobileView({
    super.key,
    required this.animeDetails,
    required this.currentEpisodeNumber,
    required this.episodeTitle,
    required this.providers,
    required this.selectedProviderId,
    required this.isLoadingProviders,
    required this.filteredTorrents,
    required this.allTorrents,
    required this.isLoadingTorrents,
    required this.errorMessage,
    required this.selectedQuality,
    required this.isSmartSearch,
    required this.showOnlyBatches,
    required this.searchController,
    required this.startingTorrentName,
    required this.onEpisodeChanged,
    required this.onProviderChanged,
    required this.onQualityChanged,
    required this.onSmartSearchChanged,
    required this.onBatchToggleChanged,
    required this.onRefresh,
    required this.onTorrentTap,
    required this.onDownloadTorrent,
    required this.onExternalPlayer,
    required this.onClose,
  });

  String? _resolveThumbnail() {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final thumbnailUrl = _resolveThumbnail();
    final totalEpisodes = _getTotalEpisodes();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F121A) : theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header Row with Episode Thumbnail
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Row(
              children: [
                if (thumbnailUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 52,
                      height: 36,
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        placeholder: (context, url) => Container(color: Colors.black26),
                        errorWidget: (context, url, error) => Container(color: theme.colorScheme.surfaceContainerHigh),
                      ),
                    ),
                  )
                else
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.cloud_download_rounded, color: theme.colorScheme.primary, size: 20),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentEpisodeNumber != null
                            ? 'Torrents • ${l10n.episodeNumber(currentEpisodeNumber!)}'
                            : 'Torrents • ${l10n.allBatches}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                      ),
                      Text(
                        animeDetails?.title ?? episodeTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Horizontal Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                // Episode changer chip
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: currentEpisodeNumber,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                      dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(l10n.allBatches, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                        ...List.generate(totalEpisodes, (i) {
                          final ep = i + 1;
                          return DropdownMenuItem<int?>(
                            value: ep,
                            child: Text(l10n.episodeNumber(ep), style: const TextStyle(fontSize: 11.5)),
                          );
                        }),
                      ],
                      onChanged: onEpisodeChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Quality selector chip
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedQuality,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                      dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'Todos',
                          child: Text(l10n.filterAll, style: const TextStyle(fontSize: 11.5)),
                        ),
                        for (final q in const ['1080p', '720p', '2160p / 4K', '480p'])
                          DropdownMenuItem<String>(
                            value: q,
                            child: Text(q, style: const TextStyle(fontSize: 11.5)),
                          ),
                      ],
                      onChanged: (val) {
                        if (val != null) onQualityChanged(val);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Provider selector chip
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProviderId,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                      dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(l10n.allProviders, style: const TextStyle(fontSize: 11.5)),
                        ),
                        ...providers.map((p) => DropdownMenuItem<String>(
                              value: p.id,
                              child: Text(p.name, style: const TextStyle(fontSize: 11.5)),
                            )),
                      ],
                      onChanged: onProviderChanged,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Batch toggle
                FilterChip(
                  label: Text(l10n.showOnlyBatches, style: const TextStyle(fontSize: 11)),
                  selected: showOnlyBatches,
                  onSelected: onBatchToggleChanged,
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.folder_zip_rounded, size: 14),
                  selectedColor: Colors.purple.withValues(alpha: 0.25),
                  checkmarkColor: Colors.purpleAccent,
                ),
                const SizedBox(width: 8),

                // Refresh button
                IconButton(
                  tooltip: l10n.refresh,
                  onPressed: isLoadingTorrents ? null : onRefresh,
                  icon: Icon(AppIcons.refresh(iconPack), size: 16),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                    minimumSize: const Size(34, 34),
                    padding: const EdgeInsets.all(6),
                  ),
                ),
              ],
            ),
          ),

          // Results counter
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Text(
                  isLoadingTorrents
                      ? l10n.searchingTorrents
                      : (selectedQuality == 'Todos' && !showOnlyBatches
                          ? '${filteredTorrents.length} ${l10n.resultsFound}'
                          : '${filteredTorrents.length} / ${allTorrents.length} ${l10n.resultsFound}'),
                  style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),

          // Torrents list
          Expanded(
            child: isLoadingTorrents
                ? const Center(child: CircularProgressIndicator())
                : (filteredTorrents.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l10n.noTorrentsForEpisode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                        itemCount: filteredTorrents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final torrent = filteredTorrents[index];
                          final isStarting = startingTorrentName == torrent.name;
                          return TorrentFileCard(
                            torrent: torrent,
                            isStarting: isStarting,
                            onTap: () => onTorrentTap(torrent),
                            onDownload: () => onDownloadTorrent(torrent),
                            onExternalPlayer: () => onExternalPlayer(torrent),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
