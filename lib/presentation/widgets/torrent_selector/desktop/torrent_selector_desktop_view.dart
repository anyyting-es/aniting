import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_file_card.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_sidebar_info_panel.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final mq = MediaQuery.of(context);
    final dialogWidth = (mq.size.width * 0.92).clamp(860.0, 1220.0);
    final dialogHeight = (mq.size.height * 0.88).clamp(560.0, 800.0);

    return Center(
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D0F15) : theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // --- TOP HEADER BAR ---
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF13161F) : theme.colorScheme.surfaceContainerHigh,
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.torrentViewerTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          animeDetails?.title ?? episodeTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Close button
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: onClose,
                      icon: const Icon(Icons.close_rounded, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        padding: const EdgeInsets.all(6),
                        minimumSize: const Size(34, 34),
                      ),
                    ),
                  ],
                ),
              ),

              // --- TWO-PANEL SPLIT BODY ---
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // LEFT PANEL: Info & Settings
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
                          searchController: searchController,
                          isLoadingTorrents: isLoadingTorrents,
                          onEpisodeChanged: onEpisodeChanged,
                          onProviderChanged: onProviderChanged,
                          onQualityChanged: onQualityChanged,
                          onSmartSearchChanged: onSmartSearchChanged,
                          onBatchToggleChanged: onBatchToggleChanged,
                          onRefresh: onRefresh,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // RIGHT PANEL: Torrents List
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF11141C) : theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Results Subheader
                              Padding(
                                padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                                child: Row(
                                  children: [
                                    Text(
                                      isLoadingTorrents
                                          ? l10n.searchingTorrents
                                          : (selectedQuality == 'Todos' && !showOnlyBatches
                                              ? '${filteredTorrents.length} ${l10n.resultsFound}'
                                              : '${filteredTorrents.length} / ${allTorrents.length} ${l10n.resultsFound}'),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (selectedQuality != 'Todos') ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          selectedQuality,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const Divider(height: 1),

                              // Torrents List Body
                              Expanded(
                                child: _buildTorrentsBody(theme, isDark, l10n, iconPack),
                              ),
                            ],
                          ),
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
    );
  }

  Widget _buildTorrentsBody(ThemeData theme, bool isDark, AppTranslations l10n, AppIconPack iconPack) {
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
                fontSize: 13.5,
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
              Icon(Icons.error_outline_rounded, size: 44, color: theme.colorScheme.error),
              const SizedBox(height: 10),
              Text(errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 16),
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
                Icons.search_off_rounded,
                size: 52,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noTorrentsForEpisode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.trySimpleSearchOrProvider,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (filteredTorrents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: 50,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noTorrentsWithQuality(selectedQuality == 'Todos' ? l10n.filterAll : selectedQuality),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
      padding: const EdgeInsets.all(16),
      itemCount: filteredTorrents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
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
    );
  }
}
