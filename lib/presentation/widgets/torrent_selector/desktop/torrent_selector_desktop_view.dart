import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_file_card.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_sidebar_info_panel.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';

class TorrentSelectorDesktopView extends ConsumerWidget {
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
  final bool searchAcrossProviders;
  final TorrentSortField sortField;
  final bool sortAscending;
  final TextEditingController searchController;
  final String? startingTorrentName;
  final ValueChanged<int?> onEpisodeChanged;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onQualityChanged;
  final ValueChanged<bool> onSmartSearchChanged;
  final ValueChanged<bool> onBatchToggleChanged;
  final ValueChanged<bool> onSearchAcrossProvidersChanged;
  final ValueChanged<TorrentSortField> onSortFieldChanged;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onRefresh;
  final void Function(TorrentItem) onTorrentTap;
  final void Function(TorrentItem) onDownloadTorrent;
  final void Function(TorrentItem) onExternalPlayer;
  final VoidCallback onClose;

  const TorrentSelectorDesktopView({
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
    this.searchAcrossProviders = false,
    this.sortField = TorrentSortField.seeders,
    this.sortAscending = false,
    required this.searchController,
    required this.startingTorrentName,
    required this.onEpisodeChanged,
    required this.onProviderChanged,
    required this.onQualityChanged,
    required this.onSmartSearchChanged,
    required this.onBatchToggleChanged,
    required this.onSearchAcrossProvidersChanged,
    required this.onSortFieldChanged,
    required this.onToggleSortDirection,
    required this.onRefresh,
    required this.onTorrentTap,
    required this.onDownloadTorrent,
    required this.onExternalPlayer,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final mq = MediaQuery.of(context);
    final dialogWidth = (mq.size.width * 0.92).clamp(900.0, 1260.0);
    final dialogHeight = (mq.size.height * 0.88).clamp(580.0, 840.0);

    final sortedTorrents = sortTorrents(filteredTorrents, sortField, sortAscending);

    return Center(
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF0C0F17) : theme.colorScheme.surface).withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- LEFT PANEL: Info & Settings ---
                  SizedBox(
                    width: 320,
                    child: TorrentSidebarInfoPanel(
                      animeDetails: animeDetails,
                      currentEpisodeNumber: currentEpisodeNumber,
                      episodeTitle: episodeTitle,
                      providers: providers,
                      selectedProviderId: selectedProviderId,
                      isLoadingProviders: isLoadingProviders,
                      selectedQuality: selectedQuality,
                      isSmartSearch: isSmartSearch,
                      showOnlyBatches: showOnlyBatches,
                      searchAcrossProviders: searchAcrossProviders,
                      searchController: searchController,
                      isLoadingTorrents: isLoadingTorrents,
                      onEpisodeChanged: onEpisodeChanged,
                      onProviderChanged: onProviderChanged,
                      onQualityChanged: onQualityChanged,
                      onSmartSearchChanged: onSmartSearchChanged,
                      onBatchToggleChanged: onBatchToggleChanged,
                      onSearchAcrossProvidersChanged: onSearchAcrossProvidersChanged,
                      onRefresh: onRefresh,
                    ),
                  ),

                  const SizedBox(width: 14),

                  // --- RIGHT PANEL: Toolbar & Torrents List ---
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF10131E) : theme.colorScheme.surfaceContainerLowest).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.07) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Top Toolbar: "28 results" on left, Sort chips & Close button on right
                          Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                          child: Row(
                            children: [
                              // Results count
                              Text(
                                '${filteredTorrents.length} ${l10n.resultsFound.toLowerCase()}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),

                              const Spacer(),

                              // Sort Toolbar Chips
                              _buildSortButton(
                                label: l10n.sortSeeders,
                                field: TorrentSortField.seeders,
                                theme: theme,
                                isDark: isDark,
                                iconPack: iconPack,
                              ),
                              const SizedBox(width: 6),
                              _buildSortButton(
                                label: l10n.sortSize,
                                field: TorrentSortField.size,
                                theme: theme,
                                isDark: isDark,
                                iconPack: iconPack,
                              ),
                              const SizedBox(width: 6),
                              _buildSortButton(
                                label: l10n.sortDate,
                                field: TorrentSortField.date,
                                theme: theme,
                                isDark: isDark,
                                iconPack: iconPack,
                              ),
                              const SizedBox(width: 6),
                              _buildSortButton(
                                label: l10n.sortResolution,
                                field: TorrentSortField.resolution,
                                theme: theme,
                                isDark: isDark,
                                iconPack: iconPack,
                              ),

                              const SizedBox(width: 8),

                              // Close Dialog Button
                              IconButton(
                                tooltip: l10n.close,
                                onPressed: onClose,
                                icon: Icon(AppIcons.close(iconPack), size: 18),
                                visualDensity: VisualDensity.compact,
                                style: IconButton.styleFrom(
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  padding: const EdgeInsets.all(6),
                                  minimumSize: const Size(30, 30),
                                ),
                              ),
                            ],
                          ),
                        ),

                        Divider(
                          height: 1,
                          color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),

                        // Torrents List Body
                        Expanded(
                          child: _buildTorrentsBody(
                            theme,
                            isDark,
                            l10n,
                            sortedTorrents,
                            iconPack,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSortButton({
    required String label,
    required TorrentSortField field,
    required ThemeData theme,
    required bool isDark,
    required AppIconPack iconPack,
  }) {
    final isSelected = sortField == field;
    final icon = isSelected
        ? (sortAscending ? AppIcons.arrowUp(iconPack) : AppIcons.arrowDown(iconPack))
        : AppIcons.unfoldMore(iconPack);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        if (isSelected) {
          onToggleSortDirection();
        } else {
          onSortFieldChanged(field);
        }
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: 0.15)
              : (isDark ? const Color(0xFF171A24) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.4)
                : (isDark ? Colors.white.withValues(alpha: 0.07) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTorrentsBody(
    ThemeData theme,
    bool isDark,
    AppTranslations l10n,
    List<TorrentItem> sortedTorrents,
    AppIconPack iconPack,
  ) {
    if (isLoadingTorrents) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(strokeWidth: 2.5),
            const SizedBox(height: 14),
            Text(
              l10n.searchingTorrentsInProviders,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.error(iconPack), size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 10),
              Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: Icon(AppIcons.refresh(iconPack), size: 16),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (allTorrents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.searchOff(iconPack),
                size: 48,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noTorrentsForEpisode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.trySimpleSearchOrProvider,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ],
          ),
        ),
      );
    }

    if (sortedTorrents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.filterAltOff(iconPack),
                size: 46,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noTorrentsWithQuality(selectedQuality == 'Todos' ? l10n.filterAll : selectedQuality),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              const SizedBox(height: 10),
              FilledButton.tonal(
                onPressed: () => onQualityChanged('Todos'),
                child: Text(l10n.resetQualityFilterAll),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: sortedTorrents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final torrent = sortedTorrents[index];
        final isStarting = startingTorrentName == torrent.name;
        return TorrentFileCard(
          torrent: torrent,
          isStarting: isStarting,
          onTap: () => onTorrentTap(torrent),
          onDownload: () => onDownloadTorrent(torrent),
          onExternalPlayer: () => onExternalPlayer(torrent),
        );
      },
    );
  }
}
