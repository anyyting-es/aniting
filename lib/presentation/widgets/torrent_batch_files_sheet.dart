import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/torrent_file_preview.dart';
import 'package:seanime_app/data/models/torrent_models.dart';

class TorrentBatchSelectionResult {
  final TorrentFilePreview file;
  final bool useExternalPlayer;
  final bool isDownloadAction;

  const TorrentBatchSelectionResult({
    required this.file,
    this.useExternalPlayer = false,
    this.isDownloadAction = false,
  });
}

class TorrentBatchFilesSheet extends ConsumerStatefulWidget {
  final TorrentItem torrent;
  final List<TorrentFilePreview> files;
  final int targetEpisodeNumber;

  const TorrentBatchFilesSheet({
    super.key,
    required this.torrent,
    required this.files,
    required this.targetEpisodeNumber,
  });

  /// Helper to find the best matching file for a given episode number.
  static TorrentFilePreview? findBestMatch(
    List<TorrentFilePreview> files,
    int targetEpisode,
  ) {
    if (files.isEmpty) return null;

    // 1. Check server-provided isLikely flag
    final likelyMatch = files.where((f) => f.isLikely).firstOrNull;
    if (likelyMatch != null) return likelyMatch;

    // 2. Exact episodeNumber parsed match
    final epMatch = files.where((f) => f.episodeNumber == targetEpisode).firstOrNull;
    if (epMatch != null) return epMatch;

    // 3. Client-side regex match on filename (e.g., E02, - 02, [02], Ep 2)
    final epStr = targetEpisode.toString();
    final paddedEp = epStr.padLeft(2, '0');
    final regex = RegExp(
      '(?:[eE]|ep|episodio|episode|[^a-zA-Z0-9])0*(?:$epStr|$paddedEp)(?:[^a-zA-Z0-9]|\$)',
      caseSensitive: false,
    );

    for (final file in files) {
      if (regex.hasMatch(file.fileName) || regex.hasMatch(file.displayTitle)) {
        return file;
      }
    }

    // 4. Fallback to first video file, or first file
    return files.where((f) => f.isVideo).firstOrNull ?? files.first;
  }

  @override
  ConsumerState<TorrentBatchFilesSheet> createState() => _TorrentBatchFilesSheetState();
}

class _TorrentBatchFilesSheetState extends ConsumerState<TorrentBatchFilesSheet> {
  late TorrentFilePreview? _selectedFile;
  late final TorrentFilePreview? _autoMatchedFile;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _autoMatchedFile = TorrentBatchFilesSheet.findBestMatch(
      widget.files,
      widget.targetEpisodeNumber,
    );
    _selectedFile = _autoMatchedFile;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TorrentFilePreview> get _filteredFiles {
    if (_searchQuery.trim().isEmpty) {
      return widget.files;
    }
    final q = _searchQuery.toLowerCase().trim();
    return widget.files.where((f) {
      return f.fileName.toLowerCase().contains(q) ||
          f.displayTitle.toLowerCase().contains(q) ||
          (f.episodeNumber > 0 && f.episodeNumber.toString() == q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.themeColors;
    final l10n = ref.watch(translationsProvider);
    final filtered = _filteredFiles;

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

              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.folder_zip_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                l10n.batchFiles,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colors.surfaceElevated,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  l10n.filesCount(widget.files.length),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.torrent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
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

              // Search Filter Bar (if many files)
              if (widget.files.length > 5)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: l10n.filterFilesOrEpisode,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

              // Files List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.noFilesMatching(_searchQuery),
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final file = filtered[index];
                          final isSelected = _selectedFile?.index == file.index;
                          final isTarget = _autoMatchedFile?.index == file.index;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                                  : colors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : isTarget
                                        ? Colors.amber.withValues(alpha: 0.6)
                                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setState(() => _selectedFile = file);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    Icon(
                                      file.isVideo
                                          ? Icons.video_file_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: 22,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  file.displayTitle.isNotEmpty
                                                      ? file.displayTitle
                                                      : (file.episodeNumber > 0
                                                          ? l10n.episodeNumber(file.episodeNumber)
                                                          : file.fileName),
                                                  style: TextStyle(
                                                    fontWeight: isSelected
                                                        ? FontWeight.bold
                                                        : FontWeight.w600,
                                                    fontSize: 13,
                                                    color: isSelected
                                                        ? theme.colorScheme.primary
                                                        : theme.colorScheme.onSurface,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isTarget) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.amber.withValues(alpha: 0.2),
                                                    borderRadius: BorderRadius.circular(5),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Icon(Icons.star_rounded,
                                                          size: 11, color: Colors.amber),
                                                      SizedBox(width: 2),
                                                      Text(
                                                        l10n.currentEpisodeBadge,
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.amber,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            file.fileName,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: theme.colorScheme.onSurfaceVariant
                                                  .withValues(alpha: 0.8),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Radio<int>(
                                      value: file.index,
                                      groupValue: _selectedFile?.index,
                                      onChanged: (_) {
                                        setState(() => _selectedFile = file);
                                      },
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Bottom Sticky Confirmation Bar
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    border: Border(
                      top: BorderSide(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _selectedFile != null
                              ? () {
                                  Navigator.pop(
                                    context,
                                    TorrentBatchSelectionResult(
                                      file: _selectedFile!,
                                      useExternalPlayer: false,
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: Text(
                            _selectedFile != null
                                ? '${l10n.play} (${_selectedFile!.displayTitle.isNotEmpty ? _selectedFile!.displayTitle : 'Ep. ${_selectedFile!.episodeNumber > 0 ? _selectedFile!.episodeNumber : _selectedFile!.index + 1}'})'
                                : l10n.selectAFile,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: l10n.downloadWithTorrentClient,
                        icon: const Icon(Icons.download_rounded),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            TorrentBatchSelectionResult(
                              file: _selectedFile ?? widget.files.first,
                              isDownloadAction: true,
                            ),
                          );
                        },
                        style: IconButton.styleFrom(
                          minimumSize: const Size(46, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: l10n.openInExternalPlayer,
                        icon: const Icon(Icons.open_in_new_rounded),
                        onPressed: _selectedFile != null
                            ? () {
                                Navigator.pop(
                                  context,
                                  TorrentBatchSelectionResult(
                                    file: _selectedFile!,
                                    useExternalPlayer: true,
                                  ),
                                );
                              }
                            : null,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(46, 46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
