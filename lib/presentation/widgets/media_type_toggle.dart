import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';

class MediaTypeToggle extends ConsumerWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final bool showAnime;
  final bool showManga;

  const MediaTypeToggle({
    super.key,
    required this.selected,
    required this.onSelected,
    this.showAnime = true,
    this.showManga = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!showAnime && !showManga) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = ref.watch(translationsProvider);
    final isAnime = selected == 'ANIME';

    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAnime)
            _buildSegment(
              context: context,
              label: l10n.anime,
              icon: Icons.play_circle_outline_rounded,
              isSelected: isAnime || !showManga,
              onTap: () => onSelected('ANIME'),
            ),
          if (showManga)
            _buildSegment(
              context: context,
              label: l10n.manga,
              icon: Icons.menu_book_rounded,
              isSelected: !isAnime || !showAnime,
              onTap: () => onSelected('MANGA'),
            ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                softWrap: false,
                maxLines: 1,
                overflow: TextOverflow.visible,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
