
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aniting/core/i18n/translations/translations.dart';

/// Slider de puntaje estilo web: pista fina, relleno animado y thumb
/// pequeño; sin el `Slider` de Material. El badge muestra el valor actual
/// y permite entrada decimal directa al tocar.
class EditEntryScoreSlider extends StatefulWidget {
  final double score; // 0.0 to 10.0
  final ValueChanged<double> onChanged;
  final AppTranslations l10n;

  /// Cuando es `true`, usa colores glass translúcidos (blancos alfa)
  /// adaptados al fondo del preview inmersivo.
  final bool glass;

  const EditEntryScoreSlider({
    super.key,
    required this.score,
    required this.onChanged,
    required this.l10n,
    this.glass = false,
  });

  @override
  State<EditEntryScoreSlider> createState() => _EditEntryScoreSliderState();
}

class _EditEntryScoreSliderState extends State<EditEntryScoreSlider> {
  bool _dragging = false;

  void _adjustScore(double delta) {
    HapticFeedback.selectionClick();
    final newScore = (widget.score + delta).clamp(0.0, 10.0);
    final rounded = (newScore * 10).round() / 10.0;
    widget.onChanged(rounded);
  }

  void _promptDirectScoreInput(BuildContext context) {
    final controller = TextEditingController(
      text: widget.score > 0
          ? (widget.score % 1 == 0 ? widget.score.toInt().toString() : widget.score.toStringAsFixed(1))
          : '',
    );
    final theme = Theme.of(context);

    showDialog<double>(
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
          title: Text(widget.l10n.score,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0 - 10',
              suffixText: '/ 10',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(widget.l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final entered = double.tryParse(controller.text.trim()) ?? widget.score;
                final clamped = entered.clamp(0.0, 10.0);
                Navigator.of(ctx).pop((clamped * 10).round() / 10.0);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((entered) {
      if (entered != null) widget.onChanged(entered);
    });
  }

  String get _scoreDisplay {
    final s = widget.score;
    if (s <= 0) return widget.l10n.noScore;
    return s % 1 == 0 ? s.toInt().toString() : s.toStringAsFixed(1);
  }

  void _updateFromLocalPosition(Offset local, BoxConstraints constraints, double padding) {
    final usable = constraints.maxWidth - padding * 2;
    if (usable <= 0) return;
    final raw = ((local.dx - padding) / usable).clamp(0.0, 1.0);
    final value = (raw * 10.0 * 10).round() / 10.0; // snap a 0.1
    if (value != widget.score) {
      HapticFeedback.selectionClick();
      widget.onChanged(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final glass = widget.glass;
    final accent = theme.colorScheme.primary;
    final hasScore = widget.score > 0.0;
    final fraction = (widget.score / 10.0).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta + badge interactivo
        SizedBox(
          height: 18,
          child: Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 13,
                color: hasScore
                    ? accent
                    : (glass
                        ? Colors.white.withValues(alpha: 0.62)
                        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8)),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  widget.l10n.score,
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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _promptDirectScoreInput(context),
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasScore
                          ? accent.withValues(alpha: glass ? 0.24 : (theme.brightness == Brightness.dark ? 0.2 : 0.13))
                          : glass
                              ? Colors.white.withValues(alpha: 0.08)
                              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: hasScore
                            ? accent.withValues(alpha: 0.4)
                            : glass
                                ? Colors.white.withValues(alpha: 0.16)
                                : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasScore) ...[
                          Icon(Icons.star_rounded, size: 10, color: accent),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          hasScore ? _scoreDisplay : widget.l10n.noScore,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: hasScore
                                ? (glass ? Colors.white : accent)
                                : (glass
                                    ? Colors.white.withValues(alpha: 0.75)
                                    : theme.colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Contenedor del slider: botones rápidos + pista custom
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: glass
                ? Colors.white.withValues(alpha: 0.06)
                : theme.colorScheme.surfaceContainerHigh.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.55 : 0.65,
                  ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: (_dragging || hasScore)
                  ? accent.withValues(alpha: _dragging ? 0.7 : 0.28)
                  : glass
                      ? Colors.white.withValues(alpha: 0.16)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: _dragging ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _QuickStepButton(
                glass: glass,
                icon: Icons.remove_rounded,
                onTap: widget.score > 0.0 ? () => _adjustScore(-0.5) : null,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const padding = 3.0;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        setState(() => _dragging = true);
                        _updateFromLocalPosition(
                          details.localPosition, constraints, padding,
                        );
                      },
                      onTapUp: (_) => setState(() => _dragging = false),
                      onTapCancel: () => _dragging = false,
                      onPanStart: (details) {
                        setState(() => _dragging = true);
                        _updateFromLocalPosition(
                          details.localPosition, constraints, padding,
                        );
                      },
                      onPanUpdate: (details) => _updateFromLocalPosition(
                        details.localPosition, constraints, padding,
                      ),
                      onPanEnd: (_) => setState(() => _dragging = false),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: SizedBox(
                          height: 40,
                          child: Center(
                            child: SizedBox(
                              height: 22, // zona de toque generosa
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  // Pista inactiva
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(2),
                                      color: glass
                                          ? Colors.white.withValues(alpha: 0.14)
                                          : theme.colorScheme.surfaceContainerHighest
                                              .withValues(alpha: 0.8),
                                    ),
                                  ),
                                  // Relleno activo animado
                                  AnimatedFractionallySizedBox(
                                    duration: _dragging
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.centerLeft,
                                    widthFactor: fraction,
                                    heightFactor: null,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(2),
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                  // Thumb redondeado
                                  AnimatedAlign(
                                    duration: _dragging
                                        ? Duration.zero
                                        : const Duration(milliseconds: 180),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment(-1.0 + fraction * 2.0, 0),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 120),
                                      width: _dragging ? 14 : 11,
                                      height: _dragging ? 14 : 11,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: accent,
                                        border: Border.all(
                                          color: glass
                                              ? Colors.black.withValues(alpha: 0.35)
                                              : theme.colorScheme.surface,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(alpha: _dragging ? 0.5 : 0.3),
                                            blurRadius: _dragging ? 8 : 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              _QuickStepButton(
                glass: glass,
                icon: Icons.add_rounded,
                onTap: widget.score < 10.0 ? () => _adjustScore(0.5) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Botón de paso rápido ±0.5 con feedback de hover.
class _QuickStepButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool glass;

  const _QuickStepButton({required this.icon, required this.onTap, this.glass = false});

  @override
  State<_QuickStepButton> createState() => _QuickStepButtonState();
}

class _QuickStepButtonState extends State<_QuickStepButton> {
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
          width: 30,
          height: 40,
          alignment: Alignment.center,
          color: _hovered && enabled
              ? (widget.glass
                  ? Colors.white.withValues(alpha: 0.10)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.06))
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
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
