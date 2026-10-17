import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/online_stream_download_provider.dart';

/// Shows the responsive Batch Download Dialog with Liquid Glass styling.
Future<void> showOnlineStreamBatchDownloadDialog(
  BuildContext context, {
  required int mediaId,
  required String animeTitle,
  required List<int> episodeNumbers,
  AniZipData? aniZipData,
  OnlinestreamProvider? initialProvider,
  bool isDubbed = false,
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
          constraints: const BoxConstraints(maxWidth: 620),
          child: OnlineStreamBatchDownloadContent(
            mediaId: mediaId,
            animeTitle: animeTitle,
            episodeNumbers: episodeNumbers,
            aniZipData: aniZipData,
            initialProvider: initialProvider,
            isDubbed: isDubbed,
            isSheet: false,
          ),
        ),
      ),
    );
  } else {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OnlineStreamBatchDownloadContent(
        mediaId: mediaId,
        animeTitle: animeTitle,
        episodeNumbers: episodeNumbers,
        aniZipData: aniZipData,
        initialProvider: initialProvider,
        isDubbed: isDubbed,
        isSheet: true,
      ),
    );
  }
}

class OnlineStreamBatchDownloadContent extends ConsumerStatefulWidget {
  final int mediaId;
  final String animeTitle;
  final List<int> episodeNumbers;
  final AniZipData? aniZipData;
  final OnlinestreamProvider? initialProvider;
  final bool isDubbed;
  final bool isSheet;

  const OnlineStreamBatchDownloadContent({
    super.key,
    required this.mediaId,
    required this.animeTitle,
    required this.episodeNumbers,
    this.aniZipData,
    this.initialProvider,
    this.isDubbed = false,
    required this.isSheet,
  });

  @override
  ConsumerState<OnlineStreamBatchDownloadContent> createState() =>
      _OnlineStreamBatchDownloadContentState();
}

