import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/onlinestream_models.dart';
import 'package:seanime_app/presentation/providers/app_providers.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';
import 'package:seanime_app/presentation/widgets/player/services/player_source_controller.dart';

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

  String _serverLabel(OnlinestreamVideoSource src) {
    var name = src.server;
    const tags = [
      '[Latino]', '(Latino)', '[Castellano]', '(Castellano)',
      '[English Dub]', '(English Dub)', '[Dub]', '[DUB]', '(Dub)',
      '[Sub (Multi)]', '[SUB]', '[Sub]', '(Sub)',
    ];
    for (final tag in tags) {
      name = name.replaceAll(tag, '');
    }
    name = name.trim();
    final label = name.isEmpty ? src.server : name;
    final quality = (src.quality.isNotEmpty && src.quality != 'auto')
        ? ' • ${src.quality}'
        : '';
    return '$label$quality';
  }

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
        : ref.watch(onlinestreamProvidersProvider).maybeWhen(
              data: (p) => p,
              orElse: () => const <OnlinestreamProvider>[],
            );

    if (sources.isEmpty && providers.length <= 1) {
      return _buildCardSurface(context, ref, onTap: onReloadSources);
    }

    return MenuAnchor(
      menuChildren: [
        if (providers.length > 1) ...[
          for (final p in providers)
            MenuItemButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                final isSel = providerName != null &&
                    (providerName!.toLowerCase() == p.id.toLowerCase() ||
                        providerName!.toLowerCase() == p.name.toLowerCase());
                if (!isSel) onSelectProvider!.call(p.id);
              },
              leadingIcon: Icon(
                _isProviderSelected(p)
                    ? AppIcons.check(iconPack)
                    : AppIcons.stream(iconPack),
                size: 18,
              ),
              child: Text(p.name.isNotEmpty ? p.name : p.id),
            ),
          const Divider(height: 1),
        ],
        for (final src in sources)
          MenuItemButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              if (!_isActive(src, active)) onSelectSource?.call(src);
            },
            leadingIcon: Icon(
              _isActive(src, active)
                  ? AppIcons.check(iconPack)
                  : AppIcons.stream(iconPack),
              size: 18,
              color: _isActive(src, active) ? theme.colorScheme.primary : null,
            ),
            child: Text(_serverLabel(src)),
          ),
        if (onReloadSources != null)
          MenuItemButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onReloadSources!.call();
            },
            leadingIcon: Icon(AppIcons.refresh(iconPack), size: 18),
            child: Text(l10n.reloadSourcesTooltip),
          ),
        if (onToggleDubbed != null)
          MenuItemButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              onToggleDubbed!.call();
            },
            leadingIcon: Icon(AppIcons.audio(iconPack), size: 18),
            child: Text(isDubbed ? l10n.audioDubbed : l10n.audioSubtitled),
          ),
      ],
      builder: (ctx, menu, child) => _buildCardSurface(
        ctx,
        ref,
        onTap: () => menu.isOpen ? menu.close() : menu.open(),
      ),
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
    final currentIsResolving = isOnline && (controller?.isResolvingSources ?? isResolvingSources);
    final currentSources = controller?.availableSources ?? availableSources;
    final currentActiveSource = controller?.activeSource ?? activeSource;
    final currentError = controller?.sourceResolutionError ?? sourceResolutionError;

    final hasError = isOnline && currentError != null && currentError.isNotEmpty;
    final isPlayingActive = isOnline && currentActiveSource != null;

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
              border: Border.all(
                color: borderColor,
                width: 0.9,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
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
                              : (currentIsResolving
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
                                    currentIsResolving
                                        ? l10n.searchingSources
                                        : (isPlayingActive
                                            ? () {
                                                final srv = currentActiveSource.server;
                                                if (srv.contains('[Latino]')) return '${srv.replaceAll(' [Latino]', '')} • LATINO';
                                                if (srv.contains('[Castellano]')) return '${srv.replaceAll(' [Castellano]', '')} • CASTELLANO';
                                                if (srv.contains('[English Dub]')) return '${srv.replaceAll(' [English Dub]', '')} • ENGLISH';
                                                if (srv.contains('[SUB]')) return '${srv.replaceAll(' [SUB]', '')} • SUB (MULTI)';
                                                if (srv.contains('[Sub]')) return '${srv.replaceAll(' [Sub]', '')} • SUB';
                                                return srv.toUpperCase();
                                              }()
                                            : (hasError
                                                ? l10n.noSourcesFoundForEpisode
                                                : (isOnline
                                                    ? l10n.playbackSources
                                                    : playbackOrigin.localizedTitle(l10n)))),
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
                                    currentActiveSource.quality.isNotEmpty &&
                                    currentActiveSource.quality != 'auto') ...[
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
                                      currentActiveSource.quality,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                                if (isOnline &&
                                    providerName != null &&
                                    providerName!.isNotEmpty) ...[
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
                                if (isOnline) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isDubbed
                                          ? theme.colorScheme.primary.withValues(alpha: 0.16)
                                          : Colors.white.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isDubbed ? l10n.dub.toUpperCase() : l10n.sub.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.bold,
                                        color: isDubbed ? theme.colorScheme.primary : Colors.white70,
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
                                          ? playbackOrigin.localizedSubtitle(l10n)
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
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
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
