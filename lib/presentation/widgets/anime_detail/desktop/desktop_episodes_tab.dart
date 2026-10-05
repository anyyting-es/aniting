import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

import 'desktop_episode_grid_card.dart';
import 'desktop_episode_list_card.dart';
import 'desktop_episode_models.dart';
import 'desktop_episode_pagination.dart';

export 'desktop_episode_models.dart';

class DesktopEpisodesTab extends ConsumerStatefulWidget {
  final int mediaId;
  final AnimeDetails? details;
  final AniZipData? aniZipData;
  final bool isLoadingAniZip;
  final int progress;
  final bool isLocalMode;
  final AnimeDetailTab currentTab;
  final List<OnlinestreamProvider> providers;
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final List<OnlinestreamEpisode> onlineEpisodes;
  final bool isLoadingOnlineEpisodes;
  final int? loadingEpisodeNumber;
  final String? fallbackCoverImage;

  final ValueChanged<OnlinestreamProvider?> onProviderChanged;
  final VoidCallback onToggleDubbed;
  final void Function(DesktopEpisodeItemData ep) onEpisodeClicked;
  final VoidCallback onToggleLocalMode;
  final ValueChanged<AnimeDetailTab> onTabChanged;

  const DesktopEpisodesTab({
    super.key,
    required this.mediaId,
    required this.details,
    required this.aniZipData,
    this.isLoadingAniZip = false,
    required this.progress,
    required this.isLocalMode,
    required this.currentTab,
    required this.providers,
    required this.selectedProvider,
    required this.isDubbed,
    required this.onlineEpisodes,
    this.isLoadingOnlineEpisodes = false,
    required this.loadingEpisodeNumber,
    required this.fallbackCoverImage,
    required this.onProviderChanged,
    required this.onToggleDubbed,
    required this.onEpisodeClicked,
    required this.onToggleLocalMode,
    required this.onTabChanged,
  });

  @override
  ConsumerState<DesktopEpisodesTab> createState() => _DesktopEpisodesTabState();
}

class _DesktopEpisodesTabState extends ConsumerState<DesktopEpisodesTab> {
  bool _isGridView = true;
  bool _isSortAscending = true;
  int _currentPage = 0;
  static const int _episodesPerPage = 20;

  LibraryEntryDetails? _libraryEntry;
  bool _isLoadingLocal = false;

  @override
  void initState() {
    super.initState();
    _loadLocalEntry();
  }

