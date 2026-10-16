import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_file_card.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/mobile/torrent_popover_menus.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';

class TorrentSelectorMobileView extends ConsumerStatefulWidget {
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
  ConsumerState<TorrentSelectorMobileView> createState() => _TorrentSelectorMobileViewState();
}

class _TorrentSelectorMobileViewState extends ConsumerState<TorrentSelectorMobileView> {
  bool _isSearchExpanded = false;
  late final GlassMenuController _providerController;
  late final GlassMenuController _episodeController;
  late final GlassMenuController _qualityController;
  late final GlassMenuController _sortController;

  @override
  void initState() {
    super.initState();
    _providerController = GlassMenuController();
    _episodeController = GlassMenuController();
    _qualityController = GlassMenuController();
    _sortController = GlassMenuController();
    if (widget.searchController.text.trim().isNotEmpty) {
      _isSearchExpanded = true;
    }
  }

  String? _resolveThumbnail() {
    final epNum = widget.currentEpisodeNumber;
    if (epNum != null && widget.animeDetails != null) {
      final anizipEp = widget.animeDetails!.aniZipData?.getEpisode(epNum);
      if (anizipEp?.image != null && anizipEp!.image!.isNotEmpty) {
        return anizipEp.image;
      }
      final ep = widget.animeDetails!.episodes.cast<AnimeEpisode?>().firstWhere(
            (e) => e?.episodeNumber == epNum,
            orElse: () => null,
          );
      if (ep?.image != null && ep!.image!.isNotEmpty) {
        return ep.image;
      }
    }
    return widget.animeDetails?.bannerImage ?? widget.animeDetails?.coverImage;
  }

  int _getTotalEpisodes() {
    if (widget.animeDetails?.episodes.isNotEmpty == true) {
      return widget.animeDetails!.episodes.length;
    }
    return widget.animeDetails?.totalEpisodes ?? math.max(widget.currentEpisodeNumber ?? 12, 12);
  }

