import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/downloads/online_stream_download_task.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/online_stream_download_provider.dart';

/// Shows the responsive Online Stream Download dialog/sheet.
Future<void> showOnlineStreamDownloadDialog(
  BuildContext context, {
  required int mediaId,
  required int episodeNumber,
  required String animeTitle,
  required String episodeTitle,
  String? thumbnail,
  OnlinestreamProvider? provider,
  bool isDubbed = false,
  List<OnlinestreamVideoSource>? preloadedSources,
}) async {
  final isWide = MediaQuery.of(context).size.width >= 720;

  if (isWide) {
    await showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: OnlineStreamDownloadDialogContent(
            mediaId: mediaId,
            episodeNumber: episodeNumber,
            animeTitle: animeTitle,
            episodeTitle: episodeTitle,
            thumbnail: thumbnail,
            initialProvider: provider,
            isDubbed: isDubbed,
            preloadedSources: preloadedSources,
            isSheet: false,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OnlineStreamDownloadDialogContent(
        mediaId: mediaId,
        episodeNumber: episodeNumber,
        animeTitle: animeTitle,
        episodeTitle: episodeTitle,
        thumbnail: thumbnail,
        initialProvider: provider,
        isDubbed: isDubbed,
        preloadedSources: preloadedSources,
        isSheet: true,
      ),
    );
  }
}

class OnlineStreamDownloadDialogContent extends ConsumerStatefulWidget {
  final int mediaId;
  final int episodeNumber;
  final String animeTitle;
  final String episodeTitle;
  final String? thumbnail;
  final OnlinestreamProvider? initialProvider;
  final bool isDubbed;
  final List<OnlinestreamVideoSource>? preloadedSources;
  final bool isSheet;

  const OnlineStreamDownloadDialogContent({
    super.key,
    required this.mediaId,
    required this.episodeNumber,
    required this.animeTitle,
    required this.episodeTitle,
    this.thumbnail,
    this.initialProvider,
    this.isDubbed = false,
    this.preloadedSources,
    required this.isSheet,
  });

  @override
  ConsumerState<OnlineStreamDownloadDialogContent> createState() =>
      _OnlineStreamDownloadDialogContentState();
}

