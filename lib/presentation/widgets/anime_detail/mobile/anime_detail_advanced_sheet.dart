import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:g1455/g1455.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:seanime_app/core/i18n/i18n_provider.dart';
import '../../../../data/models/onlinestream_models.dart';

/// Full glass modal sheet for advanced options (Dubbing switch, manual link, cache reload).
class AnimeDetailAdvancedSheet extends ConsumerStatefulWidget {
  final OnlinestreamProvider? selectedProvider;
  final bool isDubbed;
  final ValueChanged<bool> onToggleDubbed;
  final VoidCallback? onOpenManualMapping;
  final VoidCallback? onRefreshCache;

  const AnimeDetailAdvancedSheet({
    super.key,
    this.selectedProvider,
    required this.isDubbed,
    required this.onToggleDubbed,
    this.onOpenManualMapping,
    this.onRefreshCache,
  });

  @override
  ConsumerState<AnimeDetailAdvancedSheet> createState() => _AnimeDetailAdvancedSheetState();
}

class _AnimeDetailAdvancedSheetState extends ConsumerState<AnimeDetailAdvancedSheet> {
  late bool _dubbed;

  @override
  void initState() {
    super.initState();
    _dubbed = widget.isDubbed;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(translationsProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark ? Colors.white : theme.colorScheme.primary;
    final secondaryTextColor = isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant;

    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Row
            Row(
              children: [
                Icon(Icons.tune_rounded, size: 20, color: primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.advancedOptions,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.5,
                      color: isDark ? Colors.white : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                M3EIconButton(
                  variant: M3EIconButtonVariant.standard,
                  size: M3EIconButtonSize.xs,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: secondaryTextColor,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Doblaje Switch Item
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _dubbed ? Icons.record_voice_over_rounded : Icons.subtitles_rounded,
                    size: 20,
                    color: _dubbed ? theme.colorScheme.primary : secondaryTextColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.dubbing,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: isDark ? Colors.white : theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          _dubbed ? l10n.audioDubbedFull : l10n.audioSubtitled,
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  M3ESwitch(
                    value: _dubbed,
                    onChanged: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _dubbed = val);
                      widget.onToggleDubbed(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Actions: Manual Link & Cache Reload
            Row(
              children: [
                if (widget.onOpenManualMapping != null)
                  Expanded(
                    child: GlassButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onOpenManualMapping?.call();
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link_rounded, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            l10n.link,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (widget.onOpenManualMapping != null && widget.onRefreshCache != null)
                  const SizedBox(width: 10),
                if (widget.onRefreshCache != null)
                  Expanded(
                    child: GlassButton(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        widget.onRefreshCache?.call();
                        Navigator.pop(context);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.refresh_rounded, size: 17),
                          const SizedBox(width: 6),
                          Text(
                            l10n.refresh,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
