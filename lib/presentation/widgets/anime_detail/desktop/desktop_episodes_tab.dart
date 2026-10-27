import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/playback_progress_preferences_provider.dart';
import 'package:seanime_app/core/theme/smooth_scroll_controller.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/data/models/library_entry_details.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/download_history_provider.dart';
import 'package:seanime_app/presentation/screens/anime_detail_screen.dart';

import 'package:seanime_app/presentation/widgets/online_stream_download_dialog.dart';

import 'desktop_episode_context_menu.dart';
import 'desktop_episode_grid_card.dart';
import 'desktop_episode_models.dart';

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
  final VoidCallback? onMoveUpToPlay;
  final Future<void> Function({
    required int episodeNumber,
    required String episodeTitle,
    String? aniDBEpisode,
    bool isDownloadMode,
    List<int>? initialSelectedEpisodes,
  })?
  onOpenTorrentSelector;

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
    this.onMoveUpToPlay,
    this.onOpenTorrentSelector,
  });

  @override
  ConsumerState<DesktopEpisodesTab> createState() => _DesktopEpisodesTabState();
}

class _DesktopEpisodesTabState extends ConsumerState<DesktopEpisodesTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final ScrollController _horizontalScrollController =
      SmoothScrollController(smoothingFactor: 16.0, speedMultiplier: 1.0);
  bool _hasAutoScrolled = false;

  LibraryEntryDetails? _libraryEntry;
  bool _isLoadingLocal = false;
  // ─── Memoized episode items caches ───

  List<DesktopEpisodeItemData>? _cachedAniZipItems;
  AniZipData? _lastAniZip;
  AnimeDetails? _lastDetails;
  int? _lastProgress;
  String? _lastLang;
  DownloadingEpisodesState? _lastDownloads;
  bool? _lastLoadingAniZip;
  List<DownloadHistoryItem>? _lastHistoryItems;
  LibraryEntryDetails? _lastLibraryEntry;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    final cached =
        repo.getCachedAnimeLibraryEntry(widget.mediaId) ??
        ref.read(animeLibraryEntryProvider(widget.mediaId)).asData?.value;
    if (cached != null) {
      _libraryEntry = cached;
      _isLoadingLocal = false;
    }
    _loadLocalEntry(silent: cached != null);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _horizontalScrollController.dispose();
    super.dispose();
  }

  void _clearMemoizedCaches() {
    _cachedAniZipItems = null;
  }

  Future<void> _loadLocalEntry({bool silent = false}) async {
    if (!mounted) return;
    if (!silent) {
      setState(() => _isLoadingLocal = true);
    }
    try {
      final repo = ref.read(repositoryProvider);
      final entry = await repo.getAnimeLibraryEntry(widget.mediaId);
      if (mounted) {
        setState(() {
          _libraryEntry = entry;
          _isLoadingLocal = false;
          _cachedAniZipItems = null;
        });
      }
    } catch (_) {
      if (mounted && !silent) setState(() => _isLoadingLocal = false);
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
        oldWidget.isLocalMode != widget.isLocalMode ||
        oldWidget.selectedProvider?.id != widget.selectedProvider?.id ||
        oldWidget.isDubbed != widget.isDubbed) {
      // The desktop layout keeps every episode visible in one scroll view, so
      // there is no page cursor to reset here.
    }
    if (oldWidget.mediaId != widget.mediaId) {
      _hasAutoScrolled = false;
      _clearMemoizedCaches();
      _loadLocalEntry();
    } else if (oldWidget.isLocalMode != widget.isLocalMode) {
      _loadLocalEntry();
    }
  }

  int _calculateTargetEpisodeNumber(
    List<DesktopEpisodeItemData> items,
    EpisodePlaybackProgress? mediaProgress,
  ) {
    if (items.isEmpty) return 1;

    final totalCount = widget.details?.totalEpisodes ?? items.length;
    final isCompleted =
        (widget.details?.userStatus == 'COMPLETED') ||
        (widget.progress >= totalCount && totalCount > 0);

    if (isCompleted) return 1;

    int targetEpisodeNumber = 1;

    // 1. Check if the most recently played episode has in-progress playback (< 95%)
    if (mediaProgress != null &&
        mediaProgress.durationMs > 0 &&
        mediaProgress.positionMs > 0) {
      final fraction = mediaProgress.positionMs / mediaProgress.durationMs;
      if (fraction > 0.02 && fraction < 0.95) {
        targetEpisodeNumber = mediaProgress.episodeNumber;
      } else if (fraction >= 0.95) {
        targetEpisodeNumber = mediaProgress.episodeNumber + 1;
      }
    }

    // 2. If no in-progress episode was found, resume from watch progress + 1
    if (targetEpisodeNumber == 1 && widget.progress > 0) {
      targetEpisodeNumber = widget.progress + 1;
    }

    // 3. Fallback if target exceeds total count
    if (targetEpisodeNumber > totalCount) {
      targetEpisodeNumber = 1;
    }

    return targetEpisodeNumber;
  }

  void _scrollToResumeEpisode(
    List<DesktopEpisodeItemData> items,
    int targetEpisodeNumber,
  ) {
    if (_hasAutoScrolled || items.isEmpty) return;
    final targetIndex = items.indexWhere(
      (ep) => ep.number == targetEpisodeNumber,
    );
    _hasAutoScrolled = true;
    if (targetIndex <= 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalScrollController.hasClients) return;
      const step = 443.0;
      final offset = (targetIndex * step).clamp(
        0.0,
        _horizontalScrollController.position.maxScrollExtent,
      );
      _horizontalScrollController.jumpTo(offset);
    });
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
      '',
    );
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

  bool _isRealMainEpisode(
    String title,
    bool isSpecial,
    int episodeNum,
    int? maxTotal,
  ) {
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
    if (widget.progress >= episodeNumber ||
        downloadedMap.containsKey(episodeNumber)) {
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
      if ((airDate == null || airDate.isEmpty) &&
          (image == null || image.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  List<DesktopEpisodeItemData> _getEpisodes(
    AppTranslations l10n,
    String langCode,
    DownloadingEpisodesState downloadingEpisodes,
    List<DownloadHistoryItem> historyItems,
  ) {
    final aniZipData = widget.aniZipData ?? widget.details?.aniZipData;

    // Fast-path: return cached list instantly if no relevant dependency changed
    if (_cachedAniZipItems != null &&
        _lastAniZip == aniZipData &&
        _lastDetails == widget.details &&
        _lastProgress == widget.progress &&
        _lastLang == langCode &&
        _lastDownloads == downloadingEpisodes &&
        _lastLoadingAniZip == widget.isLoadingAniZip &&
        _lastLibraryEntry == _libraryEntry &&
        _lastHistoryItems == historyItems) {
      return _cachedAniZipItems!;
    }

    final Map<int, String?> downloadedMap = {
      for (final ep in (_libraryEntry?.episodes ?? <LibraryEpisode>[]))
        if (ep.isDownloaded) ep.episodeNumber: ep.localFilePath,
    };
    for (final item in historyItems) {
      if (item.filePath != null && item.filePath!.isNotEmpty) {
        int? epNum;
        if (item.id.startsWith('${widget.mediaId}_')) {
          epNum = int.tryParse(item.id.substring('${widget.mediaId}_'.length));
        }
        if (epNum != null) {
          downloadedMap[epNum] = item.filePath!;
        }
      }
    }

    final aniZipMainEps =
        aniZipData?.mainEpisodes ??
        aniZipData?.episodes.where((e) => !e.isSpecial).toList() ??
        [];

    final fallbackEps = widget.details?.episodes ?? [];
    final maxTotal = widget.details?.totalEpisodes;
    final totalCount =
        maxTotal ??
        (aniZipMainEps.isNotEmpty
            ? aniZipMainEps.length
            : (fallbackEps.isNotEmpty ? fallbackEps.length : 12));

    final nowThreshold = DateTime.now().add(const Duration(hours: 4));
    final Set<int> seenEpisodes = {};
    final List<DesktopEpisodeItemData> result = [];

    if (aniZipMainEps.isNotEmpty) {
      for (final ep in aniZipMainEps) {
        if (!_isRealMainEpisode(
          ep.displayTitle,
          ep.isSpecial,
          ep.episodeNumber,
          maxTotal,
        )) {
          continue;
        }
        if (!_hasEpisodeAired(
          ep.episodeNumber,
          ep.airDate,
          ep.image,
          downloadedMap,
          nowThreshold,
        )) {
          continue;
        }
        if (seenEpisodes.add(ep.episodeNumber)) {
          final isDownloading = downloadingEpisodes.contains(
            '${widget.mediaId}_${ep.episodeNumber}',
          );
          final downloadProgress = downloadingEpisodes.getProgress(
            widget.mediaId,
            ep.episodeNumber,
          );

          result.add(
            DesktopEpisodeItemData(
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
            ),
          );
        }
      }
    } else if (fallbackEps.isNotEmpty) {
      for (final ep in fallbackEps) {
        if (!_isRealMainEpisode(ep.title, false, ep.episodeNumber, maxTotal)) {
          continue;
        }
        if (!_hasEpisodeAired(
          ep.episodeNumber,
          null,
          ep.image,
          downloadedMap,
          nowThreshold,
        )) {
          continue;
        }
        if (seenEpisodes.add(ep.episodeNumber)) {
          final isDownloading = downloadingEpisodes.contains(
            '${widget.mediaId}_${ep.episodeNumber}',
          );
          final downloadProgress = downloadingEpisodes.getProgress(
            widget.mediaId,
            ep.episodeNumber,
          );

          result.add(
            DesktopEpisodeItemData(
              number: ep.episodeNumber,
              title: ep.title,
              synopsis: ep.description,
              image: ep.image,
              isWatched: widget.progress >= ep.episodeNumber,
              isDownloaded: downloadedMap.containsKey(ep.episodeNumber),
              isDownloading: isDownloading,
              downloadProgress: downloadProgress,
              localFilePath: downloadedMap[ep.episodeNumber],
            ),
          );
        }
      }
    }

    if (result.isEmpty && !widget.isLoadingAniZip) {
      for (int i = 1; i <= totalCount; i++) {
        if (!_hasEpisodeAired(i, null, null, downloadedMap, nowThreshold)) {
          continue;
        }
        final isDownloading = downloadingEpisodes.contains(
          '${widget.mediaId}_$i',
        );
        final downloadProgress = downloadingEpisodes.getProgress(
          widget.mediaId,
          i,
        );

        result.add(
          DesktopEpisodeItemData(
            number: i,
            title: l10n.episodeNumber(i),
            isWatched: widget.progress >= i,
            isDownloaded: downloadedMap.containsKey(i),
            isDownloading: isDownloading,
            downloadProgress: downloadProgress,
            localFilePath: downloadedMap[i],
          ),
        );
      }
    }

    // Ensure any downloaded episode not in AniZip/fallback is included
    for (final entry in downloadedMap.entries) {
      if (seenEpisodes.add(entry.key)) {
        result.add(
          DesktopEpisodeItemData(
            number: entry.key,
            title: l10n.episodeNumber(entry.key),
            isWatched: widget.progress >= entry.key,
            isDownloaded: true,
            localFilePath: entry.value,
          ),
        );
      }
    }
    result.sort((a, b) => a.number.compareTo(b.number));

    _cachedAniZipItems = result;
    _lastAniZip = aniZipData;
    _lastDetails = widget.details;
    _lastProgress = widget.progress;
    _lastLang = langCode;
    _lastDownloads = downloadingEpisodes;
    _lastLoadingAniZip = widget.isLoadingAniZip;
    _lastLibraryEntry = _libraryEntry;
    _lastHistoryItems = historyItems;
    return result;
  }

  Widget _buildLocalEmptyState(
    ThemeData theme,
    AppTranslations l10n,
    AppIconPack iconPack,
  ) {
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
            child: Icon(
              AppIcons.folderOff(iconPack),
              size: 40,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.notInLocalLibrary,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
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
                icon: Icon(AppIcons.globe(iconPack), size: 16),
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
                icon: Icon(AppIcons.cloudDownload(iconPack), size: 16),
                label: Text(l10n.searchTorrents),
              ),
              M3EButton.icon(
                style: M3EButtonStyle.outlined,
                size: M3EButtonSize.sm,
                shape: M3EButtonShape.round,
                onPressed: _scanAndRefreshLocal,
                icon: Icon(AppIcons.refresh(iconPack), size: 16),
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
    final isDark = theme.brightness == Brightness.dark;

    final historyItems = ref.watch(
      downloadHistoryProvider.select(
        (items) => items.where((i) => i.mediaId == widget.mediaId).toList(),
      ),
    );

    final items = _getEpisodes(
      l10n,
      langCode,
      downloadingEpisodes,
      historyItems,
    );

    if (items.isEmpty && !_isLoadingLocal && !widget.isLoadingAniZip) {
      return _buildLocalEmptyState(theme, l10n, iconPack);
    }

    if (items.isNotEmpty && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }

    final mediaProgress = ref.watch(
      playbackProgressPreferencesProvider.select(
        (playbackMap) => playbackMap[widget.mediaId.toString()],
      ),
    );
    final targetEpisodeNumber = _calculateTargetEpisodeNumber(
      items,
      mediaProgress,
    );
    final bool hasWatchedEpisodes =
        targetEpisodeNumber > 1 &&
        items.any((ep) => ep.number < targetEpisodeNumber);

    final displayedItems = items;
    if (hasWatchedEpisodes) {
      _scrollToResumeEpisode(displayedItems, targetEpisodeNumber);
    }

    final totalEpisodes = items.length;

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
            if (totalEpisodes > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.16)
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.25,
                          ),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  hasWatchedEpisodes
                      ? '${displayedItems.length} / $totalEpisodes'
                      : '$totalEpisodes',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white70
                        : theme.colorScheme.onSurfaceVariant,
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
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.checkCircleFilled(iconPack),
                      size: 14,
                      color: Colors.green,
                    ),
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
              Focus(
                skipTraversal: true,
                canRequestFocus: false,
                descendantsAreFocusable: false,
                child: M3EIconButton(
                  variant: M3EIconButtonVariant.tonal,
                  size: M3EIconButtonSize.xs,
                  tooltip: l10n.scanLocalFolder,
                  icon: Icon(AppIcons.refresh(iconPack), size: 17),
                  onPressed: _scanAndRefreshLocal,
                ),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // ─── Dynamic Episode Content (Horizontal List) ───
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: RepaintBoundary(
            key: ValueKey(
              'episodes_horiz_${widget.isLocalMode ? "local" : "anizip"}',
            ),
            child: Builder(
              builder: (context) {
                // ─── Loading State for Local Mode ───
                if (widget.isLocalMode && _isLoadingLocal && items.isEmpty) {
                  return _buildEpisodeSkeletons(theme, isDark);
                }

                // ─── Loading State for AniZip ───
                if (widget.isLoadingAniZip && items.isEmpty) {
                  return _buildEpisodeSkeletons(theme, isDark);
                }

                if (displayedItems.isEmpty) {
                  return SizedBox(
                    height: 290,
                    child: Center(
                      child: Text(
                        l10n.noEpisodesFound,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? Colors.white70
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                }

                // ─── Single Horizontal List (Cards with 16:9 thumbnails) ───
                return SizedBox(
                  height: 315,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const cardWidth = 425.0;
                      const gap = 18.0;
                      const step = cardWidth + gap;
                      final targetIndex = displayedItems
                          .indexWhere((ep) => ep.number == targetEpisodeNumber)
                          .clamp(0, displayedItems.length);
                      final contentWidth = displayedItems.isEmpty
                          ? 0.0
                          : displayedItems.length * cardWidth +
                                (displayedItems.length - 1) * gap;
                      final trailingSpace = hasWatchedEpisodes
                          ? (targetIndex * step +
                                    constraints.maxWidth -
                                    contentWidth -
                                    gap)
                                .clamp(0.0, double.infinity)
                          : 0.0;
                      return ListView.separated(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        cacheExtent: 1200,
                        itemCount:
                            displayedItems.length + (trailingSpace > 0 ? 1 : 0),
                        separatorBuilder: (_, _) => const SizedBox(width: 18),
                        itemBuilder: (context, index) {
                          if (index == displayedItems.length) {
                            return SizedBox(width: trailingSpace);
                          }
                          final ep = displayedItems[index];
                          return SizedBox(
                            width: 425,
                            child: DesktopGridEpisodeCard(
                              key: ValueKey('grid_ep_${ep.number}'),
                              mediaId: widget.mediaId,
                              ep: ep,
                              isFirst: index == 0,
                              isLast: index == displayedItems.length - 1,
                              isLoading:
                                  widget.loadingEpisodeNumber == ep.number,
                              formattedTitle: _formatEpisodeTitle(ep),
                              fallbackCoverImage: widget.fallbackCoverImage,
                              coverColor: widget.details?.coverColor,
                              onTap: () => widget.onEpisodeClicked(ep),
                              onArrowUp: widget.onMoveUpToPlay,
                              trailingActions: DesktopEpisodeMenuButton(
                                ep: ep,
                                mediaId: widget.mediaId,
                                details: widget.details,
                                onEpisodeClicked: widget.onEpisodeClicked,
                                onOpenTorrentSelector:
                                    widget.onOpenTorrentSelector,
                                onDownloadOnline:
                                    widget.selectedProvider != null
                                    ? () => showOnlineStreamDownloadDialog(
                                        context,
                                        mediaId: widget.mediaId,
                                        episodeNumber: ep.number,
                                        animeTitle: widget.details?.title ?? '',
                                        episodeTitle: ep.title,
                                        thumbnail: ep.image,
                                        provider: widget.selectedProvider,
                                        isDubbed: widget.isDubbed,
                                      )
                                    : null,
                                onRefreshLocal: _scanAndRefreshLocal,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeSkeletons(ThemeData theme, bool isDark) {
    if (!_shimmerController.isAnimating) {
      _shimmerController.repeat(reverse: true);
    }
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.45 + (_shimmerController.value * 0.55);
        return SizedBox(
          height: 315,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              return SizedBox(
                width: 425,
                child: Opacity(
                  opacity: opacity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 14,
                        width: 170,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
