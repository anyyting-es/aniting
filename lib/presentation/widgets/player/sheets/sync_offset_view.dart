import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import 'package:seanime_app/core/icons/app_icons.dart';

/// Reusable subview for adjusting subtitle or audio sync delay offset (in milliseconds).
class SyncOffsetView extends ConsumerWidget {
  final String title;
  final String description;
  final int offsetMs;
  final ValueChanged<int> onOffsetChanged;
  final VoidCallback onReset;

  const SyncOffsetView({
    super.key,
    required this.title,
    required this.description,
    required this.offsetMs,
    required this.onOffsetChanged,
    required this.onReset,
  });

  Widget _buildStepButton(BuildContext context, String label, int delta) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onOffsetChanged(offsetMs + delta),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final l10n = ref.watch(translationsProvider);
    final iconPack = ref.watch(iconPackProvider);

    final formattedOffset = offsetMs == 0
        ? '0 ms (${l10n.synchronized})'
        : '${offsetMs > 0 ? '+' : ''}$offsetMs ms';

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.09)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Current offset indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: offsetMs == 0
                  ? (isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05))
                  : primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: offsetMs == 0
                    ? (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.08))
                    : primaryColor.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Text(
              formattedOffset,
              style: TextStyle(
                color: offsetMs == 0 ? theme.colorScheme.onSurfaceVariant : primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick adjustment buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildStepButton(context, '-500ms', -500),
              _buildStepButton(context, '-50ms', -50),
              _buildStepButton(context, '+50ms', 50),
              _buildStepButton(context, '+500ms', 500),
            ],
          ),

          const SizedBox(height: 14),

          // Fine slider (±5000 ms)
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: primaryColor,
              inactiveTrackColor: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1),
              thumbColor: primaryColor,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              trackHeight: 3,
              overlayColor: primaryColor.withValues(alpha: 0.2),
            ),
            child: Slider(
              min: -5000.0,
              max: 5000.0,
              divisions: 200, // 50ms per tick
              value: offsetMs.clamp(-5000, 5000).toDouble(),
              onChanged: (val) => onOffsetChanged(val.toInt()),
            ),
          ),

          const SizedBox(height: 8),

          // Reset button
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: offsetMs != 0 ? onReset : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.restore(iconPack),
                      size: 14,
                      color: offsetMs != 0
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      l10n.resetTo0ms,
                      style: TextStyle(
                        color: offsetMs != 0
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

