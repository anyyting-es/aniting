import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/widgets/player/panels/player_source_selector_sheet.dart';

/// Compact, polished playback source card rendered in the player's info panel.
/// Adheres to Apple iOS Liquid Glass design standards (g1455 GlassCard/GlassSurface),
/// displaying the active server/quality, handling reload on demand, and opening
/// the liquid glass source selector sheet to switch stream providers or servers.
class PlayerSourceCard extends ConsumerWidget {
  final bool isResolvingSources;
  final List<OnlinestreamVideoSource> availableSources;
  final OnlinestreamVideoSource? activeSource;
  final String? sourceResolutionError;
  final String? providerName;
  final int? episodeNumber;
  final String? animeTitle;
  final VoidCallback? onReloadSources;
  final ValueChanged<OnlinestreamVideoSource>? onSelectSource;
  final ValueChanged<String>? onSelectProvider;

  const PlayerSourceCard({
    super.key,
    required this.isResolvingSources,
    this.availableSources = const [],
    this.activeSource,
    this.sourceResolutionError,
    this.providerName,
    this.episodeNumber,
    this.animeTitle,
    this.onReloadSources,
    this.onSelectSource,
    this.onSelectProvider,
  });

  void _showSourcesModal(BuildContext context) {
    HapticFeedback.lightImpact();
    PlayerSourceSelectorSheet.show(
      context: context,
      availableSources: availableSources,
      activeSource: activeSource,
      isResolvingSources: isResolvingSources,
      sourceResolutionError: sourceResolutionError,
      providerName: providerName,
      episodeNumber: episodeNumber,
      onReloadSources: onReloadSources,
      onSelectSource: onSelectSource,
      onSelectProvider: onSelectProvider,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final hasError = sourceResolutionError != null && sourceResolutionError!.isNotEmpty;
    final isPlayingActive = activeSource != null;

    final borderColor = hasError
        ? theme.colorScheme.error.withValues(alpha: 0.5)
        : (isResolvingSources
            ? theme.colorScheme.primary.withValues(alpha: 0.5)
            : theme.colorScheme.outlineVariant.withValues(alpha: 0.28));

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
                width: 0.9,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _showSourcesModal(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      // Status icon or loading indicator inside frosted capsule
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: hasError
                              ? theme.colorScheme.errorContainer.withValues(alpha: 0.45)
                              : (isResolvingSources
                                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.7)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: hasError
                                ? theme.colorScheme.error.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(alpha: 0.2),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: isResolvingSources
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : Icon(
                                  hasError ? Icons.warning_amber_rounded : Icons.stream_rounded,
                                  size: 19,
                                  color: hasError
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.primary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Main info column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    isResolvingSources
                                        ? l10n.searchingSources
                                        : (isPlayingActive
                                            ? activeSource!.server.toUpperCase()
                                            : (hasError
                                                ? l10n.noSourcesFoundForEpisode
                                                : l10n.playbackSources)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: hasError ? theme.colorScheme.error : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isPlayingActive &&
                                    activeSource!.quality.isNotEmpty &&
                                    activeSource!.quality != 'auto') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Text(
                                      activeSource!.quality,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (providerName != null && providerName!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '• $providerName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isResolvingSources
                                  ? '${l10n.searchingSources} • ${l10n.tapToChangeProvider}'
                                  : (hasError
                                      ? '${l10n.noSourcesFoundForEpisode} • ${l10n.tapToChangeProvider}'
                                      : (availableSources.isNotEmpty
                                          ? '${availableSources.length} ${l10n.availableSourcesCount} • ${l10n.tapToChangeSource}'
                                          : l10n.tapToChangeProvider)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: hasError
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Reload button
                      if (onReloadSources != null)
                        IconButton(
                          icon: Icon(
                            AppIcons.refresh(iconPack),
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          tooltip: l10n.reloadSourcesTooltip,
                          onPressed: isResolvingSources
                              ? null
                              : () {
                                  HapticFeedback.lightImpact();
                                  onReloadSources?.call();
                                },
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
