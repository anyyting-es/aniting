import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';

/// Minimalist, clean streaming sources sheet with iOS Liquid Glass design (g1455).
/// Features a single cohesive container for options without individual boxes,
/// subtle checkmarks, and a clean "N options" header.
class PlayerSourceSelectorSheet extends ConsumerWidget {
  final List<OnlinestreamVideoSource> availableSources;
  final OnlinestreamVideoSource? activeSource;
  final bool isResolvingSources;
  final String? sourceResolutionError;
  final String? providerName;
  final int? episodeNumber;
  final VoidCallback? onReloadSources;
  final ValueChanged<OnlinestreamVideoSource>? onSelectSource;
  final ValueChanged<String>? onSelectProvider;

  const PlayerSourceSelectorSheet({
    super.key,
    required this.availableSources,
    this.activeSource,
    required this.isResolvingSources,
    this.sourceResolutionError,
    this.providerName,
    this.episodeNumber,
    this.onReloadSources,
    this.onSelectSource,
    this.onSelectProvider,
  });

  static Future<void> show({
    required BuildContext context,
    required List<OnlinestreamVideoSource> availableSources,
    required OnlinestreamVideoSource? activeSource,
    required bool isResolvingSources,
    String? sourceResolutionError,
    String? providerName,
    int? episodeNumber,
    VoidCallback? onReloadSources,
    ValueChanged<OnlinestreamVideoSource>? onSelectSource,
    ValueChanged<String>? onSelectProvider,
  }) {
    return showGlassSheet(
      context: context,
      finish: GlassFinish.regularDark,
      showGrabber: true,
      builder: (modalCtx) => PlayerSourceSelectorSheet(
        availableSources: availableSources,
        activeSource: activeSource,
        isResolvingSources: isResolvingSources,
        sourceResolutionError: sourceResolutionError,
        providerName: providerName,
        episodeNumber: episodeNumber,
        onReloadSources: onReloadSources,
        onSelectSource: onSelectSource,
        onSelectProvider: onSelectProvider,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        // Dark translucent scrim to tone down excessive background transparency
        decoration: BoxDecoration(
          color: const Color(0xFF14151B).withValues(alpha: 0.72),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top compact bar: Provider pills & action buttons
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
                                                Navigator.pop(context);
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
                                                    : Colors.white.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: isSelected
                                                      ? theme.colorScheme.primary.withValues(alpha: 0.85)
                                                      : Colors.white.withValues(alpha: 0.12),
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
                                                      : Colors.white70,
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

                    // Reload & Close actions
                    if (onReloadSources != null)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 19, color: Colors.white70),
                        tooltip: l10n.reloadSourcesTooltip,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                          onReloadSources?.call();
                        },
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 19, color: Colors.white70),
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
                if (isResolvingSources)
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
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (availableSources.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.search_off_rounded,
                            size: 34,
                            color: Colors.white38,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            sourceResolutionError ?? l10n.noSourcesFoundForEpisode,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                          if (onReloadSources != null) ...[
                            const SizedBox(height: 12),
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
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
                                      Icons.refresh_rounded,
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
                  // Small clean header: "N options"
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      l10n.optionsCountLabel(availableSources.length),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),

                  // Single unified container grouping all source rows (no individual cubes)
                  Flexible(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                          width: 0.8,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.zero,
                        itemCount: availableSources.length,
                        separatorBuilder: (_, _) => Divider(
                          height: 1,
                          thickness: 0.6,
                          indent: 14,
                          endIndent: 14,
                          color: Colors.white.withValues(alpha: 0.07),
                        ),
                        itemBuilder: (context, idx) {
                          final src = availableSources[idx];
                          final isActive = activeSource != null &&
                              (activeSource!.url == src.url ||
                                  (activeSource!.server == src.server &&
                                      activeSource!.quality == src.quality));

                          final hasQuality = src.quality.isNotEmpty && src.quality != 'auto';

                          return Material(
                            color: isActive
                                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                Navigator.pop(context);
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

                                          if (src.server.contains('[Latino]')) {
                                            serverName = src.server.replaceAll(' [Latino]', '');
                                            audioBadge = 'LATINO';
                                            badgeColor = const Color(0xFF10B981);
                                          } else if (src.server.contains('[Castellano]')) {
                                            serverName = src.server.replaceAll(' [Castellano]', '');
                                            audioBadge = 'CASTELLANO';
                                            badgeColor = const Color(0xFFF59E0B);
                                          } else if (src.server.contains('[English Dub]')) {
                                            serverName = src.server.replaceAll(' [English Dub]', '');
                                            audioBadge = 'ENGLISH';
                                            badgeColor = const Color(0xFF3B82F6);
                                          } else if (src.server.contains('[SUB]')) {
                                            serverName = src.server.replaceAll(' [SUB]', '');
                                            audioBadge = 'SUB (MULTI)';
                                            badgeColor = theme.colorScheme.primary;
                                          } else if (src.server.contains('[Sub]')) {
                                            serverName = src.server.replaceAll(' [Sub]', '');
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
                                                  color: isActive ? theme.colorScheme.primary : Colors.white,
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
                                                        : Colors.white54,
                                                  ),
                                                ),
                                              ],
                                              if (src.isHls) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 4.5, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.08),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'HLS',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white70,
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
                                        Icons.check_rounded,
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
