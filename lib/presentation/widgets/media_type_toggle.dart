import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Selector simple y elegante con Liquid Glass (`g1455` GlassMenuAnchor + GlassButton)
/// idéntico al selector de fuentes de streaming de anime detail.
class MediaTypeToggle extends ConsumerWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final bool showAnime;
  final bool showShows;
  final bool showManga;

  const MediaTypeToggle({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showAnime = true,
    this.showShows = false,
    this.showManga = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showAnime && !showShows && !showManga) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final types = <String>[
      if (showAnime) 'ANIME',
      if (showShows) 'SHOWS',
      if (showManga) 'MANGA',
    ];

    final IconData activeIcon;
    final String activeLabel;
    switch (selected) {
      case 'SHOWS':
        activeIcon = Icons.movie_filter_rounded;
        activeLabel = l10n.shows;
        break;
      case 'MANGA':
        activeIcon = Icons.menu_book_rounded;
        activeLabel = l10n.manga;
        break;
      case 'ANIME':
      default:
        activeIcon = AppIcons.play(iconPack);
        activeLabel = l10n.anime;
        break;
    }

    return GlassMenuAnchor(
      width: 170,
      items: types.map((type) {
        final IconData itemIcon;
        final String itemLabel;
        switch (type) {
          case 'SHOWS':
            itemIcon = Icons.movie_filter_rounded;
            itemLabel = l10n.shows;
            break;
          case 'MANGA':
            itemIcon = Icons.menu_book_rounded;
            itemLabel = l10n.manga;
            break;
          case 'ANIME':
          default:
            itemIcon = AppIcons.play(iconPack);
            itemLabel = l10n.anime;
            break;
        }

        final isCurrent = type == selected;

        return GlassMenuItem(
          label: itemLabel,
          icon: Icon(
            isCurrent ? Icons.check_circle_rounded : itemIcon,
            size: 18,
            color: isCurrent ? theme.colorScheme.primary : null,
          ),
          onPressed: () {
            onSelected(type);
          },
        );
      }).toList(),
      builder: (context, controller) {
        return GlassButton(
          onPressed: controller.open,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                activeIcon,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                activeLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 17,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ],
          ),
        );
      },
    );
  }
}