  Future<void> _loadLocalEntry() async {
    if (!mounted) return;
    setState(() => _isLoadingLocal = true);
    try {
      final repo = ref.read(repositoryProvider);
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      if (mounted) {
        setState(() {
          _libraryEntry = entry;
          _isLoadingLocal = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingLocal = false);
    }
  }

  Future<void> _scanAndRefreshLocal() async {
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.scanStarted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    await repo.scanLibrary();
    await _loadLocalEntry();
    ref.invalidate(downloadedAnimeProvider);
    ref.invalidate(animeCollectionProvider);
  }

  @override
  void didUpdateWidget(covariant DesktopEpisodesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentTab != widget.currentTab ||
        oldWidget.selectedProvider?.id != widget.selectedProvider?.id ||
        oldWidget.isDubbed != widget.isDubbed) {
      setState(() {
        _currentPage = 0;
      });
    }
    if (oldWidget.mediaId != widget.mediaId || oldWidget.isLocalMode != widget.isLocalMode) {
      _loadLocalEntry();
    }
  }

  String _formatEpisodeTitle(DesktopEpisodeItemData ep) {
    final t = ep.title.trim();
    if (t.toLowerCase() == 'episodio ${ep.number}' ||
        t.toLowerCase() == 'episode ${ep.number}' ||
        t.isEmpty) {
      return 'EP ${ep.number}';
    }
    final cleanT = t.replaceFirst(
        RegExp(r'^(episodio|episode)\s*\d+\s*[:.-]?\s*', caseSensitive: false),
        '');
    if (cleanT.isNotEmpty) {
      return 'EP ${ep.number}. $cleanT';
    }
    return 'EP ${ep.number}. $t';
  }

  Widget _buildLocalEmptyState(ThemeData theme, AppTranslations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.folder_off_outlined,
              size: 40,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.notInLocalLibrary,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              l10n.notInLocalLibraryDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: () {
                  widget.onToggleLocalMode();
                  widget.onTabChanged(AnimeDetailTab.online);
                },
                icon: const Icon(Icons.public, size: 16),
                label: Text(l10n.watchOnlineStream),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  widget.onToggleLocalMode();
                  widget.onTabChanged(AnimeDetailTab.torrent);
                },
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(l10n.searchTorrents),
              ),
              OutlinedButton.icon(
                onPressed: _scanAndRefreshLocal,
                icon: const Icon(Icons.sync_rounded, size: 16),
                label: Text(l10n.scanLocalFolder),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLanguage = ref.watch(appLanguageProvider);
    final iconPack = ref.watch(iconPackProvider);
    final l10n = ref.watch(translationsProvider);
    final downloadingEpisodes = ref.watch(downloadingEpisodesProvider);
    final langCode = currentLanguage.name;
    final theme = Theme.of(context);

    if (widget.isLocalMode) {
      if (_isLoadingLocal && _libraryEntry == null) {
        return Container(
          padding: const EdgeInsets.all(48),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                l10n.checkingLocalFiles,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      }

      final downloadedEps = _libraryEntry?.episodes.where((e) => e.isDownloaded).toList() ?? [];
      if (downloadedEps.isEmpty) {
        return _buildLocalEmptyState(theme, l10n);
      }
    }

    final aniZipData = widget.aniZipData ?? widget.details?.aniZipData;
    final aniZipMainEps = aniZipData?.mainEpisodes ??
        aniZipData?.episodes.where((e) => !e.isSpecial).toList() ??
        [];
    final fallbackEps = widget.details?.episodes ?? [];
    final maxTotal = widget.details?.totalEpisodes;
    final totalCount = maxTotal ??
        (aniZipMainEps.isNotEmpty
            ? aniZipMainEps.length
            : (fallbackEps.isNotEmpty ? fallbackEps.length : 12));

    bool isRealMainEpisode(String title, bool isSpecial, int episodeNum) {
      if (isSpecial) return false;
      if (episodeNum <= 0) return false;
      if (maxTotal != null && maxTotal > 0 && episodeNum > maxTotal) {
        return false;
      }
      final lower = title.toLowerCase();
      const forbiddenTerms = [
        'extra episode',
        'special episode',
        'opening',
        'ending',
        'creditless',
        'ncop',
        'nced',
        'preview',
        'teaser',
        'music video',
        'web teaser',
        'recap',
      ];
      for (final term in forbiddenTerms) {
        if (lower.contains(term)) return false;
      }
      return true;
    }

    final downloadedMap = {
      for (final ep in (_libraryEntry?.episodes ?? <LibraryEpisode>[]))
        if (ep.isDownloaded) ep.episodeNumber: ep.localFilePath,
    };

    bool hasEpisodeAired(int episodeNumber, String? airDate, String? image) {
      if (widget.progress >= episodeNumber || downloadedMap.containsKey(episodeNumber)) {
        return true;
      }
      if (airDate != null && airDate.isNotEmpty) {
        final dt = DateTime.tryParse(airDate);
        if (dt != null && dt.isAfter(DateTime.now().add(const Duration(hours: 4)))) {
          return false;
        }
      }
      final nextAiring = widget.details?.rawMedia?['nextAiringEpisode'];
      if (nextAiring is Map<String, dynamic>) {
        final nextEpNum = nextAiring['episode'] as int?;
        if (nextEpNum != null && episodeNumber >= nextEpNum) {
          return false;
        }
      }
      final status = widget.details?.status?.toUpperCase();
      if (status == 'NOT_YET_RELEASED') return false;
      if (status == 'RELEASING') {
        if ((airDate == null || airDate.isEmpty) && (image == null || image.isEmpty)) {
          return false;
        }
      }
      return true;
    }

    final List<DesktopEpisodeItemData> items = [];

    if (widget.isLocalMode) {
      // ─── Mode: Local Library (Downloaded episodes directly from disk) ───
      final downloadedEps = _libraryEntry?.episodes.where((e) => e.isDownloaded).toList() ?? [];
      for (final ep in downloadedEps) {
        final aniZipEp = aniZipData?.episodes
            .where((e) => e.episodeNumber == ep.episodeNumber)
            .firstOrNull;
        final thumb = (ep.thumbnail != null && ep.thumbnail!.isNotEmpty)
            ? ep.thumbnail
            : (aniZipEp?.image ?? widget.fallbackCoverImage);
        final synopsis = aniZipEp?.synopsis;
        final rawTitle = (ep.episodeTitle != null && ep.episodeTitle!.isNotEmpty)
            ? ep.episodeTitle!
            : ep.displayTitle;
        final isGeneric = rawTitle.isEmpty ||
            rawTitle.toLowerCase() == 'episode ${ep.episodeNumber}' ||
            rawTitle.toLowerCase() == 'episodio ${ep.episodeNumber}';
        final epTitle = !isGeneric
            ? rawTitle
            : (aniZipEp?.displayTitleForLang(langCode) ?? l10n.episodeNumber(ep.episodeNumber));

        items.add(DesktopEpisodeItemData(
          number: ep.episodeNumber,
          title: epTitle,
          synopsis: synopsis,
          image: thumb,
          aniDBEpisode: aniZipEp?.episode,
          isWatched: widget.progress >= ep.episodeNumber,
          isDownloaded: true,
          localFilePath: ep.localFilePath,
        ));
      }
    } else if (widget.currentTab == AnimeDetailTab.online) {
      // ─── Mode: Online Streaming (Consult the selected source) ───
      final Map<int, dynamic> aniZipByNumber = {
        for (final ep in aniZipMainEps) ep.episodeNumber: ep,
      };

      final Set<int> seenOnline = {};
      for (final ep in widget.onlineEpisodes) {
        if (!isRealMainEpisode(ep.displayTitle, false, ep.number)) continue;
        if (!seenOnline.add(ep.number)) continue;

        final aniZipEp = aniZipByNumber[ep.number];
        final thumb = (ep.image != null && ep.image!.isNotEmpty)
            ? ep.image
            : aniZipEp?.image;
        final synopsis = (ep.description != null && ep.description!.isNotEmpty)
            ? ep.description
            : aniZipEp?.synopsis;
        final rawTitle = ep.displayTitle;
        final isGenericOnlineTitle = rawTitle.isEmpty ||
            rawTitle.toLowerCase() == 'episode ${ep.number}' ||
            rawTitle.toLowerCase() == 'episodio ${ep.number}';
        final epTitle = !isGenericOnlineTitle
            ? rawTitle
            : (aniZipEp?.displayTitleForLang(langCode) ??
                l10n.episodeNumber(ep.number));

        final isDownloading =
            downloadingEpisodes.contains('${widget.mediaId}_${ep.number}');
        final downloadProgress =
            downloadingEpisodes.getProgress(widget.mediaId, ep.number);

        items.add(DesktopEpisodeItemData(
          number: ep.number,
          title: epTitle,
          synopsis: synopsis,
          image: thumb,
          aniDBEpisode: aniZipEp?.episode,
          isWatched: widget.progress >= ep.number,
          isDownloaded: downloadedMap.containsKey(ep.number),
          isDownloading: isDownloading,
          downloadProgress: downloadProgress,
          localFilePath: downloadedMap[ep.number],
        ));
      }
    } else {
      // ─── Mode: Torrent / Default (100% Real AniList / AniZip canon episode list) ───
      final Set<int> seenTorrent = {};
      if (aniZipMainEps.isNotEmpty) {
        for (final ep in aniZipMainEps) {
          if (!isRealMainEpisode(ep.displayTitle, ep.isSpecial, ep.episodeNumber)) {
            continue;
          }
          if (!hasEpisodeAired(ep.episodeNumber, ep.airDate, ep.image)) {
            continue;
          }
          if (seenTorrent.add(ep.episodeNumber)) {
            final isDownloading =
                downloadingEpisodes.contains('${widget.mediaId}_${ep.episodeNumber}');
            final downloadProgress =
                downloadingEpisodes.getProgress(widget.mediaId, ep.episodeNumber);

            items.add(DesktopEpisodeItemData(
              number: ep.episodeNumber,
              title: ep.displayTitleForLang(langCode),
              synopsis: ep.synopsis,
              image: ep.image,
              aniDBEpisode: ep.episode,
              isWatched: widget.progress >= ep.episodeNumber,
              isDownloaded: downloadedMap.containsKey(ep.episodeNumber),
              isDownloading: isDownloading,
              downloadProgress: downloadProgress,
              localFilePath: downloadedMap[ep.episodeNumber],
            ));
          }
        }
      } else if (fallbackEps.isNotEmpty) {
        for (final ep in fallbackEps) {
          if (!isRealMainEpisode(ep.title, false, ep.episodeNumber)) {
            continue;
          }
          if (!hasEpisodeAired(ep.episodeNumber, null, ep.image)) {
            continue;
          }
          if (seenTorrent.add(ep.episodeNumber)) {
            final isDownloading =
                downloadingEpisodes.contains('${widget.mediaId}_${ep.episodeNumber}');
            final downloadProgress =
                downloadingEpisodes.getProgress(widget.mediaId, ep.episodeNumber);

            items.add(DesktopEpisodeItemData(
              number: ep.episodeNumber,
              title: ep.title,
              synopsis: ep.description,
              image: ep.image,
              isWatched: widget.progress >= ep.episodeNumber,
              isDownloaded: downloadedMap.containsKey(ep.episodeNumber),
              isDownloading: isDownloading,
              downloadProgress: downloadProgress,
              localFilePath: downloadedMap[ep.episodeNumber],
            ));
          }
        }
      }

      // Only generate numbered placeholders when AniZip has definitively finished
      // loading with no data — never during the initial load (prevents flash).
      if (items.isEmpty && !widget.isLoadingAniZip) {
        for (int i = 1; i <= totalCount; i++) {
          if (!hasEpisodeAired(i, null, null)) continue;
          final isDownloading =
              downloadingEpisodes.contains('${widget.mediaId}_$i');
          final downloadProgress =
              downloadingEpisodes.getProgress(widget.mediaId, i);

          items.add(DesktopEpisodeItemData(
            number: i,
            title: l10n.episodeNumber(i),
            isWatched: widget.progress >= i,
            isDownloaded: downloadedMap.containsKey(i),
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            localFilePath: downloadedMap[i],
          ));
        }
      }
    }

    if (!_isSortAscending) {
      items.sort((a, b) => b.number.compareTo(a.number));
    } else {
      items.sort((a, b) => a.number.compareTo(b.number));
    }

    final totalEpisodes = items.length;
    final totalPages = (totalEpisodes / _episodesPerPage).ceil();
    if (_currentPage >= totalPages && totalPages > 0) {
      _currentPage = totalPages - 1;
    }
    if (_currentPage < 0) {
      _currentPage = 0;
    }

    final startIndex = _currentPage * _episodesPerPage;
    final endIndex = (startIndex + _episodesPerPage).clamp(0, totalEpisodes);
    final pagedItems = totalEpisodes == 0
        ? <DesktopEpisodeItemData>[]
        : items.sublist(startIndex, endIndex);

    final headerCountText = totalPages > 1
        ? '${items.length} ${l10n.episodes} • ${l10n.page} ${_currentPage + 1}/$totalPages'
        : '${items.length} ${l10n.episodes}';

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: [Episodes Count] on left, Provider & Toggles on right ───
        Row(
          children: [
            Text(
              headerCountText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                letterSpacing: -0.2,
              ),
            ),

            const Spacer(),

            // If Local mode, show local count pill and scan button
            if (widget.isLocalMode) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      '${items.length} ${l10n.localEpisodes}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                ),
                tooltip: l10n.scanLocalFolder,
                icon: const Icon(Icons.sync_rounded, size: 18),
                onPressed: _scanAndRefreshLocal,
              ),
            ] else if (widget.currentTab == AnimeDetailTab.online && widget.providers.isNotEmpty) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<OnlinestreamProvider>(
                    value: widget.selectedProvider,
                    dropdownColor: isDark ? const Color(0xFF1E2228) : theme.colorScheme.surfaceContainerHigh,
                    icon: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Icon(AppIcons.chevronDown(iconPack), size: 15, color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant),
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                    items: widget.providers
                        .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                        .toList(),
                    onChanged: widget.onProviderChanged,
                  ),
                ),
              ),
              if (widget.selectedProvider?.supportsDub ?? false) ...[
                const SizedBox(width: 4),
                IconButton(
                  style: IconButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
                  ),
                  icon: Icon(
                    widget.isDubbed ? AppIcons.voice(iconPack) : AppIcons.subtitles(iconPack),
                    size: 18,
                    color: widget.isDubbed
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : (isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant),
                  ),
                  tooltip: widget.isDubbed ? l10n.audioDubbed : l10n.audioSubtitled,
                  onPressed: widget.onToggleDubbed,
                ),
              ],
              const SizedBox(width: 6),
            ],

            // Toggle Grid / List View
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
              ),
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView
                  ? l10n.switchToList
                  : l10n.switchToGrid,
              icon: Icon(
                _isGridView ? AppIcons.list(iconPack) : AppIcons.grid(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),

            // Toggle Sort Ascending / Descending
            IconButton(
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(6),
                hoverColor: isDark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.surfaceContainerHighest,
              ),
              onPressed: () => setState(() {
                _isSortAscending = !_isSortAscending;
                _currentPage = 0;
              }),
              tooltip: _isSortAscending
                  ? l10n.orderAsc
                  : l10n.orderDesc,
              icon: Icon(
                AppIcons.swapVert(iconPack),
                size: 18,
                color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Loading State for Online Mode ───
        if (widget.currentTab == AnimeDetailTab.online && widget.isLoadingOnlineEpisodes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.loadingEpisodesFrom(widget.selectedProvider?.name ?? l10n.source),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        // ─── Loading State for AniZip (Torrent/Default Mode) ───
        else if (widget.currentTab != AnimeDetailTab.online && widget.isLoadingAniZip && items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (int i = 0; i < 4; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Container(
                          width: 220,
                          height: 124,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 14,
                                width: 180,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : theme.colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                height: 11,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: 11,
                                width: 140,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          )
        // ─── Empty State for Online Mode ───
        else if (widget.currentTab == AnimeDetailTab.online && items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_collection_outlined,
                    size: 40,
                    color: isDark ? Colors.white.withValues(alpha: 0.3) : theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.noEpisodesFoundInProvider(widget.selectedProvider?.name ?? l10n.source),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.tryAnotherServerOrSubDub,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white.withValues(alpha: 0.45) : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        // ─── Mode 1: Grid Mode (Bigger cards, clean thumbnails, max 20 per page) ───
        else if (_isGridView)
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = (constraints.maxWidth / 210).floor().clamp(2, 5);
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagedItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.25,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                ),
                itemBuilder: (context, index) {
                  final ep = pagedItems[index];
                  return DesktopGridEpisodeCard(
                    ep: ep,
                    isLoading: widget.loadingEpisodeNumber == ep.number,
                    formattedTitle: _formatEpisodeTitle(ep),
                    fallbackCoverImage: widget.fallbackCoverImage,
                    onTap: () => widget.onEpisodeClicked(ep),
                  );
                },
              );
            },
          )
        // ─── Mode 2: 2-Column List Mode (Unboxed, Bigger Cards, Clean Image + Text, max 20 per page) ───
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isDual = constraints.maxWidth > 860;
              final crossAxisCount = isDual ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: pagedItems.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisExtent: 136,
                  crossAxisSpacing: 24,
                  mainAxisSpacing: 16,
                ),
                itemBuilder: (context, index) {
                  final ep = pagedItems[index];
                  return DesktopListEpisodeCard(
                    ep: ep,
                    isLoading: widget.loadingEpisodeNumber == ep.number,
                    formattedTitle: _formatEpisodeTitle(ep),
                    fallbackCoverImage: widget.fallbackCoverImage,
                    onTap: () => widget.onEpisodeClicked(ep),
                  );
                },
              );
            },
          ),

        // ─── Pagination Controls (Next / Prev / Page Buttons) ───
        if (totalPages > 1)
          DesktopEpisodePagination(
            currentPage: _currentPage,
            totalPages: totalPages,
            startIndex: startIndex,
            endIndex: endIndex,
            onPageChanged: (newPage) => setState(() => _currentPage = newPage),
          ),
      ],
    );
  }
}
