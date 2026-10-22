import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/torrent_batch_files_sheet.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/mobile/torrent_selector_mobile_view.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';
import 'package:seanime_app/presentation/widgets/toast/app_toast.dart';

class TorrentSelectorDialog extends ConsumerStatefulWidget {
  final int mediaId;
  final int episodeNumber;
  final String episodeTitle;
  final AnimeDetails? animeDetails;
  final String? aniDBEpisode;
  final bool isSheet;
  final bool isDownloadMode;
  final List<int>? initialSelectedEpisodes;

  const TorrentSelectorDialog({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    required this.episodeTitle,
    this.animeDetails,
    this.aniDBEpisode,
    this.isSheet = false,
    this.isDownloadMode = false,
    this.initialSelectedEpisodes,
  });

  @override
  ConsumerState<TorrentSelectorDialog> createState() => _TorrentSelectorDialogState();
}

class _TorrentSelectorDialogState extends ConsumerState<TorrentSelectorDialog> {
  List<AnimeTorrentProvider> _providers = [];
  String? _selectedProviderId;
  bool _isLoadingProviders = true;

  List<TorrentItem> _torrents = [];
  bool _isLoadingTorrents = false;
  String? _errorMessage;

  bool _isSmartSearch = true;
  bool _showOnlyBatches = false;
  bool _searchAcrossProviders = false;
  TorrentSortField _sortField = TorrentSortField.seeders;
  bool _sortAscending = false;
  String _selectedQuality = 'Todos';
  late final TextEditingController _searchController;
  late int? _currentEpisodeNumber;

  late bool _isDownloadMode;
  final Map<int, TorrentItem> _selectedDownloadTorrents = {};

  String? _startingTorrentName;

  List<TorrentItem> get _filteredTorrents {
    return filterTorrentsList(
      _torrents,
      quality: _selectedQuality,
      showOnlyBatches: _showOnlyBatches,
    );
  }

