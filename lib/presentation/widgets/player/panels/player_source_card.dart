import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';
import 'package:aniting/core/icons/app_icons.dart';
import 'package:aniting/core/player/stream_server_label.dart';
import 'package:aniting/data/models/onlinestream_models.dart';
import 'package:aniting/presentation/providers/app_providers.dart';
import 'package:aniting/presentation/widgets/player/models/player_types.dart';
import 'package:aniting/presentation/widgets/player/services/player_source_controller.dart';

/// Compact playback source card rendered in the player's watch content.
/// Tapping it opens a small web-style dropdown (g1455 GlassMenuAnchor) listing
/// the available servers so the user can switch without a full-screen modal.
class PlayerSourceCard extends ConsumerWidget {
  final PlayerSourceController? controller;
  final PlayerPlaybackOrigin playbackOrigin;
  final bool isResolvingSources;
  final List<OnlinestreamVideoSource> availableSources;
  final OnlinestreamVideoSource? activeSource;
  final String? sourceResolutionError;
  final String? providerName;
  final int? episodeNumber;
  final String? animeTitle;
  final bool isDubbed;
  final VoidCallback? onToggleDubbed;
  final VoidCallback? onReloadSources;
  final ValueChanged<OnlinestreamVideoSource>? onSelectSource;
  final ValueChanged<String>? onSelectProvider;

  const PlayerSourceCard({
    super.key,
    this.controller,
    this.playbackOrigin = PlayerPlaybackOrigin.online,
    required this.isResolvingSources,
    this.availableSources = const [],
    this.activeSource,
    this.sourceResolutionError,
    this.providerName,
    this.episodeNumber,
    this.animeTitle,
    this.isDubbed = false,
    this.onToggleDubbed,
    this.onReloadSources,
    this.onSelectSource,
    this.onSelectProvider,
  });

  String _serverLabel(OnlinestreamVideoSource src) => formatStreamServerLabel(
    src.server,
    quality: src.quality,
    includeQuality: true,
  );

  bool _isActive(OnlinestreamVideoSource src, OnlinestreamVideoSource? active) {
    if (active == null) return false;
    return active.url == src.url ||
        (active.server == src.server && active.quality == src.quality);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (controller != null) {
      return ListenableBuilder(
        listenable: controller!,
        builder: (ctx, _) => _buildWithMenu(ctx, ref),
      );
    }
    return _buildWithMenu(context, ref);
  }

  Widget _buildWithMenu(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final isOnline = playbackOrigin.isSwitchable;
    final sources = controller?.availableSources ?? availableSources;
    final active = controller?.activeSource ?? activeSource;

    if (!isOnline) {
      return _buildCardSurface(context, ref);
    }

    final providers = onSelectProvider == null
        ? const <OnlinestreamProvider>[]
        : ref
              .watch(onlinestreamProvidersProvider)
              .maybeWhen(
                data: (p) => p,
                orElse: () => const <OnlinestreamProvider>[],
              );

    if (sources.isEmpty && providers.length <= 1) {
      return _buildCardSurface(context, ref, onTap: onReloadSources);
    }

    return GlassMenuAnchor(
      width: 300,
      barrierLabel: l10n.selectServerQuality,
      items: [
        // This dropdown is intentionally server-only. Provider switching,
        // reloading and the dub toggle have their own affordances in the card.
        for (final src in sources)
          GlassMenuItem(
            label: _serverLabel(src),
            icon: Icon(
              _isActive(src, active)
                  ? AppIcons.check(iconPack)
                  : AppIcons.stream(iconPack),
              size: 18,
              color: _isActive(src, active) ? theme.colorScheme.primary : null,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (!_isActive(src, active)) onSelectSource?.call(src);
            },
          ),
      ],
      builder: (ctx, menu) => _buildCardSurface(ctx, ref, onTap: menu.open),
    );
  }

  bool _isProviderSelected(OnlinestreamProvider p) {
    final current = providerName?.toLowerCase();
    if (current == null) return false;
    return current == p.id.toLowerCase() || current == p.name.toLowerCase();
  }

