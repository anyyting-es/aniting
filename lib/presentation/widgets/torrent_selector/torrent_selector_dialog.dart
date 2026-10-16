import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/torrent_batch_files_sheet.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/desktop/torrent_selector_desktop_view.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/mobile/torrent_selector_mobile_view.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';

class TorrentSelectorDialog extends ConsumerStatefulWidget {
  final int mediaId;
  final int episodeNumber;
  final String episodeTitle;
  final AnimeDetails? animeDetails;
  final String? aniDBEpisode;
  final bool isSheet;

  const TorrentSelectorDialog({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    required this.episodeTitle,
    this.animeDetails,
    this.aniDBEpisode,
    this.isSheet = false,
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
    _currentEpisodeNumber = widget.episodeNumber;
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

  Future<void> _handleTorrentTap(TorrentItem torrent) async {
    if (isBatchTorrent(torrent)) {
      await _inspectBatchAndStream(torrent);
    } else {
      await _startStream(torrent);
    }
  }

  Future<void> _downloadTorrent(TorrentItem torrent) async {
    final l10n = ref.read(translationsProvider);
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
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
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(AppIcons.error(ref.read(iconPackProvider)), color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(l10n.error)),
              ],
            ),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      ref.read(downloadingEpisodesProvider.notifier).remove(widget.mediaId, epNum);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onDownloadTorrentPressed(TorrentItem torrent) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.serverNotOnline),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.serverNotOnline),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.openingExternalPlayer} (${torrent.name})'),
            behavior: SnackBarBehavior.floating,
          ),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToStartTorrent),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = !widget.isSheet && MediaQuery.of(context).size.width >= 768;

    if (isDesktop) {
      return TorrentSelectorDesktopView(
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
        onToggleSortDirection: () {
          setState(() => _sortAscending = !_sortAscending);
        },
        onRefresh: _searchTorrents,
        onTorrentTap: _handleTorrentTap,
        onDownloadTorrent: _onDownloadTorrentPressed,
        onExternalPlayer: (t) => isBatchTorrent(t)
            ? _inspectBatchAndStream(t, defaultExternalPlayer: true)
            : _startStream(t, useExternalPlayer: true),
        onClose: () => Navigator.of(context).pop(),
      );
    }

    return TorrentSelectorMobileView(
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
      onClose: () => Navigator.of(context).pop(),
    );
  }
}
