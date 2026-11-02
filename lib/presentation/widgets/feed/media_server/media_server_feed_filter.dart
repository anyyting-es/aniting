import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/i18n/i18n_provider.dart';
import '../../../../core/media_servers/models/media_server_config.dart';
import '../../../../core/media_servers/models/media_server_type.dart';

enum FeedFilterMode {
  all,
  server,
  anime,
}

/// Compact Liquid Glass dropdown for filtering the feed between the server
/// library and the user's anime list.
class MediaServerFeedFilter extends ConsumerWidget {
  final FeedFilterMode mode;
  final ValueChanged<FeedFilterMode> onModeChanged;
  final MediaServerConfig? server;

  const MediaServerFeedFilter({
    super.key,
    required this.mode,
    required this.onModeChanged,
    this.server,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (server == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = ref.watch(translationsProvider);
    final isPlex = server!.type == MediaServerType.plex;

    String currentLabel;
    IconData currentIcon;
    Color currentColor;

    switch (mode) {
      case FeedFilterMode.all:
        currentLabel = l10n.feedFilterAll;
        currentIcon = LucideIcons.layers;
        currentColor = colorScheme.primary;
        break;
      case FeedFilterMode.server:
        currentLabel = server!.name;
        currentIcon = isPlex ? LucideIcons.tv : LucideIcons.film;
        currentColor = colorScheme.primary;
        break;
      case FeedFilterMode.anime:
        currentLabel = l10n.feedFilterAnimeOnly;
        currentIcon = LucideIcons.sparkles;
        currentColor = colorScheme.secondary;
        break;
    }

    Icon itemIcon({
      required IconData icon,
      required bool selected,
      required Color activeColor,
    }) {
      return Icon(
        selected ? LucideIcons.check : icon,
        size: 18,
        color: selected ? activeColor : null,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Align(
        alignment: Alignment.centerLeft,
        child: GlassMenuAnchor(
          width: 220,
          items: [
            GlassMenuItem(
              label: l10n.feedFilterAll,
              icon: itemIcon(
                icon: LucideIcons.layers,
                selected: mode == FeedFilterMode.all,
                activeColor: colorScheme.primary,
              ),
              onPressed: () => onModeChanged(FeedFilterMode.all),
            ),
            GlassMenuItem(
              label: server!.name,
              icon: itemIcon(
                icon: isPlex ? LucideIcons.tv : LucideIcons.film,
                selected: mode == FeedFilterMode.server,
                activeColor: colorScheme.primary,
              ),
              onPressed: () => onModeChanged(FeedFilterMode.server),
            ),
            GlassMenuItem(
              label: l10n.feedFilterAnimeOnly,
              icon: itemIcon(
                icon: LucideIcons.sparkles,
                selected: mode == FeedFilterMode.anime,
                activeColor: colorScheme.secondary,
              ),
              onPressed: () => onModeChanged(FeedFilterMode.anime),
            ),
          ],
          builder: (context, controller) {
            return GlassButton(
              onPressed: controller.open,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(currentIcon, size: 14, color: currentColor),
                  const SizedBox(width: 7),
                  Text(
                    currentLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(LucideIcons.chevronDown, size: 13),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
