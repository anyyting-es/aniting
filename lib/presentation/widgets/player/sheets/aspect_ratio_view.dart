import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

class AspectRatioView extends ConsumerWidget {
  final PlayerFitMode currentFitMode;
  final ValueChanged<PlayerFitMode> onFitModeChanged;

  const AspectRatioView({
    super.key,
    required this.currentFitMode,
    required this.onFitModeChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF151518),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: PlayerFitMode.values.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final mode = PlayerFitMode.values[index];
            final isSelected = mode == currentFitMode;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onFitModeChanged(mode),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        mode.getIcon(iconPack),
                        color: isSelected ? primaryColor : Colors.white60,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          mode.localizedLabel(l10n),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(AppIcons.check(iconPack), color: primaryColor, size: 18),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