class _OnlineStreamDownloadDialogContentState
    extends ConsumerState<OnlineStreamDownloadDialogContent> {
  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedProvider;
  List<OnlinestreamVideoSource> _sources = [];
  OnlinestreamVideoSource? _selectedSource;
  bool _isLoading = false;
  String? _error;
  String? _resolvedSavePath;

  @override
  void initState() {
    super.initState();
    _selectedProvider = widget.initialProvider;
    if (widget.preloadedSources != null &&
        widget.preloadedSources!.isNotEmpty) {
      _sources = widget.preloadedSources!;
      _selectedSource = _sources.first;
    }
    _initData();
  }

  Future<void> _initData() async {
    final repo = ref.read(repositoryProvider);

    // Resolve target path preview
    try {
      final destDir = await repo.resolveAnimeDownloadDestination(
        mediaId: widget.mediaId,
        animeTitle: widget.animeTitle,
      );
      if (destDir != null && mounted) {
        final cleanTitle = widget.animeTitle
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        final paddedEp = widget.episodeNumber.toString().padLeft(2, '0');
        final isWindows = Platform.isWindows || destDir.contains(r'\');
        final sep = isWindows ? r'\' : '/';
        setState(() {
          _resolvedSavePath = '$destDir$sep$cleanTitle - $paddedEp.mp4';
        });
      }
    } catch (_) {}

    // Load providers if not provided
    if (_selectedProvider == null) {
      try {
        final provs = await repo.getOnlinestreamProviders();
        if (mounted && provs.isNotEmpty) {
          setState(() {
            _providers = provs;
            _selectedProvider = provs.first;
          });
        }
      } catch (_) {}
    }

    if (_sources.isEmpty) {
      await _fetchSources();
    }
  }

  Future<void> _fetchSources() async {
    final prov = _selectedProvider;
    if (prov == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final repo = ref.read(repositoryProvider);
    try {
      final sources = await repo.getOnlinestreamSource(
        mediaId: widget.mediaId,
        episodeNumber: widget.episodeNumber,
        provider: prov.id,
        dubbed: widget.isDubbed,
        title: widget.animeTitle,
      );

      if (mounted) {
        setState(() {
          _sources = sources;
          _selectedSource = sources.firstOrNull;
          _isLoading = false;
          if (sources.isEmpty) {
            _error = ref.read(translationsProvider).noSourcesFoundForEpisode;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _onStartDownload() async {
    final src = _selectedSource;
    final prov = _selectedProvider;
    if (src == null || prov == null) return;

    final l10n = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);

    final result = await ref
        .read(onlineStreamDownloadProvider.notifier)
        .startDownload(
          mediaId: widget.mediaId,
          episodeNumber: widget.episodeNumber,
          animeTitle: widget.animeTitle,
          episodeTitle: widget.episodeTitle,
          thumbnail: widget.thumbnail,
          source: src,
          providerId: prov.id,
          providerName: prov.name,
        );

    if (!mounted) return;

    switch (result) {
      case DownloadStartResult.started:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.onlineDownloadStarted}: ${widget.animeTitle} - ${l10n.episodeNumber(widget.episodeNumber)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      case DownloadStartResult.alreadyDownloading:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.alreadyDownloading),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case DownloadStartResult.noDestination:
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.noSaveLocationConfigured),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Red banner shown when a download finished but produced no playable file
  /// (protected source, invalid output, ...).
  Widget _buildFailureBanner(
    ThemeData theme,
    AppTranslations l10n,
    OnlineStreamDownloadTask task,
  ) {
    final message = switch (task.errorCode) {
      'protected' => l10n.downloadFailedProtected,
      'invalid' => l10n.downloadFailedInvalid,
      _ => l10n.downloadFailedGeneric,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12.5),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            tooltip: l10n.close,
            onPressed: () => ref
                .read(onlineStreamDownloadProvider.notifier)
                .removeTask(task.id),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final taskId = '${widget.mediaId}_${widget.episodeNumber}';
    final downloadTasks = ref.watch(onlineStreamDownloadProvider).tasks;
    final activeTask = downloadTasks[taskId];
    final isCurrentlyDownloading = activeTask != null && activeTask.isActive;

    final glassEnabled = ref.watch(glassEffectsEnabledProvider);
    final radius = BorderRadius.circular(widget.isSheet ? 24 : 20);
    return ClipRRect(
      borderRadius: radius,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: glassEnabled
                ? (isDark
                    ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.40)
                    : theme.colorScheme.surfaceContainer.withValues(alpha: 0.55))
                : theme.colorScheme.surfaceContainer,
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: glassEnabled ? 0.20 : 0.12)
                  : theme.colorScheme.outlineVariant.withValues(alpha: glassEnabled ? 0.45 : 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sheet grabber handle
            if (widget.isSheet) ...[
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.35,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],

            // Header: Title & Close Button
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.downloadOnlineStream,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.episodeTitle.isNotEmpty
                            ? widget.episodeTitle
                            : l10n.episodeNumber(widget.episodeNumber),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.animeTitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: l10n.close,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active Downloading State Banner
            if (isCurrentlyDownloading) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.25,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            value: activeTask.progress > 0
                                ? activeTask.progress
                                : null,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.alreadyDownloading,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (activeTask.speed.isNotEmpty)
                          Text(
                            activeTask.speed,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: activeTask.progress > 0
                            ? activeTask.progress
                            : null,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () {
                            ref
                                .read(onlineStreamDownloadProvider.notifier)
                                .cancelDownload(taskId);
                          },
                          icon: Icon(
                            AppIcons.trash(iconPack),
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                          label: Text(
                            l10n.cancelDownload,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else if (activeTask != null &&
                activeTask.status == OnlineStreamDownloadStatus.failed) ...[
              _buildFailureBanner(theme, l10n, activeTask),
              const SizedBox(height: 12),
            ] else ...[
              // Preview Thumbnail
              if (widget.thumbnail != null && widget.thumbnail!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: CachedNetworkImage(
                      imageUrl: widget.thumbnail!,
                      fit: BoxFit.cover,
                      memCacheWidth: 640,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              const SizedBox(height: 14),

              // Loading sources state
              if (_isLoading) ...[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.resolvingOnlineSources,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_error != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.error,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _fetchSources,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: Text(l10n.refresh),
                      ),
                    ],
                  ),
                ),
              ] else if (_sources.isNotEmpty) ...[
                if (_providers.length > 1) ...[
                  Text(
                    l10n.onlineProvider,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _providers.map((prov) {
                      final isSelected = _selectedProvider?.id == prov.id;
                      return ChoiceChip(
                        selected: isSelected,
                        label: Text(prov.name),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _selectedProvider = prov;
                              _sources = [];
                              _selectedSource = null;
                            });
                            _fetchSources();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Quality & Server Selection
                Text(
                  l10n.selectServerAndQuality,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sources.map((src) {
                    final isSelected = _selectedSource == src;
                    final qualityLabel = src.displayLabel;
                    return FilterChip(
                      selected: isSelected,
                      label: Text(qualityLabel),
                      avatar: src.isHls
                          ? const Icon(Icons.stream_rounded, size: 14)
                          : const Icon(Icons.video_file_outlined, size: 14),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _selectedSource = src);
                        }
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // Subtitles Information
                if (_selectedSource != null &&
                    _selectedSource!.subtitles.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.subtitles_outlined,
                        size: 16,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.subtitlesIncluded}: ${_selectedSource!.subtitles.map((s) => s.language).toSet().join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                // Save Location Preview
                if (_resolvedSavePath != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${l10n.saveLocation}: $_resolvedSavePath',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                SizedBox(
                  width: double.infinity,
                  child: M3EButton(
                    onPressed: _selectedSource != null
                        ? _onStartDownload
                        : null,
                    style: M3EButtonStyle.filled,
                    icon: Icon(AppIcons.download(iconPack), size: 18),
                    label: Text(
                      _selectedSource != null
                          ? '${l10n.startDownloadAction} (${_selectedSource!.displayLabel})'
                          : l10n.startDownloadAction,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    ),
  );
}
}
