import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/online_stream_download_dialog.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_source_controller.dart';

/// Minimalist, clean streaming sources sheet with iOS Liquid Glass design (g1455).
/// Features a single cohesive container for options without individual boxes,
/// subtle checkmarks, and a clean "N options" header.
class PlayerSourceSelectorSheet extends ConsumerWidget {
  final PlayerSourceController? controller;
  final List<OnlinestreamVideoSource> availableSources;
  final OnlinestreamVideoSource? activeSource;
  final bool isResolvingSources;
  final String? sourceResolutionError;
  final String? providerName;
  final int? episodeNumber;
  final bool isDubbed;
  final VoidCallback? onToggleDubbed;
  final VoidCallback? onReloadSources;
  final ValueChanged<OnlinestreamVideoSource>? onSelectSource;
  final ValueChanged<String>? onSelectProvider;

  const PlayerSourceSelectorSheet({
    super.key,
    this.controller,
    required this.availableSources,
    this.activeSource,
    required this.isResolvingSources,
    this.sourceResolutionError,
    this.providerName,
    this.episodeNumber,
    this.isDubbed = false,
    this.onToggleDubbed,
    this.onReloadSources,
    this.onSelectSource,
    this.onSelectProvider,
  });

  static Future<void> show({
    required BuildContext context,
    PlayerSourceController? controller,
    required List<OnlinestreamVideoSource> availableSources,
    required OnlinestreamVideoSource? activeSource,
    required bool isResolvingSources,
    String? sourceResolutionError,
    String? providerName,
    int? episodeNumber,
    bool isDubbed = false,
    VoidCallback? onToggleDubbed,
    VoidCallback? onReloadSources,
    ValueChanged<OnlinestreamVideoSource>? onSelectSource,
    ValueChanged<String>? onSelectProvider,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showGlassSheet(
      context: context,
      finish: isDark ? GlassFinish.regularDark : GlassFinish.regularLight,
      showGrabber: true,
      builder: (modalCtx) => PlayerSourceSelectorSheet(
        controller: controller,
        availableSources: availableSources,
        activeSource: activeSource,
        isResolvingSources: isResolvingSources,
        sourceResolutionError: sourceResolutionError,
        providerName: providerName,
        episodeNumber: episodeNumber,
        isDubbed: isDubbed,
        onToggleDubbed: onToggleDubbed,
        onReloadSources: onReloadSources,
        onSelectSource: onSelectSource,
        onSelectProvider: onSelectProvider,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller!,
        builder: (ctx, _) => _buildContent(ctx, ref),
      );
    }
    return _buildContent(context, ref);
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final currentIsResolving = controller?.isResolvingSources ?? isResolvingSources;
    final currentSources = controller?.availableSources ?? availableSources;
    final currentActiveSource = controller?.activeSource ?? activeSource;
    final currentError = controller?.sourceResolutionError ?? sourceResolutionError;

    final isDark = theme.brightness == Brightness.dark;

    return Material(
      type: MaterialType.transparency,
      child: Container(
        // Translucent scrim to tone down excessive background transparency
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF14151B).withValues(alpha: 0.72)
              : theme.colorScheme.surface.withValues(alpha: 0.78),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top compact bar: Provider pills, Sub/Dub toggle & action buttons
                Row(
                  children: [
                    // Provider selector pills (if multiple exist)
                    if (onSelectProvider != null)
                      Expanded(
                        child: Consumer(
                          builder: (context, cRef, _) {
                            final providersAsync = cRef.watch(onlinestreamProvidersProvider);
                            return providersAsync.maybeWhen(
                              data: (providers) {
                                if (providers.isEmpty) return const SizedBox.shrink();
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: Row(
                                    children: providers.map((p) {
                                      final isSelected = (providerName != null &&
                                              providerName!.toLowerCase() == p.id.toLowerCase()) ||
                                          (providerName != null &&
                                              providerName!.toLowerCase() == p.name.toLowerCase());

                                      return Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(16),
                                            onTap: () {
                                              HapticFeedback.lightImpact();
                                              if (!isSelected) {
                                                onSelectProvider?.call(p.id);
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? theme.colorScheme.primary.withValues(alpha: 0.22)
                                                    : (isDark
                                                        ? Colors.white.withValues(alpha: 0.08)
                                                        : Colors.black.withValues(alpha: 0.05)),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? theme.colorScheme.primary.withValues(alpha: 0.85)
                                                      : (isDark
                                                          ? Colors.white.withValues(alpha: 0.12)
                                                          : Colors.black.withValues(alpha: 0.08)),
                                                  width: isSelected ? 1.2 : 0.8,
                                                ),
                                              ),
                                              child: Text(
                                                p.name.isNotEmpty ? p.name : p.id,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  color: isSelected
                                                      ? theme.colorScheme.primary
                                                      : theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                              orElse: () => const SizedBox.shrink(),
                            );
                          },
                        ),
                      )
                    else
                      const Spacer(),

                    // Dubbed / Subbed toggle
                    if (onToggleDubbed != null) ...[
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onToggleDubbed?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDubbed
                                  ? theme.colorScheme.primary.withValues(alpha: 0.22)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.05)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDubbed
                                    ? theme.colorScheme.primary.withValues(alpha: 0.85)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.12)
                                        : Colors.black.withValues(alpha: 0.08)),
                                width: isDubbed ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isDubbed ? AppIcons.voice(iconPack) : AppIcons.subtitles(iconPack),
                                  size: 14,
                                  color: isDubbed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isDubbed ? l10n.dub.toUpperCase() : l10n.sub.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isDubbed ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],

                    // Download stream action
                    IconButton(
                      icon: Icon(AppIcons.download(iconPack), size: 19, color: theme.colorScheme.onSurfaceVariant),
                      tooltip: l10n.downloadOnlineStream,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        final epNum = controller?.getEpisodeNumber() ?? episodeNumber ?? 1;
                        final animeTitle = controller?.title ?? '';
                        final epTitle = controller?.getEpisodeTitle() ?? '';
                        final thumb = controller
                            ?.getAnimeDetails()
                            ?.aniZipData
                            ?.episodes
                            .where((e) => e.episodeNumber == epNum)
                            .firstOrNull
                            ?.image;
                        showOnlineStreamDownloadDialog(
                          context,
                          mediaId: controller?.mediaId ?? 0,
                          episodeNumber: epNum,
                          animeTitle: animeTitle,
                          episodeTitle: epTitle,
                          thumbnail: thumb,
                          preloadedSources: currentSources,
                          isDubbed: isDubbed,
                        );
                      },
                    ),
                    const SizedBox(width: 4),

                    // Reload & Close actions
                    if (onReloadSources != null)
                      IconButton(
                        icon: Icon(AppIcons.refresh(iconPack), size: 19, color: theme.colorScheme.onSurfaceVariant),
                        tooltip: l10n.reloadSourcesTooltip,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          onReloadSources?.call();
                        },
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(AppIcons.close(iconPack), size: 19, color: theme.colorScheme.onSurfaceVariant),
                      tooltip: l10n.closeSettings,
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Sources list / loading / empty state
                if (currentIsResolving && currentSources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.searchingSources,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (currentSources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            AppIcons.searchOff(iconPack),
                            size: 34,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentError ?? l10n.noSourcesFoundForEpisode,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (onReloadSources != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                onReloadSources?.call();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      AppIcons.refresh(iconPack),
                                      size: 15,
                                      color: theme.colorScheme.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      l10n.retry,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                else ...[
                  // Small clean header: "N options" + subtle active loading indicator
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Text(
                          l10n.optionsCountLabel(currentSources.length),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (currentIsResolving) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Single unified container grouping all source rows (no individual cubes)
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.035),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.09)
                              : Colors.black.withValues(alpha: 0.08),
                          width: 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (currentIsResolving)
                            LinearProgressIndicator(
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
                              color: theme.colorScheme.primary,
                            ),
                          Flexible(
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const BouncingScrollPhysics(),
                              padding: EdgeInsets.zero,
                              itemCount: currentSources.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                thickness: 0.6,
                                indent: 14,
                                endIndent: 14,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.07)
                                    : Colors.black.withValues(alpha: 0.06),
                              ),
                              itemBuilder: (context, idx) {
                                final src = currentSources[idx];
                                final isActive = currentActiveSource != null &&
                                    (currentActiveSource.url == src.url ||
                                        (currentActiveSource.server == src.server &&
                                            currentActiveSource.quality == src.quality));

                                final hasQuality = src.quality.isNotEmpty && src.quality != 'auto';

                                return Material(
                                  color: isActive
                                      ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      if (!isActive && onSelectSource != null) {
                                        onSelectSource!(src);
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          // Server name and quality
                                          Expanded(
                                            child: Builder(
                                              builder: (context) {
                                                String serverName = src.server;
                                                String? audioBadge;
                                                Color? badgeColor;

                                                if (src.server.contains('[Latino]') || src.server.contains('(Latino)')) {
                                                  serverName = src.server
                                                      .replaceAll(' [Latino]', '')
                                                      .replaceAll('[Latino]', '')
                                                      .replaceAll('(Latino)', '')
                                                      .trim();
                                                  audioBadge = 'LATINO';
                                                  badgeColor = const Color(0xFF10B981);
                                                } else if (src.server.contains('[Castellano]') || src.server.contains('(Castellano)')) {
                                                  serverName = src.server
                                                      .replaceAll(' [Castellano]', '')
                                                      .replaceAll('[Castellano]', '')
                                                      .replaceAll('(Castellano)', '')
                                                      .trim();
                                                  audioBadge = 'CASTELLANO';
                                                  badgeColor = const Color(0xFFF59E0B);
                                                } else if (src.server.contains('[English Dub]') || src.server.contains('(English Dub)')) {
                                                  serverName = src.server
                                                      .replaceAll(' [English Dub]', '')
                                                      .replaceAll('[English Dub]', '')
                                                      .replaceAll('(English Dub)', '')
                                                      .trim();
                                                  audioBadge = 'ENGLISH';
                                                  badgeColor = const Color(0xFF3B82F6);
                                                } else if (src.server.contains('[Dub]') || src.server.contains('[DUB]') || src.server.contains('(Dub)')) {
                                                  serverName = src.server
                                                      .replaceAll(' [Dub]', '')
                                                      .replaceAll('[Dub]', '')
                                                      .replaceAll('[DUB]', '')
                                                      .replaceAll('(Dub)', '')
                                                      .trim();
                                                  audioBadge = 'DUB';
                                                  badgeColor = const Color(0xFF10B981);
                                                } else if (src.server.contains('[SUB]') || src.server.contains('[Sub (Multi)]')) {
                                                  serverName = src.server
                                                      .replaceAll(' [SUB]', '')
                                                      .replaceAll('[SUB]', '')
                                                      .replaceAll(' [Sub (Multi)]', '')
                                                      .trim();
                                                  audioBadge = 'SUB (MULTI)';
                                                  badgeColor = theme.colorScheme.primary;
                                                } else if (src.server.contains('[Sub]') || src.server.contains('(Sub)')) {
                                                  serverName = src.server
                                                      .replaceAll(' [Sub]', '')
                                                      .replaceAll('[Sub]', '')
                                                      .replaceAll('(Sub)', '')
                                                      .trim();
                                                  audioBadge = 'SUB';
                                                  badgeColor = theme.colorScheme.primary;
                                                }

                                                return Row(
                                                  children: [
                                                    Text(
                                                      serverName.toUpperCase(),
                                                      style: TextStyle(
                                                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                                        fontSize: 14,
                                                        letterSpacing: 0.2,
                                                        color: isActive
                                                            ? theme.colorScheme.primary
                                                            : theme.colorScheme.onSurface,
                                                      ),
                                                    ),
                                                    if (audioBadge != null) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: (badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.18),
                                                          borderRadius: BorderRadius.circular(5),
                                                          border: Border.all(
                                                            color: (badgeColor ?? theme.colorScheme.primary).withValues(alpha: 0.4),
                                                            width: 0.8,
                                                          ),
                                                        ),
                                                        child: Text(
                                                          audioBadge,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: badgeColor ?? theme.colorScheme.primary,
                                                            letterSpacing: 0.4,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                    if (hasQuality) ...[
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        src.quality,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isActive
                                                              ? theme.colorScheme.primary.withValues(alpha: 0.85)
                                                              : theme.colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                    if (src.isHls) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 4.5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: isDark
                                                              ? Colors.white.withValues(alpha: 0.08)
                                                              : Colors.black.withValues(alpha: 0.06),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'HLS',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                            color: theme.colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                          // Checkmark for selected item
                                          if (isActive)
                                            Icon(
                                              AppIcons.check(iconPack),
                                              size: 19,
                                              color: theme.colorScheme.primary,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
