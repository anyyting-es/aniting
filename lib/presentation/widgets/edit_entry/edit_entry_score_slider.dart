import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:seanime_app/core/i18n/translations/translations.dart';

/// Control deslizante para puntaje (Score) con estética Liquid Glass,
/// badge dinámico de estrellas, precisión decimal (0.0 - 10.0) y botones rápidos de ajuste.
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
        // Header: Label left, Badge right
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star_rounded,
                    size: 17,
                    color: hasScore ? const Color(0xFFFBBF24) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: hasScore
                    ? (isDark
                        ? const Color(0xFFFBBF24).withValues(alpha: 0.18)
                        : const Color(0xFFFBBF24).withValues(alpha: 0.14))
                    : (isDark
                        ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasScore
                      ? const Color(0xFFFBBF24).withValues(alpha: 0.35)
                      : (isDark
                          ? theme.colorScheme.outlineVariant.withValues(alpha: 0.25)
                          : Colors.black.withValues(alpha: 0.08)),
                  width: 0.9,
                ),
              ),
              child: Text(
                hasScore ? '$scoreDisplay / 10' : scoreDisplay,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: hasScore
                      ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309))
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),

        // Slider Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Fast Step Down button [-]
                  _buildQuickStepButton(
                    theme: theme,
                    icon: Icons.remove_rounded,
                    onTap: score > 0.0 ? () => _adjustScore(-0.5) : null,
                  ),

                  // Slider
                  Expanded(
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 5.5,
                        activeTrackColor: const Color(0xFFFBBF24),
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.08),
                        thumbColor: const Color(0xFFF59E0B),
                        overlayColor: const Color(0xFFFBBF24).withValues(alpha: 0.18),
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8.0,
                          elevation: 3.0,
                        ),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18.0),
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
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isEnabled
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isEnabled
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08))
                  : Colors.transparent,
              width: 0.8,
            ),
          ),
          child: Icon(
            icon,
            size: 17,
            color: isEnabled
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withValues(alpha: 0.25),
          ),
        ),
      ),
    );
  }
}
