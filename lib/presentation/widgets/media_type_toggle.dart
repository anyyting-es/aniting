import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Hybrid Material 3 Expressive Split Button with Liquid Glass (`g1455`)
/// for selecting media type (Anime, Shows, Manga).
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

    if (!types.contains(selected) && types.isNotEmpty) {
      // Fallback if selected is not in allowed types
    }

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

    final glassBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40);
    final glassTrailingBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    final glassBorder = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.35);
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : theme.colorScheme.outlineVariant.withValues(alpha: 0.28);

    return GlassCard(
      borderRadius: BorderRadius.circular(100),
      padding: EdgeInsets.zero,
      child: M3ESplitButton<String>(
        label: activeLabel,
        leadingIcon: activeIcon,
        style: M3EButtonStyle.tonal,
        size: M3EButtonSize.sm,
        shape: M3EButtonShape.round,
        trailingAlignment: M3ESplitButtonTrailingAlignment.opticalCenter,
        enabled: true,
        selectedValue: selected,
        onPressed: () {
          if (types.length <= 1) return;
          final currentIndex = types.indexOf(selected);
          final nextIndex = (currentIndex + 1) % types.length;
          onSelected(types[nextIndex]);
        },
        onSelected: (String val) {
          onSelected(val);
        },
        decoration: M3ESplitButtonDecoration.styleFrom(
          backgroundColor: glassBg,
          trailingBackgroundColor: glassTrailingBg,
          foregroundColor: isDark ? Colors.white : theme.colorScheme.onSurface,
          trailingForegroundColor:
              isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant,
          dividerColor: dividerColor,
          side: BorderSide(
            color: glassBorder,
            width: 1.0,
          ),
          menuStyle: M3ESplitButtonMenuStyle.popup,
          popupDecoration: M3ESplitButtonPopupDecoration(
            backgroundColor: isDark
                ? const Color(0xFF16161A).withValues(alpha: 0.94)
                : Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: glassBorder,
              width: 1.0,
            ),
            elevation: 8,
            minWidth: 150,
          ),
        ),
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

          return M3ESplitButtonItem<String>(
            value: type,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  itemIcon,
                  size: 16,
                  color: isCurrent ? theme.colorScheme.primary : null,
                ),
                const SizedBox(width: 8),
                Text(
                  itemLabel,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    color: isCurrent ? theme.colorScheme.primary : null,
                  ),
                ),
                if (isCurrent) ...[
                  const Spacer(),
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
