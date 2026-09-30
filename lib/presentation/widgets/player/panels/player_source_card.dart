import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/core/theme/app_theme_colors.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';

/// Compact, polished playback source card rendered in the player's info panel.
/// Shows the active server/quality, handles reloading sources on demand,
/// and allows opening an in-player modal to pick alternative servers/qualities.
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
  });

  void _showSourcesModal(BuildContext context, AppTranslations l10n) {
    if (availableSources.isEmpty) {
      if (sourceResolutionError != null && onReloadSources != null) {
        onReloadSources!();
      }
      return;
    }

    final theme = Theme.of(context);
    final borderRadius = context.themeColors.borderRadius;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(borderRadius.clamp(16.0, 24.0))),
      ),
      builder: (modalCtx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
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
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.settings_input_composite_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.playbackSources,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            episodeNumber != null
                                ? '${l10n.episode} $episodeNumber • ${availableSources.length} ${l10n.availableSourcesCount}'
                                : '${availableSources.length} ${l10n.availableSourcesCount}',
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
                    if (onReloadSources != null)
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                        tooltip: l10n.reloadSourcesTooltip,
                        onPressed: () {
                          Navigator.pop(modalCtx);
                          onReloadSources!();
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 8),
                // Sources list
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: availableSources.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (context, idx) {
                      final src = availableSources[idx];
                      final isActive = activeSource != null &&
                          (activeSource!.url == src.url ||
                              (activeSource!.server == src.server &&
                                  activeSource!.quality == src.quality));

                      return Material(
                        color: isActive
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                            : theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(borderRadius),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(borderRadius),
                          onTap: () {
                            Navigator.pop(modalCtx);
                            if (!isActive && onSelectSource != null) {
                              onSelectSource!(src);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(borderRadius),
                              border: Border.all(
                                color: isActive
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                                width: isActive ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: isActive
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.surfaceContainerHighest,
                                  child: Icon(
                                    isActive ? Icons.play_arrow_rounded : Icons.dns_rounded,
                                    size: 18,
                                    color: isActive
                                        ? theme.colorScheme.onPrimary
                                        : theme.colorScheme.onSurfaceVariant,
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
                                            src.server.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isActive ? theme.colorScheme.primary : null,
                                            ),
                                          ),
                                          if (src.isHls) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 5, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.tertiaryContainer,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'HLS',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme.onTertiaryContainer,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        src.quality.isNotEmpty && src.quality != 'auto'
                                            ? '${l10n.quality}: ${src.quality}'
                                            : l10n.server,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isActive)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 20,
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final borderRadius = context.themeColors.borderRadius;

    final hasError = sourceResolutionError != null && sourceResolutionError!.isNotEmpty;
    final isPlayingActive = activeSource != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(borderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(borderRadius),
          onTap: () => _showSourcesModal(context, l10n),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: hasError
                    ? theme.colorScheme.error.withValues(alpha: 0.5)
                    : (isResolvingSources
                        ? theme.colorScheme.primary.withValues(alpha: 0.45)
                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.28)),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Status icon or loading indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: hasError
                        ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
                        : (isResolvingSources
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                            : theme.colorScheme.primaryContainer),
                    borderRadius: BorderRadius.circular(8),
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
                            size: 18,
                            color: hasError
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary,
                          ),
                  ),
                ),
                const SizedBox(width: 10),
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
                                fontSize: 13,
                                color: hasError ? theme.colorScheme.error : null,
                              ),
                            ),
                          ),
                          if (isPlayingActive &&
                              activeSource!.quality.isNotEmpty &&
                              activeSource!.quality != 'auto') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
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
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isResolvingSources
                            ? l10n.playingFirstAvailable
                            : (hasError
                                ? sourceResolutionError!
                                : (availableSources.isNotEmpty
                                    ? '${availableSources.length} ${l10n.availableSourcesCount} • ${l10n.tapToChangeSource}'
                                    : l10n.tapToChangeSource)),
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
                    onPressed: isResolvingSources ? null : onReloadSources,
                  ),
                const SizedBox(width: 4),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