  Widget _buildCardSurface(
    BuildContext context,
    WidgetRef ref, {
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final isOnline = playbackOrigin.isSwitchable;
    final currentIsResolving =
        isOnline && (controller?.isResolvingSources ?? isResolvingSources);
    final currentSources = controller?.availableSources ?? availableSources;
    final currentActiveSource = controller?.activeSource ?? activeSource;
    final currentError =
        controller?.sourceResolutionError ?? sourceResolutionError;

    final hasError =
        isOnline && currentError != null && currentError.isNotEmpty;
    final isPlayingActive = isOnline && currentActiveSource != null;

    final providers = !isOnline || onSelectProvider == null
        ? const <OnlinestreamProvider>[]
        : ref
              .watch(onlinestreamProvidersProvider)
              .maybeWhen(
                data: (p) => p,
                orElse: () => const <OnlinestreamProvider>[],
              );
    final selectedProvider = providers.where(_isProviderSelected).firstOrNull;
    final providerLabel = selectedProvider != null
        ? (selectedProvider.name.isNotEmpty
              ? selectedProvider.name
              : selectedProvider.id)
        : (providerName ?? '');

    // Non-online playback (local file / torrent stream) has nothing to select,
    // so it renders an informational, non-interactive card instead.
    final statusIcon = !isOnline
        ? (playbackOrigin == PlayerPlaybackOrigin.local
              ? AppIcons.downloadOffline(iconPack)
              : AppIcons.stream(iconPack))
        : (hasError ? AppIcons.error(iconPack) : AppIcons.stream(iconPack));

    final borderColor = hasError
        ? theme.colorScheme.error.withValues(alpha: 0.5)
        : (currentIsResolving
              ? theme.colorScheme.primary.withValues(alpha: 0.5)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.28));

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor, width: 0.9),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      // Status icon or loading indicator inside frosted capsule
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: hasError
                              ? theme.colorScheme.errorContainer.withValues(
                                  alpha: 0.45,
                                )
                              : (currentIsResolving
                                    ? theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.35)
                                    : theme.colorScheme.primaryContainer
                                          .withValues(alpha: 0.7)),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: hasError
                                ? theme.colorScheme.error.withValues(alpha: 0.3)
                                : theme.colorScheme.primary.withValues(
                                    alpha: 0.2,
                                  ),
                            width: 0.8,
                          ),
                        ),
                        child: Center(
                          child: currentIsResolving
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : Icon(
                                  statusIcon,
                                  size: 21,
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
                                    currentIsResolving
                                        ? l10n.searchingSources
                                        : (isPlayingActive
                                              ? formatStreamServerLabel(
                                                  currentActiveSource.server,
                                                ).toUpperCase()
                                              : (hasError
                                                    ? l10n.noSourcesFoundForEpisode
                                                    : (isOnline
                                                          ? l10n.playbackSources
                                                          : playbackOrigin
                                                                .localizedTitle(
                                                                  l10n,
                                                                )))),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14.5,
                                      color: hasError
                                          ? theme.colorScheme.error
                                          : theme.colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                                if (isPlayingActive &&
                                    currentActiveSource.quality.isNotEmpty &&
                                    currentActiveSource.quality != 'auto') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5.5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: theme.colorScheme.primary
                                            .withValues(alpha: 0.3),
                                        width: 0.7,
                                      ),
                                    ),
                                    child: Text(
                                      currentActiveSource.quality,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isOnline && providerLabel.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  _ProviderChip(
                                    label: providerLabel,
                                    providers: providers,
                                    providerName: providerName,
                                    onSelectProvider: onSelectProvider,
                                    iconPack: iconPack,
                                    tooltip: l10n.changeProvider,
                                  ),
                                ],
                                if (isOnline) ...[
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: isDubbed
                                        ? l10n.audioDubbed
                                        : l10n.audioSubtitled,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: onToggleDubbed == null
                                          ? null
                                          : () {
                                              HapticFeedback.lightImpact();
                                              onToggleDubbed!();
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isDubbed
                                              ? theme.colorScheme.primary
                                                    .withValues(alpha: 0.16)
                                              : Colors.white.withValues(
                                                  alpha: 0.08,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          isDubbed
                                              ? l10n.dub.toUpperCase()
                                              : l10n.sub.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: isDubbed
                                                ? theme.colorScheme.primary
                                                : Colors.white70,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              currentIsResolving
                                  ? '${l10n.searchingSources} • ${l10n.tapToChangeProvider}'
                                  : (hasError
                                        ? '${l10n.noSourcesFoundForEpisode} • ${l10n.tapToChangeProvider}'
                                        : (!isOnline
                                              ? playbackOrigin
                                                    .localizedSubtitle(l10n)
                                              : (currentSources.isNotEmpty
                                                    ? '${currentSources.length} ${l10n.availableSourcesCount} • ${l10n.tapToChangeSource}'
                                                    : l10n.tapToChangeProvider))),
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
                      if (isOnline && onReloadSources != null)
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
                      if (isOnline && onTap != null) ...[
                        const SizedBox(width: 4),
                        Icon(
                          AppIcons.chevronDown(iconPack),
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ],
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

/// Small provider chip shown in the source card. Tapping it opens a menu with
/// the installed providers, keeping provider switching out of the server list.
class _ProviderChip extends StatelessWidget {
  final String label;
  final List<OnlinestreamProvider> providers;
  final String? providerName;
  final ValueChanged<String>? onSelectProvider;
  final AppIconPack iconPack;
  final String tooltip;

  const _ProviderChip({
    required this.label,
    required this.providers,
    required this.providerName,
    required this.onSelectProvider,
    required this.iconPack,
    required this.tooltip,
  });

  bool _isSelected(OnlinestreamProvider provider) {
    final current = providerName?.toLowerCase();
    if (current == null) return false;
    return current == provider.id.toLowerCase() ||
        current == provider.name.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (onSelectProvider == null || providers.isEmpty) {
      return Text(
        '• $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return GlassMenuAnchor(
      width: 240,
      barrierLabel: tooltip,
      items: [
        for (final provider in providers)
          GlassMenuItem(
            label: provider.name.isNotEmpty ? provider.name : provider.id,
            icon: Icon(
              _isSelected(provider)
                  ? AppIcons.check(iconPack)
                  : AppIcons.globe(iconPack),
              size: 18,
              color: _isSelected(provider) ? theme.colorScheme.primary : null,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              if (!_isSelected(provider)) {
                onSelectProvider!.call(provider.id);
              }
            },
          ),
      ],
      builder: (context, menu) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: menu.open,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '• $label',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Icon(
                  AppIcons.arrowDropDown(iconPack),
                  size: 14,
                  color: theme.colorScheme.primary.withValues(alpha: 0.8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
