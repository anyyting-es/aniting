import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/preferences/playback_progress_preferences_provider.dart';
import 'package:aniting/presentation/widgets/anime_detail/anime_episode_target.dart';
import 'package:aniting/core/theme/smooth_scroll_controller.dart';
import 'package:aniting/data/models/anime_details.dart';
import 'package:aniting/data/models/anizip_data.dart';
import 'package:aniting/data/models/episode_item.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/data/models/library_entry_details.dart';
import 'package:aniting/data/services/offline_library_service.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/providers/active_downloads_provider.dart';
import 'package:aniting/presentation/providers/download_history_provider.dart';
import 'package:aniting/presentation/providers/episode_selection_provider.dart';
import 'package:aniting/presentation/screens/anime_detail_screen.dart';

import 'package:aniting/presentation/widgets/online_stream_batch_download_dialog.dart';
import 'package:aniting/presentation/widgets/online_stream_download_dialog.dart';
import 'package:aniting/presentation/widgets/toast/app_toast.dart';

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

  /// When the episodes come from an external source (Plex/Jellyfin) there is no
  /// local library entry to load, so skip every local/anime library lookup.
  final bool isExternalSource;

  /// TMDB mode: render [tmdbEpisodes] with the same cards as Anime.
  final bool isTmdb;
  final List<EpisodeItem>? tmdbEpisodes;

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
    this.isExternalSource = false,
    this.isTmdb = false,
    this.tmdbEpisodes,
    this.onOpenTorrentSelector,
  });

  @override
  ConsumerState<DesktopEpisodesTab> createState() => DesktopEpisodesTabState();
}

