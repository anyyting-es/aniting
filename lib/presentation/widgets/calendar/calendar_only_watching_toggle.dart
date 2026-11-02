import 'package:flutter/material.dart';

/// Explicit switch control for filtering only currently watching/repeating anime.
///
/// Uses a real switch widget so the ON/OFF state is unmistakable at a glance.
class CalendarOnlyWatchingToggle extends StatelessWidget {
  final bool value;
  final String label;
  final bool showLabel;
  final ValueChanged<bool> onChanged;

  const CalendarOnlyWatchingToggle({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final labelWidget = Text(
      label,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: value ? FontWeight.w700 : FontWeight.w500,
        letterSpacing: -0.1,
        color: value
            ? (isDark ? Colors.white : theme.colorScheme.onSurface)
            : (isDark
                ? Colors.white.withValues(alpha: 0.65)
                : theme.colorScheme.onSurfaceVariant),
      ),
    );

    final switchWidget = Transform.scale(
      scale: 0.78,
      child: Switch(
        value: value,
        onChanged: onChanged,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        activeThumbColor: theme.colorScheme.primary,
        activeTrackColor: theme.colorScheme.primary.withValues(alpha: 0.32),
        inactiveThumbColor: isDark
            ? Colors.white.withValues(alpha: 0.6)
            : theme.colorScheme.outline,
        inactiveTrackColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : theme.colorScheme.surfaceContainerHighest,
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return theme.colorScheme.primary.withValues(alpha: 0.5);
          }
          return isDark
              ? Colors.white.withValues(alpha: 0.12)
              : theme.colorScheme.outlineVariant;
        }),
      ),
    );

    final content = InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showLabel) ...[
              labelWidget,
              const SizedBox(width: 4),
            ],
            switchWidget,
          ],
        ),
      ),
    );

    if (showLabel) return content;
    return Tooltip(message: label, child: content);
  }
}
