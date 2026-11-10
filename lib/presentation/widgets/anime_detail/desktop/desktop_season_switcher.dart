import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/i18n/i18n_provider.dart';

/// Horizontal season selector used by the shared show detail view.
///
/// It only renders when the data source exposes more than one season.
class DesktopSeasonSwitcher extends ConsumerWidget {
  final List<int> seasons;
  final int selectedSeason;
  final ValueChanged<int> onSeasonChanged;

  const DesktopSeasonSwitcher({
    super.key,
    required this.seasons,
    required this.selectedSeason,
    required this.onSeasonChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(translationsProvider);
    if (seasons.isEmpty) return const SizedBox.shrink();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < seasons.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            M3EButton(
              onPressed: () => onSeasonChanged(seasons[i]),
              style: seasons[i] == selectedSeason
                  ? M3EButtonStyle.filled
                  : M3EButtonStyle.outlined,
              size: M3EButtonSize.sm,
              shape: M3EButtonShape.round,
              child: Text(
                seasons[i] == 0
                    ? l10n.specials
                    : '${l10n.season} ${seasons[i]}',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
