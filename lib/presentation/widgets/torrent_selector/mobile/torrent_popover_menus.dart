import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/data/models/torrent_models.dart';
import 'package:seanime_app/presentation/widgets/torrent_selector/models/torrent_selector_helpers.dart';

/// Item de fila reutilizable para los menús popover de Liquid Glass.
class _PopoverRowItem extends StatelessWidget {
  final String title;
  final bool isSelected;
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;
  final AppIconPack iconPack;

  const _PopoverRowItem({
    required this.title,
    required this.isSelected,
    required this.icon,
    this.iconColor,
    required this.onTap,
    required this.iconPack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.primary
                    : (iconColor ?? theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isSelected)
                Icon(
                  AppIcons.check(iconPack),
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido del popover para seleccionar Proveedor de torrents.
class TorrentProviderPopoverContent extends ConsumerWidget {
  final List<AnimeTorrentProvider> providers;
  final String? selectedProviderId;
  final ValueChanged<String?> onProviderSelected;
  final VoidCallback onClose;

  const TorrentProviderPopoverContent({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.onProviderSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 280),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopoverRowItem(
                title: l10n.allProviders,
                isSelected: selectedProviderId == null,
                icon: AppIcons.globe(iconPack),
                iconPack: iconPack,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onProviderSelected(null);
                  onClose();
                },
              ),
              if (providers.isNotEmpty)
                const Divider(height: 6, indent: 8, endIndent: 8),
              ...providers.map((p) {
                final isSelected = selectedProviderId == p.id;
                return _PopoverRowItem(
                  title: p.name,
                  isSelected: isSelected,
                  icon: AppIcons.server(iconPack),
                  iconPack: iconPack,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onProviderSelected(p.id);
                    onClose();
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido del popover para seleccionar Episodio o Batches.
class TorrentEpisodePopoverContent extends ConsumerWidget {
  final int? currentEpisode;
  final int totalEpisodes;
  final ValueChanged<int?> onEpisodeSelected;
  final VoidCallback onClose;

  const TorrentEpisodePopoverContent({
    super.key,
    required this.currentEpisode,
    required this.totalEpisodes,
    required this.onEpisodeSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 300),
      child: Scrollbar(
        thumbVisibility: true,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PopoverRowItem(
                title: l10n.allBatches,
                isSelected: currentEpisode == null,
                icon: AppIcons.folderZip(iconPack),
                iconColor: Colors.purpleAccent,
                iconPack: iconPack,
                onTap: () {
                  HapticFeedback.lightImpact();
                  onEpisodeSelected(null);
                  onClose();
                },
              ),
              const Divider(height: 6, indent: 8, endIndent: 8),
              for (int ep = 1; ep <= totalEpisodes; ep++)
                _PopoverRowItem(
                  title: l10n.episodeNumber(ep),
                  isSelected: currentEpisode == ep,
                  icon: AppIcons.playCircle(iconPack),
                  iconPack: iconPack,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onEpisodeSelected(ep);
                    onClose();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenido del popover para seleccionar Calidad de video.
class TorrentQualityPopoverContent extends ConsumerWidget {
  final String selectedQuality;
  final ValueChanged<String> onQualitySelected;
  final VoidCallback onClose;

  const TorrentQualityPopoverContent({
    super.key,
    required this.selectedQuality,
    required this.onQualitySelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    const qualities = ['Todos', '1080p', '720p', '2160p / 4K', '480p'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: qualities.map((q) {
          final isSelected = selectedQuality == q;
          return _PopoverRowItem(
            title: q == 'Todos' ? l10n.filterAll : q,
            isSelected: isSelected,
            icon: AppIcons.sliders(iconPack),
            iconPack: iconPack,
            onTap: () {
              HapticFeedback.lightImpact();
              onQualitySelected(q);
              onClose();
            },
          );
        }).toList(),
      ),
    );
  }
}

/// Contenido del popover para seleccionar Criterio y Dirección de Ordenación.
class TorrentSortPopoverContent extends ConsumerWidget {
  final TorrentSortField sortField;
  final bool sortAscending;
  final ValueChanged<TorrentSortField> onSortFieldChanged;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onClose;

  const TorrentSortPopoverContent({
    super.key,
    required this.sortField,
    required this.sortAscending,
    required this.onSortFieldChanged,
    required this.onToggleSortDirection,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sortOptions = [
      (TorrentSortField.seeders, l10n.sortSeeders, AppIcons.sensors(iconPack)),
      (TorrentSortField.size, l10n.sortSize, AppIcons.storage(iconPack)),
      (TorrentSortField.date, l10n.sortDate, AppIcons.calendar(iconPack)),
      (TorrentSortField.resolution, l10n.sortResolution, AppIcons.highQuality(iconPack)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...sortOptions.map((opt) {
            final isSelected = sortField == opt.$1;
            return _PopoverRowItem(
              title: '${opt.$2} ${isSelected ? (sortAscending ? "↑" : "↓") : ""}',
              isSelected: isSelected,
              icon: opt.$3,
              iconPack: iconPack,
              onTap: () {
                HapticFeedback.lightImpact();
                if (isSelected) {
                  onToggleSortDirection();
                } else {
                  onSortFieldChanged(opt.$1);
                }
                onClose();
              },
            );
          }),
          const Divider(height: 6, indent: 8, endIndent: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () {
                HapticFeedback.selectionClick();
                onToggleSortDirection();
                onClose();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      sortAscending ? AppIcons.arrowUp(iconPack) : AppIcons.arrowDown(iconPack),
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sortAscending ? 'Ascendente (↑)' : 'Descendente (↓)',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
