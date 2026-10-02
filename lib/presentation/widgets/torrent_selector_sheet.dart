import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/anime_details.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
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
  String _selectedQuality = 'Todos';
  late final TextEditingController _searchController;

  String? _startingTorrentName;

  List<TorrentItem> get _filteredTorrents {
    if (_selectedQuality == 'Todos') {
      return _torrents;
    }
    return _torrents.where((t) {
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
        episodeNumber: _isSmartSearch ? widget.episodeNumber : null,
        provider: _selectedProviderId,
        query: _isSmartSearch ? null : _searchController.text.trim(),
        type: _isSmartSearch ? 'smart' : 'simple',
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
    if (torrent.isBatch) return true;
    final name = torrent.name.toLowerCase();

    // 1. Explicit batch / complete release keywords
    if (RegExp(r'\b(?:batch|complete|completa|completo)\b').hasMatch(name)) {
      return true;
    }

    // 2. Explicit full-series / all-episodes indicators
    if (RegExp(r'\b(?:entire\s+series|all\s+episodes|temporada\s+completa|serie\s+completa)\b').hasMatch(name)) {
      return true;
    }

    // 3. Multi-season ranges (e.g. "S01-S03", "Season 1-3")
    if (RegExp(r'\b(?:s|season|temporada)\s*\d{1,2}\s*[-~]\s*(?:s|season|temporada)?\s*\d{1,2}\b').hasMatch(name)) {
      return true;
    }

    // 4. Bracketed/parenthesized episode ranges: e.g. "(01-12)", "[01~12]", "[01 - 24]"
    final bracketedRange = RegExp(r'[\[\(]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\s*[\]\)]').firstMatch(name);
    if (bracketedRange != null) {
      final start = int.tryParse(bracketedRange.group(1) ?? '');
      final end = int.tryParse(bracketedRange.group(2) ?? '');
      if (start != null && end != null && end > start) {
        return true;
      }
    }

    // 5. Episode ranges with "ep" / "eps" or tilde "~": e.g. "ep01-ep12", "01~12", "eps 01-24"
    final epRange = RegExp(r'\b(?:ep|eps|e)\s*(\d{1,3})\s*[-~]\s*(?:ep|eps|e)?\s*(\d{1,3})\b').firstMatch(name);
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

    // 6. Explicit episode range like "01-12" that is NOT preceded by season prefix ("S3 - 07")
    final standaloneRange = RegExp(r'(?<!(?:s|season|temporada)\s*)\b0*([1-9]\d{0,2})\s*-\s*0*([1-9]\d{0,2})\b').firstMatch(name);
    if (standaloneRange != null) {
      final start = int.tryParse(standaloneRange.group(1) ?? '');
      final end = int.tryParse(standaloneRange.group(2) ?? '');
      if (start != null && end != null && end > start && (end - start) >= 2) {
        return true;
      }
    }

    return false;
  }

  Future<void> _handleTorrentTap(TorrentItem torrent) async {
    if (_isBatchTorrent(torrent)) {
      await _inspectBatchAndStream(torrent);
    } else {
      await _startStream(torrent);
    }
  }

  Future<void> _inspectBatchAndStream(TorrentItem torrent, {bool defaultExternalPlayer = false}) async {
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
      episodeNumber: widget.episodeNumber,
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
          targetEpisodeNumber: widget.episodeNumber,
        ),
      );

      if (result != null && mounted) {
        await _startStream(
          torrent,
          fileIndex: result.file.index,
          fileTitle: result.file.displayTitle.isNotEmpty
              ? result.file.displayTitle
              : result.file.fileName,
          useExternalPlayer: result.useExternalPlayer,
        );
      }
    } else if (files.length == 1) {
      await _startStream(
        torrent,
        fileIndex: files.first.index,
        fileTitle: files.first.displayTitle.isNotEmpty
            ? files.first.displayTitle
            : files.first.fileName,
        useExternalPlayer: defaultExternalPlayer,
      );
    } else {
      // Fallback: start directly without fileIndex if fetching previews failed
      await _startStream(torrent, useExternalPlayer: defaultExternalPlayer);
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
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Torrents - ${l10n.episode} ${widget.episodeNumber}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            widget.episodeTitle,
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
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Filter Controls (Provider & Search Type)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: Row(
                  children: [
                    // Provider Dropdown
                    Expanded(
                      flex: 3,
                      child: Container(
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
                            hint: Text(
                              _isLoadingProviders ? l10n.loadingProviders : l10n.onlineProvider,
                              style: const TextStyle(fontSize: 13),
                            ),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                            items: [
                              DropdownMenuItem<String>(
                                value: null,
                                child: Text(l10n.allProviders, style: const TextStyle(fontSize: 13)),
                              ),
                              ..._providers.map((p) => DropdownMenuItem<String>(
                                    value: p.id,
                                    child: Text(
                                      p.name,
                                      style: const TextStyle(fontSize: 13),
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
                    const SizedBox(width: 8),

                    // Smart / Simple search compact toggle icon
                    IconButton(
                      icon: Icon(
                        _isSmartSearch ? Icons.auto_awesome_rounded : Icons.manage_search_rounded,
                        size: 20,
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

                    const SizedBox(width: 6),
                    // Refresh button
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                      tooltip: l10n.refresh,
                      onPressed: _isLoadingTorrents ? null : _searchTorrents,
                    ),
                  ],
                ),
              ),

              // Quality Filter Chips
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final quality in const ['Todos', '1080p', '720p', '2160p / 4K', '480p']) ...[
                        FilterChip(
                          selected: _selectedQuality == quality,
                          label: Text(quality == 'Todos' ? l10n.filterAll : quality, style: const TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => _selectedQuality = quality);
                            }
                          },
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
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
                          : (_selectedQuality == 'Todos'
                              ? '${_torrents.length} ${l10n.resultsFound}'
                              : l10n.torrentsFilterCount(_filteredTorrents.length, _torrents.length, _selectedQuality)),
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
                child: _buildBody(theme, scrollController, l10n),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody(ThemeData theme, ScrollController scrollController, AppTranslations l10n) {
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
                              tooltip: 'Ver archivos del torrent',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.folder_open_rounded,
                                size: 19,
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                              ),
                              onPressed: () => _inspectBatchAndStream(torrent),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: l10n.openInExternalPlayer,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                Icons.open_in_new_rounded,
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
