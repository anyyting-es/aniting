import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Stepper moderno con estética Liquid Glass para Progreso (Episodios / Capítulos)
/// y Repeticiones (Rewatches / Rereads).
class EditEntryStepper extends StatelessWidget {
  final String label;
  final int value;
  final int? totalCount;
  final ValueChanged<int> onChanged;
  final IconData? icon;
  final BorderRadius borderRadius;

  const EditEntryStepper({
    super.key,
    required this.label,
    required this.value,
    this.totalCount,
    required this.onChanged,
    this.icon,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  void _step(int delta) {
    HapticFeedback.lightImpact();
    int newVal = value + delta;
    if (newVal < 0) newVal = 0;
    if (totalCount != null && totalCount! > 0 && newVal > totalCount!) {
      newVal = totalCount!;
    }
    onChanged(newVal);
  }

  void _promptDirectInput(BuildContext context) {
    final controller = TextEditingController(text: value.toString());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark
              ? theme.colorScheme.surfaceContainer
              : theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '0',
              suffixText: totalCount != null && totalCount! > 0 ? '/ $totalCount' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final entered = int.tryParse(controller.text.trim()) ?? value;
                Navigator.of(ctx).pop(entered);
              },
              child: const Text('Aceptar'),
            ),
          ],
        );
      },
    ).then((entered) {
      if (entered != null) {
        _step(entered - value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasTotal = totalCount != null && totalCount! > 0;
    final progressFraction = hasTotal ? (value / totalCount!).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 5),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (hasTotal) ...[
              const SizedBox(width: 8),
              Text(
                'Total: $totalCount',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 7),

        // Stepper Control Box
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.30)
                : Colors.white,
            borderRadius: borderRadius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.10),
              width: 1.0,
            ),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Subtle background progress fill if total is known
              if (hasTotal && progressFraction > 0.0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressFraction,
                    child: Container(
                      color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.06),
                    ),
                  ),
                ),

              // Content Row: [-] [Value] [+]
              Row(
                children: [
                  // Step Down Button [-]
                  _buildStepperButton(
                    theme: theme,
                    icon: Icons.remove_rounded,
                    onTap: value > 0 ? () => _step(-1) : null,
                  ),

                  // Center Value Display (Tap to input direct number)
                  Expanded(
                    child: InkWell(
                      onTap: () => _promptDirectInput(context),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              value.toString(),
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (hasTotal) ...[
                              const SizedBox(width: 3),
                              Text(
                                '/ $totalCount',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Step Up Button [+]
                  _buildStepperButton(
                    theme: theme,
                    icon: Icons.add_rounded,
                    onTap: (hasTotal && value >= totalCount!) ? null : () => _step(1),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepperButton({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 46,
          child: Center(
            child: Icon(
              icon,
              size: 20,
              color: isEnabled
                  ? (isDark ? Colors.white : theme.colorScheme.primary)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.20),
            ),
          ),
        ),
      ),
    );
  }
}
