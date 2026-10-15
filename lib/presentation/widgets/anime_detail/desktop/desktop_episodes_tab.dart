import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

import 'package:g1455/g1455.dart';
import 'desktop_episode_context_menu.dart';
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
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
  })? onOpenTorrentSelector;

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
    this.onOpenTorrentSelector,
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

  // ─── Memoized episode items caches ───
  List<DesktopEpisodeItemData>? _cachedLocalItems;
  dynamic _lastLocalLibraryEntry;
  int? _lastLocalProgress;
  String? _lastLocalLang;

  List<DesktopEpisodeItemData>? _cachedOnlineItems;
  List<OnlinestreamEpisode>? _lastOnlineEpisodes;
  int? _lastOnlineProgress;
  String? _lastOnlineLang;
  DownloadingEpisodesState? _lastOnlineDownloads;
  AniZipData? _lastOnlineAniZip;

  List<DesktopEpisodeItemData>? _cachedTorrentItems;
  AniZipData? _lastTorrentAniZip;
  AnimeDetails? _lastTorrentDetails;
  int? _lastTorrentProgress;
  String? _lastTorrentLang;
  DownloadingEpisodesState? _lastTorrentDownloads;
  bool? _lastTorrentLoadingAniZip;

  @override
  void initState() {
    super.initState();
    _loadLocalEntry();
  }

  void _clearMemoizedCaches() {
    _cachedLocalItems = null;
    _cachedOnlineItems = null;
    _cachedTorrentItems = null;
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
          _cachedLocalItems = null;
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
      if (_currentPage != 0) {
        setState(() {
          _currentPage = 0;
        });
      }
    }
    if (oldWidget.mediaId != widget.mediaId) {
      _clearMemoizedCaches();
      _loadLocalEntry();
    } else if (oldWidget.isLocalMode != widget.isLocalMode) {
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

  static const _forbiddenTerms = [
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

  bool _isRealMainEpisode(String title, bool isSpecial, int episodeNum, int? maxTotal) {
    if (isSpecial) return false;
    if (episodeNum <= 0) return false;
    if (maxTotal != null && maxTotal > 0 && episodeNum > maxTotal) {
      return false;
    }
    final lower = title.toLowerCase();
    for (final term in _forbiddenTerms) {
      if (lower.contains(term)) return false;
    }
    return true;
  }

  bool _hasEpisodeAired(
    int episodeNumber,
    String? airDate,
    String? image,
    Map<int, String?> downloadedMap,
    DateTime nowThreshold,
  ) {
    if (widget.progress >= episodeNumber || downloadedMap.containsKey(episodeNumber)) {
      return true;
    }
    if (airDate != null && airDate.isNotEmpty) {
      final dt = DateTime.tryParse(airDate);
      if (dt != null && dt.isAfter(nowThreshold)) {
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

  List<DesktopEpisodeItemData> _getEpisodes(
    AppTranslations l10n,
    String langCode,
    DownloadingEpisodesState downloadingEpisodes,
  ) {
    final Map<int, String?> downloadedMap = {
      for (final ep in (_libraryEntry?.episodes ?? <LibraryEpisode>[]))
        if (ep.isDownloaded) ep.episodeNumber: ep.localFilePath,
    };

    final aniZipData = widget.aniZipData ?? widget.details?.aniZipData;
    final aniZipMainEps = aniZipData?.mainEpisodes ??
        aniZipData?.episodes.where((e) => !e.isSpecial).toList() ??
        [];

    if (widget.isLocalMode) {
      if (_cachedLocalItems != null &&
          _lastLocalLibraryEntry == _libraryEntry &&
          _lastLocalProgress == widget.progress &&
          _lastLocalLang == langCode) {
        return _cachedLocalItems!;
      }

      final downloadedEps = _libraryEntry?.episodes.where((e) => e.isDownloaded).toList() ?? [];
      final List<DesktopEpisodeItemData> result = [];
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

        result.add(DesktopEpisodeItemData(
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
      _cachedLocalItems = result;
      _lastLocalLibraryEntry = _libraryEntry;
      _lastLocalProgress = widget.progress;
      _lastLocalLang = langCode;
      return result;
    }

    if (widget.currentTab == AnimeDetailTab.online) {
      if (_cachedOnlineItems != null &&
          _lastOnlineEpisodes == widget.onlineEpisodes &&
          _lastOnlineProgress == widget.progress &&
          _lastOnlineLang == langCode &&
          _lastOnlineDownloads == downloadingEpisodes &&
          _lastOnlineAniZip == aniZipData) {
        return _cachedOnlineItems!;
      }

      final Map<int, dynamic> aniZipByNumber = {
        for (final ep in aniZipMainEps) ep.episodeNumber: ep,
      };

      final Set<int> seenOnline = {};
      final List<DesktopEpisodeItemData> result = [];
      final maxTotal = widget.details?.totalEpisodes;

      for (final ep in widget.onlineEpisodes) {
        if (!_isRealMainEpisode(ep.displayTitle, false, ep.number, maxTotal)) continue;
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

        result.add(DesktopEpisodeItemData(
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
      _cachedOnlineItems = result;
      _lastOnlineEpisodes = widget.onlineEpisodes;
      _lastOnlineProgress = widget.progress;
      _lastOnlineLang = langCode;
      _lastOnlineDownloads = downloadingEpisodes;
      _lastOnlineAniZip = aniZipData;
      return result;
    }

    // Tab is Torrent / Default
    if (_cachedTorrentItems != null &&
        _lastTorrentAniZip == aniZipData &&
        _lastTorrentDetails == widget.details &&
        _lastTorrentProgress == widget.progress &&
        _lastTorrentLang == langCode &&
        _lastTorrentDownloads == downloadingEpisodes &&
        _lastTorrentLoadingAniZip == widget.isLoadingAniZip) {
      return _cachedTorrentItems!;
    }

    final fallbackEps = widget.details?.episodes ?? [];
    final maxTotal = widget.details?.totalEpisodes;
    final totalCount = maxTotal ??
        (aniZipMainEps.isNotEmpty
            ? aniZipMainEps.length
            : (fallbackEps.isNotEmpty ? fallbackEps.length : 12));

    final nowThreshold = DateTime.now().add(const Duration(hours: 4));
    final Set<int> seenTorrent = {};
    final List<DesktopEpisodeItemData> result = [];

    if (aniZipMainEps.isNotEmpty) {
      for (final ep in aniZipMainEps) {
        if (!_isRealMainEpisode(ep.displayTitle, ep.isSpecial, ep.episodeNumber, maxTotal)) {
          continue;
        }
        if (!_hasEpisodeAired(ep.episodeNumber, ep.airDate, ep.image, downloadedMap, nowThreshold)) {
          continue;
        }
        if (seenTorrent.add(ep.episodeNumber)) {
          final isDownloading =
              downloadingEpisodes.contains('${widget.mediaId}_${ep.episodeNumber}');
          final downloadProgress =
              downloadingEpisodes.getProgress(widget.mediaId, ep.episodeNumber);

          result.add(DesktopEpisodeItemData(
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
        if (!_isRealMainEpisode(ep.title, false, ep.episodeNumber, maxTotal)) {
          continue;
        }
        if (!_hasEpisodeAired(ep.episodeNumber, null, ep.image, downloadedMap, nowThreshold)) {
          continue;
        }
        if (seenTorrent.add(ep.episodeNumber)) {
          final isDownloading =
              downloadingEpisodes.contains('${widget.mediaId}_${ep.episodeNumber}');
          final downloadProgress =
              downloadingEpisodes.getProgress(widget.mediaId, ep.episodeNumber);

          result.add(DesktopEpisodeItemData(
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

    if (result.isEmpty && !widget.isLoadingAniZip) {
      for (int i = 1; i <= totalCount; i++) {
        if (!_hasEpisodeAired(i, null, null, downloadedMap, nowThreshold)) continue;
        final isDownloading =
            downloadingEpisodes.contains('${widget.mediaId}_$i');
        final downloadProgress =
            downloadingEpisodes.getProgress(widget.mediaId, i);

        result.add(DesktopEpisodeItemData(
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

    _cachedTorrentItems = result;
    _lastTorrentAniZip = aniZipData;
    _lastTorrentDetails = widget.details;
    _lastTorrentProgress = widget.progress;
    _lastTorrentLang = langCode;
    _lastTorrentDownloads = downloadingEpisodes;
    _lastTorrentLoadingAniZip = widget.isLoadingAniZip;
    return result;
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
              M3EButton.icon(
                style: M3EButtonStyle.filled,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
                onPressed: () {
                  widget.onToggleLocalMode();
                  widget.onTabChanged(AnimeDetailTab.online);
                },
                icon: const Icon(Icons.public, size: 16),
                label: Text(l10n.watchOnlineStream),
              ),
              M3EButton.icon(
                style: M3EButtonStyle.outlined,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
                onPressed: () {
                  widget.onToggleLocalMode();
                  widget.onTabChanged(AnimeDetailTab.torrent);
                },
                icon: const Icon(Icons.cloud_download_rounded, size: 16),
                label: Text(l10n.searchTorrents),
              ),
              M3EButton.icon(
                style: M3EButtonStyle.outlined,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
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

    final rawItems = _getEpisodes(l10n, langCode, downloadingEpisodes);
    final List<DesktopEpisodeItemData> items = List.of(rawItems);

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

    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: Episodes Title & Controls ───
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              l10n.episodes,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            if (totalPages > 1) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '${l10n.page} ${_currentPage + 1}/$totalPages',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            const Spacer(),

            // If Local mode, show local count pill and scan button
            if (widget.isLocalMode) ...[
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
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
              M3EIconButton(
                variant: M3EIconButtonVariant.tonal,
                size: M3EIconButtonSize.xs,
                tooltip: l10n.scanLocalFolder,
                icon: const Icon(Icons.sync_rounded, size: 17),
                onPressed: _scanAndRefreshLocal,
              ),
            ] else if (widget.currentTab == AnimeDetailTab.online && widget.providers.isNotEmpty) ...[
              GlassMenuAnchor(
                width: 220,
                items: widget.providers.map((p) {
                  final isCurrent = widget.selectedProvider?.id == p.id;
                  return GlassMenuItem(
                    label: p.name,
                    icon: Icon(
                      isCurrent ? Icons.check_circle_rounded : Icons.public_rounded,
                      size: 18,
                      color: isCurrent ? theme.colorScheme.primary : null,
                    ),
                    onPressed: () {
                      widget.onProviderChanged(p);
                    },
                  );
                }).toList(),
                builder: (context, controller) {
                  return GlassButton(
                    onPressed: controller.open,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.public_rounded,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          widget.selectedProvider?.name ?? l10n.source,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 17,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (widget.selectedProvider?.supportsDub ?? false) ...[
                const SizedBox(width: 6),
                M3EIconButton(
                  variant: M3EIconButtonVariant.tonal,
                  size: M3EIconButtonSize.xs,
                  icon: Icon(
                    widget.isDubbed ? AppIcons.voice(iconPack) : AppIcons.subtitles(iconPack),
                    size: 16,
                    color: widget.isDubbed
                        ? (isDark ? Colors.white : theme.colorScheme.primary)
                        : (isDark ? Colors.white70 : Colors.black87),
                  ),
                  tooltip: widget.isDubbed ? l10n.audioDubbed : l10n.audioSubtitled,
                  onPressed: widget.onToggleDubbed,
                ),
              ],
              const SizedBox(width: 6),
            ],

            // Toggle Grid / List View (Material 3 Expressive)
            M3EIconButton(
              variant: M3EIconButtonVariant.tonal,
              size: M3EIconButtonSize.xs,
              onPressed: () => setState(() => _isGridView = !_isGridView),
              tooltip: _isGridView
                  ? l10n.switchToList
                  : l10n.switchToGrid,
              icon: Icon(
                _isGridView ? AppIcons.list(iconPack) : AppIcons.grid(iconPack),
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),

            // Toggle Sort Ascending / Descending (Material 3 Expressive)
            M3EIconButton(
              variant: M3EIconButtonVariant.tonal,
              size: M3EIconButtonSize.xs,
              onPressed: () => setState(() {
                _isSortAscending = !_isSortAscending;
                _currentPage = 0;
              }),
              tooltip: _isSortAscending
                  ? l10n.orderAsc
                  : l10n.orderDesc,
              icon: Icon(
                AppIcons.swapVert(iconPack),
                size: 16,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // ─── Dynamic Episode Content (Animated Transition between View Modes & Sources) ───
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: RepaintBoundary(
            key: ValueKey('episodes_view_${_isGridView ? "grid" : "list"}_${widget.isLocalMode}'),
            child: Builder(
              builder: (context) {
                // ─── Loading State for Online Mode ───
                if (widget.currentTab == AnimeDetailTab.online && widget.isLoadingOnlineEpisodes) {
                  return Padding(
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
                  );
                }

                // ─── Loading State for AniZip (Torrent/Default Mode) ───
                if (widget.currentTab != AnimeDetailTab.online && widget.isLoadingAniZip && items.isEmpty) {
                  return Padding(
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
                  );
                }

                // ─── Empty State for Online Mode ───
                if (widget.currentTab == AnimeDetailTab.online && items.isEmpty) {
                  return Padding(
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
                  );
                }

                // ─── Mode 1: Grid Mode (Bigger cards, clean thumbnails) ───
                if (_isGridView) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = (constraints.maxWidth / 320).floor().clamp(2, 5);
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: pagedItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1.28,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 22,
                        ),
                        itemBuilder: (context, index) {
                          final ep = pagedItems[index];
                          return DesktopGridEpisodeCard(
                            key: ValueKey('grid_ep_${ep.number}'),
                            mediaId: widget.mediaId,
                            ep: ep,
                            isLoading: widget.loadingEpisodeNumber == ep.number,
                            formattedTitle: _formatEpisodeTitle(ep),
                            fallbackCoverImage: widget.fallbackCoverImage,
                            onTap: () => widget.onEpisodeClicked(ep),
                            trailingActions: DesktopEpisodeMenuButton(
                              ep: ep,
                              mediaId: widget.mediaId,
                              details: widget.details,
                              onEpisodeClicked: widget.onEpisodeClicked,
                              onOpenTorrentSelector: widget.onOpenTorrentSelector,
                              onRefreshLocal: _scanAndRefreshLocal,
                            ),
                          );
                        },
                      );
                    },
                  );
                }

                // ─── Mode 2: 2-Column List Mode (Unboxed, Clean Image + Text) ───
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 1200;
                    final crossAxisCount = isWide ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pagedItems.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        mainAxisExtent: 154,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 18,
                      ),
                      itemBuilder: (context, index) {
                        final ep = pagedItems[index];
                        return DesktopListEpisodeCard(
                          key: ValueKey('list_ep_${ep.number}'),
                          mediaId: widget.mediaId,
                          ep: ep,
                          isLoading: widget.loadingEpisodeNumber == ep.number,
                          formattedTitle: _formatEpisodeTitle(ep),
                          fallbackCoverImage: widget.fallbackCoverImage,
                          onTap: () => widget.onEpisodeClicked(ep),
                          trailingActions: DesktopEpisodeMenuButton(
                            ep: ep,
                            mediaId: widget.mediaId,
                            details: widget.details,
                            onEpisodeClicked: widget.onEpisodeClicked,
                            onOpenTorrentSelector: widget.onOpenTorrentSelector,
                            onRefreshLocal: _scanAndRefreshLocal,
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
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