  @override
  void initState() {
    super.initState();
    _isDownloadMode = widget.isDownloadMode;
    if (widget.initialSelectedEpisodes != null && widget.initialSelectedEpisodes!.isNotEmpty) {
      _isDownloadMode = true;
      _currentEpisodeNumber = widget.initialSelectedEpisodes!.first;
    } else {
      _currentEpisodeNumber = widget.episodeNumber;
    }
    _searchController = TextEditingController();
    _loadProviders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onEpisodeChanged(int? newEp) {
    setState(() {
      _currentEpisodeNumber = newEp;
      if (newEp != null) {
        _showOnlyBatches = false;
      } else {
        _showOnlyBatches = true;
      }
    });
    _searchTorrents();
  }

  Future<void> _loadProviders() async {
    final repo = ref.read(repositoryProvider);
    repo.ensureTorrentStreamingEnabled();
    try {
      final list = await repo.getAnimeTorrentProviders();
      if (mounted) {
        setState(() {
          _providers = list;
          if (list.isNotEmpty) {
            _selectedProviderId = list.first.id;
          }
          _isLoadingProviders = false;
        });
        _searchTorrents();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingProviders = false;
        });
        _searchTorrents();
      }
    }
  }

  Future<void> _searchTorrents() async {
    if (!mounted) return;
    setState(() {
      _isLoadingTorrents = true;
      _errorMessage = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final customQuery = _searchController.text.trim();
      final results = await repo.searchTorrents(
        mediaId: widget.mediaId,
        episodeNumber: _isSmartSearch && !_showOnlyBatches ? _currentEpisodeNumber : null,
        provider: _searchAcrossProviders ? null : _selectedProviderId,
        query: customQuery.isNotEmpty
            ? customQuery
            : (_isSmartSearch ? null : widget.animeDetails?.title),
        type: _isSmartSearch ? 'smart' : 'simple',
        batch: _showOnlyBatches,
        animeDetails: widget.animeDetails,
      );

      if (mounted) {
        setState(() {
          _torrents = results;
          _isLoadingTorrents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final l10n = ref.read(translationsProvider);
        setState(() {
          _errorMessage = '${l10n.error}: $e';
          _isLoadingTorrents = false;
        });
      }
    }
  }

  void _toggleSelectForDownload(TorrentItem torrent) {
    final epNum = _currentEpisodeNumber;
    if (epNum == null) return;
    setState(() {
      final current = _selectedDownloadTorrents[epNum];
      if (current != null && current.infoHash == torrent.infoHash && current.name == torrent.name) {
        _selectedDownloadTorrents.remove(epNum);
      } else {
        _selectedDownloadTorrents[epNum] = torrent;
      }
    });
  }

  Future<void> _startBatchDownload() async {
    if (_selectedDownloadTorrents.isEmpty) return;

    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final nav = Navigator.of(context);

    final entries = _selectedDownloadTorrents.entries.toList();

    if (nav.canPop()) {
      nav.pop();
    }

    for (final entry in entries) {
      final epNum = entry.key;
      final torrent = entry.value;
      ref.read(downloadingEpisodesProvider.notifier).add(
            widget.mediaId,
            epNum,
            hash: torrent.infoHash,
            torrentName: torrent.name,
          );
    }

    int successCount = 0;
    for (final entry in entries) {
      final epNum = entry.key;
      final torrent = entry.value;
      try {
        final success = await repo.downloadTorrentToClient(
          torrent: torrent,
          media: widget.animeDetails?.toBaseAnimeMap() ?? widget.animeDetails?.rawMedia,
          animeTitle: widget.animeDetails?.title,
          mediaId: widget.animeDetails?.id ?? widget.mediaId,
        );
        if (success) {
          successCount++;
        } else {
          ref.read(downloadingEpisodesProvider.notifier).remove(widget.mediaId, epNum);
        }
      } catch (e) {
        ref.read(downloadingEpisodesProvider.notifier).remove(widget.mediaId, epNum);
      }
    }

    ref.read(activeDownloadsProvider.notifier).refresh();

    if (successCount > 0) {
      AppToast.success(l10n.torrentBatchDownloadQueued);
    } else {
      AppToast.error(l10n.error);
    }
  }

  Future<void> _handleTorrentTap(TorrentItem torrent) async {
    if (_isDownloadMode || _selectedDownloadTorrents.isNotEmpty) {
      _toggleSelectForDownload(torrent);
      return;
    }
    if (isBatchTorrent(torrent)) {
      await _inspectBatchAndStream(torrent);
    } else {
      await _startStream(torrent);
    }
  }

  Future<void> _downloadTorrent(TorrentItem torrent) async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final nav = Navigator.of(context);

    if (nav.canPop()) {
      nav.pop();
    }

    final epNum = _currentEpisodeNumber ?? widget.episodeNumber;
    ref.read(downloadingEpisodesProvider.notifier).add(
          widget.mediaId,
          epNum,
          hash: torrent.infoHash,
          torrentName: torrent.name,
        );

    try {
      final success = await repo.downloadTorrentToClient(
        torrent: torrent,
        media: widget.animeDetails?.toBaseAnimeMap() ?? widget.animeDetails?.rawMedia,
        animeTitle: widget.animeDetails?.title,
        mediaId: widget.animeDetails?.id ?? widget.mediaId,
      );

      ref.read(activeDownloadsProvider.notifier).refresh();

      if (!success) {
        ref.read(downloadingEpisodesProvider.notifier).remove(widget.mediaId, epNum);
        AppToast.error(l10n.error);
      }
    } catch (e) {
      ref.read(downloadingEpisodesProvider.notifier).remove(widget.mediaId, epNum);
      AppToast.error('${l10n.error}: $e');
    }
  }

  void _onDownloadTorrentPressed(TorrentItem torrent) {
    if (_isDownloadMode || _selectedDownloadTorrents.isNotEmpty) {
      _toggleSelectForDownload(torrent);
      return;
    }
    if (isBatchTorrent(torrent)) {
      _inspectBatchAndStream(torrent, defaultDownload: true);
    } else {
      _downloadTorrent(torrent);
    }
  }

  Future<void> _inspectBatchAndStream(
    TorrentItem torrent, {
    bool defaultExternalPlayer = false,
    bool defaultDownload = false,
  }) async {
    final l10n = ref.read(translationsProvider);
    final isOnline = ref.read(serverNotifierProvider).isOnline;

    if (!isOnline) {
      AppToast.warning(l10n.serverNotOnline, context: context);
      return;
    }

    setState(() => _startingTorrentName = torrent.name);

    final repo = ref.read(repositoryProvider);
    final files = await repo.getTorrentFilePreviews(
      torrent: torrent,
      episodeNumber: _currentEpisodeNumber ?? widget.episodeNumber,
      mediaId: widget.mediaId,
      animeDetails: widget.animeDetails,
    );

    if (!mounted) return;
    setState(() => _startingTorrentName = null);

    if (files.length > 1) {
      final result = await showModalBottomSheet<TorrentBatchSelectionResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => TorrentBatchFilesSheet(
          torrent: torrent,
          files: files,
          targetEpisodeNumber: _currentEpisodeNumber ?? widget.episodeNumber,
        ),
      );

      if (result != null && mounted) {
        if (result.isDownloadAction || defaultDownload) {
          await _downloadTorrent(torrent);
        } else {
          await _startStream(
            torrent,
            fileIndex: result.file.index,
            fileTitle: result.file.displayTitle.isNotEmpty
                ? result.file.displayTitle
                : result.file.fileName,
            useExternalPlayer: result.useExternalPlayer,
          );
        }
      }
    } else if (files.length == 1) {
      if (defaultDownload) {
        await _downloadTorrent(torrent);
      } else {
        await _startStream(
          torrent,
          fileIndex: files.first.index,
          fileTitle: files.first.displayTitle.isNotEmpty
              ? files.first.displayTitle
              : files.first.fileName,
          useExternalPlayer: defaultExternalPlayer,
        );
      }
    } else {
      if (defaultDownload) {
        await _downloadTorrent(torrent);
      } else {
        await _startStream(torrent, useExternalPlayer: defaultExternalPlayer);
      }
    }
  }

  Future<void> _startStream(
    TorrentItem torrent, {
    int? fileIndex,
    String? fileTitle,
    bool useExternalPlayer = false,
  }) async {
    final l10n = ref.read(translationsProvider);
    setState(() => _startingTorrentName = torrent.name);

    final repo = ref.read(repositoryProvider);
    final serverManager = ref.read(serverManagerProvider);
    final isOnline = ref.read(serverNotifierProvider).isOnline;

    if (!isOnline) {
      AppToast.warning(l10n.serverNotOnline, context: context);
      setState(() => _startingTorrentName = null);
      return;
    }

    final success = await repo.startTorrentStream(
      mediaId: widget.mediaId,
      episodeNumber: widget.episodeNumber,
      aniDBEpisode: widget.aniDBEpisode ?? widget.episodeNumber.toString(),
      torrent: torrent,
      fileIndex: fileIndex,
      autoSelect: false,
      playbackType: useExternalPlayer ? 'default' : 'none',
    );

    if (!mounted) return;
    setState(() => _startingTorrentName = null);

    if (success) {
      if (useExternalPlayer) {
        AppToast.info('${l10n.openingExternalPlayer} (${torrent.name})', context: context);
        Navigator.of(context).pop();
      } else {
        final animeTitle = widget.animeDetails?.title ?? 'Anime';
        final streamUrl =
            'http://${serverManager.host}:${serverManager.port}/api/v1/torrentstream/stream/video.mkv';

        final sourceLabel = fileTitle != null && fileTitle.isNotEmpty
            ? 'Torrent • $fileTitle'
            : 'Torrent • ${torrent.name}';

        Navigator.of(context).pop(
          TorrentStreamLaunchInfo(
            mediaId: widget.mediaId,
            videoUrl: streamUrl,
            title: animeTitle,
            episodeTitle: widget.episodeTitle,
            episodeNumber: widget.episodeNumber,
            videoSource: sourceLabel,
            onDispose: () {
              repo.stopTorrentStream();
            },
          ),
        );
      }
    } else {
      AppToast.error(l10n.failedToStartTorrent, context: context);
    }
  }

  Future<void> _startDebridStream(TorrentItem torrent) async {
    final l10n = ref.read(translationsProvider);
    final isOnline = ref.read(serverNotifierProvider).isOnline;
    if (!isOnline) {
      AppToast.warning(l10n.serverNotOnline, context: context);
      return;
    }

    setState(() => _startingTorrentName = torrent.name);
    final repo = ref.read(repositoryProvider);
    final serverManager = ref.read(serverManagerProvider);

    final success = await repo.startDebridStream(
      mediaId: widget.mediaId,
      episodeNumber: _currentEpisodeNumber ?? widget.episodeNumber,
      torrent: torrent,
      autoSelect: true,
      playbackType: 'nativeplayer',
    );

    if (!mounted) return;
    setState(() => _startingTorrentName = null);

    if (success) {
      final animeTitle = widget.animeDetails?.title ?? 'Anime';
      final streamUrl =
          'http://${serverManager.host}:${serverManager.port}/api/v1/directstream/stream';

      Navigator.of(context).pop(
        TorrentStreamLaunchInfo(
          mediaId: widget.mediaId,
          videoUrl: streamUrl,
          title: animeTitle,
          episodeTitle: widget.episodeTitle,
          episodeNumber: _currentEpisodeNumber ?? widget.episodeNumber,
          videoSource: '⚡ Debrid • ${torrent.name}',
          onDispose: () {
            repo.cancelDebridStream();
          },
        ),
      );
    } else {
      AppToast.error(l10n.failedToStartTorrent, context: context);
    }
  }

  Future<void> _downloadDebridTorrent(TorrentItem torrent) async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);

    final settings = await repo.getServerSettings();
    final destination = settings?['library']?['libraryPath'] as String? ?? '';
    final success = await repo.addDebridTorrent(
      torrent: torrent,
      mediaId: widget.mediaId,
      destination: destination,
    );

    if (mounted) {
      if (success) {
        AppToast.success(l10n.debridDownloadStarted, context: context);
      } else {
        AppToast.error(l10n.error, context: context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !widget.isSheet && MediaQuery.of(context).size.width >= 768;

    final unifiedView = TorrentSelectorMobileView(
      animeDetails: widget.animeDetails,
      currentEpisodeNumber: _currentEpisodeNumber,
      episodeTitle: widget.episodeTitle,
      providers: _providers,
      selectedProviderId: _selectedProviderId,
      isLoadingProviders: _isLoadingProviders,
      filteredTorrents: _filteredTorrents,
      allTorrents: _torrents,
      isLoadingTorrents: _isLoadingTorrents,
      errorMessage: _errorMessage,
      selectedQuality: _selectedQuality,
      isSmartSearch: _isSmartSearch,
      showOnlyBatches: _showOnlyBatches,
      searchAcrossProviders: _searchAcrossProviders,
      sortField: _sortField,
      sortAscending: _sortAscending,
      searchController: _searchController,
      startingTorrentName: _startingTorrentName,
      selectedDownloadTorrents: _selectedDownloadTorrents,
      isDownloadMode: _isDownloadMode,
      onToggleDownloadMode: (val) => setState(() => _isDownloadMode = val),
      onStartBatchDownload: _startBatchDownload,
      onClearSelectedTorrents: () => setState(() => _selectedDownloadTorrents.clear()),
      onRemoveSelectedEpisode: (ep) => setState(() => _selectedDownloadTorrents.remove(ep)),
      onEpisodeChanged: _onEpisodeChanged,
      onProviderChanged: (val) {
        setState(() => _selectedProviderId = val);
        _searchTorrents();
      },
      onQualityChanged: (val) => setState(() => _selectedQuality = val),
      onSmartSearchChanged: (val) {
        setState(() => _isSmartSearch = val);
        _searchTorrents();
      },
      onBatchToggleChanged: (val) {
        setState(() => _showOnlyBatches = val);
        _searchTorrents();
      },
      onSearchAcrossProvidersChanged: (val) {
        setState(() => _searchAcrossProviders = val);
        _searchTorrents();
      },
      onSortFieldChanged: (field) {
        setState(() {
          _sortField = field;
          _sortAscending = false;
        });
      },
      onToggleSortDirection: () => setState(() => _sortAscending = !_sortAscending),
      onRefresh: _searchTorrents,
      onTorrentTap: _handleTorrentTap,
      onDownloadTorrent: _onDownloadTorrentPressed,
      onExternalPlayer: (t) => isBatchTorrent(t)
          ? _inspectBatchAndStream(t, defaultExternalPlayer: true)
          : _startStream(t, useExternalPlayer: true),
      onDebridStream: _startDebridStream,
      onDebridDownload: _downloadDebridTorrent,
      onClose: () => Navigator.of(context).pop(),
    );

    if (isDesktop) {
      return Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 740,
            maxHeight: math.min(840, MediaQuery.of(context).size.height * 0.88),
          ),
          child: GlassCard(
            borderRadius: BorderRadius.circular(24),
            padding: EdgeInsets.zero,
            child: unifiedView,
          ),
        ),
      );
    }

    return unifiedView;
  }
}
