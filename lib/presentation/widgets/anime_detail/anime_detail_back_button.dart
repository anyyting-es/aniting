import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:aniting/core/icons/app_icons.dart';

/// Shared back button for the anime detail screen.
///
/// Used by both the loading gate and the loaded mobile header so the control
/// never jumps position or changes shape between states.
class AnimeDetailBackButton extends ConsumerWidget {
  final Color color;
  final bool showShadow;
  final VoidCallback onPressed;

  const AnimeDetailBackButton({
    super.key,
    required this.color,
    required this.onPressed,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return M3EIconButton(
      variant: M3EIconButtonVariant.standard,
      size: M3EIconButtonSize.sm,
      tooltip: MaterialLocalizations.of(context).backButtonTooltip,
      icon: Icon(
        AppIcons.arrowLeft(ref.watch(iconPackProvider)),
        color: color,
        size: 22,
        shadows: showShadow
            ? const [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      onPressed: onPressed,
    );
  }
}
