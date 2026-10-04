import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/providers/active_downloads_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/torrent_batch_files_sheet.dart';

class TorrentStreamLaunchInfo {
  final int mediaId;
  final String videoUrl;
  final String title;
  final String episodeTitle;
  final int episodeNumber;
  final String videoSource;
  final VoidCallback onDispose;

  const TorrentStreamLaunchInfo({
    required this.mediaId,
    required this.videoUrl,
    required this.title,
    required this.episodeTitle,
    required this.episodeNumber,
    required this.videoSource,
    required this.onDispose,
  });
}

class TorrentSelectorSheet extends ConsumerStatefulWidget {
  final int mediaId;
  final int episodeNumber;
  final String episodeTitle;
  final AnimeDetails? animeDetails;
  final String? aniDBEpisode;

  const TorrentSelectorSheet({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    required this.episodeTitle,
    this.animeDetails,
    this.aniDBEpisode,
  });

  @override
  ConsumerState<TorrentSelectorSheet> createState() => _TorrentSelectorSheetState();
}

class _TorrentSelectorSheetState extends ConsumerState<TorrentSelectorSheet> {
  List<AnimeTorrentProvider> _providers = [];
  String? _selectedProviderId;
  bool _isLoadingProviders = true;

  List<TorrentItem> _torrents = [];
  bool _isLoadingTorrents = false;
  String? _errorMessage;

  bool _isSmartSearch = true;
  bool _showOnlyBatches = false;
  String _selectedQuality = 'Todos';
  late final TextEditingController _searchController;
  late int? _currentEpisodeNumber;

  String? _startingTorrentName;

