import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

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

    int selectedIndex = types.indexOf(selected);
    if (selectedIndex < 0) selectedIndex = 0;

    final double toggleWidth = types.length * 92.0;

    return SizedBox(
      width: toggleWidth,
      child: GlassSegmentedControl(
        selectedIndex: selectedIndex,
        onSelected: (idx) {
          if (idx >= 0 && idx < types.length) {
            onSelected(types[idx]);
          }
        },
        trackColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        thumbColor: isDark
            ? theme.colorScheme.surfaceContainerHighest
            : Colors.white,
        segments: types.map((type) {
          final isCurrent = selected == type;
          final IconData icon;
          final String label;

          switch (type) {
            case 'SHOWS':
              icon = Icons.movie_filter_rounded;
              label = l10n.shows;
              break;
            case 'MANGA':
              icon = Icons.menu_book_rounded;
              label = l10n.manga;
              break;
            case 'ANIME':
            default:
              icon = AppIcons.play(iconPack);
              label = l10n.anime;
              break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13.5,
                  color: isCurrent
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    color: isCurrent
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white60 : Colors.black54),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

