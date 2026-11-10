
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aniting/core/i18n/translations/translations.dart';

/// Stepper compacto estilo web para Progreso / Repeticiones.
/// Botones `- / +` con feedback de hover, relleno de avance sutil y
/// número central con transición animada (tap para entrada directa).
class EditEntryStepper extends StatelessWidget {
  final String label;
  final int value;
  final int? totalCount;
  final ValueChanged<int> onChanged;
  final IconData? icon;
  final AppTranslations? l10n;

  /// Cuando es `true`, usa colores glass translúcidos (blancos alfa)
  /// adaptados al fondo del preview inmersivo.
  final bool glass;

  const EditEntryStepper({
    super.key,
    required this.label,
    required this.value,
    this.totalCount,
    required this.onChanged,
    this.icon,
    this.l10n,
    this.glass = false,
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

    showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surfaceContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '0',
              suffixText: totalCount != null && totalCount! > 0 ? '/ $totalCount' : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final entered = int.tryParse(controller.text.trim()) ?? value;
                Navigator.of(ctx).pop(entered);
              },
              child: Text(l10n?.save ?? 'Save'),
            ),
          ],
        );
      },
    ).then((entered) {
      if (entered != null) {
        onChanged(entered.clamp(0, totalCount ?? 1 << 30));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = this.glass;
    final hasTotal = totalCount != null && totalCount! > 0;
    final progressFraction = hasTotal ? (value / totalCount!).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel(
          icon: icon,
          label: label,
          trailing: hasTotal ? '${l10n?.total ?? 'Total'} $totalCount' : null,
          glass: glass,
        ),
        const SizedBox(height: 6),
        Container(
          height: 40,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: glass
                ? Colors.white.withValues(alpha: 0.06)
                : theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65,
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: glass
                  ? Colors.white.withValues(alpha: 0.16)
                  : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              if (hasTotal && progressFraction > 0.0)
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progressFraction,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      color: theme.colorScheme.primary.withValues(
                        alpha: glass ? 0.20 : (theme.brightness == Brightness.dark ? 0.13 : 0.09),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  _StepperButton(
                    icon: Icons.remove_rounded,
                    onTap: value > 0 ? () => _step(-1) : null,
                    glass: glass,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => _promptDirectInput(context),
                      borderRadius: BorderRadius.circular(6),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            // Transición suave al cambiar el número.
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, anim) => FadeTransition(
                                opacity: anim,
                                child: ScaleTransition(scale: anim, child: child),
                              ),
                              child: Text(
                                value.toString(),
                                key: ValueKey(value),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                  color: glass
                                      ? Colors.white.withValues(alpha: 0.95)
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (hasTotal) ...[
                              const SizedBox(width: 3),
                              Text(
                                '/ $totalCount',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: glass
                                      ? Colors.white.withValues(alpha: 0.55)
                                      : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  _StepperButton(
                    icon: Icons.add_rounded,
                    onTap: (hasTotal && value >= totalCount!) ? null : () => _step(1),
                    glass: glass,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón lateral del stepper con estado de hover animado.
class _StepperButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool glass;

  const _StepperButton({required this.icon, required this.onTap, this.glass = false});

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = widget.onTap != null;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => enabled ? setState(() => _hovered = true) : null,
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 38,
          height: 40,
          alignment: Alignment.center,
          color: _hovered && enabled
              ? (widget.glass
                  ? Colors.white.withValues(alpha: 0.10)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 17,
            color: enabled
                ? (widget.glass
                    ? Colors.white.withValues(alpha: 0.9)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.85))
                : (widget.glass
                    ? Colors.white.withValues(alpha: 0.22)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.18)),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta compartida minimalist de cada campo (alineada a la grilla).
class _FieldLabel extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String? trailing;
  final bool glass;

  const _FieldLabel({this.icon, required this.label, this.trailing, this.glass = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = glass
        ? Colors.white.withValues(alpha: 0.62)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85);
    final trailingColor = glass
        ? Colors.white.withValues(alpha: 0.42)
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);
    return SizedBox(
      height: 18,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: labelColor),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(
              trailing!,
              style: TextStyle(
                color: trailingColor,
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