  List<TorrentItem> get _filteredTorrents {
    var list = _torrents;
    if (_showOnlyBatches) {
      list = list.where((t) => _isBatchTorrent(t)).toList();
    }
    if (_selectedQuality == 'Todos') {
      return list;
    }
    return list.where((t) {
      final res = (t.resolution ?? '').toLowerCase();
      final name = t.name.toLowerCase();
      switch (_selectedQuality) {
        case '1080p':
          return res.contains('1080') || name.contains('1080');
        case '720p':
          return res.contains('720') || name.contains('720');
        case '2160p / 4K':
          return res.contains('2160') || res.contains('4k') || name.contains('2160') || name.contains('4k');
        case '480p':
          return res.contains('480') || res.contains('540') || name.contains('480');
        default:
          return true;
      }
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _currentEpisodeNumber = widget.episodeNumber;
    final defaultTitle = widget.animeDetails?.romajiTitle ??
        widget.animeDetails?.title ??
        '';
    _searchController = TextEditingController(
      text: '$defaultTitle ${widget.episodeNumber}',
    );
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
      final defaultTitle = widget.animeDetails?.romajiTitle ??
          widget.animeDetails?.title ??
          '';
      if (newEp != null) {
        _showOnlyBatches = false;
        _searchController.text = '$defaultTitle $newEp';
      } else {
        _showOnlyBatches = true;
        _searchController.text = '$defaultTitle Batch';
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
    } catch (e) {
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
      final results = await repo.searchTorrents(
        mediaId: widget.mediaId,
        episodeNumber: _isSmartSearch && !_showOnlyBatches ? _currentEpisodeNumber : null,
        provider: _selectedProviderId,
        query: _isSmartSearch ? null : _searchController.text.trim(),
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

  bool _isBatchTorrent(TorrentItem torrent) {
    final name = torrent.name.toLowerCase();

    // 1. Explicit batch / complete release keywords ALWAYS identify a batch
    if (RegExp(
      r'\b(?:batch|complete\s*series?|completa|completo|temporada\s+completa|serie\s+completa|all\s+episodes|entire\s+series)\b',
    ).hasMatch(name)) {
      return true;
    }

    // 2. Explicit single episode patterns: e.g. "S3-04", "S03E04", "S1 - 04", "Ep 04", "Capítulo 04", "E04", " - 04"
    final singleEpPatterns = [
      RegExp(r'\b[sS]\d{1,2}\s*[-_eE]\s*\d{1,3}\b'),
      RegExp(r'\b(?:ep|eps|e|cap|capitulo|cap[ií]tulo|episodio)\.?\s*0*(\d{1,4})\b', caseSensitive: false),
      RegExp(r'\s+-\s+0*(\d{1,3})(?:v\d+)?\b'),
    ];

    bool hasSingleEp = false;
    for (final pattern in singleEpPatterns) {
      if (pattern.hasMatch(torrent.name)) {
        hasSingleEp = true;
        break;
      }
    }

    // 3. Multi-season ranges (e.g. "S01-S03", "Season 1-3", "Seasons 1-3")
    // Both sides require explicit 's' or word 'season', preventing "S3-04" from false matching
    final isMultiSeason = RegExp(
      r'\b[sS]\d{1,2}\s*[-~]\s*[sS]\d{1,2}\b|\b(?:season|temporada)\s*\d{1,2}\s*[-~]\s*(?:season|temporada)?\s*\d{1,2}\b|\b(?:seasons|temporadas)\s*\d{1,2}\s*[-~]\s*\d{1,2}\b',
      caseSensitive: false,
    ).hasMatch(name);

    if (isMultiSeason) {
      return true;
    }

    // 4. Bracketed or explicit episode ranges (e.g. "(01-12)", "[01~12]", "ep01-ep12")
    final bracketedRange = RegExp(
      r'[\[\(]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[\]\)]',
    ).firstMatch(name);
    if (bracketedRange != null) {
      final start = int.tryParse(bracketedRange.group(1) ?? '');
      final end = int.tryParse(bracketedRange.group(2) ?? '');
      if (start != null && end != null && end > start) {
        return true;
      }
    }

    final epRange = RegExp(
      r'\b(?:ep|eps|e)\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\b',
    ).firstMatch(name);
    if (epRange != null) {
      final start = int.tryParse(epRange.group(1) ?? '');
      final end = int.tryParse(epRange.group(2) ?? '');
      if (start != null && end != null && end > start) {
        return true;
      }
    }

    final tildeRange = RegExp(r'\b(\d{1,3})\s*~\s*(\d{1,3})\b').firstMatch(name);
    if (tildeRange != null) {
      final start = int.tryParse(tildeRange.group(1) ?? '');
      final end = int.tryParse(tildeRange.group(2) ?? '');
      if (start != null && end != null && end > start) {
        return true;
      }
    }

    // If single episode pattern was found and no multi-episode range exists, it's NOT a batch
    if (hasSingleEp) {
      return false;
    }

    // 5. Fallback to server-parsed flag (Habari/Anitomy)
    return torrent.isBatch;
  }

  Future<void> _handleTorrentTap(TorrentItem torrent) async {
    if (_isBatchTorrent(torrent)) {
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

    // 1. Immediately close the sheet so user returns to the episode view cleanly
    if (nav.canPop()) {
      nav.pop();
    }

    // 2. Mark episode as downloading for inline spinning indicator
    final epNum = _currentEpisodeNumber ?? widget.episodeNumber;
    ref.read(downloadingEpisodesProvider.notifier).add(
      widget.mediaId,
      epNum,
      hash: torrent.infoHash,
      torrentName: torrent.name,
    );

    // 3. Initiate download in background
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
                const Icon(Icons.error_rounded, color: Colors.white, size: 20),
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
    if (_isBatchTorrent(torrent)) {
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

    setState(() {
      _startingTorrentName = torrent.name;
    });

    final repo = ref.read(repositoryProvider);
    final files = await repo.getTorrentFilePreviews(
      torrent: torrent,
      episodeNumber: _currentEpisodeNumber ?? widget.episodeNumber,
      mediaId: widget.mediaId,
      animeDetails: widget.animeDetails,
    );

    if (!mounted) return;
    setState(() {
      _startingTorrentName = null;
    });

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
    setState(() {
      _startingTorrentName = torrent.name;
    });

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
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Torrents',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            widget.animeDetails?.title ?? widget.episodeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Episode Selector Dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _currentEpisodeNumber,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          dropdownColor: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          items: [
                            DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                l10n.allBatches,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ...List.generate(
                              widget.animeDetails?.episodes.isNotEmpty == true
                                  ? widget.animeDetails!.episodes.length
                                  : (widget.animeDetails?.totalEpisodes ?? math.max(widget.episodeNumber, 12)),
                              (i) {
                                final epNum = i + 1;
                                return DropdownMenuItem<int?>(
                                  value: epNum,
                                  child: Text(
                                    l10n.episodeNumber(epNum),
                                    style: const TextStyle(fontSize: 12.5),
                                  ),
                                );
                              },
                            ),
                          ],
                          onChanged: _onEpisodeChanged,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter Controls (Provider, Quality, Batch toggle, Smart toggle, Refresh)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    // Provider Dropdown
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedProviderId,
                            isExpanded: true,
                            isDense: true,
                            hint: Text(
                              _isLoadingProviders ? l10n.loadingProviders : l10n.onlineProvider,
                              style: const TextStyle(fontSize: 12),
                            ),
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(l10n.allProviders, style: const TextStyle(fontSize: 12)),
                              ),
                              ..._providers.map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedProviderId = val;
                              });
                              _searchTorrents();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Quality Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 38,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedQuality,
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(Icons.arrow_drop_down, size: 18),
                            items: [
                              DropdownMenuItem<String>(
                                value: 'Todos',
                                child: Text(l10n.filterAll, style: const TextStyle(fontSize: 12)),
                              ),
                              for (final q in const ['1080p', '720p', '2160p / 4K', '480p'])
                                DropdownMenuItem<String>(
                                  value: q,
                                  child: Text(q, style: const TextStyle(fontSize: 12)),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedQuality = val);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Batch toggle button
                    IconButton(
                      icon: Icon(
                        Icons.folder_zip_rounded,
                        size: 19,
                        color: _showOnlyBatches ? Colors.purpleAccent : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: l10n.showOnlyBatches,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      style: IconButton.styleFrom(
                        backgroundColor: _showOnlyBatches
                            ? Colors.purple.withValues(alpha: 0.25)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        setState(() => _showOnlyBatches = !_showOnlyBatches);
                        _searchTorrents();
                      },
                    ),
                    const SizedBox(width: 4),

                    // Smart / Simple search compact toggle icon
                    IconButton(
                      icon: Icon(
                        _isSmartSearch ? Icons.auto_awesome_rounded : Icons.manage_search_rounded,
                        size: 19,
                        color: _isSmartSearch ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                      ),
                      tooltip: _isSmartSearch ? '${l10n.smartSearch} (Activo)' : '${l10n.simpleSearch} (Activo)',
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      style: IconButton.styleFrom(
                        backgroundColor: _isSmartSearch
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.all(8),
                      ),
                      onPressed: () {
                        setState(() {
                          _isSmartSearch = !_isSmartSearch;
                        });
                        _searchTorrents();
                      },
                    ),
                    const SizedBox(width: 4),

                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: l10n.refresh,
                      constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                      onPressed: _isLoadingTorrents ? null : _searchTorrents,
                    ),
                  ],
                ),
              ),

              // Simple search text input if not smart search
              if (!_isSmartSearch)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: l10n.searchQueryHint,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: const Icon(Icons.search, size: 18),
                          ),
                          onSubmitted: (_) => _searchTorrents(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonal(
                        onPressed: _isLoadingTorrents ? null : _searchTorrents,
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(l10n.search, style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),

              // Results Count Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isLoadingTorrents
                          ? l10n.searchingTorrents
                          : (_selectedQuality == 'Todos' && !_showOnlyBatches
                              ? '${_torrents.length} ${l10n.resultsFound}'
                              : '${_filteredTorrents.length} / ${_torrents.length} ${l10n.resultsFound}'),
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 4),

              // Torrents List Body
              Expanded(
                child: _buildBody(theme, scrollController, l10n, iconPack),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, ScrollController scrollController, AppTranslations l10n, AppIconPack iconPack) {
    if (_isLoadingTorrents) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(l10n.searchingTorrentsInProviders, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _searchTorrents,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_torrents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 46,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.noTorrentsForEpisode,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.trySimpleSearchOrProvider,
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final torrents = _filteredTorrents;
    if (torrents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 10),
              Text(
                l10n.noTorrentsWithQuality(_selectedQuality == 'Todos' ? l10n.filterAll : _selectedQuality),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _selectedQuality = 'Todos'),
                child: Text(l10n.resetQualityFilterAll),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      itemCount: torrents.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final torrent = torrents[index];
        final isStarting = _startingTorrentName == torrent.name;

        return Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: torrent.isBestRelease
                  ? Colors.amber.withValues(alpha: 0.6)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              width: torrent.isBestRelease ? 1.5 : 1.0,
            ),
          ),
          color: theme.colorScheme.surfaceContainerLow,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isStarting ? null : () => _handleTorrentTap(torrent),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Title & Badges
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          torrent.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isStarting)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: l10n.downloadWithTorrentClient,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                AppIcons.download(iconPack),
                                size: 20,
                                color: theme.colorScheme.primary,
                              ),
                              onPressed: () => _onDownloadTorrentPressed(torrent),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: l10n.openInExternalPlayer,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                AppIcons.openInNew(iconPack),
                                size: 19,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                              onPressed: () => _isBatchTorrent(torrent)
                                  ? _inspectBatchAndStream(torrent, defaultExternalPlayer: true)
                                  : _startStream(torrent, useExternalPlayer: true),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Metadata Badges Row (Resolution, Best, Size, Seeders, Leechers)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Batch Release
                      if (_isBatchTorrent(torrent))
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.folder_zip_rounded, size: 11, color: Colors.purpleAccent),
                              SizedBox(width: 3),
                              Text(
                                'Batch',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purpleAccent,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Best Release
                      if (torrent.isBestRelease)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                              const SizedBox(width: 3),
                              Text(
                                l10n.bestRelease,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.amber,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Resolution
                      if (torrent.resolution != null && torrent.resolution!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            torrent.resolution!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),

                      // Size
                      if (torrent.formattedSize.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            torrent.formattedSize,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                      // Seeders
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_upward_rounded, size: 10, color: Colors.green),
                            const SizedBox(width: 2),
                            Text(
                              '${torrent.seeders}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Leechers
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.arrow_downward_rounded, size: 10, color: Colors.red),
                            const SizedBox(width: 2),
                            Text(
                              '${torrent.leechers}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Provider
                      if (torrent.provider != null && torrent.provider!.isNotEmpty)
                        Text(
                          torrent.provider!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
