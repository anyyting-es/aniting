import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Subview for choosing playback speed rate.
class PlaybackSpeedView extends ConsumerWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedSelected;

  static const List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  const PlaybackSpeedView({
    super.key,
    required this.currentSpeed,
    required this.onSpeedSelected,
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
          itemCount: speeds.length,
          separatorBuilder: (context, index) =>
              const Divider(color: Colors.white10, height: 1),
          itemBuilder: (context, index) {
            final speed = speeds[index];
            final isSelected = (speed - currentSpeed).abs() < 0.05;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSpeedSelected(speed),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.speed(iconPack),
                        size: 18,
                        color: isSelected ? primaryColor : Colors.white60,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          speed == 1.0 ? '1.0x (${l10n.normal})' : '${speed}x',
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