  String _getSortFieldLabel(BuildContext context) {
    final l10n = ref.read(translationsProvider);
    switch (widget.sortField) {
      case TorrentSortField.seeders:
        return l10n.sortSeeders;
      case TorrentSortField.size:
        return l10n.sortSize;
      case TorrentSortField.date:
        return l10n.sortDate;
      case TorrentSortField.resolution:
        return l10n.sortResolution;
      case TorrentSortField.none:
        return l10n.filterAll;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final thumbnailUrl = _resolveThumbnail();
    final totalEpisodes = _getTotalEpisodes();
    final sortedTorrents = sortTorrents(
      widget.filteredTorrents,
      widget.sortField,
      widget.sortAscending,
    );

    final selectedProviderName = widget.selectedProviderId != null
        ? widget.providers
            .cast<AnimeTorrentProvider?>()
            .firstWhere((p) => p?.id == widget.selectedProviderId, orElse: () => null)
            ?.name
        : l10n.allProviders;

    final hasActiveCustomFilter = widget.selectedQuality != 'Todos' ||
        widget.showOnlyBatches ||
        widget.searchController.text.trim().isNotEmpty;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- 1. Compact Liquid Header ---
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 12, 8),
                child: Row(
                  children: [
                    if (thumbnailUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 50,
                          height: 38,
                          child: CachedNetworkImage(
                            imageUrl: thumbnailUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 200,
                            placeholder: (_, _) => Container(color: Colors.black26),
                            errorWidget: (_, _, _) => Container(
                              color: theme.colorScheme.surfaceContainerHigh,
                              child: Icon(AppIcons.movie(iconPack), size: 18, color: theme.colorScheme.primary),
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 40,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(AppIcons.download(iconPack), color: theme.colorScheme.primary, size: 20),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.currentEpisodeNumber != null
                                      ? l10n.episodeNumber(widget.currentEpisodeNumber!)
                                      : l10n.allBatches,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                              ),
                              if (widget.currentEpisodeNumber != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'P2P',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.animeDetails?.title ?? widget.episodeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Search Toggle Button
                    IconButton(
                      tooltip: l10n.search,
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() => _isSearchExpanded = !_isSearchExpanded);
                      },
                      icon: Icon(
                        _isSearchExpanded ? AppIcons.searchOff(iconPack) : AppIcons.search(iconPack),
                        size: 20,
                        color: _isSearchExpanded || widget.searchController.text.isNotEmpty
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: (_isSearchExpanded || widget.searchController.text.isNotEmpty)
                            ? theme.colorScheme.primary.withValues(alpha: 0.16)
                            : (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04)),
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Refresh Button
                    IconButton(
                      tooltip: l10n.refresh,
                      onPressed: widget.isLoadingTorrents ? null : widget.onRefresh,
                      icon: widget.isLoadingTorrents
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                            )
                          : Icon(AppIcons.refresh(iconPack), size: 18),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    const SizedBox(width: 4),

                    // Close Button
                    IconButton(
                      tooltip: l10n.close,
                      onPressed: widget.onClose,
                      icon: Icon(AppIcons.close(iconPack), size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                        minimumSize: const Size(36, 36),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),

              // --- 2. Expandable Search Bar ---
              if (_isSearchExpanded)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(AppIcons.search(iconPack), size: 18, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: widget.searchController,
                                autofocus: true,
                                textInputAction: TextInputAction.search,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: l10n.refineTitleHint,
                                  hintStyle: TextStyle(
                                    fontSize: 12.5,
                                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                ),
                                onSubmitted: (_) => widget.onRefresh(),
                              ),
                            ),
                            if (widget.searchController.text.isNotEmpty)
                              IconButton(
                                icon: Icon(AppIcons.close(iconPack), size: 16),
                                onPressed: () {
                                  widget.searchController.clear();
                                  widget.onRefresh();
                                },
                                visualDensity: VisualDensity.compact,
                              ),
                          ],
                        ),
                        const Divider(height: 1),
                        // Quick search toggles
                        Padding(
                          padding: const EdgeInsets.only(top: 4, bottom: 2),
                          child: Row(
                            children: [
                              _buildMiniToggle(
                                label: l10n.smartSearch,
                                isSelected: widget.isSmartSearch,
                                icon: AppIcons.sparkles(iconPack),
                                onTap: () => widget.onSmartSearchChanged(!widget.isSmartSearch),
                              ),
                              const SizedBox(width: 6),
                              _buildMiniToggle(
                                label: l10n.searchAcrossProviders,
                                isSelected: widget.searchAcrossProviders,
                                icon: AppIcons.globe(iconPack),
                                onTap: () => widget.onSearchAcrossProvidersChanged(!widget.searchAcrossProviders),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // --- 2. Combined Provider & Episode Stepper in a Single Line ---
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 6),
                child: Row(
                  children: [
                    // Provider Dropdown (Expanded, left aligned)
                    Expanded(
                      child: GlassPopoverAnchor(
                        controller: _providerController,
                        width: 250,
                        radius: 18,
                        popoverBuilder: (ctx) => TorrentProviderPopoverContent(
                          providers: widget.providers,
                          selectedProviderId: widget.selectedProviderId,
                          onProviderSelected: widget.onProviderChanged,
                          onClose: () => _providerController.close(),
                        ),
                        builder: (ctx, controller) => _buildProviderButton(
                          theme: theme,
                          isDark: isDark,
                          selectedName: selectedProviderName ?? l10n.allProviders,
                          hasProvider: widget.selectedProviderId != null,
                          iconPack: iconPack,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            controller.open();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Episode Stepper (< [Ep. X ▾] >)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Previous Episode Arrow
                        _buildStepperArrowButton(
                          context: context,
                          icon: AppIcons.chevronLeft(iconPack),
                          tooltip: l10n.previousEpisode,
                          enabled: widget.currentEpisodeNumber != null,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (widget.currentEpisodeNumber == 1) {
                              widget.onEpisodeChanged(null);
                            } else if (widget.currentEpisodeNumber != null && widget.currentEpisodeNumber! > 1) {
                              widget.onEpisodeChanged(widget.currentEpisodeNumber! - 1);
                            }
                          },
                        ),
                        const SizedBox(width: 4),

                        // Center Episode Popover Button
                        GlassPopoverAnchor(
                          controller: _episodeController,
                          width: 250,
                          radius: 18,
                          popoverBuilder: (ctx) => TorrentEpisodePopoverContent(
                            currentEpisode: widget.currentEpisodeNumber,
                            totalEpisodes: totalEpisodes,
                            onEpisodeSelected: widget.onEpisodeChanged,
                            onClose: () => _episodeController.close(),
                          ),
                          builder: (ctx, controller) => _buildEpisodeButton(
                            theme: theme,
                            isDark: isDark,
                            label: widget.currentEpisodeNumber != null
                                ? 'Ep. ${widget.currentEpisodeNumber}'
                                : l10n.allBatches,
                            isBatch: widget.currentEpisodeNumber == null,
                            iconPack: iconPack,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.open();
                            },
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Next Episode Arrow
                        _buildStepperArrowButton(
                          context: context,
                          icon: AppIcons.chevronRight(iconPack),
                          tooltip: l10n.nextEpisode,
                          enabled: widget.currentEpisodeNumber == null || widget.currentEpisodeNumber! < totalEpisodes,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            if (widget.currentEpisodeNumber == null) {
                              widget.onEpisodeChanged(1);
                            } else if (widget.currentEpisodeNumber! < totalEpisodes) {
                              widget.onEpisodeChanged(widget.currentEpisodeNumber! + 1);
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // --- 3. Liquid Filter Bar (Horizontal Carousel with Popovers) ---
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Row(
                  children: [
                    // Quality Popover Pill
                    GlassPopoverAnchor(
                      controller: _qualityController,
                      width: 190,
                      radius: 18,
                      popoverBuilder: (ctx) => TorrentQualityPopoverContent(
                        selectedQuality: widget.selectedQuality,
                        onQualitySelected: widget.onQualityChanged,
                        onClose: () => _qualityController.close(),
                      ),
                      builder: (ctx, controller) => _buildFilterPill(
                        icon: AppIcons.highQuality(iconPack),
                        label: widget.selectedQuality == 'Todos' ? l10n.filterAll : widget.selectedQuality,
                        isActive: widget.selectedQuality != 'Todos',
                        iconPack: iconPack,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.open();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Sort Popover Pill
                    GlassPopoverAnchor(
                      controller: _sortController,
                      width: 230,
                      radius: 18,
                      popoverBuilder: (ctx) => TorrentSortPopoverContent(
                        sortField: widget.sortField,
                        sortAscending: widget.sortAscending,
                        onSortFieldChanged: widget.onSortFieldChanged,
                        onToggleSortDirection: widget.onToggleSortDirection,
                        onClose: () => _sortController.close(),
                      ),
                      builder: (ctx, controller) => _buildFilterPill(
                        icon: AppIcons.sort(iconPack),
                        label: '${_getSortFieldLabel(context)} ${widget.sortAscending ? "↑" : "↓"}',
                        iconPack: iconPack,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          controller.open();
                        },
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Batches Toggle Pill
                    _buildActionChip(
                      icon: AppIcons.folderZip(iconPack),
                      label: l10n.batches,
                      isSelected: widget.showOnlyBatches,
                      activeColor: Colors.purpleAccent,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onBatchToggleChanged(!widget.showOnlyBatches);
                      },
                    ),
                  ],
                ),
              ),

              // --- 4. Results & Status Bar ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Row(
                  children: [
                    if (widget.isLoadingTorrents) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        l10n.searchingTorrents,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      Text(
                        sortedTorrents.length == widget.allTorrents.length
                            ? '${sortedTorrents.length} ${l10n.resultsFound}'
                            : '${sortedTorrents.length} / ${widget.allTorrents.length} ${l10n.resultsFound}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (hasActiveCustomFilter)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          widget.onQualityChanged('Todos');
                          if (widget.currentEpisodeNumber != null) {
                            widget.onBatchToggleChanged(false);
                          }
                          widget.searchController.clear();
                          widget.onRefresh();
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          child: Text(
                            l10n.filterAll,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // --- 5. Torrents List View ---
              Flexible(
                child: widget.isLoadingTorrents
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.2, color: theme.colorScheme.primary),
                            const SizedBox(height: 14),
                            Text(
                              l10n.searchingTorrents,
                              style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : widget.errorMessage != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(AppIcons.error(iconPack), size: 36, color: Colors.red.shade400),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.errorMessage!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 14),
                                  OutlinedButton.icon(
                                    onPressed: widget.onRefresh,
                                    icon: Icon(AppIcons.refresh(iconPack), size: 16),
                                    label: Text(l10n.retry),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : sortedTorrents.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(28),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(AppIcons.searchOff(iconPack), size: 40, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                                      const SizedBox(height: 10),
                                      Text(
                                        l10n.noTorrentsForEpisode,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        l10n.noTorrentsFoundDesc,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          widget.onSearchAcrossProvidersChanged(true);
                                          widget.onRefresh();
                                        },
                                        icon: Icon(AppIcons.globe(iconPack), size: 16),
                                        label: Text(l10n.searchAcrossProviders),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                                physics: const BouncingScrollPhysics(),
                                itemCount: sortedTorrents.length,
                                separatorBuilder: (_, _) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final torrent = sortedTorrents[index];
                                  final isStarting = widget.startingTorrentName == torrent.name;
                                  return TorrentFileCard(
                                    torrent: torrent,
                                    isStarting: isStarting,
                                    onTap: () => widget.onTorrentTap(torrent),
                                    onDownload: () => widget.onDownloadTorrent(torrent),
                                    onExternalPlayer: () => widget.onExternalPlayer(torrent),
                                  );
                                },
                              ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderButton({
    required ThemeData theme,
    required bool isDark,
    required String selectedName,
    required bool hasProvider,
    required AppIconPack iconPack,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Icon(AppIcons.server(iconPack), size: 15, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  selectedName,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: hasProvider ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.chevronDown(iconPack),
                size: 16,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeButton({
    required ThemeData theme,
    required bool isDark,
    required String label,
    required bool isBatch,
    required AppIconPack iconPack,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isBatch ? AppIcons.folderZip(iconPack) : AppIcons.playCircle(iconPack),
                size: 15,
                color: isBatch ? Colors.purpleAccent : theme.colorScheme.primary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                AppIcons.chevronDown(iconPack),
                size: 15,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepperArrowButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 150),
            opacity: enabled ? 1.0 : 0.35,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Icon(
                icon,
                size: 20,
                color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppIconPack iconPack,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withValues(alpha: 0.2)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? theme.colorScheme.primary.withValues(alpha: 0.7)
                  : (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
              width: isActive ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                AppIcons.arrowDropDown(iconPack),
                size: 16,
                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.22)
                : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.75)
                  : (isDark ? Colors.white.withValues(alpha: 0.12) : theme.colorScheme.outlineVariant.withValues(alpha: 0.35)),
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? activeColor : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniToggle({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 12,
              color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
