
import 'package:flutter/material.dart';
import 'package:aniting/core/i18n/translations/translations.dart';

/// Campo de fecha compacto estilo web: hover con borde de acento,
/// botón de limpiar que aparece al pasar el cursor y tipografía mono-espaciada
/// mediante cifras tabulares para la fecha.
class EditEntryDatePicker extends StatefulWidget {
  final String label;
  final String? dateLabel; // Fecha ya formateada (yyyy-MM-dd) o null
  final VoidCallback onPick;
  final VoidCallback onClear;
  final AppTranslations l10n;

  /// Cuando es `true`, usa colores glass translúcidos (blancos alfa)
  /// adaptados al fondo del preview inmersivo.
  final bool glass;

  const EditEntryDatePicker({
    super.key,
    required this.label,
    required this.dateLabel,
    required this.onPick,
    required this.onClear,
    required this.l10n,
    this.glass = false,
  });

  @override
  State<EditEntryDatePicker> createState() => _EditEntryDatePickerState();
}

class _EditEntryDatePickerState extends State<EditEntryDatePicker> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasDate = widget.dateLabel != null;
    final glass = widget.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 18,
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 12,
                color: glass
                    ? Colors.white.withValues(alpha: 0.62)
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: glass
                        ? Colors.white.withValues(alpha: 0.62)
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPick,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: glass
                    ? Colors.white
                        .withValues(alpha: _isHovered ? 0.10 : 0.06)
                    : theme.colorScheme.surfaceContainerHigh.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65,
                      ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isHovered && hasDate
                      ? theme.colorScheme.primary.withValues(alpha: 0.6)
                      : glass
                          ? Colors.white.withValues(alpha: 0.16)
                          : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  width: _isHovered && hasDate ? 1.3 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.dateLabel ?? widget.l10n.selectDate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: hasDate ? FontWeight.w600 : FontWeight.w500,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: hasDate
                            ? (glass
                                ? Colors.white.withValues(alpha: 0.95)
                                : theme.colorScheme.onSurface)
                            : (glass
                                ? Colors.white.withValues(alpha: 0.55)
                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                      ),
                    ),
                  ),
                  // Botón de limpiar: solo visible con fecha y al hacer hover.
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 130),
                    opacity: _isHovered && hasDate ? 1 : 0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 130),
                      width: hasDate ? 22 : 0,
                      child: hasDate
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _isHovered ? widget.onClear : null,
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: glass
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