class DesktopEpisodesTabState extends ConsumerState<DesktopEpisodesTab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmerController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );
  late final ScrollController _horizontalScrollController =
      SmoothScrollController(smoothingFactor: 16.0, speedMultiplier: 1.0);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'desktop_episode_search',
  );
  bool _isSearchExpanded = false;
  String _searchQuery = '';

  /// Episode the list last auto-scrolled to, per anime.
  ///
  /// Tracking the target (instead of a one-shot boolean) is what makes the list
  /// follow the progress when another episode gets marked as watched.
  int? _lastAutoScrollTarget;
  int? _lastAutoScrollMediaId;
  int _lastAlignmentRequest = 0;

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
    if (widget.isExternalSource || widget.isTmdb) return;
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
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  /// Expands and focuses the episode search. Called by the Ctrl+F shortcut
  /// from the desktop detail layout.
  void focusSearch() {
    final selection = ref.read(episodeSelectionProvider(widget.mediaId));
    if (selection.isSelectionMode) {
      ref.read(episodeSelectionProvider(widget.mediaId).notifier).clear();
    }
    if (!_isSearchExpanded) {
      setState(() => _isSearchExpanded = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _onSearchChanged(String value) {
    // Let clearing the query restore the resume scroll position.
    _lastAutoScrollTarget = null;
    _lastAutoScrollMediaId = null;
    setState(() => _searchQuery = value);
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _closeSearch() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    _lastAutoScrollTarget = null;
    _lastAutoScrollMediaId = null;
    setState(() {
      _isSearchExpanded = false;
      _searchQuery = '';
    });
  }

  Future<void> _batchDownload(
    BuildContext context,
    List<int> selectedNumbers,
    Map<int, String?> downloadedMap,
  ) async {
    final l10n = ref.read(translationsProvider);
    final toDownload =
        selectedNumbers
            .where(
              (n) => !downloadedMap.containsKey(n) || downloadedMap[n] == null,
            )
            .toList()
          ..sort();
    if (toDownload.isEmpty) return;

    final isOnline =
        !widget.isLocalMode && widget.currentTab == AnimeDetailTab.online;
    if (!isOnline) {
      final openTorrentSelector = widget.onOpenTorrentSelector;
      if (openTorrentSelector == null) return;
      final first = toDownload.first;
      await openTorrentSelector(
        episodeNumber: first,
        episodeTitle: l10n.episodeNumber(first),
        isDownloadMode: true,
        initialSelectedEpisodes: toDownload,
      );
      if (mounted) {
        ref.read(episodeSelectionProvider(widget.mediaId).notifier).clear();
      }
      return;
    }

    if (toDownload.length == 1) {
      final epNum = toDownload.first;
      final epThumb = widget.details?.aniZipData?.episodes
          .where((e) => e.episodeNumber == epNum)
          .firstOrNull
          ?.image;
      showOnlineStreamDownloadDialog(
        context,
        mediaId: widget.mediaId,
        episodeNumber: epNum,
        animeTitle: widget.details?.title ?? 'Anime',
        episodeTitle: l10n.episodeNumber(epNum),
        thumbnail: epThumb,
        provider: widget.selectedProvider,
        isDubbed: widget.isDubbed,
      );
    } else {
      showOnlineStreamBatchDownloadDialog(
        context,
        mediaId: widget.mediaId,
        animeTitle: widget.details?.title ?? 'Anime',
        episodeNumbers: toDownload,
        aniZipData: widget.details?.aniZipData,
        initialProvider: widget.selectedProvider,
        isDubbed: widget.isDubbed,
      );
    }
    if (mounted) {
      ref.read(episodeSelectionProvider(widget.mediaId).notifier).clear();
    }
  }

  Future<void> _batchDelete(
    BuildContext context,
    List<int> selectedNumbers,
    Map<int, String?> downloadedMap,
  ) async {
    final l10n = ref.read(translationsProvider);
    final downloadedSelected = selectedNumbers
        .where((n) => downloadedMap.containsKey(n) && downloadedMap[n] != null)
        .toList();
    if (downloadedSelected.isEmpty) return;

    final confirmed = await showGlassDialog<bool>(
      context: context,
      builder: (ctx) => GlassAlert(
        title: Text(l10n.deleteDownload, textAlign: TextAlign.center),
        message: Text(
          l10n.deleteSelectedEpisodesConfirm(downloadedSelected.length),
          textAlign: TextAlign.center,
        ),
        actions: <GlassAlertAction>[
          GlassAlertAction(
            label: l10n.cancel,
            onPressed: () => Navigator.pop(ctx, false),
          ),
          GlassAlertAction(
            label: l10n.delete,
            isDestructive: true,
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final repo = ref.read(repositoryProvider);
    final paths = downloadedSelected
        .map((n) => downloadedMap[n])
        .whereType<String>()
        .toList();
    if (paths.isNotEmpty) {
      try {
        await repo.deleteLocalFiles(paths);
      } catch (_) {}
      for (final path in paths) {
        try {
          final file = File(path);
          if (file.existsSync()) file.deleteSync();
        } catch (_) {}
      }
    }

    final history = ref.read(downloadHistoryProvider.notifier);
    for (final epNum in downloadedSelected) {
      history.removeItem('${widget.mediaId}_$epNum');
      history.removeItem('$epNum');
    }

    ref.invalidate(downloadedAnimeProvider);
    ref.invalidate(animeLibraryEntryProvider(widget.mediaId));
    ref.invalidate(animeCollectionProvider);
    ref.read(activeDownloadsProvider.notifier).refresh();
    ref.read(episodeSelectionProvider(widget.mediaId).notifier).clear();

    if (!mounted || !context.mounted) return;
    _loadLocalEntry();
    AppToast.success(l10n.downloadDeleted, context: context);
  }

  Future<void> _batchMarkWatched(
    BuildContext context,
    List<int> selectedNumbers, {
    required bool markAsWatched,
  }) async {
    if (selectedNumbers.isEmpty) return;
    final repo = ref.read(repositoryProvider);
    final l10n = ref.read(translationsProvider);
    final localService = OfflineLibraryService.instance;
    final existingEntry = localService.getAnimeEntry(widget.mediaId);

    final selectedMax = selectedNumbers.reduce((a, b) => a > b ? a : b);
    final selectedMin = selectedNumbers.reduce((a, b) => a < b ? a : b);
    final currentProgress = math.max(
      widget.progress,
      existingEntry?.progress ?? 0,
    );

    // AniList progress is linear: marking EP n also marks every previous
    // episode. Never move the progress backwards when marking as watched.
    final targetEpisode = markAsWatched
        ? math.max(currentProgress, selectedMax)
        : (math.min(currentProgress, selectedMin) - 1).clamp(0, 9999);

    // Save the progress locally first so the episode row reacts instantly.
    if (existingEntry == null) {
      await localService.recordAnimeWatch(
        mediaId: widget.mediaId,
        title: widget.details?.title ?? '',
        episodeNumber: targetEpisode,
        totalEpisodes: widget.details?.totalEpisodes,
        isTmdb: widget.isTmdb,
      );
    }
    await localService.updateAnimeProgress(
      mediaId: widget.mediaId,
      episodeNumber: targetEpisode,
      totalEpisodes: widget.details?.totalEpisodes,
      isTmdb: widget.isTmdb,
    );
    if (!mounted || !context.mounted) return;

    ref.invalidate(animeCollectionProvider);
    ref.invalidate(animeLibraryEntryProvider(widget.mediaId));
    ref.invalidate(continueWatchingProvider);
    ref.read(episodeSelectionProvider(widget.mediaId).notifier).clear();
    AppToast.info(
      markAsWatched
          ? l10n.markedAsWatched(targetEpisode)
          : l10n.markedAsUnwatched(targetEpisode + 1),
      context: context,
    );

    // Sync AniList in the background; the local progress is already saved.
    if (!widget.isTmdb) {
      final synced = await repo.updateAnimeProgress(
        mediaId: widget.mediaId,
        episodeNumber: targetEpisode,
        totalEpisodes: widget.details?.totalEpisodes ?? 0,
      );
      if (!synced) {
        debugPrint('AniList progress sync failed; local progress saved.');
      }
    }
  }

  Widget _buildSelectionHeader({
    required EpisodeSelectionState selection,
    required List<int> allEpisodeNumbers,
    required Map<int, String?> downloadedMap,
    required AppTranslations l10n,
    required AppIconPack iconPack,
    required ThemeData theme,
  }) {
    final notifier = ref.read(episodeSelectionProvider(widget.mediaId).notifier);
    final selected = selection.selectedNumbers.toList()..sort();
    final notDownloaded = selected
        .where((n) => !downloadedMap.containsKey(n) || downloadedMap[n] == null)
        .toList();
    final downloaded = selected
        .where((n) => downloadedMap.containsKey(n) && downloadedMap[n] != null)
        .toList();
    final isAllSelected =
        allEpisodeNumbers.isNotEmpty &&
        selection.selectedNumbers.length >= allEpisodeNumbers.length;
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      key: const ValueKey('episode_selection_header'),
      children: [
        M3EIconButton(
          variant: M3EIconButtonVariant.standard,
          size: M3EIconButtonSize.xs,
          tooltip: l10n.close,
          icon: Icon(AppIcons.close(iconPack), size: 18),
          onPressed: notifier.clear,
        ),
        const SizedBox(width: 8),
        Text(
          l10n.selectedEpisodesCount(selection.count),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 10),
        M3EButton.icon(
          style: M3EButtonStyle.tonal,
          size: M3EButtonSize.sm,
          shape: M3EButtonShape.round,
          icon: Icon(
            isAllSelected
                ? AppIcons.removeDone(iconPack)
                : Icons.select_all_rounded,
            size: 16,
          ),
          label: Text(isAllSelected ? l10n.deselectAll : l10n.selectAll),
          onPressed: () {
            if (isAllSelected) {
              notifier.clear();
            } else {
              notifier.selectAll(allEpisodeNumbers);
            }
          },
        ),
        const Spacer(),
        if (notDownloaded.isNotEmpty)
          M3EButton.icon(
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            icon: Icon(AppIcons.download(iconPack), size: 16),
            label: Text(l10n.downloadCount(notDownloaded.length)),
            onPressed: () =>
                _batchDownload(context, notDownloaded, downloadedMap),
          ),
        if (downloaded.isNotEmpty) ...[
          const SizedBox(width: 6),
          M3EIconButton(
            variant: M3EIconButtonVariant.standard,
            size: M3EIconButtonSize.xs,
            tooltip: l10n.deleteCount(downloaded.length),
            icon: Icon(
              AppIcons.trash(iconPack),
              size: 18,
              color: theme.colorScheme.error,
            ),
            onPressed: () => _batchDelete(context, downloaded, downloadedMap),
          ),
        ],
        const SizedBox(width: 6),
        M3EButton.icon(
          style: M3EButtonStyle.tonal,
          size: M3EButtonSize.sm,
          shape: M3EButtonShape.round,
          icon: Icon(AppIcons.checkCircle(iconPack), size: 16),
          label: Text(l10n.markWatched),
          onPressed: () =>
              _batchMarkWatched(context, selected, markAsWatched: true),
        ),
      ],
    );
  }

  void _clearMemoizedCaches() {
    _cachedAniZipItems = null;
  }

  Future<void> _loadLocalEntry({bool silent = false}) async {
    if (widget.isExternalSource || widget.isTmdb) return;
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
      // The list is source-dependent: torrent/local uses the metadata
      // providers, online merges the provider's episodes with that metadata.
      // Drop the memoized list and re-align the resume target for the new
      // source instead of showing the previous tab's episodes.
      _cachedAniZipItems = null;
      _lastAutoScrollTarget = null;
      _lastAutoScrollMediaId = null;
    }
    if (oldWidget.mediaId != widget.mediaId) {
      _lastAutoScrollTarget = null;
      _lastAutoScrollMediaId = null;
      _clearMemoizedCaches();
      _loadLocalEntry();
    } else if (oldWidget.isLocalMode != widget.isLocalMode) {
      _loadLocalEntry();
    }
  }

  /// Progress including the offline entry that the player just updated.
  ///
  /// The parent may not rebuild immediately when the local library changes, so
  /// the tab reads it directly. This is what makes the resume target advance
  /// from 15 to 16 as soon as episode 15 is completed, without waiting for the
  /// server collection round-trip.
  int get _effectiveProgress => math.max(
    widget.progress,
    OfflineLibraryService.instance.getAnimeEntry(widget.mediaId)?.progress ?? 0,
  );

  /// Next episode to surface, derived from the **same value the action bar
  /// uses**, so the "Continuar EP n" label and the episode list can never
  /// disagree. See [resolveTargetEpisodeNumber].
  int _calculateTargetEpisodeNumber(
    List<DesktopEpisodeItemData> items,
    EpisodePlaybackProgress? mediaProgress,
  ) {
    return resolveTargetEpisodeNumber(
      episodeNumbers: [for (final ep in items) ep.number],
      progress: _effectiveProgress,
      totalEpisodes: widget.details?.totalEpisodes,
      userStatus: widget.details?.userStatus,
      playbackEpisodeNumber: mediaProgress?.episodeNumber,
      playbackPositionMs: mediaProgress?.positionMs ?? 0,
      playbackDurationMs: mediaProgress?.durationMs ?? 0,
    );
  }

  void _scrollToResumeEpisode(
    List<DesktopEpisodeItemData> items,
    int targetEpisodeNumber,
  ) {
    if (items.isEmpty) return;

    // Same target for the same anime: leave the user's scroll alone.
    if (_lastAutoScrollTarget == targetEpisodeNumber &&
        _lastAutoScrollMediaId == widget.mediaId) {
      return;
    }

    final targetIndex = items.indexWhere(
      (ep) => ep.number == targetEpisodeNumber,
    );
    if (targetIndex < 0) return;

    // First alignment for a media happens while the page is opening: jump to
    // the final position instead of animating across a long, heavy card list.
    final isInitialAlignment = _lastAutoScrollMediaId != widget.mediaId;
    _lastAutoScrollTarget = targetEpisodeNumber;
    _lastAutoScrollMediaId = widget.mediaId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_horizontalScrollController.hasClients) return;

      final position = _horizontalScrollController.position;
      const step = 443.0;
      final currentOffset = position.pixels;

      // The resume episode must be the first card in the carousel, not merely
      // "somewhere visible": after finishing 15 the list should start at 16,
      // and while 15 is in progress it should start at 15.
      final targetStart = targetIndex * step;
      final clamped = targetStart.clamp(0.0, position.maxScrollExtent);
      _moveEpisodeCarouselTo(
        target: clamped,
        delta: (clamped - currentOffset).abs(),
        isInitial: isInitialAlignment,
        step: step,
      );
    });
  }

  /// Smooth for short, visible corrections; instant for long jumps.
  ///
  /// Animating over many 443 px episode cards rebuilds every card in between
  /// and is what made returning from the player feel like a stutter. Large
  /// alignments now happen off-screen (initial) or in a single frame.
  void _moveEpisodeCarouselTo({
    required double target,
    required double delta,
    required bool isInitial,
    required double step,
  }) {
    if (delta < 1) return;
    if (isInitial || delta > step * 4) {
      _horizontalScrollController.jumpTo(target);
      return;
    }
    _horizontalScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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
    if (_effectiveProgress >= episodeNumber ||
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

  bool _isGenericEpisodeTitle(String? title) {
    final value = (title ?? '').trim();
    if (value.isEmpty) return true;
    return RegExp(
      r'^(episode|episodio|ep|special|especial|especiales)\s*\d+$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  /// Builds the episode row from the selected online provider when its list
  /// does not match AniList 1:1 (extra episodes, missing episodes or different
  /// numbering). AniZip/Animap metadata is used only to enrich matching
  /// episodes.
  List<DesktopEpisodeItemData> _buildOnlineProviderEpisodes(
    AppTranslations l10n,
    String langCode,
    DownloadingEpisodesState downloadingEpisodes,
    List<DownloadHistoryItem> historyItems,
    AniZipData? aniZipData,
  ) {
    final downloadedMap = <int, String?>{
      for (final ep in (_libraryEntry?.episodes ?? <LibraryEpisode>[]))
        if (ep.isDownloaded) ep.episodeNumber: ep.localFilePath,
    };
    for (final item in historyItems) {
      if (item.filePath == null || item.filePath!.isEmpty) continue;
      int? epNum;
      if (item.id.startsWith('${widget.mediaId}_')) {
        epNum = int.tryParse(item.id.substring('${widget.mediaId}_'.length));
      }
      if (epNum != null) downloadedMap[epNum] = item.filePath;
    }

    // Only main episodes: AniZip specials (S1, S2, ...) reuse the same numeric
    // `episodeNumber` (1, 2, ...) and would overwrite the real episode metadata
    // in the map, leaking special titles/thumbnails into the episode list.
    final aniZipByNumber = <int, AniZipEpisode>{
      for (final ep in (aniZipData?.mainEpisodes ?? const <AniZipEpisode>[]))
        ep.episodeNumber: ep,
    };

    // The backend resolves episodes through Animap, which (unlike AniZip for
    // brand-new seasons) usually already has real titles and TVDB stills.
    final backendEpisodesByNumber = <int, AnimeEpisode>{
      for (final ep in (widget.details?.episodes ?? const <AnimeEpisode>[]))
        ep.episodeNumber: ep,
    };

    final seen = <int>{};
    final result = <DesktopEpisodeItemData>[];
    for (final online in widget.onlineEpisodes) {
      if (!seen.add(online.number)) continue;
      final aniZipEp = aniZipByNumber[online.number];
      final backendEp = backendEpisodesByNumber[online.number];
      final onlineTitle = (online.title ?? '').trim();
      final aniZipTitle = aniZipEp?.displayTitleForLang(langCode);
      final String title;
      if (!_isGenericEpisodeTitle(onlineTitle)) {
        title = onlineTitle;
      } else if (!_isGenericEpisodeTitle(aniZipTitle)) {
        title = aniZipTitle!;
      } else if (!_isGenericEpisodeTitle(backendEp?.title)) {
        title = backendEp!.title;
      } else {
        title = l10n.episodeNumber(online.number);
      }
      final synopsis =
          (online.description != null && online.description!.trim().isNotEmpty)
          ? online.description
          : (aniZipEp?.synopsis ?? backendEp?.description);
      final image =
          (online.image != null && online.image!.trim().isNotEmpty)
          ? online.image
          : (aniZipEp?.image ?? backendEp?.image);

      result.add(
        DesktopEpisodeItemData(
          number: online.number,
          title: title,
          synopsis: synopsis,
          image: image,
          aniDBEpisode: aniZipEp?.episode,
          isWatched: _effectiveProgress >= online.number,
          isDownloaded: downloadedMap.containsKey(online.number),
          isDownloading: downloadingEpisodes.contains(
            '${widget.mediaId}_${online.number}',
          ),
          downloadProgress: downloadingEpisodes.getProgress(
            widget.mediaId,
            online.number,
          ),
          localFilePath: downloadedMap[online.number],
        ),
      );
    }
    result.sort((a, b) => a.number.compareTo(b.number));
    return result;
  }

  List<DesktopEpisodeItemData> _getEpisodes(
    AppTranslations l10n,
    String langCode,
    DownloadingEpisodesState downloadingEpisodes,
    List<DownloadHistoryItem> historyItems,
  ) {
    // TMDB episodes already come merged with local files from EpisodesNotifier.
    if (widget.isTmdb) {
      return (widget.tmdbEpisodes ?? const <EpisodeItem>[])
          .map(
            (ep) => DesktopEpisodeItemData(
              number: ep.number,
              title: ep.title,
              synopsis: ep.synopsis,
              image: ep.image,
              isWatched: _effectiveProgress >= ep.number,
              isDownloaded: ep.isDownloaded,
              localFilePath: ep.localFilePath,
            ),
          )
          .toList();
    }

    final aniZipData = widget.aniZipData ?? widget.details?.aniZipData;

    // Online mode: mirror the mobile flow. The provider's episode list is the
    // source of truth, but when it maps 1:1 to AniList/AniZip we keep the
    // canonical episode list (official titles, art and numbering).
    final isOnlineProviderMode =
        !widget.isLocalMode &&
        widget.currentTab == AnimeDetailTab.online &&
        widget.onlineEpisodes.isNotEmpty;
    if (isOnlineProviderMode) {
      final mainEps =
          aniZipData?.mainEpisodes ??
          aniZipData?.episodes.where((e) => !e.isSpecial).toList() ??
          const <AniZipEpisode>[];
      final aniZipNumbers = <int>{
        for (final ep in mainEps) ep.episodeNumber,
      };
      if (aniZipNumbers.isEmpty) {
        aniZipNumbers.addAll(
          (widget.details?.episodes ?? const <AnimeEpisode>[])
              .map((ep) => ep.episodeNumber),
        );
      }
      final providerNumbers = <int>{
        for (final ep in widget.onlineEpisodes) ep.number,
      };
      final isOneToOne =
          aniZipNumbers.length == providerNumbers.length &&
          aniZipNumbers.containsAll(providerNumbers);
      if (!isOneToOne) {
        return _buildOnlineProviderEpisodes(
          l10n,
          langCode,
          downloadingEpisodes,
          historyItems,
          aniZipData,
        );
      }
    }

    // Fast-path: return cached list instantly if no relevant dependency changed
    if (_cachedAniZipItems != null &&
        _lastAniZip == aniZipData &&
        _lastDetails == widget.details &&
        _lastProgress == _effectiveProgress &&
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
    final backendEpsByNumber = <int, AnimeEpisode>{
      for (final ep in (widget.details?.episodes ?? const <AnimeEpisode>[]))
        ep.episodeNumber: ep,
    };

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
        final backendEp = backendEpsByNumber[ep.episodeNumber];
        final resolvedImage = ep.image ?? backendEp?.image;
        if (!_hasEpisodeAired(
          ep.episodeNumber,
          ep.airDate,
          resolvedImage,
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

          final aniZipTitle = ep.displayTitleForLang(langCode);
          result.add(
            DesktopEpisodeItemData(
              number: ep.episodeNumber,
              // Torrent/local lists combine AniZip with the backend's Animap
              // metadata: AniZip may be missing titles/stills for new seasons.
              title: _isGenericEpisodeTitle(aniZipTitle)
                  ? (backendEp?.title ?? aniZipTitle)
                  : aniZipTitle,
              synopsis: ep.synopsis ?? backendEp?.description,
              image: resolvedImage,
              aniDBEpisode: ep.episode,
              isWatched: _effectiveProgress >= ep.episodeNumber,
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
              isWatched: _effectiveProgress >= ep.episodeNumber,
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
            isWatched: _effectiveProgress >= i,
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
            isWatched: _effectiveProgress >= entry.key,
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
    _lastProgress = _effectiveProgress;
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

    // Re-align the resume card after the player closes, even when the target
    // episode number stayed the same (e.g. the user had scrolled the carousel
    // away before pressing Continue).
    final alignmentRequest = ref.watch(episodeResumeAlignmentProvider);
    if (alignmentRequest != _lastAlignmentRequest) {
      _lastAlignmentRequest = alignmentRequest;
      _lastAutoScrollTarget = null;
      _lastAutoScrollMediaId = null;
    }

    final items = _getEpisodes(
      l10n,
      langCode,
      downloadingEpisodes,
      historyItems,
    );

    if (items.isEmpty && !_isLoadingLocal && !widget.isLoadingAniZip) {
      if (widget.isTmdb) {
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

    final normalizedQuery = _searchQuery.trim().toLowerCase();
    final isFiltering = normalizedQuery.isNotEmpty;
    final numericQuery = int.tryParse(normalizedQuery);
    final displayedItems = isFiltering
        ? items.where((ep) {
            // Typing an episode number lists that episode and every later one,
            // so "5" surfaces 5, 6, 7… instead of only the exact match.
            if (numericQuery != null) {
              return ep.number >= numericQuery;
            }
            return ep.number.toString() == normalizedQuery ||
                ep.title.toLowerCase().contains(normalizedQuery);
          }).toList()
        : items;
    final bool hasWatchedEpisodes =
        !isFiltering &&
        targetEpisodeNumber > 1 &&
        items.any((ep) => ep.number < targetEpisodeNumber);

    // Always reconcile the scroll with the current target: marking another
    // episode as watched moves it, and the list has to follow.
    if (!isFiltering) {
      _scrollToResumeEpisode(items, targetEpisodeNumber);
    }

    final totalEpisodes = items.length;

    final selection = ref.watch(episodeSelectionProvider(widget.mediaId));
    final isSelectionMode = selection.isSelectionMode;
    final allEpisodeNumbers = displayedItems.map((e) => e.number).toList();
    final downloadedMap = <int, String?>{
      for (final ep in items)
        if (ep.isDownloaded) ep.number: ep.localFilePath,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header: selection toolbar or normal controls ───
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0, -0.08),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: isSelectionMode
                ? _buildSelectionHeader(
                    selection: selection,
                    allEpisodeNumbers: allEpisodeNumbers,
                    downloadedMap: downloadedMap,
                    l10n: l10n,
                    iconPack: iconPack,
                    theme: theme,
                  )
                : Row(
                    key: const ValueKey('episodes_header_normal'),
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
                  isFiltering || hasWatchedEpisodes
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

            // ─── Episode search (Ctrl+F) ───
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.centerRight,
              child: _isSearchExpanded
                  ? SizedBox(
                      width: 280,
                      child: GlassTextField.search(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        placeholder: l10n.filterEpisodesHint,
                        onChanged: _onSearchChanged,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_searchQuery.isNotEmpty)
                              InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _clearSearch,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Icon(
                                    AppIcons.close(iconPack),
                                    size: 16,
                                  ),
                                ),
                              ),
                            InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _closeSearch,
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  AppIcons.searchOff(iconPack),
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Focus(
                      skipTraversal: true,
                      canRequestFocus: false,
                      descendantsAreFocusable: false,
                      child: M3EIconButton(
                        variant: M3EIconButtonVariant.standard,
                        size: M3EIconButtonSize.xs,
                        tooltip: l10n.searchEpisodesShortcut,
                        icon: Icon(AppIcons.search(iconPack), size: 17),
                        onPressed: focusSearch,
                      ),
                    ),
            ),
            const SizedBox(width: 6),

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
        ),
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
                        isFiltering
                            ? '${l10n.noEpisodesFoundMatching} "${_searchQuery.trim()}".'
                            : l10n.noEpisodesFound,
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
                      final cardCount = displayedItems.length;
                      final targetIndex = displayedItems
                          .indexWhere((ep) => ep.number == targetEpisodeNumber)
                          .clamp(0, cardCount);

                      // Trailing slots let the target episode reach the left
                      // edge even near the end of the list. Every slot is
                      // exactly [step] wide so the ListView can estimate the
                      // total scroll extent immediately (a single variable
                      // width spacer was under-estimated and left a sliver of
                      // the previous episode visible).
                      final targetOffset = targetIndex * step;
                      final requiredSlots = hasWatchedEpisodes
                          ? ((targetOffset + constraints.maxWidth) / step)
                                .ceil()
                          : cardCount;
                      final trailingItemCount = (requiredSlots - cardCount)
                          .clamp(0, 100000);
                      final itemCount = cardCount + trailingItemCount;

                      return ListView.builder(
                        controller: _horizontalScrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        cacheExtent: 1200,
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index >= cardCount) {
                            return const SizedBox(width: step);
                          }
                          final ep = displayedItems[index];
                          return SizedBox(
                            width: step,
                            child: Padding(
                              padding: const EdgeInsets.only(right: gap),
                              child: DesktopGridEpisodeCard(
                                key: ValueKey('grid_ep_${ep.number}'),
                                mediaId: widget.mediaId,
                                ep: ep,
                                isFirst: index == 0,
                                isLast: index == cardCount - 1,
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
                                          animeTitle:
                                              widget.details?.title ?? '',
                                          episodeTitle: ep.title,
                                          thumbnail: ep.image,
                                          provider: widget.selectedProvider,
                                          isDubbed: widget.isDubbed,
                                        )
                                      : null,
                                  onRefreshLocal: _scanAndRefreshLocal,
                                ),
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
