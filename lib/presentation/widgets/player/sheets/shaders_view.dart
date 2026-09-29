import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';
import 'package:seanime_app/presentation/widgets/player/models/player_types.dart';

/// Subview for selecting GLSL enhancement shaders (Anime4K, NVScaler, ArtCNN).
/// OFF (Desactivado) by default as requested.
class ShadersView extends ConsumerWidget {
  final ShaderPreset activePreset;
  final bool isMpvActive;
  final ValueChanged<ShaderPreset> onPresetSelected;

  const ShadersView({
    super.key,
    required this.activePreset,
    required this.isMpvActive,
    required this.onPresetSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isMpvActive)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(AppIcons.info(iconPack),
                    color: Colors.amber, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.shadersRequireMpv,
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Container(
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
              itemCount: ShaderPreset.presets.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final preset = ShaderPreset.presets[index];
                final isSelected = preset.id == activePreset.id;

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onPresetSelected(preset),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            preset.isNone
                                ? AppIcons.power(iconPack)
                                : AppIcons.sparkles(iconPack),
                            size: 18,
                            color: isSelected ? primaryColor : Colors.white60,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        preset.isNone ? l10n.disabled : preset.name,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white70,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          fontSize: 13,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (preset.isNone) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: Colors.white12,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          l10n.offBadge,
                                          style: const TextStyle(
                                            color: Colors.white60,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    preset.description,
                                    style: TextStyle(
                                      color: isSelected
                                          ? primaryColor.withValues(alpha: 0.8)
                                          : Colors.white38,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(AppIcons.check(iconPack),
                                color: primaryColor, size: 18),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

