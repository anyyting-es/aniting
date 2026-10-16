import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

/// Control deslizante para puntaje (Score) con estética Liquid Glass,
/// badge dinámico que respeta los colores del tema de la app (sin colores amarillos estáticos),
/// altura calibrada a 46px para alineación perfecta y entrada directa por diálogo.
class EditEntryScoreSlider extends StatelessWidget {
  final double score; // 0.0 to 10.0
  final ValueChanged<double> onChanged;
  final AppTranslations l10n;
  final BorderRadius borderRadius;

  const EditEntryScoreSlider({
    super.key,
    required this.score,
    required this.onChanged,
    required this.l10n,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  void _adjustScore(double delta) {
    HapticFeedback.selectionClick();
    final newScore = (score + delta).clamp(0.0, 10.0);
    final rounded = (newScore * 10).round() / 10.0;
    onChanged(rounded);
  }

  void _promptDirectScoreInput(BuildContext context) {
    final controller = TextEditingController(
      text: score > 0 ? (score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1)) : '',
    );
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog<double>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark
              ? theme.colorScheme.surfaceContainer
              : theme.colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l10n.score, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              hintText: '0 - 10',
              suffixText: '/ 10',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final entered = double.tryParse(controller.text.trim()) ?? score;
                final clamped = entered.clamp(0.0, 10.0);
                Navigator.of(ctx).pop((clamped * 10).round() / 10.0);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    ).then((entered) {
      if (entered != null) {
        onChanged(entered);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hasScore = score > 0.0;

    final scoreDisplay = hasScore
        ? (score % 1 == 0 ? score.toInt().toString() : score.toStringAsFixed(1))
        : l10n.noScore;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header: Icon + Label left, Badge right (Height 22px for strict grid alignment)
        SizedBox(
          height: 22,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_rounded,
                      size: 16,
                      color: hasScore ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        l10n.score,
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
              const SizedBox(width: 6),
              // Interactive Score Badge (Tap to enter direct decimal score)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _promptDirectScoreInput(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: hasScore
                          ? theme.colorScheme.primary.withValues(alpha: isDark ? 0.20 : 0.12)
                          : (isDark
                              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.05)),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: hasScore
                            ? theme.colorScheme.primary.withValues(alpha: 0.35)
                            : (isDark
                                ? theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
                                : Colors.black.withValues(alpha: 0.08)),
                        width: 0.9,
                      ),
                    ),
                    child: Text(
                      hasScore ? '$scoreDisplay / 10' : scoreDisplay,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: hasScore
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Slider Box (strictly height 46px to match status and steppers)
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 6),
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
          child: Row(
            children: [
              // Fast Step Down button [-]
              _buildQuickStepButton(
                theme: theme,
                icon: Icons.remove_rounded,
                onTap: score > 0.0 ? () => _adjustScore(-0.5) : null,
              ),

              // Slider with primary theme color
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4.0,
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    thumbColor: theme.colorScheme.primary,
                    overlayColor: theme.colorScheme.primary.withValues(alpha: 0.16),
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7.0,
                      elevation: 2.0,
                    ),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
                  ),
                  child: Slider(
                    value: score,
                    min: 0.0,
                    max: 10.0,
                    divisions: 100,
                    onChanged: (val) {
                      final rounded = (val * 10).round() / 10.0;
                      if (rounded != score) {
                        HapticFeedback.selectionClick();
                        onChanged(rounded);
                      }
                    },
                  ),
                ),
              ),

              // Fast Step Up button [+]
              _buildQuickStepButton(
                theme: theme,
                icon: Icons.add_rounded,
                onTap: score < 10.0 ? () => _adjustScore(0.5) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStepButton({
    required ThemeData theme,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    final isEnabled = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 36,
          child: Center(
            child: Icon(
              icon,
              size: 18,
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
