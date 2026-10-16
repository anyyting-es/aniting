import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/preferences/glass_theme_provider.dart';
import 'package:seanime_app/data/models/anizip_data.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/providers/online_stream_download_provider.dart';

const List<Color> _sourcePalette = [
  Color(0xFF00E5FF), // Cyan
  Color(0xFFFFB300), // Amber
  Color(0xFF00E676), // Emerald
  Color(0xFFB388FF), // Purple
  Color(0xFFFF4081), // Pink
  Color(0xFF448AFF), // Electric Blue
  Color(0xFFFF7043), // Coral Orange
  Color(0xFF64FFDA), // Mint
];

Color getSourceColor(int index) {
  return _sourcePalette[index % _sourcePalette.length];
}

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
  List<OnlinestreamProvider> _providers = [];
  OnlinestreamProvider? _selectedPreferredProvider;

  // Map of provider.id -> set of available episode numbers
  final Map<String, Set<int>> _providerAvailableEpisodes = {};
  final Map<String, bool> _providerLoadingStatus = {};

  // Map of episodeNumber -> assigned provider
  final Map<int, OnlinestreamProvider?> _assignedProviders = {};
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _loadProvidersAndEpisodes();
  }

  Future<void> _loadProvidersAndEpisodes() async {
    final repo = ref.read(repositoryProvider);
    try {
      final provList = await repo.getOnlinestreamProviders();
      if (!mounted) return;

      setState(() {
        _providers = provList;
        if (widget.initialProvider != null &&
            provList.any((p) => p.id == widget.initialProvider!.id)) {
          _selectedPreferredProvider = provList.firstWhere(
            (p) => p.id == widget.initialProvider!.id,
          );
        } else if (provList.isNotEmpty) {
          _selectedPreferredProvider = provList.first;
        }
      });

      // Fetch episode availability for each provider concurrently
      for (final p in provList) {
        _providerLoadingStatus[p.id] = true;
      }

      await Future.wait(
        provList.map((p) async {
          try {
            final eps = await repo.getOnlinestreamEpisodes(
              mediaId: widget.mediaId,
              provider: p.id,
              dubbed: widget.isDubbed,
            );
            if (mounted) {
              setState(() {
                _providerAvailableEpisodes[p.id] =
                    eps.map((e) => e.number).toSet();
                _providerLoadingStatus[p.id] = false;
                _recalculateAssignments();
              });
            }
          } catch (_) {
            if (mounted) {
              setState(() {
                _providerAvailableEpisodes[p.id] = {};
                _providerLoadingStatus[p.id] = false;
              });
            }
          }
        }),
      );
    } catch (e) {
      debugPrint('Error loading providers for batch download: $e');
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
    final preferred = _selectedPreferredProvider;
    for (final epNum in widget.episodeNumbers) {
      if (preferred != null &&
          (_providerAvailableEpisodes[preferred.id]?.contains(epNum) ?? false)) {
        _assignedProviders[epNum] = preferred;
      } else {
        // Fallback: Pick the first available alternative provider that has this episode
        OnlinestreamProvider? fallback;
        for (final p in _providers) {
          if (p.id != preferred?.id &&
              (_providerAvailableEpisodes[p.id]?.contains(epNum) ?? false)) {
            fallback = p;
            break;
          }
        }
        _assignedProviders[epNum] = fallback;
      }
    }
  }

  void _onSelectPreferredProvider(OnlinestreamProvider provider) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPreferredProvider = provider;
      _recalculateAssignments();
    });
  }

  void _showChangeProviderModalForEpisode(int epNum) {
    final l10n = ref.read(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => GlassCard(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        padding: EdgeInsets.zero,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                '${l10n.episodeNumber(epNum)} - ${l10n.source}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _providers.map((p) {
                  final idx = _providers.indexOf(p);
                  final color = getSourceColor(idx);
                  final hasEp =
                      _providerAvailableEpisodes[p.id]?.contains(epNum) ?? false;
                  final isAssigned = _assignedProviders[epNum]?.id == p.id;

                  return ActionChip(
                    avatar: CircleAvatar(
                      radius: 5,
                      backgroundColor: color,
                    ),
                    label: Text(
                      hasEp ? p.name : '${p.name} (N/A)',
                      style: TextStyle(
                        color: hasEp ? color : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: isAssigned ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    backgroundColor: isAssigned
                        ? color.withValues(alpha: 0.22)
                        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    side: BorderSide(
                      color: isAssigned ? color : color.withValues(alpha: 0.2),
                      width: isAssigned ? 1.5 : 0.8,
                    ),
                    onPressed: hasEp
                        ? () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _assignedProviders[epNum] = p;
                            });
                            Navigator.pop(ctx);
                          }
                        : null,
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
        .where((n) => _assignedProviders[n] != null)
        .toList();

    if (validToDownload.isEmpty) return;

    setState(() => _isDownloading = true);
    final l10n = ref.read(translationsProvider);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(repositoryProvider);
    final downloadNotifier = ref.read(onlineStreamDownloadProvider.notifier);

    Navigator.of(context).pop();

    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.downloadingEpisodesCount(validToDownload.length)),
        behavior: SnackBarBehavior.floating,
      ),
    );

    int queued = 0;
    for (final epNum in validToDownload) {
      final prov = _assignedProviders[epNum];
      if (prov == null) continue;

      try {
        final sources = await repo.getOnlinestreamSource(
          mediaId: widget.mediaId,
          episodeNumber: epNum,
          provider: prov.id,
          dubbed: widget.isDubbed,
          title: widget.animeTitle,
        );

        if (sources.isNotEmpty) {
          final chosen = sources.first;
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
            providerId: prov.id,
            providerName: prov.name,
          );

          if (res == DownloadStartResult.started) queued++;
        }
      } catch (e) {
        debugPrint('Error downloading batch episode $epNum from ${prov.name}: $e');
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

    // Count how many episodes are assigned to which provider
    final Map<String, int> providerCounts = {};
    for (final prov in _assignedProviders.values) {
      if (prov != null) {
        providerCounts[prov.id] = (providerCounts[prov.id] ?? 0) + 1;
      }
    }

    final totalAssigned = _assignedProviders.values.where((p) => p != null).length;

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
                          '${widget.episodeNumbers.length} ${l10n.episodes.toLowerCase()} ${l10n.selectedEpisodesCount(widget.episodeNumbers.length)}',
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

              // Section: Sources with distinctive colors
              Text(
                l10n.selectPreferredSource,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.sourceFallbackNotice,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 8),

              // Horizontal sources list
              if (_providers.isEmpty && _isLoading)
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
              else
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _providers.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, idx) {
                      final prov = _providers[idx];
                      final color = getSourceColor(idx);
                      final isSelected = _selectedPreferredProvider?.id == prov.id;
                      final availableCount = widget.episodeNumbers
                          .where((n) => _providerAvailableEpisodes[prov.id]?.contains(n) ?? false)
                          .length;

                      return GestureDetector(
                        onTap: () => _onSelectPreferredProvider(prov),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.22)
                                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? color : color.withValues(alpha: 0.3),
                              width: isSelected ? 1.6 : 0.8,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.35),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: color,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                prov.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? color : theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.black38 : Colors.white60,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$availableCount/${widget.episodeNumbers.length}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: availableCount == widget.episodeNumbers.length
                                        ? color
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

              const SizedBox(height: 14),

              // Section: Episode List with assigned sources
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
                      final assigned = _assignedProviders[epNum];
                      final provIndex = assigned != null ? _providers.indexOf(assigned) : -1;
                      final provColor = provIndex >= 0
                          ? getSourceColor(provIndex)
                          : theme.colorScheme.error;

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
                          const SizedBox(width: 8),

                          // Source pill button with distinctive color
                          GestureDetector(
                            onTap: () => _showChangeProviderModalForEpisode(epNum),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: assigned != null
                                    ? provColor.withValues(alpha: 0.16)
                                    : theme.colorScheme.errorContainer.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: assigned != null
                                      ? provColor.withValues(alpha: 0.7)
                                      : theme.colorScheme.error.withValues(alpha: 0.5),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: provColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    assigned?.name ?? l10n.noSourceAvailable,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: provColor,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 16,
                                    color: provColor,
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

              const SizedBox(height: 14),

              // Bottom summary chips
              if (providerCounts.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: providerCounts.entries.map((entry) {
                    final prov = _providers.firstWhere((p) => p.id == entry.key);
                    final idx = _providers.indexOf(prov);
                    final color = getSourceColor(idx);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 6, color: color),
                          const SizedBox(width: 4),
                          Text(
                            '${entry.value} ${prov.name}',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
              ],

              // Download CTA Button
              SizedBox(
                width: double.infinity,
                child: M3EButton(
                  style: M3EButtonStyle.filled,
                  size: M3EButtonSize.md,
                  onPressed: totalAssigned > 0 && !_isDownloading
                      ? _startBatchDownloads
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.download(ref.watch(iconPackProvider)), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        l10n.startDownloadCount(totalAssigned),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
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
