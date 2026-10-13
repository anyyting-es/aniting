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
  final TextEditingController searchController;
  final bool isLoadingTorrents;
  final ValueChanged<int?> onEpisodeChanged;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onSmartSearchChanged;
  final ValueChanged<bool> onBatchToggleChanged;
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
    required this.searchController,
    required this.isLoadingTorrents,
    required this.onEpisodeChanged,
    required this.onProviderChanged,
    required this.onQualityChanged,
    required this.onSmartSearchChanged,
    required this.onBatchToggleChanged,
    required this.onRefresh,
  });

  String? _resolveEpisodeThumbnail() {
    final epNum = currentEpisodeNumber;
    if (epNum != null && animeDetails != null) {
      // 1. AniZip episode thumbnail
      final anizipEp = animeDetails!.aniZipData?.getEpisode(epNum);
      if (anizipEp?.image != null && anizipEp!.image!.isNotEmpty) {
        return anizipEp.image;
      }
      // 2. AnimeEpisode image
      final ep = animeDetails!.episodes.cast<AnimeEpisode?>().firstWhere(
            (e) => e?.episodeNumber == epNum,
            orElse: () => null,
          );
      if (ep?.image != null && ep!.image!.isNotEmpty) {
        return ep.image;
      }
    }
    // 3. Fallbacks: banner or cover image
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

    final thumbnailUrl = _resolveEpisodeThumbnail();
    final totalEpisodes = _getTotalEpisodes();
    final currentEp = currentEpisodeNumber;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF11141C) : theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- EPISODE THUMBNAIL & INFO CARD ---
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumbnailUrl != null)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      memCacheWidth: 600,
                      placeholder: (context, url) => Container(color: Colors.black26),
                      errorWidget: (context, url, error) => Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: Icon(Icons.movie_outlined, size: 36, color: theme.colorScheme.outline),
                      ),
                    )
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: Icon(Icons.movie_outlined, size: 36, color: theme.colorScheme.outline),
                    ),

                  // Gradient Protection
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black87,
                        ],
                      ),
                    ),
                  ),

                  // Episode Badge (Top Left)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        currentEp != null ? 'EP $currentEp' : 'BATCH',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  // Title on thumbnail bottom
                  Positioned(
                    bottom: 10,
                    left: 10,
                    right: 10,
                    child: Text(
                      currentEp != null
                          ? (episodeTitle.isNotEmpty ? episodeTitle : l10n.episodeNumber(currentEp))
                          : l10n.allBatches,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Anime Title
          Text(
            animeDetails?.title ?? 'Anime',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // --- EPISODE CHANGER ---
          Text(
            l10n.episodeChanger,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              // Previous Button
              IconButton(
                tooltip: l10n.previousEpisode,
                onPressed: (currentEp != null && currentEp > 1)
                    ? () => onEpisodeChanged(currentEp - 1)
                    : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(38, 38),
                ),
              ),
              const SizedBox(width: 8),

              // Episode Dropdown Pill
              Expanded(
                child: Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1D27) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: currentEp,
                      isExpanded: true,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                      dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(12),
                      items: [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            l10n.allBatches,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...List.generate(totalEpisodes, (i) {
                          final ep = i + 1;
                          return DropdownMenuItem<int?>(
                            value: ep,
                            child: Text(
                              l10n.episodeNumber(ep),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          );
                        }),
                      ],
                      onChanged: onEpisodeChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Next Button
              IconButton(
                tooltip: l10n.nextEpisode,
                onPressed: (currentEp != null && currentEp < totalEpisodes)
                    ? () => onEpisodeChanged(currentEp + 1)
                    : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(38, 38),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // --- RESOLUTION / QUALITY SELECTOR ---
          Text(
            l10n.resolutionQuality,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in const ['Todos', '1080p', '720p', '2160p / 4K', '480p']) ...[
                Builder(
                  builder: (context) {
                    final isSelected = selectedQuality == q;
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onQualityChanged(q),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : (isDark
                                  ? const Color(0xFF1A1D27)
                                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          q == 'Todos' ? l10n.filterAll : q,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),

          const SizedBox(height: 18),

          // --- PROVIDER SELECTOR ---
          Text(
            l10n.torrentProviderLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1D27) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
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
                icon: const Icon(Icons.arrow_drop_down_rounded, size: 20),
                dropdownColor: isDark ? const Color(0xFF1E222E) : theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                items: [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Text(l10n.allProviders, style: const TextStyle(fontSize: 12.5)),
                  ),
                  ...providers.map((p) => DropdownMenuItem<String>(
                        value: p.id,
                        child: Text(
                          p.name,
                          style: const TextStyle(fontSize: 12.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )),
                ],
                onChanged: onProviderChanged,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // --- SEARCH MODE (SMART VS SIMPLE) ---
          Row(
            children: [
              Text(
                isSmartSearch ? l10n.smartSearch : l10n.simpleSearch,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: isSmartSearch ? l10n.simpleSearch : l10n.smartSearch,
                onPressed: () => onSmartSearchChanged(!isSmartSearch),
                icon: Icon(
                  isSmartSearch ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
                  size: 18,
                  color: isSmartSearch ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                style: IconButton.styleFrom(
                  backgroundColor: isSmartSearch
                      ? theme.colorScheme.primary.withValues(alpha: 0.15)
                      : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                  padding: const EdgeInsets.all(6),
                  minimumSize: const Size(32, 32),
                ),
              ),
            ],
          ),

          if (!isSmartSearch) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D27) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: searchController,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: l10n.searchQueryHint,
                        hintStyle: const TextStyle(fontSize: 12),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                      onSubmitted: (_) => onRefresh(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.search_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(38, 38),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 18),

          // --- BATCH TOGGLE SWITCH ---
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onBatchToggleChanged(!showOnlyBatches),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: showOnlyBatches
                    ? Colors.purple.withValues(alpha: 0.15)
                    : (isDark ? const Color(0xFF1A1D27) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: showOnlyBatches
                      ? Colors.purpleAccent.withValues(alpha: 0.4)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_zip_rounded,
                    size: 18,
                    color: showOnlyBatches ? Colors.purpleAccent : theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.showOnlyBatches,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: showOnlyBatches ? FontWeight.bold : FontWeight.w500,
                        color: showOnlyBatches ? Colors.purpleAccent : theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: showOnlyBatches,
                    onChanged: onBatchToggleChanged,
                    activeTrackColor: Colors.purpleAccent,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // --- REFRESH BUTTON ---
          FilledButton.tonalIcon(
            onPressed: isLoadingTorrents ? null : onRefresh,
            icon: Icon(AppIcons.refresh(iconPack), size: 16),
            label: Text(l10n.refresh, style: const TextStyle(fontSize: 12.5)),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}