class _OnlineStreamBatchDownloadContentState
    extends ConsumerState<OnlineStreamBatchDownloadContent> {
  bool _isLoading = true;
  OnlinestreamProvider? _activeProvider;

  // Unique server names discovered across all episodes (canonical normalized: uppercase trimmed)
  final List<String> _uniqueServers = [];
  String? _preferredServer;

  // Episode number -> list of discovered sources/servers
  final Map<int, List<OnlinestreamVideoSource>> _episodeSources = {};
  // Episode number -> currently assigned video source
  final Map<int, OnlinestreamVideoSource?> _assignedSources = {};
  // Episode number -> loading status
  final Map<int, bool> _episodeLoading = {};

  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadSourcesAndResolveServers();
  }

  Future<void> _loadSourcesAndResolveServers() async {
    final repo = ref.read(repositoryProvider);

    try {
      OnlinestreamProvider? prov = widget.initialProvider;
      if (prov == null) {
        final provList = await repo.getOnlinestreamProviders();
        if (provList.isNotEmpty) {
          prov = provList.first;
        }
      }
      if (!mounted) return;

      setState(() {
        _activeProvider = prov;
      });

      if (prov == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Concurrently fetch video sources for all selected episodes
      const int poolSize = 4;
      final episodes = List<int>.from(widget.episodeNumbers);

      for (int i = 0; i < episodes.length; i += poolSize) {
        final chunk = episodes.skip(i).take(poolSize);
        await Future.wait(
          chunk.map((epNum) async {
            _episodeLoading[epNum] = true;
            try {
              final sources = await repo.getOnlinestreamSource(
                mediaId: widget.mediaId,
                episodeNumber: epNum,
                provider: prov!.id,
                dubbed: widget.isDubbed,
                title: widget.animeTitle,
              );
              if (mounted) {
                _episodeSources[epNum] = sources;
                _episodeLoading[epNum] = false;

                // Discover unique server names
                for (final src in sources) {
                  final sName = src.server.trim().toUpperCase();
                  if (sName.isNotEmpty && !_uniqueServers.contains(sName)) {
                    _uniqueServers.add(sName);
                  }
                }
              }
            } catch (e) {
              if (mounted) {
                _episodeSources[epNum] = [];
                _episodeLoading[epNum] = false;
              }
            }
          }),
        );
        if (mounted) {
          setState(() {
            _recalculateAssignments();
          });
        }
      }

      if (_preferredServer == null && _uniqueServers.isNotEmpty) {
        _preferredServer = _uniqueServers.first;
      }
    } catch (e) {
      debugPrint('Error loading sources for batch download: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _recalculateAssignments();
        });
      }
    }
  }

  void _recalculateAssignments() {
    final preferred = _preferredServer;

    for (final epNum in widget.episodeNumbers) {
      final sources = _episodeSources[epNum] ?? [];
      if (sources.isEmpty) {
        _assignedSources[epNum] = null;
        continue;
      }

      // Check if current manual assignment is still valid
      final currentAssigned = _assignedSources[epNum];
      if (currentAssigned != null &&
          sources.any((s) => s.url == currentAssigned.url)) {
        continue;
      }

      // Check if preferred server is available for this episode
      if (preferred != null) {
        final match = sources.firstWhere(
          (s) => s.server.trim().toUpperCase() == preferred,
          orElse: () => sources.first,
        );
        _assignedSources[epNum] = match;
      } else {
        _assignedSources[epNum] = sources.first;
      }
    }
  }

  void _onSelectPreferredServer(String server) {
    HapticFeedback.selectionClick();
    setState(() {
      _preferredServer = server;
      // Reassign all episodes according to new server preference
      for (final epNum in widget.episodeNumbers) {
        final sources = _episodeSources[epNum] ?? [];
        if (sources.isEmpty) continue;

        final match = sources.firstWhere(
          (s) => s.server.trim().toUpperCase() == server,
          orElse: () => sources.first,
        );
        _assignedSources[epNum] = match;
      }
    });
  }

  void _showChangeServerModalForEpisode(int epNum) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sources = _episodeSources[epNum] ?? [];

    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        padding: EdgeInsets.zero,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            math.max(16.0, MediaQuery.of(ctx).padding.bottom + 12.0),
          ),
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainer.withValues(alpha: 0.50)
                : theme.colorScheme.surfaceContainer.withValues(alpha: 0.65),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${l10n.episodeNumber(epNum)} - ${l10n.selectServerAndQuality}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              if (sources.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    l10n.noSourceAvailable,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: sources.map((src) {
                    final isAssigned = _assignedSources[epNum]?.url == src.url;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _assignedSources[epNum] = src;
                          });
                          Navigator.pop(ctx);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: isAssigned
                                ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                : (isDark
                                    ? Colors.white.withValues(alpha: 0.06)
                                    : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAssigned
                                  ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08)),
                              width: isAssigned ? 1.4 : 0.8,
                            ),
                          ),
                          child: Text(
                            src.displayLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isAssigned ? FontWeight.bold : FontWeight.w500,
                              color: isAssigned
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startBatchDownloads() async {
    final validToDownload = widget.episodeNumbers
        .where((n) => _assignedSources[n] != null)
        .toList();

    if (validToDownload.isEmpty) return;

    setState(() => _isDownloading = true);
    final l10n = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final downloadNotifier = ref.read(onlineStreamDownloadProvider.notifier);

    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.downloadingEpisodesCount(validToDownload.length)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    int queued = 0;
    final prov = _activeProvider;

    for (final epNum in validToDownload) {
      final chosen = _assignedSources[epNum];
      if (chosen == null) continue;

      try {
        final epThumb = widget.aniZipData?.episodes
            .where((e) => e.episodeNumber == epNum)
            .firstOrNull
            ?.image;

        final res = await downloadNotifier.startDownload(
          mediaId: widget.mediaId,
          episodeNumber: epNum,
          animeTitle: widget.animeTitle,
          episodeTitle: l10n.episodeNumber(epNum),
          thumbnail: epThumb,
          source: chosen,
          providerId: prov?.id ?? '',
          providerName: prov?.name ?? '',
        );

        if (res == DownloadStartResult.started) queued++;
      } catch (e) {
        debugPrint('Error starting batch download for ep $epNum: $e');
      }
    }

    if (queued > 0) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.episodesQueuedForDownload(queued)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final glassEnabled = ref.watch(glassEffectsEnabledProvider);

    final radius = BorderRadius.circular(widget.isSheet ? 24 : 20);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final totalAssigned = _assignedSources.values.where((s) => s != null).length;

    return ClipRRect(
      borderRadius: radius,
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: radius,
        child: Container(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            widget.isSheet ? (bottomInset > 0 ? bottomInset + 12 : 20) : 20,
          ),
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
              // Grabber for sheet
              if (widget.isSheet) ...[
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],

              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.batchDownloadEpisodes,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.animeTitle,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.episodeNumbers.length} ${l10n.episodes.toLowerCase()} ${l10n.selectedEpisodesCount(widget.episodeNumbers.length)}'
                          '${_activeProvider != null ? ' • ${_activeProvider!.name}' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
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

              const SizedBox(height: 14),

              // Section: Video Servers with distinctive colors
              Text(
                l10n.selectPreferredServer,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.serverFallbackNotice,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),

              // Horizontal servers list
              if (_uniqueServers.isEmpty && _isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_uniqueServers.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    l10n.noSourceAvailable,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _uniqueServers.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final serverName = _uniqueServers[idx];
                      final isSelected = _preferredServer == serverName;
                      final availableCount = widget.episodeNumbers.where((ep) {
                        final srcs = _episodeSources[ep] ?? [];
                        return srcs.any((s) => s.server.trim().toUpperCase() == serverName);
                      }).length;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _onSelectPreferredServer(serverName),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? theme.colorScheme.primary.withValues(alpha: 0.18)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08)),
                                width: isSelected ? 1.4 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  serverName,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                        : (isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.07)),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$availableCount/${widget.episodeNumbers.length}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),

              // Section: Episode List with assigned server & source
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: widget.isSheet ? 260 : 320,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.episodeNumbers.length,
                    separatorBuilder: (context, index) => Divider(
                      height: 10,
                      thickness: 0.6,
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                    ),
                    itemBuilder: (context, index) {
                      final epNum = widget.episodeNumbers[index];
                      final assigned = _assignedSources[epNum];
                      final isEpLoading = _episodeLoading[epNum] ?? false;

                      final epData = widget.aniZipData?.episodes
                          .where((e) => e.episodeNumber == epNum)
                          .firstOrNull;
                      final thumbUrl = epData?.image;
                      final epTitle = epData?.displayTitle ?? l10n.episodeNumber(epNum);

                      return Row(
                        children: [
                          // Screencap or Ep tag
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 52,
                              height: 32,
                              child: thumbUrl != null && thumbUrl.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: thumbUrl,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: Center(
                                          child: Text('EP $epNum', style: const TextStyle(fontSize: 9)),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: Center(
                                        child: Text('EP $epNum', style: const TextStyle(fontSize: 9)),
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Episode title
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EP $epNum',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (epTitle.isNotEmpty)
                                  Text(
                                    epTitle,
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
                          // Server selector button
                          if (isEpLoading)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            GestureDetector(
                              onTap: () => _showChangeServerModalForEpisode(epNum),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: assigned != null
                                      ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                                      : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: assigned != null
                                        ? theme.colorScheme.outlineVariant.withValues(alpha: 0.4)
                                        : theme.colorScheme.error.withValues(alpha: 0.5),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      assigned != null
                                          ? assigned.displayLabel
                                          : l10n.noSourceAvailable,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: assigned != null
                                            ? theme.colorScheme.onSurface
                                            : theme.colorScheme.error,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Icons.arrow_drop_down_rounded,
                                      size: 16,
                                      color: assigned != null
                                          ? theme.colorScheme.onSurfaceVariant
                                          : theme.colorScheme.error,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Download CTA Button (Glass / Fluid styling)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: totalAssigned > 0 && !_isDownloading
                      ? _startBatchDownloads
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: totalAssigned > 0 && !_isDownloading
                          ? (glassEnabled
                              ? theme.colorScheme.primary.withValues(alpha: 0.88)
                              : theme.colorScheme.primary)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: totalAssigned > 0 && !_isDownloading
                            ? Colors.white.withValues(alpha: 0.25)
                            : Colors.transparent,
                        width: 1.0,
                      ),
                      boxShadow: totalAssigned > 0 && !_isDownloading
                          ? [
                              BoxShadow(
                                color: theme.colorScheme.primary.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          AppIcons.download(ref.watch(iconPackProvider)),
                          size: 18,
                          color: totalAssigned > 0 && !_isDownloading
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.startDownloadCount(totalAssigned),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: totalAssigned > 0 && !_isDownloading
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
